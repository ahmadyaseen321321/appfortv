package com.cct.appfortv.flutter_app

import android.app.Activity
import android.app.Application
import android.os.Bundle

/**
 * Tracks whether the app is currently in the foreground.
 *
 * Register this in MainActivity.onCreate() via:
 *   application.registerActivityLifecycleCallbacks(AppLifecycleTracker)
 *
 * ForceOpenService checks isInForeground before launching a new activity
 * to avoid spawning a second Flutter engine when the app is already open.
 */
object AppLifecycleTracker : Application.ActivityLifecycleCallbacks {

    @Volatile
    var isInForeground: Boolean = false
        private set

    private var resumedCount = 0

    override fun onActivityResumed(activity: Activity) {
        resumedCount++
        isInForeground = true
    }

    override fun onActivityPaused(activity: Activity) {
        resumedCount--
        if (resumedCount <= 0) {
            resumedCount = 0
            isInForeground = false
        }
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
    override fun onActivityStarted(activity: Activity) {}
    override fun onActivityStopped(activity: Activity) {}
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
    override fun onActivityDestroyed(activity: Activity) {}
}
