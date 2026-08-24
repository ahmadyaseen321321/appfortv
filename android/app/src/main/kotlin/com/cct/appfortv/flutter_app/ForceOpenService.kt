package com.cct.appfortv.flutter_app

import android.app.ActivityManager
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

class ForceOpenService : Service() {

    companion object {
        private const val CHANNEL_ID    = "force_open_channel"
        private const val EXTRA_TYPE    = "disconnect_type"
        private const val WAKE_LOCK_TAG = "tvapp:disconnect_wake"

        fun launch(context: Context, disconnectType: String) {
            val intent = Intent(context, ForceOpenService::class.java).apply {
                putExtra(EXTRA_TYPE, disconnectType)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** True if our MainActivity is currently the top visible activity. */
        private fun isAppInForeground(context: Context): Boolean {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            @Suppress("DEPRECATION")
            val tasks = am.getRunningTasks(1)
            if (tasks.isNullOrEmpty()) return false
            val topActivity = tasks[0].topActivity ?: return false
            return topActivity.packageName == context.packageName
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val disconnectType = intent?.getStringExtra("disconnect_type") ?: "Disconnected"
        val navigateTo = intent?.getStringExtra("navigate_to") ?: "code_view"

        // Must call startForeground immediately
        startForeground(startId, buildSilentNotification())

        // For boot launch — just open the app normally (no code_view flag)
        if (navigateTo == "session") {
            android.util.Log.d("ForceOpenService", "Boot launch — opening app")
            val launchIntent = Intent(applicationContext, MainActivity::class.java).apply {
                setAction(Intent.ACTION_MAIN)
                addCategory(Intent.CATEGORY_LAUNCHER)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("launched_on_boot", true)
            }
            applicationContext.startActivity(launchIntent)

            // Keep the foreground service alive for 6 seconds so Android doesn't
            // kill the process before MainActivity has fully rendered.
            // Once the activity is visible, the process stays alive on its own.
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                stopSelf(startId)
            }, 6000L)

            return START_NOT_STICKY
        }

        if (isAppInForeground(applicationContext)) {
            android.util.Log.d("ForceOpenService",
                "App is in foreground — Flutter handles navigation, skipping launch")
            stopSelf(startId)
            return START_NOT_STICKY
        }

        // App is in background or killed — wake screen and launch to CodeView
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
