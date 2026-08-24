package com.cct.appfortv.flutter_app

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * A ContentProvider whose sole purpose is to trigger app auto-launch on boot.
 *
 * ContentProviders are initialized by the Android framework BEFORE Application.onCreate()
 * whenever the app process is created for ANY reason (boot, alarm, service start, etc.).
 *
 * By marking this provider as directBootAware, the system will create the app process
 * and initialize this provider very early in the boot sequence.
 */
class BootContentProvider : ContentProvider() {

    companion object {
        private const val TAG = "BootContentProvider"
    }

    override fun onCreate(): Boolean {
        Log.d(TAG, "ContentProvider onCreate — process started")

        val ctx = context ?: return true

        // Throttle: don't launch if we already launched within the last 60 seconds
        try {
            val prefs = ctx.getSharedPreferences("boot_launch", 0)
            val lastLaunch = prefs.getLong("last_provider_launch", 0)
            val now = System.currentTimeMillis()

            if (now - lastLaunch < 60_000L) {
                Log.d(TAG, "Skipping — launched ${(now - lastLaunch) / 1000}s ago")
                return true
            }

            prefs.edit().putLong("last_provider_launch", now).apply()
        } catch (e: Exception) {
            Log.w(TAG, "Prefs check failed: ${e.message}")
        }

        // Schedule launch attempts with increasing delays
        val handler = Handler(Looper.getMainLooper())

        // Quick attempt at 2s
        handler.postDelayed({ launchApp(ctx, "2s") }, 2_000L)

        // After system settles at 8s
        handler.postDelayed({ launchApp(ctx, "8s") }, 8_000L)

        // After TV launcher fully loads at 20s
        handler.postDelayed({ launchApp(ctx, "20s") }, 20_000L)

        // Late attempt at 40s for very slow TV boxes
        handler.postDelayed({ launchApp(ctx, "40s") }, 40_000L)

        return true
    }

    private fun launchApp(ctx: android.content.Context, tag: String) {
        Log.d(TAG, "Attempting launch ($tag)")

        // Strategy 1: Direct startActivity — with background_activity_starts_enabled=1
        // this should now work on Android 11
        try {
            val launchIntent = Intent(ctx, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                putExtra("navigate_to", "session")
                putExtra("disconnect_type", "boot")
                putExtra("launched_on_boot", true)
            }
            ctx.startActivity(launchIntent)
            Log.d(TAG, "startActivity ($tag): SUCCESS")
        } catch (e: Exception) {
            Log.w(TAG, "startActivity ($tag) failed: ${e.message}")
        }

        // Strategy 2: ForceOpenService with full-screen notification
        // The full-screen intent is allowed even without background_activity_starts
        try {
            val serviceIntent = Intent(ctx, ForceOpenService::class.java).apply {
                putExtra("navigate_to", "session")
                putExtra("disconnect_type", "boot")
            }
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                ctx.startForegroundService(serviceIntent)
            } else {
                ctx.startService(serviceIntent)
            }
            Log.d(TAG, "ForceOpenService ($tag): started")
        } catch (e: Exception) {
            Log.w(TAG, "ForceOpenService ($tag) failed: ${e.message}")
        }
    }

    // Required overrides — this provider stores nothing
    override fun query(u: Uri, p: Array<String>?, s: String?, a: Array<String>?, o: String?): Cursor? = null
    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<String>?): Int = 0
}
