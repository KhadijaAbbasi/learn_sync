package com.example.learnsync

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "learnsync/live_lockdown"
    private var lockdownActive = false
    private var previousInterruptionFilter: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> result.success(enableLockdown())
                    "disable" -> {
                        disableLockdown()
                        result.success(null)
                    }
                    "openNotificationPolicySettings" ->
                        result.success(openNotificationPolicySettings())
                    else -> result.notImplemented()
                }
            }
    }

    private fun enableLockdown(): Map<String, Any?> {
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )

        var screenPinning = false
        try {
            startLockTask()
            screenPinning = true
        } catch (_: Exception) {
            screenPinning = false
        }

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        var dnd = false
        var needsDndPermission = false
        if (nm.isNotificationPolicyAccessGranted) {
            previousInterruptionFilter = nm.currentInterruptionFilter
            nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
            dnd = true
        } else {
            needsDndPermission = true
        }

        lockdownActive = true
        return mapOf(
            "keepScreenOn" to true,
            "secure" to true,
            "screenPinning" to screenPinning,
            "dnd" to dnd,
            "needsDndPermission" to needsDndPermission,
            "platform" to "android",
            "note" to
                "Best-effort Android lockdown. Calls and other apps are not " +
                "fully blocked without Device Owner / MDM. Screen pinning " +
                "needs the system pin confirmation; DND needs policy access.",
        )
    }

    private fun disableLockdown() {
        if (!lockdownActive) {
            // Still clear flags in case of a partial enable.
        }
        try {
            stopLockTask()
        } catch (_: Exception) {
            // Not pinned, or already stopped.
        }
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.isNotificationPolicyAccessGranted) {
            val restore = previousInterruptionFilter
                ?: NotificationManager.INTERRUPTION_FILTER_ALL
            nm.setInterruptionFilter(restore)
        }
        previousInterruptionFilter = null
        lockdownActive = false
    }

    private fun openNotificationPolicySettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun onDestroy() {
        if (lockdownActive) {
            disableLockdown()
        }
        super.onDestroy()
    }
}
