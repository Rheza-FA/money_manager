package com.example.money_manager

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.pdf.PdfRenderer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class ReceiptShareChannel(
    private val appCacheDir: File,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL_NAME = "neymo/receipt_share"
        private const val MAX_WIDTH_PX = 2560
        private const val MAX_TOTAL_PIXELS = 12_000_000L
        private const val MAX_PDF_PAGES = 3
        private const val PDF_TARGET_DIMENSION = 2400
        private val CURRENCY_HINT_REGEX = Regex("""(?i)\b(rp\.?|idr)\s*[0-9]""")
    }

    private sealed interface PendingState {
        data object Scanning : PendingState
        data class Ready(val payload: Map<String, Any?>) : PendingState
        data class Failed(val error: Map<String, Any?>) : PendingState
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val lock = Any()

    // Accessed exclusively on the Main Looper as recommended by ML Kit / GoogleApi.
    private var recognizer: TextRecognizer? = null

    private var dartReady = false
    private var activeJobId = 0L
    private var pendingInitial: PendingState? = null
    private var disposed = false

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "consumeInitialShare" -> {
                // Ensure any share captured right before Dart attached is drained first.
                drainPendingShare()

                val snapshot: PendingState?
                synchronized(lock) {
                    dartReady = true
                    snapshot = pendingInitial
                    if (snapshot !is PendingState.Scanning) {
                        pendingInitial = null
                    }
                }
                when (snapshot) {
                    null -> result.success(null)
                    is PendingState.Scanning -> result.success(mapOf("status" to "scanning"))
                    is PendingState.Ready -> result.success(
                        mapOf("status" to "ready", "payload" to snapshot.payload),
                    )
                    is PendingState.Failed -> result.success(
                        mapOf("status" to "error", "error" to snapshot.error),
                    )
                }
            }
            else -> result.notImplemented()
        }
    }

    fun drainPendingShare() {
        val job = SharePayloadStore.poll() ?: return
        processCapturedJob(job)
    }

    private fun processCapturedJob(job: CapturedShareJob) {
        // 1. Pure text share (no file stream was attached).
        if (!job.hadStreamUri) {
            val payload = mapOf<String, Any?>(
                "lines" to emptyList<String>(),
                "extraText" to job.extraText,
                "extraSubject" to job.extraSubject,
                "mimeType" to (job.mimeType ?: "text/plain"),
                "referrer" to job.referrer,
                "hasAttachment" to false,
            )
            deliverReady(jobId = claimJobId(job.id), payload = payload)
            return
        }

        // 2. Attachment existed, but stream capture failed in ShareReceiverActivity.
        val tempFile = job.tempFile
        if (job.captureError != null || tempFile == null) {
            runCatching { tempFile?.delete() }
            deliverFailure(
                jobId = claimJobId(job.id),
                code = job.captureError ?: "OPEN_STREAM_FAILED",
                job = job,
            )
            return
        }

        // 3. Decode bitmap(s) on background executor, then run ML Kit OCR on Main Looper.
        val jobId = startScanningJob(job.id)
        executor.execute {
            val decodedBitmaps: List<Bitmap> = try {
                decodeFileToBitmaps(tempFile, job.mimeType)
            } catch (e: IllegalArgumentException) {
                SharePayloadStore.logWarn("decode", "Invalid media: ${e.message}")
                deliverFailure(jobId = jobId, code = e.message ?: "DECODE_IMAGE_FAILED", job = job)
                return@execute
            } catch (e: OutOfMemoryError) {
                SharePayloadStore.logWarn("decode", "OutOfMemoryError during decode")
                deliverFailure(jobId = jobId, code = "IMAGE_TOO_LARGE", job = job)
                return@execute
            } catch (e: Throwable) {
                SharePayloadStore.logWarn("decode", "Decode failed: ${e.javaClass.simpleName}")
                deliverFailure(jobId = jobId, code = "DECODE_IMAGE_FAILED", job = job)
                return@execute
            } finally {
                // Delete sensitive receipt file immediately after decoding into memory.
                runCatching { tempFile.delete() }
            }

            if (decodedBitmaps.isEmpty()) {
                deliverFailure(jobId = jobId, code = "DECODE_IMAGE_FAILED", job = job)
                return@execute
            }

            mainHandler.post {
                recognizeBitmapsSequentially(
                    jobId = jobId,
                    job = job,
                    bitmaps = decodedBitmaps,
                    index = 0,
                    accumulatedLines = ArrayList(),
                )
            }
        }
    }

    fun dispose() {
        synchronized(lock) {
            disposed = true
        }
        channel.setMethodCallHandler(null)
        mainHandler.post {
            runCatching { recognizer?.close() }
            recognizer = null
        }
        executor.execute { purgeTempDir() }
        executor.shutdown()
    }

    // -------------------------------------------------------------------------
    // Main-Looper ML Kit Recognition Pipeline
    // -------------------------------------------------------------------------

    private fun getOrCreateRecognizerOnMain(): TextRecognizer {
        val existing = recognizer
        if (existing != null) return existing
        val created = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer = created
        return created
    }

    private fun recognizeBitmapsSequentially(
        jobId: Long,
        job: CapturedShareJob,
        bitmaps: List<Bitmap>,
        index: Int,
        accumulatedLines: MutableList<String>,
    ) {
        val cancelled = synchronized(lock) { disposed || jobId != activeJobId }
        if (cancelled) {
            for (i in index until bitmaps.size) {
                runCatching { bitmaps[i].recycle() }
            }
            return
        }

        if (index >= bitmaps.size) {
            if (accumulatedLines.isEmpty() && !hasStructuredReceiptText(job.extraText)) {
                SharePayloadStore.logWarn("ocr", "OCR completed with 0 recognized text lines")
                deliverFailure(jobId = jobId, code = "OCR_EMPTY", job = job)
            } else {
                val payload = mapOf<String, Any?>(
                    "lines" to accumulatedLines,
                    "extraText" to job.extraText,
                    "extraSubject" to job.extraSubject,
                    "mimeType" to job.mimeType,
                    "referrer" to job.referrer,
                    "hasAttachment" to true,
                )
                deliverReady(jobId = jobId, payload = payload)
            }
            return
        }

        val currentBitmap = bitmaps[index]
        val client: TextRecognizer = try {
            getOrCreateRecognizerOnMain()
        } catch (e: Throwable) {
            SharePayloadStore.logWarn("ocr_init", "Recognizer init failed: ${e.javaClass.simpleName}")
            for (i in index until bitmaps.size) {
                runCatching { bitmaps[i].recycle() }
            }
            deliverFailure(jobId = jobId, code = "OCR_INIT_FAILED", job = job)
            return
        }

        val inputImage = try {
            InputImage.fromBitmap(currentBitmap, 0)
        } catch (e: Throwable) {
            SharePayloadStore.logWarn("ocr_input", "InputImage failed: ${e.javaClass.simpleName}")
            for (i in index until bitmaps.size) {
                runCatching { bitmaps[i].recycle() }
            }
            deliverFailure(jobId = jobId, code = "OCR_FAILED", job = job)
            return
        }

        client.process(inputImage)
            .addOnSuccessListener { visionText ->
                val pageRows = reconstructVisualRows(visionText)
                accumulatedLines.addAll(pageRows)
                runCatching { currentBitmap.recycle() }
                recognizeBitmapsSequentially(
                    jobId = jobId,
                    job = job,
                    bitmaps = bitmaps,
                    index = index + 1,
                    accumulatedLines = accumulatedLines,
                )
            }
            .addOnFailureListener { e ->
                SharePayloadStore.logWarn("ocr_run", "ML Kit failure: ${e.javaClass.simpleName}")
                for (i in index until bitmaps.size) {
                    runCatching { bitmaps[i].recycle() }
                }
                deliverFailure(jobId = jobId, code = "OCR_FAILED", job = job)
            }
    }

    private fun hasStructuredReceiptText(extraText: String?): Boolean {
        if (extraText.isNullOrBlank()) return false
        return CURRENCY_HINT_REGEX.containsMatchIn(extraText)
    }

    // -------------------------------------------------------------------------
    // State transitions & UI-thread dispatch
    // -------------------------------------------------------------------------

    private fun claimJobId(candidateId: Long): Long = synchronized(lock) {
        activeJobId = max(activeJobId + 1, candidateId)
        activeJobId
    }

    private fun startScanningJob(candidateId: Long): Long {
        val shouldNotifyDart: Boolean
        val id: Long
        synchronized(lock) {
            id = max(activeJobId + 1, candidateId)
            activeJobId = id
            shouldNotifyDart = dartReady
            if (!dartReady) {
                pendingInitial = PendingState.Scanning
            }
        }
        if (shouldNotifyDart) {
            mainHandler.post { channel.invokeMethod("onShareStarted", null) }
        }
        return id
    }

    private fun deliverReady(jobId: Long, payload: Map<String, Any?>) {
        val shouldPushToDart: Boolean
        synchronized(lock) {
            if (disposed || jobId != activeJobId) return
            shouldPushToDart = dartReady
            pendingInitial = if (dartReady) null else PendingState.Ready(payload)
        }
        if (shouldPushToDart) {
            mainHandler.post { channel.invokeMethod("onShareResolved", payload) }
        }
    }

    private fun deliverFailure(jobId: Long, code: String, job: CapturedShareJob) {
        val errorMap = mapOf<String, Any?>(
            "code" to code,
            "referrer" to job.referrer,
            "extraText" to job.extraText,
            "extraSubject" to job.extraSubject,
            "mimeType" to job.mimeType,
        )
        val shouldPushToDart: Boolean
        synchronized(lock) {
            if (disposed || jobId != activeJobId) return
            shouldPushToDart = dartReady
            pendingInitial = if (dartReady) null else PendingState.Failed(errorMap)
        }
        if (shouldPushToDart) {
            mainHandler.post { channel.invokeMethod("onShareFailed", errorMap) }
        }
    }

    private fun purgeTempDir() {
        val dir = File(appCacheDir, "shared_receipts")
        if (!dir.exists()) return
        dir.listFiles()?.forEach { runCatching { it.delete() } }
    }

    // -------------------------------------------------------------------------
    // High-Fidelity Image & PDF Decoding (EXIF + Alpha-to-White Compositing)
    // -------------------------------------------------------------------------

    private fun decodeFileToBitmaps(file: File, mimeType: String?): List<Bitmap> {
        val isPdf = mimeType?.equals("application/pdf", ignoreCase = true) == true ||
            hasPdfHeader(file)
        return if (isPdf) {
            decodePdfPages(file)
        } else {
            listOf(decodeReceiptImage(file))
        }
    }

    private fun hasPdfHeader(file: File): Boolean {
        return try {
            val header = ByteArray(5)
            val count = file.inputStream().use { it.read(header) }
            count == 5 && String(header, Charsets.US_ASCII) == "%PDF-"
        } catch (_: Exception) {
            false
        }
    }

    private fun decodeReceiptImage(file: File): Bitmap {
        val rotationDegrees = readExifRotation(file)
        val boundsOpts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, boundsOpts)
        if (boundsOpts.outWidth <= 0 || boundsOpts.outHeight <= 0) {
            val modernFallback = decodeWithImageDecoderFallback(file)
                ?: throw IllegalArgumentException("DECODE_IMAGE_FAILED")
            return normalizeBitmapForOcr(modernFallback, rotationDegrees = 0)
        }

        // Preserve horizontal sharpness on tall 20:9 / scrollshot receipts (GoPay, BRImo)
        // by sampling down only when width exceeds MAX_WIDTH_PX or total pixels exceed budget.
        val effectiveWidth = if (rotationDegrees == 90 || rotationDegrees == 270) {
            boundsOpts.outHeight
        } else {
            boundsOpts.outWidth
        }
        val effectiveHeight = if (rotationDegrees == 90 || rotationDegrees == 270) {
            boundsOpts.outWidth
        } else {
            boundsOpts.outHeight
        }

        var sampleSize = 1
        while ((effectiveWidth / sampleSize) > MAX_WIDTH_PX ||
            ((effectiveWidth.toLong() / sampleSize) * (effectiveHeight.toLong() / sampleSize)) > MAX_TOTAL_PIXELS
        ) {
            sampleSize *= 2
        }

        val decodeOpts = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inMutable = false
        }
        val rawBitmap = BitmapFactory.decodeFile(file.absolutePath, decodeOpts)
        if (rawBitmap == null) {
            val modernFallback = decodeWithImageDecoderFallback(file)
                ?: throw IllegalArgumentException("DECODE_IMAGE_FAILED")
            return normalizeBitmapForOcr(modernFallback, rotationDegrees = 0)
        }

        return normalizeBitmapForOcr(rawBitmap, rotationDegrees)
    }

    private fun decodeWithImageDecoderFallback(file: File): Bitmap? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return null
        return runCatching {
            val source = ImageDecoder.createSource(file)
            ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                decoder.isMutableRequired = false
                val w = info.size.width
                val h = info.size.height
                var sample = 1
                while ((w / sample) > MAX_WIDTH_PX ||
                    ((w.toLong() / sample) * (h.toLong() / sample)) > MAX_TOTAL_PIXELS
                ) {
                    sample *= 2
                }
                if (sample > 1) {
                    decoder.setTargetSampleSize(sample)
                }
            }
        }.getOrNull()
    }

    /**
     * Applies EXIF rotation and composites transparent pixels onto solid white.
     * Many banking/e-wallet share cards export PNGs with transparent corners or
     * backgrounds (`0x00000000`), which otherwise flatten to black (`RGB 0,0,0`)
     * during grayscale conversion and destroy dark-glyph contrast.
     */
    private fun normalizeBitmapForOcr(source: Bitmap, rotationDegrees: Int): Bitmap {
        val needsSoftwareCopy = source.config != Bitmap.Config.ARGB_8888
        val needsWhiteComposite = source.hasAlpha()
        val needsRotation = rotationDegrees != 0

        if (!needsSoftwareCopy && !needsWhiteComposite && !needsRotation) {
            return source
        }

        try {
            val working: Bitmap = if (needsSoftwareCopy) {
                source.copy(Bitmap.Config.ARGB_8888, false)
                    ?: throw IllegalArgumentException("DECODE_IMAGE_FAILED")
            } else {
                source
            }

            val rotated: Bitmap = if (needsRotation) {
                val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
                val r = Bitmap.createBitmap(working, 0, 0, working.width, working.height, matrix, true)
                if (working !== source && r !== working) {
                    working.recycle()
                }
                r
            } else {
                working
            }

            if (!needsWhiteComposite) {
                if (rotated !== source) {
                    source.recycle()
                }
                return rotated
            }

            val flattened = Bitmap.createBitmap(
                rotated.width,
                rotated.height,
                Bitmap.Config.ARGB_8888,
            )
            val canvas = Canvas(flattened)
            canvas.drawColor(Color.WHITE)
            canvas.drawBitmap(rotated, 0f, 0f, Paint(Paint.FILTER_BITMAP_FLAG))

            if (rotated !== source) {
                rotated.recycle()
            }
            source.recycle()
            return flattened
        } catch (e: Throwable) {
            runCatching { source.recycle() }
            throw e
        }
    }

    private fun decodePdfPages(file: File): List<Bitmap> {
        val pages = ArrayList<Bitmap>()
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { pfd ->
            PdfRenderer(pfd).use { renderer ->
                val count = min(MAX_PDF_PAGES, renderer.pageCount)
                for (pageIndex in 0 until count) {
                    renderer.openPage(pageIndex).use { page ->
                        val maxSide = max(page.width, page.height).coerceAtLeast(1)
                        val scale = (PDF_TARGET_DIMENSION.toFloat() / maxSide.toFloat())
                            .coerceIn(1.5f, 3.5f)
                        val width = (page.width * scale).toInt().coerceAtLeast(1)
                        val height = (page.height * scale).toInt().coerceAtLeast(1)

                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        Canvas(bitmap).drawColor(Color.WHITE)
                        page.render(
                            bitmap,
                            null,
                            null,
                            PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY,
                        )
                        pages.add(bitmap)
                    }
                }
            }
        }
        return pages
    }

    private fun readExifRotation(file: File): Int {
        return try {
            val exif = ExifInterface(file.absolutePath)
            when (
                exif.getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            ) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90
                ExifInterface.ORIENTATION_ROTATE_180 -> 180
                ExifInterface.ORIENTATION_ROTATE_270 -> 270
                else -> 0
            }
        } catch (_: Exception) {
            0
        }
    }

    // -------------------------------------------------------------------------
    // Geometric 2-Column Visual Row Reconstruction
    // -------------------------------------------------------------------------

    private data class PositionedSegment(
        val text: String,
        val box: Rect,
        val centerY: Double,
        val height: Double,
    )

    private class VisualRow(first: PositionedSegment) {
        val segments = mutableListOf(first)
        var avgCenterY: Double = first.centerY
        var avgHeight: Double = first.height

        fun canMerge(candidate: PositionedSegment): Boolean {
            val verticalTolerance = min(avgHeight, candidate.height) * 0.55
            val centerAligned = abs(candidate.centerY - avgCenterY) <= verticalTolerance
            val topAligned = !centerAligned && segments.any { existing ->
                abs(candidate.box.top - existing.box.top) <=
                    min(existing.height, candidate.height) * 0.58
            }
            val inlineContained = !centerAligned && !topAligned && segments.any { existing ->
                val verticalOverlap =
                    min(existing.box.bottom, candidate.box.bottom) -
                        max(existing.box.top, candidate.box.top)
                verticalOverlap >= min(existing.height, candidate.height) * 0.65
            }
            if (!centerAligned && !topAligned && !inlineContained) return false

            for (existing in segments) {
                val overlapLeft = max(existing.box.left, candidate.box.left)
                val overlapRight = min(existing.box.right, candidate.box.right)
                val overlapWidth = overlapRight - overlapLeft
                if (overlapWidth > 0) {
                    val minWidth = min(existing.box.width(), candidate.box.width()).coerceAtLeast(1)
                    if (overlapWidth.toDouble() / minWidth.toDouble() > 0.25) {
                        return false
                    }
                }
            }
            return true
        }

        fun add(segment: PositionedSegment) {
            segments.add(segment)
            val n = segments.size.toDouble()
            avgCenterY = segments.sumOf { it.centerY } / n
            avgHeight = segments.sumOf { it.height } / n
        }
    }

    private fun isLikelyWatermarkNoise(text: String, confidence: Float): Boolean {
        if (confidence <= 0f || confidence >= 0.36f) return false
        if (text.any { it.isDigit() }) return false
        val lower = text.lowercase()
        if (lower == "rp" || lower == "idr") return false
        return true
    }

    private fun reconstructVisualRows(visionText: Text): List<String> {
        val positioned = mutableListOf<PositionedSegment>()
        val unpositioned = mutableListOf<String>()

        for (block in visionText.textBlocks) {
            for (line in block.lines) {
                val trimmed = line.text.trim()
                if (trimmed.isEmpty()) continue
                if (isLikelyWatermarkNoise(trimmed, line.confidence)) continue
                val box = line.boundingBox
                if (box == null) {
                    unpositioned.add(trimmed)
                } else {
                    val centerY = (box.top + box.bottom) / 2.0
                    val height = max(1, box.bottom - box.top).toDouble()
                    positioned.add(PositionedSegment(trimmed, box, centerY, height))
                }
            }
        }

        positioned.sortWith(compareBy<PositionedSegment> { it.box.top }.thenBy { it.box.left })

        val rows = mutableListOf<VisualRow>()
        for (seg in positioned) {
            val matchingRow = rows.lastOrNull { it.canMerge(seg) }
            if (matchingRow != null) {
                matchingRow.add(seg)
            } else {
                rows.add(VisualRow(seg))
            }
        }

        rows.sortBy { row -> row.segments.minOf { it.box.top } }

        val result = ArrayList<String>(rows.size + unpositioned.size)
        for (row in rows) {
            row.segments.sortBy { it.box.left }
            result.add(row.segments.joinToString(separator = "   ") { it.text })
        }
        result.addAll(unpositioned)
        return result
    }
}
