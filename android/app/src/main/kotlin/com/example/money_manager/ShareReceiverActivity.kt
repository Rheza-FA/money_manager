package com.example.money_manager

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.UUID

internal data class CapturedShareJob(
    val id: Long,
    val tempFile: File?,
    val hadStreamUri: Boolean,
    val captureError: String?,
    val extraText: String?,
    val extraSubject: String?,
    val mimeType: String?,
    val referrer: String?,
)

/**
 * In-process thread-safe handoff queue between [ShareReceiverActivity] and
 * [ReceiptShareChannel]. Keeping shared payloads in memory inside our own UID
 * eliminates external Intent-extra spoofing and survives cold-start engine init.
 */
internal object SharePayloadStore {
    private const val TAG = "NeymoReceiptShare"
    private val lock = Any()
    private var nextId = 0L
    private var latestJob: CapturedShareJob? = null

    fun nextJobId(): Long = synchronized(lock) { ++nextId }

    fun publish(job: CapturedShareJob) {
        var supersededFile: File? = null
        synchronized(lock) {
            supersededFile = latestJob?.tempFile
            latestJob = job
        }
        if (supersededFile != null && supersededFile != job.tempFile) {
            runCatching { supersededFile?.delete() }
        }
    }

    fun poll(): CapturedShareJob? = synchronized(lock) {
        val job = latestJob
        latestJob = null
        job
    }

    fun logWarn(stage: String, detail: String) {
        Log.w(TAG, "[$stage] $detail")
    }
}

/**
 * Dedicated translucent trampoline Activity that receives `ACTION_SEND` /
 * `ACTION_SEND_MULTIPLE` directly inside the sender's share flow.
 *
 * Copying the shared `content://` stream synchronously inside [onCreate]
 * guarantees that temporary `FLAG_GRANT_READ_URI_PERMISSION` grants from
 * banking/e-wallet `FileProvider`s (GoPay, BRImo, myBCA, Livin', etc.) are
 * consumed while valid—avoiding `singleTask` cross-task permission drops and
 * stale `Activity.getReferrer()` values on Android 11–16 / MIUI / HyperOS.
 */
class ShareReceiverActivity : Activity() {

    companion object {
        const val ACTION_INTERNAL_SHARE = "com.example.money_manager.ACTION_INTERNAL_SHARE"
        private const val MAX_SHARED_BYTES = 20L * 1024L * 1024L // 20 MB cap
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val incoming = intent
        if (incoming != null &&
            (incoming.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) == 0 &&
            (incoming.action == Intent.ACTION_SEND || incoming.action == Intent.ACTION_SEND_MULTIPLE)
        ) {
            captureAndEnqueue(incoming)
            launchMainActivity()
        }

        finish()
        suppressTransition()
    }

