package com.cct.appfortv.flutter_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log

/**
 * Receives BOOT_COMPLETED (and equivalents) and auto-launches the app.
 *
 * Uses multiple strategies because different TV boxes behave differently:
 *
 * 1. `am start` via Runtime.exec — Works without root on most TV boxes.
 *    Unlike context.startActivity(), this goes through the Activity Manager
 *    shell interface which bypasses background activity start restrictions.
 *
 * 2. Direct startActivity() — Works on TV boxes that whitelist boot receivers.
 *
 * 3. ForceOpenService — Foreground service with full-screen notification fallback.
 *
 * 4. AlarmManager at 5s, 15s, 30s — Catches late-boot scenarios.
 *
 * goAsync() is used so Android doesn't kill us after the default 10s timeout.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val intentAction = intent.action ?: return
        Log.d(TAG, "onReceive: action=$intentAction")

        val isBoot = intentAction == Intent.ACTION_BOOT_COMPLETED ||
                     intentAction == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
                     intentAction == "android.intent.action.QUICKBOOT_POWERON" ||
                     intentAction == "com.htc.intent.action.QUICKBOOT_POWERON" ||
                     intentAction == "android.intent.action.REBOOT" ||
                     intentAction == Intent.ACTION_MY_PACKAGE_REPLACED ||
                     intentAction == Intent.ACTION_USER_PRESENT

        if (!isBoot) return

        // Use goAsync() to extend the BroadcastReceiver timeout from 10s to 30s
        val pendingResult = goAsync()

        Thread {
            try {
                performLaunch(context)
            } catch (e: Exception) {
                Log.e(TAG, "Launch sequence error: ${e.message}")
            } finally {
                pendingResult.finish()
            }
        }.start()
    }

    private fun performLaunch(context: Context) {
        Log.d(TAG, "Boot detected — starting multi-strategy launch sequence")

        // Wake the screen
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wl = pm.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "tvapp:boot_wake"
            )
            wl.acquire(30_000L)
        } catch (e: Exception) {
            Log.w(TAG, "WakeLock acquire failed: ${e.message}")
        }

        // Small delay to let the system settle
        Thread.sleep(2_000L)

        // ── Strategy 1: `am start` via shell (NO ROOT NEEDED) ─────────────────
        // This is the most reliable method on Android TV boxes.
        // The `am` command talks directly to ActivityManagerService via Binder,
        // bypassing the background-activity-start restriction that silently
        // drops context.startActivity() calls from BroadcastReceivers on Android 10+.
        try {
            val pkg = context.packageName
            val process = Runtime.getRuntime().exec(
                arrayOf("am", "start",
                    "-n", "$pkg/$pkg.MainActivity",
                    "-a", "android.intent.action.MAIN",
                    "-c", "android.intent.category.LAUNCHER",
                    "-f", "0x10200000",  // FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                    "--es", "navigate_to", "session",
                    "--es", "disconnect_type", "boot",
                    "--ez", "launched_on_boot", "true")
            )
            val exitCode = process.waitFor()
            Log.d(TAG, "Strategy 1 (am start): exitCode=$exitCode")
            if (exitCode == 0) {
                Log.d(TAG, "Strategy 1 (am start): SUCCESS")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Strategy 1 (am start) failed: ${e.message}")
        }

        // ── Strategy 2: PendingIntent.send() ──────────────────────────────────
        try {
            val launchIntent = buildLaunchIntent(context)
            val pi = PendingIntent.getActivity(
                context, 900, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            pi.send()
            Log.d(TAG, "Strategy 2 (PendingIntent.send): SUCCESS")
        } catch (e: Exception) {
            Log.w(TAG, "Strategy 2 (PendingIntent.send) failed: ${e.message}")
        }

        // ── Strategy 3: Direct startActivity() ───────────────────────────────
        try {
            context.startActivity(buildLaunchIntent(context))
            Log.d(TAG, "Strategy 3 (direct startActivity): SUCCESS")
        } catch (e: Exception) {
            Log.w(TAG, "Strategy 3 (direct startActivity) failed: ${e.message}")
        }

        // ── Strategy 4: ForceOpenService ──────────────────────────────────────
        try {
            val serviceIntent = Intent(context, ForceOpenService::class.java).apply {
                putExtra("navigate_to", "session")
                putExtra("disconnect_type", "boot")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "Strategy 4: ForceOpenService started")
        } catch (e: Exception) {
            Log.e(TAG, "Strategy 4 (ForceOpenService) failed: ${e.message}")
        }

        // ── Strategy 5: AlarmManager backups ──────────────────────────────────
        scheduleAlarm(context, 5_000L, 5)
        scheduleAlarm(context, 15_000L, 15)
        scheduleAlarm(context, 30_000L, 30)
    }

    private fun buildLaunchIntent(context: Context): Intent {
        return (context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("navigate_to", "session")
            putExtra("disconnect_type", "boot")
            putExtra("launched_on_boot", true)
        }
    }

    private fun scheduleAlarm(context: Context, delayMs: Long, tag: Int) {
        try {
            val alarmIntent = Intent(context, LaunchAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context, tag, alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAt = SystemClock.elapsedRealtime() + delayMs
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent
            )
            Log.d(TAG, "AlarmManager set for ${delayMs / 1000}s (tag=$tag)")
        } catch (e: Exception) {
            Log.e(TAG, "AlarmManager schedule failed (tag=$tag): ${e.message}")
        }
    }
}
