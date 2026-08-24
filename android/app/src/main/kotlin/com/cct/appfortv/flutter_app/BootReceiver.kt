package com.cct.appfortv.flutter_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives the BOOT_COMPLETED broadcast so the TV app launches
 * automatically when the Android TV box powers on.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            context.startActivity(launchIntent)
        }
    }
}
