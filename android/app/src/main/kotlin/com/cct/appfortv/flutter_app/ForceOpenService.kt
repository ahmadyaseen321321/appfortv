package com.cct.appfortv.flutter_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Foreground service that wakes the screen and launches MainActivity.
 *
 * IMPORTANT: This service should only run when the app is NOT already
 * in the foreground. When the app is open, Flutter's onMessage listener
 * handles navigation directly — launching a new activity would spawn a
 * second Flutter engine and break navigation.
 *
 * AppLifecycleTracker (registered in MainActivity) tracks whether the
 * app is currently in the foreground so we can skip the launch if so.
 */
class ForceOpenService : Service() {

    companion object {
        private const val CHANNEL_ID = "force_open_channel"
        private const val EXTRA_TYPE = "disconnect_type"
        private const val WAKE_LOCK_TAG = "tvapp:disconnect_wake"

        fun launch(context: Context, disconnectType: String) {
            // Skip if app is already in foreground — Flutter handles it there
            if (AppLifecycleTracker.isInForeground) {
                android.util.Log.d("ForceOpenService",
                    "App is in foreground — skipping activity launch, Flutter handles it")
                return
            }

            val intent = Intent(context, ForceOpenService::class.java).apply {
                putExtra(EXTRA_TYPE, disconnectType)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val disconnectType = intent?.getStringExtra(EXTRA_TYPE) ?: "Disconnected"

        // Double-check — if app came to foreground between the check and here, skip
        if (AppLifecycleTracker.isInForeground) {
            android.util.Log.d("ForceOpenService", "App now in foreground — skipping launch")
            stopSelf(startId)
            return START_NOT_STICKY
        }

        startForeground(startId, buildSilentNotification())

        // Acquire wake lock to turn screen on
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = pm.newWakeLock(
            PowerManager.FULL_WAKE_LOCK        or
            PowerManager.ACQUIRE_CAUSES_WAKEUP or
            PowerManager.ON_AFTER_RELEASE,
            WAKE_LOCK_TAG
        )
        wakeLock.acquire(10_000L)

        val launchIntent = Intent(applicationContext, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
            putExtra("navigate_to", "code_view")
            putExtra("disconnect_type", disconnectType)
        }
        applicationContext.startActivity(launchIntent)

        wakeLock.release()
        stopSelf(startId)
        return START_NOT_STICKY
    }

    private fun buildSilentNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "TV App", NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("TV App")
            .setContentText("Updating…")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .build()
    }
}