    private fun captureAndEnqueue(intent: Intent) {
        val streamUri = extractStreamUri(intent)
        val extraText = extractText(intent, hasStream = streamUri != null)
        val extraSubject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        val mimeType = resolveMimeType(intent, streamUri)
        val callerReferrer = extractFreshReferrer(intent)

        if (streamUri == null && extraText.isNullOrBlank() && extraSubject.isNullOrBlank()) {
            SharePayloadStore.logWarn("capture", "Empty share intent ignored")
            return
        }

        val jobId = SharePayloadStore.nextJobId()

        if (streamUri == null) {
            SharePayloadStore.publish(
                CapturedShareJob(
                    id = jobId,
                    tempFile = null,
                    hadStreamUri = false,
                    captureError = null,
                    extraText = extraText,
                    extraSubject = extraSubject,
                    mimeType = mimeType ?: "text/plain",
                    referrer = callerReferrer,
                ),
            )
            return
        }

        if (isForbiddenInternalUri(streamUri)) {
            SharePayloadStore.logWarn("security", "Blocked internal URI scheme=${streamUri.scheme}")
            SharePayloadStore.publish(
                CapturedShareJob(
                    id = jobId,
                    tempFile = null,
                    hadStreamUri = true,
                    captureError = "FORBIDDEN_URI",
                    extraText = extraText,
                    extraSubject = extraSubject,
                    mimeType = mimeType,
                    referrer = callerReferrer,
                ),
            )
            return
        }

        var copiedFile: File? = null
        var errorCode: String? = null
        try {
            openSharedStream(streamUri).use { stream ->
                if (stream == null) {
                    errorCode = "OPEN_STREAM_FAILED"
                } else {
                    copiedFile = copyStreamBounded(stream)
                }
            }
        } catch (e: SecurityException) {
            SharePayloadStore.logWarn("stream", "SecurityException: ${e.javaClass.simpleName}")
            errorCode = "SECURITY_ERROR"
        } catch (e: IllegalArgumentException) {
            SharePayloadStore.logWarn("stream", "Invalid stream: ${e.message}")
            errorCode = e.message ?: "INVALID_FILE"
        } catch (e: Exception) {
            SharePayloadStore.logWarn("stream", "Stream copy failed: ${e.javaClass.simpleName}")
            errorCode = "OPEN_STREAM_FAILED"
        }

        SharePayloadStore.publish(
            CapturedShareJob(
                id = jobId,
                tempFile = copiedFile,
                hadStreamUri = true,
                captureError = errorCode,
                extraText = extraText,
                extraSubject = extraSubject,
                mimeType = mimeType,
                referrer = callerReferrer,
            ),
        )
    }

    private fun openSharedStream(uri: Uri): InputStream? {
        var securityError: SecurityException? = null
        try {
            val direct = contentResolver.openInputStream(uri)
            if (direct != null) return direct
        } catch (e: SecurityException) {
            securityError = e
        } catch (_: Exception) {
            // Fall through to AssetFileDescriptor fallback.
        }

        try {
            val afdStream = contentResolver.openAssetFileDescriptor(uri, "r")?.createInputStream()
            if (afdStream != null) return afdStream
        } catch (e: SecurityException) {
            if (securityError == null) securityError = e
        } catch (_: Exception) {
            // Fall through.
        }

        if (securityError != null) throw securityError
        return null
    }

    private fun copyStreamBounded(input: InputStream): File {
        val shareDir = File(applicationContext.cacheDir, "shared_receipts")
        if (!shareDir.exists()) shareDir.mkdirs()

        val outFile = File(shareDir, "share_${UUID.randomUUID()}.tmp")
        var total = 0L
        val buffer = ByteArray(32 * 1024)

        FileOutputStream(outFile).use { out ->
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                if (read == 0) continue
                total += read
                if (total > MAX_SHARED_BYTES) {
                    out.close()
                    outFile.delete()
                    throw IllegalArgumentException("FILE_TOO_LARGE")
                }
                out.write(buffer, 0, read)
            }
        }

