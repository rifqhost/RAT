package com.rmodz.rmodz_agent

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.graphics.Path
import android.os.Build
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

        /** Duration per gesture segment so the synthesized timeline tracks real input. */
        private const val MOVE_SEGMENT_MS = 20L

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

    // Accessibility gesture state so an ordered down -> move... -> up sequence is
    // synthesized as a real drag/gesture instead of one tap per event.
    private var pendingStroke: GestureDescription.StrokeDescription? = null
    private var strokeEndTime: Long = 0
    private var lastX = 0f
    private var lastY = 0f

    private fun dispatchTouch(action: Int, x: Float, y: Float) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            dispatchTap(x, y)
            return
        }
        when (action) {
            0 -> beginStroke(x, y)        // ACTION_DOWN
            2 -> moveStroke(x, y)         // ACTION_MOVE
            1 -> endStroke(x, y)          // ACTION_UP
            else -> dispatchTap(x, y)
        }
    }

    /** Starts a press-and-hold stroke that subsequent move/up events extend. */
    private fun beginStroke(x: Float, y: Float) {
        resetGesture()
        try {
            lastX = x
            lastY = y
            val path = Path().apply { moveTo(x, y) }
            val stroke = GestureDescription.StrokeDescription(path, 0, MOVE_SEGMENT_MS, true)
            if (dispatchGesture(strokeToGesture(stroke), null, null)) {
                pendingStroke = stroke
                strokeEndTime = MOVE_SEGMENT_MS
            } else {
                // Gesture rejected (e.g. another gesture in progress); fall back to a tap.
                resetGesture()
            }
        } catch (e: Exception) {
            Log.e(TAG, "beginStroke failed", e)
            resetGesture()
        }
    }

    /** Extends the active stroke towards the new coordinate. */
    private fun moveStroke(x: Float, y: Float) {
        val previous = pendingStroke ?: return
        try {
            val path = Path().apply {
                moveTo(lastX, lastY)
                lineTo(x, y)
            }
            val start = strokeEndTime
            val stroke = previous.continueStroke(path, start, MOVE_SEGMENT_MS, true)
            if (dispatchGesture(strokeToGesture(stroke), null, null)) {
                pendingStroke = stroke
                strokeEndTime = start + MOVE_SEGMENT_MS
                lastX = x
                lastY = y
            } else {
                resetGesture()
            }
        } catch (e: Exception) {
            Log.e(TAG, "moveStroke failed", e)
            resetGesture()
        }
    }

    /** Finishes the active stroke at the given coordinate. */
    private fun endStroke(x: Float, y: Float) {
        val previous = pendingStroke ?: run {
            // A lone UP with no active stroke - synthesize a tap
            // so a standalone "tap" event still produces a click.
            dispatchTap(x, y)
            return
        }
        try {
            val path = Path().apply {
                moveTo(lastX, lastY)
                lineTo(x, y)
            }
            val start = strokeEndTime
            val stroke = previous.continueStroke(path, start, 0, false)
            dispatchGesture(strokeToGesture(stroke), null, null)
        } catch (e: Exception) {
            Log.e(TAG, "endStroke failed", e)
        } finally {
            resetGesture()
        }
    }

    private fun strokeToGesture(stroke: GestureDescription.StrokeDescription): GestureDescription =
        GestureDescription.Builder().addStroke(stroke).build()

    /** Simple down->up tap, used as a fallback for old APIs or rejected gestures. */
    private fun dispatchTap(x: Float, y: Float) {
        try {
            val path = Path().apply { moveTo(x, y) }
            val stroke = GestureDescription.StrokeDescription(path, 0, 60)
            val gesture = GestureDescription.Builder()
                .addStroke(stroke)
                .build()
            dispatchGesture(gesture, null, null)
        } catch (e: Exception) {
            Log.e(TAG, "dispatchGesture failed", e)
        }
    }

    private fun resetGesture() {
        pendingStroke = null
        strokeEndTime = 0
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
