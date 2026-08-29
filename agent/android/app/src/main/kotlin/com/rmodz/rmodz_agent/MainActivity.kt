package com.rmodz.rmodz_agent

import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "rmodz_native"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                "dispatchTouch" -> {
                    val args = call.arguments as? Map<*, *>
                    val action = (args?.get("action") as? Number)?.toInt() ?: 1
                    val x = (args?.get("x") as? Number)?.toDouble() ?: 0.5
                    val y = (args?.get("y") as? Number)?.toDouble() ?: 0.5
                    result.success(RMODZAccessibilityService.touch(this, action, x, y))
                }
                "globalAction" -> {
                    val action = (call.arguments as? Map<*, *>)?.get("action") as? String ?: ""
                    result.success(RMODZAccessibilityService.global(this, action))
                }
                "setText" -> {
                    val text = (call.arguments as? Map<*, *>)?.get("text") as? String ?: ""
                    result.success(RMODZAccessibilityService.setText(this, text))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val expected = "$packageName/${RMODZAccessibilityService::class.java.name}"
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled
            .split(':')
            .any { it.equals(expected, ignoreCase = true) }
    }

    private fun openAccessibilitySettings() {
        try {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        } catch (_: Exception) {
            // fall back to app settings if accessibility intent is unavailable
            try {
                startActivity(Intent(Settings.ACTION_SETTINGS))
            } catch (_: Exception) {
                // ignore
            }
        }
    }
}