        if (total == 0L) {
            outFile.delete()
            throw IllegalArgumentException("EMPTY_FILE")
        }
        return outFile
    }

    private fun extractStreamUri(intent: Intent): Uri? {
        // 1. Standard EXTRA_STREAM as Uri
        val singleUri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            runCatching { intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java) }.getOrNull()
        } else {
            @Suppress("DEPRECATION")
            runCatching { intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri }.getOrNull()
        }
        if (singleUri != null && isSupportedStreamUri(singleUri)) return singleUri

        // 2. ArrayList<Uri> in EXTRA_STREAM (ACTION_SEND_MULTIPLE or non-standard ACTION_SEND senders)
        val uriList: ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            runCatching { intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java) }.getOrNull()
        } else {
            @Suppress("DEPRECATION")
            runCatching { intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) }.getOrNull()
        }
        val listCandidate = uriList?.firstOrNull { isSupportedStreamUri(it) }
        if (listCandidate != null) return listCandidate

        // 3. String URI fallback in EXTRA_STREAM
        val rawStr = runCatching { intent.getStringExtra(Intent.EXTRA_STREAM) }.getOrNull()
        if (!rawStr.isNullOrBlank()) {
            val parsed = runCatching { Uri.parse(rawStr.trim()) }.getOrNull()
            if (parsed != null && isSupportedStreamUri(parsed)) return parsed
        }

        // 4. Inspect ALL ClipData items (item[0] can be text/https while item[1] holds the content:// URI)
        val clip = intent.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                val itemUri = clip.getItemAt(i)?.uri
                if (itemUri != null && isSupportedStreamUri(itemUri)) return itemUri
            }
        }

        return null
    }

    private fun isSupportedStreamUri(uri: Uri): Boolean {
        val scheme = uri.scheme ?: return false
        return scheme.equals("content", ignoreCase = true) ||
            scheme.equals("file", ignoreCase = true)
    }

    private fun extractText(intent: Intent, hasStream: Boolean): String? {
        val direct = intent.getStringExtra(Intent.EXTRA_TEXT)
        if (!direct.isNullOrBlank()) return direct

        val charSeq = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        if (!charSeq.isNullOrBlank()) return charSeq

        if (!hasStream) {
            val clip = intent.clipData
            if (clip != null) {
                for (i in 0 until clip.itemCount) {
                    val text = runCatching {
                        clip.getItemAt(i)?.coerceToText(this)?.toString()
                    }.getOrNull()
                    if (!text.isNullOrBlank()) return text
                }
            }
        }
        return null
    }

    private fun resolveMimeType(intent: Intent, streamUri: Uri?): String? {
        if (streamUri != null) {
            val resolved = runCatching { contentResolver.getType(streamUri) }.getOrNull()
            if (!resolved.isNullOrBlank()) return resolved
        }
        return intent.type
    }

    private fun extractFreshReferrer(intent: Intent): String? {
        val callingPkg = callingPackage
        if (!callingPkg.isNullOrBlank() && callingPkg != "android") {
            return callingPkg
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            val ref = runCatching { referrer }.getOrNull()
            val host = ref?.host
            if (!host.isNullOrBlank() && host != "android") {
                return host
            }
            val str = ref?.toString()
            if (!str.isNullOrBlank() && !str.endsWith("//android")) {
                return str
            }
        }
        val extraRef: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            runCatching { intent.getParcelableExtra(Intent.EXTRA_REFERRER, Uri::class.java) }.getOrNull()
        } else {
            @Suppress("DEPRECATION")
            runCatching { intent.getParcelableExtra(Intent.EXTRA_REFERRER) as? Uri }.getOrNull()
        }
        return extraRef?.host?.takeIf { it.isNotBlank() }
            ?: intent.getStringExtra(Intent.EXTRA_REFERRER_NAME)
    }

    private fun isForbiddenInternalUri(uri: Uri): Boolean {
        if ("content".equals(uri.scheme, ignoreCase = true)) {
            val auth = uri.authority ?: return true
            return auth.equals(packageName, ignoreCase = true) ||
                auth.startsWith("$packageName.", ignoreCase = true)
        }
        if (!"file".equals(uri.scheme, ignoreCase = true)) return false
        val path = uri.path ?: return true
        return try {
            val targetFile = File(path)
            val appDirFile = File(applicationInfo.dataDir)
            val canonicalTarget = targetFile.canonicalPath
            val canonicalAppDir = appDirFile.canonicalPath
            canonicalTarget == canonicalAppDir ||
                canonicalTarget.startsWith("$canonicalAppDir${File.separator}") ||
                targetFile.absolutePath.startsWith(appDirFile.absolutePath)
        } catch (_: Exception) {
            true
        }
    }

    private fun launchMainActivity() {
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_INTERNAL_SHARE
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
        }
        startActivity(mainIntent)
    }

    private fun suppressTransition() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            overrideActivityTransition(OVERRIDE_TRANSITION_OPEN, 0, 0)
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }
    }
}
