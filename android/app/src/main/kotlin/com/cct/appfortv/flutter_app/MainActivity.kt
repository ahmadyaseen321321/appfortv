package com.cct.appfortv.flutter_app

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.cct.appfortv/notification"
    }

    private var pendingNavigateTo: String? = null
    private var pendingDisconnectType: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Register lifecycle tracker so ForceOpenService knows if app is in foreground
        application.registerActivityLifecycleCallbacks(AppLifecycleTracker)
        extractIntentExtras(intent)
        applyWakeFlags(intent)

        // If launched on boot, move to front immediately so the TV launcher
        // can't push us to background and get us killed
        if (intent?.getBooleanExtra("launched_on_boot", false) == true) {
            moveTaskToFront()
        }
    }

    private fun moveTaskToFront() {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        am.moveTaskToFront(taskId, android.app.ActivityManager.MOVE_TASK_WITH_HOME)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractIntentExtras(intent)
        applyWakeFlags(intent)
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            sendPendingNavigationToFlutter(messenger)
        }
    }

    /**
     * If this activity was launched by a disconnect notification, turn the
     * screen on and bring the window to front — even if the device is asleep.
     */
    private fun applyWakeFlags(intent: Intent?) {
        if (intent?.getStringExtra("navigate_to") == "code_view") {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            }
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON        or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON        or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED      or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingNavigation" -> {
                        if (pendingNavigateTo != null) {
                            result.success(mapOf(
                                "navigate_to"     to pendingNavigateTo,
                                "disconnect_type" to (pendingDisconnectType ?: "")
                            ))
                            pendingNavigateTo    = null
                            pendingDisconnectType = null
                        } else {
                            result.success(null)
                        }
                    }
                    // Called by Flutter background isolate to launch the app
                    "sendDisconnectBroadcast" -> {
                        val args = call.arguments as? Map<*, *>
                        val disconnectType = args?.get("disconnect_type")?.toString() ?: "Disconnected"
                        DisconnectReceiver.send(applicationContext, disconnectType)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun extractIntentExtras(intent: Intent?) {
        val nav = intent?.getStringExtra("navigate_to")
        if (nav != null) {
            pendingNavigateTo     = nav
            pendingDisconnectType = intent.getStringExtra("disconnect_type")
        }
    }

    private fun sendPendingNavigationToFlutter(
        messenger: io.flutter.plugin.common.BinaryMessenger
    ) {
        if (pendingNavigateTo == null) return
        MethodChannel(messenger, CHANNEL).invokeMethod(
            "navigateTo",
            mapOf(
                "navigate_to"     to pendingNavigateTo,
                "disconnect_type" to (pendingDisconnectType ?: "")
            )
        )
        pendingNavigateTo    = null
        pendingDisconnectType = null
    }

    /**
     * Catch any remote control key press that Flutter didn't consume and
     * exit the app — mirrors the GestureDetector tap behaviour in main_view.
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // Let Flutter handle it first; if it returns false (not consumed),
        // we exit the app.
        val handled = super.onKeyDown(keyCode, event)
        if (!handled) {
            finishAffinity()  // closes app and removes from recents
        }
        return true
    }
}
