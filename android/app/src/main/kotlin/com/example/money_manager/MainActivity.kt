package com.example.money_manager

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var receiptShareChannel: ReceiptShareChannel? = null
    private var tactileHapticChannel: TactileHapticChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        tactileHapticChannel = TactileHapticChannel(
            context = applicationContext,
            messenger = messenger,
        )

        val channel = ReceiptShareChannel(
            appCacheDir = applicationContext.cacheDir,
            messenger = messenger,
        )
        receiptShareChannel = channel
        channel.drainPendingShare()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiptShareChannel?.drainPendingShare()
    }

    override fun onResume() {
        super.onResume()
        receiptShareChannel?.drainPendingShare()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        tactileHapticChannel?.dispose()
        tactileHapticChannel = null
        receiptShareChannel?.dispose()
        receiptShareChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
