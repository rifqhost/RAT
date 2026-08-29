package com.rmodz.rmodz_agent

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.graphics.Path
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Accessibility service used to inject touch gestures, navigation and text.
 *
 * This service is only active while a session has granted the TOUCH permission.
 * It is consent-based: the user must enable it in system settings manually.
 */
class RMODZAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "RMODZAccess"

        @Volatile
        var instance: RMODZAccessibilityService? = null
            private set

        /** Dispatches a touch gesture at normalized (0..1) coordinates. */
        fun touch(activity: Context?, action: Int, xNorm: Double, yNorm: Double): Boolean {
            val svc = instance ?: return false
            val (w, h) = svc.getRealDisplaySize()
            val x = (xNorm * w).toFloat()
            val y = (yNorm * h).toFloat()
            svc.dispatchTouch(action, x, y)
            return true
        }

        /** Performs a global system action: BACK, HOME, RECENTS. */
        fun global(activity: Context?, action: String): Boolean {
            val svc = instance ?: return false
            return svc.performGlobalActionSafely(action)
        }

        /** Inserts text into the currently focused field. */
        fun setText(activity: Context?, text: String): Boolean {
            val svc = instance ?: return false
            return svc.injectText(text)
        }
    }

    private fun getRealDisplaySize(): kotlin.Pair<Int, Int> {
        val display = runCatching {
            @Suppress("DEPRECATION")
            val displayMetrics = resources.displayMetrics
            Pair(displayMetrics.widthPixels, displayMetrics.heightPixels)
        }.getOrDefault(Pair(1080, 2400))
        return display
    }

    private fun dispatchTouch(action: Int, x: Float, y: Float) {
        // Android's accessibility gesture API dispatches complete gestures (down->move->up),
        // not individual MotionEvent actions. For the touch-control MVP we synthesize a tap
        // (down + up) at the given coordinate for every event the controller sends, which
        // gives reliable click/select behaviour across apps.
        try {
            val path = Path()
            path.moveTo(x, y)
            val stroke = GestureDescription.StrokeDescription(path, 0, 60)
            val gesture = GestureDescription.Builder()
                .addStroke(stroke)
                .build()
            dispatchGesture(gesture, null, null)
        } catch (e: Exception) {
            Log.e(TAG, "dispatchTouch failed", e)
        }
    }

    private fun performGlobalActionSafely(action: String): Boolean {
        val mapped = when (action.uppercase()) {
            "HOME" -> AccessibilityService.GLOBAL_ACTION_HOME
            "BACK" -> AccessibilityService.GLOBAL_ACTION_BACK
            "RECENTS" -> AccessibilityService.GLOBAL_ACTION_RECENTS
            else -> return false
        }
        return performGlobalAction(mapped)
    }

    private fun injectText(text: String): Boolean {
        if (text.isEmpty()) return false
        val root = rootInActiveWindow ?: return false
        var node: AccessibilityNodeInfo? = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: root
        // if the focused node is not editable, search the tree
        if (node != null && !node.isEditable) {
            node = findFirstEditable(node)
        }
        if (node == null || !node.isEditable) return false
        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        }
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    private fun findFirstEditable(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (root.isEditable) return root
        for (i in 0 until root.childCount) {
            val child = root.getChild(i) ?: continue
            if (child.isEditable) return child
            val nested = findFirstEditable(child)
            if (nested != null) return nested
        }
        return null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // used to keep the service alive; no filtering required here
    }

    override fun onInterrupt() {
        // no-op
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        if (instance === this) instance = null
        return super.onUnbind(intent)
    }
}
