package com.cct.appfortv.flutter_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager

/**
 * Receives the internal "disconnect" broadcast sent by the Flutter
 * background isolate (via the platform channel) and launches the app.
 *
 * This works even when the notification payload has a `notification` block
 * (which bypasses FcmService) because the Flutter background isolate
 * sends this broadcast after saving the disconnect flag to SharedPreferences.
 */
class DisconnectReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION = "com.cct.appfortv.flutter_app.DISCONNECT"
        const val EXTRA_TYPE = "disconnect_type"

        fun send(context: Context, disconnectType: String) {
            val intent = Intent(ACTION).apply {
                setPackage(context.packageName)
                putExtra(EXTRA_TYPE, disconnectType)
            }
            context.sendBroadcast(intent)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return

        val disconnectType = intent.getStringExtra(EXTRA_TYPE) ?: "Disconnected"

        // Acquire wake lock to turn screen on
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = pm.newWakeLock(
            PowerManager.FULL_WAKE_LOCK        or
            PowerManager.ACQUIRE_CAUSES_WAKEUP or
            PowerManager.ON_AFTER_RELEASE,
            "tvapp:disconnect_broadcast"
        )
        wakeLock.acquire(10_000L)

        // Launch MainActivity — BroadcastReceivers CAN call startActivity
        // when the device is not in strict background restriction mode
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("navigate_to", "code_view")
            putExtra("disconnect_type", disconnectType)
        }
        context.startActivity(launchIntent)

        wakeLock.release()
    }
}
