package com.cct.appfortv.flutter_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class FcmService : FirebaseMessagingService() {

    companion object {
        private const val CHANNEL_ID  = "tv_disconnect_channel"
        private const val CHANNEL_NAME = "TV Disconnect Notifications"
        private const val NOTIF_ID    = 9001
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        val data  = remoteMessage.data
        val title = data["title"] ?: remoteMessage.notification?.title ?: "Notification"
        val body  = data["body"]  ?: remoteMessage.notification?.body  ?: ""
        val type  = data["type"]  ?: data["title"]
                    ?: remoteMessage.notification?.title ?: ""

        val isDisconnect = type.equals("Disconnected", ignoreCase = true) ||
                           type.equals("Deleted",      ignoreCase = true) ||
                           type.equals("Suspended",    ignoreCase = true)

        createNotificationChannel()

        // Always show a visible banner
        showHeadsUpNotification(title, body, type)

        if (isDisconnect) {
            // ForceOpenService is a foreground service — it IS allowed to
            // call startActivity() on Android 10+, unlike a plain FCM service.
            ForceOpenService.launch(applicationContext, type)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH
            ).apply {
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }

    private fun showHeadsUpNotification(title: String, body: String, type: String) {
        val tapIntent = Intent(applicationContext, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
            putExtra("navigate_to", "code_view")
            putExtra("disconnect_type", type)
        }
        val pendingIntent = PendingIntent.getActivity(
            applicationContext, NOTIF_ID, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(Notification.DEFAULT_ALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        try {
            NotificationManagerCompat.from(applicationContext).notify(NOTIF_ID, notification)
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }
}
