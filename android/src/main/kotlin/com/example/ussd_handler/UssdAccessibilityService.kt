package com.example.ussd_handler

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ConcurrentHashMap

class UssdAccessibilityService : AccessibilityService() {
    
    companion object {
        private const val TAG = "UssdAccessibilityService"
        private var instance: UssdAccessibilityService? = null
        private val eventSinks = ConcurrentHashMap<String, EventChannel.EventSink>()
        
        // Variables for multi-session handling
        @Volatile private var isMultiSessionActive = false
        @Volatile private var currentMultiSessionEvent: android.view.accessibility.AccessibilityEvent? = null
        private var multiSessionResponseCallback: ((String) -> Unit)? = null
        
        fun getInstance(): UssdAccessibilityService? = instance
        
        fun isServiceEnabled(): Boolean = instance != null
        
        // Function to check if there is an active multi-session session
        fun isMultiSessionActive(): Boolean = isMultiSessionActive
        
        fun addEventSink(id: String, eventSink: EventChannel.EventSink) {
            eventSinks[id] = eventSink
            Log.d(TAG, "Added event sink with id: $id")
        }
        
        fun removeEventSink(id: String) {
            eventSinks.remove(id)
            Log.d(TAG, "Removed event sink with id: $id")
        }
        
        private fun sendToAllSinks(event: Map<String, Any>) {
            eventSinks.values.forEach { sink ->
                try {
                    sink.success(event)
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending event to sink: ${e.message}")
                }
            }
        }
    }
    
    // Callback for USSD responses
    private var ussdResponseCallback: ((String) -> Unit)? = null
    @Volatile private var responseAlreadySent = false
    
    // Headless mode - when activated, dialogs are automatically closed
    @Volatile private var headlessMode = false
    
    // Function to monitor and wait for the appearance of system USSD dialogs
    private var waitingForUssdDialog = false
    private var ussdDialogWaitCallback: ((Boolean) -> Unit)? = null
    private val ussdDialogWaitTimeout = 10000L // 10 seconds
    
    fun setUssdResponseCallback(callback: (String) -> Unit) {
        synchronized(this) {
            ussdResponseCallback = callback
            responseAlreadySent = false // Reset when setting new callback
            Log.d(TAG, "USSD response callback set, responseAlreadySent reset to false")
        }
    }
    
    fun clearUssdResponseCallback() {
        synchronized(this) {
            ussdResponseCallback = null
            responseAlreadySent = false // Reset when clearing callback
            Log.d(TAG, "USSD response callback cleared, responseAlreadySent reset to false")
        }
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        
        Log.d(TAG, "USSD Accessibility Service connected")
        
        // Configure the service to listen to specific events
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or 
                        AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                   AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            packageNames = arrayOf("com.android.phone", "android")
        }
        serviceInfo = info
        
        // Notify that the service is available
        sendToAllSinks(mapOf(
            "type" to "service_connected",
            "message" to "USSD accessibility service connected"
        ))
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "USSD Accessibility Service disconnected")
        
        // Notify that the service was disconnected
        sendToAllSinks(mapOf(
            "type" to "service_disconnected",
            "message" to "USSD accessibility service disconnected"
        ))
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        try {
            when (event.eventType) {
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                    handleWindowStateChanged(event)
                }
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                    handleWindowContentChanged(event)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing accessibility event: ${e.message}", e)
        }
    }
    
    private fun handleWindowStateChanged(event: AccessibilityEvent) {
        val className = event.className?.toString()
        val packageName = event.packageName?.toString()
        Log.d(TAG, "Window state changed: className=$className, package=$packageName")
        
        // Check if it's a system USSD dialog
        val isUssdDialog = isUssdSystemDialog(className, packageName)
        
        if (isUssdDialog) {
            Log.d(TAG, "🎯 DETECTED: System USSD dialog appeared")
            
            // If we were waiting for a USSD dialog, notify that it appeared
            if (waitingForUssdDialog) {
                Log.d(TAG, "✅ Expected USSD dialog detected")
                waitingForUssdDialog = false
                ussdDialogWaitCallback?.invoke(true)
                ussdDialogWaitCallback = null
            }
            
            // Extract dialog content (with multi-session support)
            extractUssdContentWithMultiSession(event.source)
        } else {
            Log.d(TAG, "ℹ️ Detected window is NOT a system USSD dialog")
        }
    }
    
    private fun isUssdSystemDialog(className: String?, packageName: String?): Boolean {
        // Check by className
        val ussdClassNames = listOf(
            "AlertDialog", "PhoneUtils", "UssdAlertActivity", 
            "MMIDialogActivity", "MmiCode", "GSMPhone"
        )
        
        if (className != null) {
            for (ussdClass in ussdClassNames) {
                if (className.contains(ussdClass, ignoreCase = true)) {
                    Log.d(TAG, "USSD dialog detected by className: $className")
                    return true
                }
            }
        }
        
        // Check by packageName
        val ussdPackages = listOf(
            "com.android.phone", "com.android.dialer", 
            "telephony", "ussd", "mmi"
        )
        
        if (packageName != null) {
            for (ussdPackage in ussdPackages) {
                if (packageName.contains(ussdPackage, ignoreCase = true)) {
                    Log.d(TAG, "USSD dialog detected by packageName: $packageName")
                    return true
                }
            }
        }
        
        return false
    }
    
    private fun handleWindowContentChanged(event: AccessibilityEvent) {
        val className = event.className?.toString()
        
        // Only process content changes in USSD dialogs
        if (isUssdDialog(className)) {
            Log.d(TAG, "USSD content changed in: $className")
            extractUssdContentWithMultiSession(event.source)
        }
    }
    
    private fun isUssdDialog(className: String?): Boolean {
        if (className == null) return false
        
        return className.contains("AlertDialog", ignoreCase = true) ||
               className.contains("PhoneUtils", ignoreCase = true) ||
               className.contains("UssdAlertActivity", ignoreCase = true) ||
               className.contains("com.android.phone", ignoreCase = true)
    }
    
    private fun extractUssdContent(rootNode: AccessibilityNodeInfo?) {
        if (rootNode == null) return
        
        try {
            // Check if response was already sent to avoid duplicate processing
            if (responseAlreadySent) {
                Log.d(TAG, "Response already sent, ignoring additional accessibility event")
                return
            }
            
            // Search for text in the dialog
            val ussdText = findUssdText(rootNode)
            
            if (ussdText.isNotEmpty()) {
                Log.d(TAG, "USSD content extracted: $ussdText")
                
                // Use synchronized to avoid race conditions
                synchronized(this) {
                    // Double verification within synchronized block
                    if (ussdResponseCallback != null && !responseAlreadySent) {
                        responseAlreadySent = true
                        Log.d(TAG, "Sending USSD response via callback")
                        
                        try {
                            ussdResponseCallback?.invoke(ussdText)
                            Log.d(TAG, "USSD response callback executed successfully")
                        } catch (e: Exception) {
                            Log.e(TAG, "Error invoking USSD response callback: ${e.message}", e)
                            // Do not reset responseAlreadySent in case of error to avoid multiple attempts
                        }
                    } else if (responseAlreadySent) {
                        Log.d(TAG, "Response already sent previously, ignoring additional event")
                    } else {
                        Log.d(TAG, "No callback configured, only sending event to Flutter")
                    }
                }
                
                // Send event to Flutter (this is independent of the callback)
                sendToAllSinks(mapOf(
                    "type" to "ussd_response",
                    "message" to ussdText,
                    "timestamp" to System.currentTimeMillis()
                ))
                
                // AUTO-DISMISS: Automatically close the native dialog after capturing content
                // to create a completely headless experience
                if (headlessMode) {
                    autoDismissUssdDialog(rootNode)
                }
            } else {
                Log.d(TAG, "No valid USSD text found in dialog")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting USSD content: ${e.message}", e)
        }
    }
    
    private fun findUssdText(node: AccessibilityNodeInfo): String {
        val textBuilder = StringBuilder()
        
        // Get text from current node
        node.text?.let { text ->
            val textStr = text.toString().trim()
            if (textStr.isNotEmpty() && !isButtonText(textStr)) {
                textBuilder.append(textStr).append(" ")
            }
        }
        
        // Recursively search in child nodes
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { child ->
                val childText = findUssdText(child)
                if (childText.isNotEmpty()) {
                    textBuilder.append(childText).append(" ")
                }
                child.recycle()
            }
        }
        
        return textBuilder.toString().trim()
    }
    
    private fun isButtonText(text: String): Boolean {
        val buttonTexts = listOf("OK", "Cancel", "Cancelar", "Accept", "Aceptar", "Send", "Enviar", "Back", "Atrás")
        return buttonTexts.any { it.equals(text, ignoreCase = true) }
    }

    override fun onInterrupt() {
        Log.d(TAG, "USSD Accessibility Service interrupted")
    }
    
    // Function to simulate click on USSD buttons (legacy version - maintained for compatibility)
    fun clickUssdButton(buttonText: String): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        
        // Check if we are in a real system USSD dialog
        if (!isRealUssdDialog(rootNode)) {
            Log.w(TAG, "Not a system USSD dialog. Ignoring click attempt on '$buttonText'")
            return false
        }
        
        // Use the improved method by default
        return clickUssdButtonImproved(buttonText)
    }
    
    // Improved function to click USSD buttons with more robust search
    fun clickUssdButtonImproved(buttonText: String): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        
        // Check if we are in a real system USSD dialog
        if (!isRealUssdDialog(rootNode)) {
            Log.w(TAG, "Not a system USSD dialog. Ignoring click attempt on '$buttonText'")
            return false
        }
        
        return try {
            // First, log all available buttons for debugging
            logAllClickableNodes(rootNode)
            
            // Strategy 1: Exact search (current)
            var buttonNode = findButtonByText(rootNode, buttonText)
            if (buttonNode != null) {
                val clicked = buttonNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                buttonNode.recycle()
                Log.d(TAG, "Clicked USSD button '$buttonText' (exact match): $clicked")
                return clicked
            }
            
            // Strategy 2: Partial content search
            buttonNode = findButtonByPartialText(rootNode, buttonText)
            if (buttonNode != null) {
                val clicked = buttonNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                buttonNode.recycle()
                Log.d(TAG, "Clicked USSD button '$buttonText' (partial match): $clicked")
                return clicked
            }
            
            // Strategy 3: Search by content description
            buttonNode = findButtonByContentDescription(rootNode, buttonText)
            if (buttonNode != null) {
                val clicked = buttonNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                buttonNode.recycle()
                Log.d(TAG, "Clicked USSD button '$buttonText' (content description): $clicked")
                return clicked
            }
            
            // Strategy 4: Search for any button that may be a confirmation button based on position or class
            buttonNode = findGenericConfirmButton(rootNode)
            if (buttonNode != null) {
                val clicked = buttonNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                buttonNode.recycle()
                Log.d(TAG, "Clicked generic confirm button: $clicked")
                return clicked
            }
            
            Log.w(TAG, "Button '$buttonText' not found with any strategy")
            false
            
        } catch (e: Exception) {
            Log.e(TAG, "Error clicking USSD button (improved): ${e.message}", e)
            false
        }
    }
    
    private fun logAllClickableNodes(node: AccessibilityNodeInfo, depth: Int = 0) {
        try {
            val indent = "  ".repeat(depth)
            if (node.isClickable) {
                val text = node.text?.toString() ?: "no-text"
                val contentDesc = node.contentDescription?.toString() ?: "no-desc"
                val className = node.className?.toString() ?: "no-class"
                Log.d(TAG, "${indent}CLICKABLE: text='$text', desc='$contentDesc', class='$className'")
            }
            
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    logAllClickableNodes(child, depth + 1)
                    child.recycle()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error logging clickable nodes: ${e.message}")
        }
    }
    
    private fun findButtonByPartialText(node: AccessibilityNodeInfo, targetText: String): AccessibilityNodeInfo? {
        val text = node.text?.toString()
        if (node.isClickable && text != null && text.contains(targetText, ignoreCase = true)) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val result = findButtonByPartialText(child, targetText)
                if (result != null) {
                    child.recycle()
                    return result
                }
                child.recycle()
            }
        }
        
        return null
    }
    
    private fun findButtonByContentDescription(node: AccessibilityNodeInfo, targetText: String): AccessibilityNodeInfo? {
        val contentDesc = node.contentDescription?.toString()
        if (node.isClickable && contentDesc != null && contentDesc.contains(targetText, ignoreCase = true)) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val result = findButtonByContentDescription(child, targetText)
                if (result != null) {
                    child.recycle()
                    return result
                }
                child.recycle()
            }
        }
        
        return null
    }
    
    private fun findGenericConfirmButton(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        // Search for common confirmation buttons based on className or position
        val className = node.className?.toString()
        if (node.isClickable && className != null && 
            (className.contains("Button") || className.contains("TextView")) &&
            node.text != null) {
            
            val text = node.text.toString()
            // Common patterns of confirmation buttons in different languages
            val confirmPatterns = listOf(
                "ok", "yes", "send", "submit", "confirm", "continue", "next", "proceed",
                "aceptar", "sí", "enviar", "confirmar", "continuar", "siguiente", "proceder",
                "✓", "→", "▶", "⏩"
            )
            
            for (pattern in confirmPatterns) {
                if (text.contains(pattern, ignoreCase = true)) {
                    Log.d(TAG, "Found generic confirm button with text: '$text'")
                    return node
                }
            }
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val result = findGenericConfirmButton(child)
                if (result != null) {
                    child.recycle()
                    return result
                }
                child.recycle()
            }
        }
        
        return null
    }
    
    // Function to write text in input fields of USSD dialogs
    fun writeTextToUssdDialog(text: String): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        
        Log.d(TAG, "=== WRITE TEXT IN USSD DIALOG ===")
        Log.d(TAG, "Text to write: '$text'")
        
        // Check if we are in a real system USSD dialog
        if (!isRealUssdDialog(rootNode)) {
            Log.w(TAG, "Not a system USSD dialog. Ignoring attempt to write text '$text'")
            return false
        }
        
        return try {
            Log.d(TAG, "Searching for input field in USSD dialog...")
            val editTextNode = findEditTextNode(rootNode)
            if (editTextNode != null) {
                Log.d(TAG, "✅ Input field found: ${editTextNode.className}")
                Log.d(TAG, "Field properties: editable=${editTextNode.isEditable}, focusable=${editTextNode.isFocusable}, enabled=${editTextNode.isEnabled}")
                
                // Try various strategies to write the text
                var result = false
                
                // Strategy 1: ACTION_SET_TEXT
                try {
                    val arguments = Bundle()
                    arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                    result = editTextNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                    Log.d(TAG, "Strategy 1 (ACTION_SET_TEXT): $result")
                } catch (e: Exception) {
                    Log.w(TAG, "Error with ACTION_SET_TEXT: ${e.message}")
                }
                
                // Strategy 2: Focus and then ACTION_SET_TEXT
                if (!result) {
                    try {
                        editTextNode.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                        Thread.sleep(100) // Small pause for focus to be established
                        val arguments = Bundle()
                        arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                        result = editTextNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                        Log.d(TAG, "Strategy 2 (FOCUS + ACTION_SET_TEXT): $result")
                    } catch (e: Exception) {
                        Log.w(TAG, "Error with FOCUS + ACTION_SET_TEXT: ${e.message}")
                    }
                }
                
                // Strategy 3: Clear field and then write
                if (!result) {
                    try {
                        // Clear field first
                        val clearArgs = Bundle()
                        clearArgs.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, "")
                        editTextNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, clearArgs)
                        Thread.sleep(50)
                        
                        // Write text
                        val arguments = Bundle()
                        arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                        result = editTextNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                        Log.d(TAG, "Strategy 3 (CLEAR + ACTION_SET_TEXT): $result")
                    } catch (e: Exception) {
                        Log.w(TAG, "Error with CLEAR + ACTION_SET_TEXT: ${e.message}")
                    }
                }
                
                editTextNode.recycle()
                
                if (result) {
                    Log.d(TAG, "✅ Text '$text' written successfully in input field")
                } else {
                    Log.w(TAG, "❌ Could not write text '$text' in input field")
                }
                
                return result
            } else {
                Log.w(TAG, "❌ No input field found in USSD dialog")
                
                // Debug: List all nodes to diagnose the problem
                Log.d(TAG, "=== DEBUG: Listing all dialog nodes ===")
                debugLogAllNodes(rootNode, 0)
                
                return false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error writing text in USSD dialog: ${e.message}", e)
            false
        }
    }
    
    private fun findEditTextNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        Log.d(TAG, "Searching for input field in node: ${node.className}, editable=${node.isEditable}, focusable=${node.isFocusable}, enabled=${node.isEnabled}")
        
        // Strategy 1: Search traditional EditText
        if (node.className?.toString()?.contains("EditText", ignoreCase = true) == true && 
            node.isEditable && node.isFocusable) {
            Log.d(TAG, "✅ Traditional EditText found")
            return node
        }
        
        // Strategy 2: Search editable fields even if they're not EditText
        if (node.isEditable && node.isFocusable && node.isEnabled) {
            Log.d(TAG, "✅ Generic editable field found: ${node.className}")
            return node
        }
        
        // Strategy 3: Search by hint text (placeholder/hint)
        val hintText = node.hintText?.toString()?.lowercase()
        if (hintText != null && (hintText.contains("input") || hintText.contains("enter") || 
            hintText.contains("write") || hintText.contains("type") || hintText.contains("type"))) {
            if (node.isEnabled && (node.isEditable || node.isFocusable)) {
                Log.d(TAG, "✅ Field found by hint text: '$hintText'")
                return node
            }
        }
        
        // Strategy 4: Search text fields that can receive input
        val className = node.className?.toString()?.lowercase()
        if (className != null && (className.contains("text") || className.contains("input") || 
            className.contains("field")) && (node.isEditable || node.isFocusable) && node.isEnabled) {
            Log.d(TAG, "✅ Generic text field found: $className")
            return node
        }
        
        // Strategy 5: Search nodes that accept ACTION_SET_TEXT
        val actions = node.actionList
        if (actions.any { it.id == AccessibilityNodeInfo.ACTION_SET_TEXT } && node.isEnabled) {
            Log.d(TAG, "✅ Node that accepts ACTION_SET_TEXT found: ${node.className}")
            return node
        }
        
        // Search recursively in child nodes
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val result = findEditTextNode(child)
                if (result != null) {
                    child.recycle()
                    return result
                }
                child.recycle()
            }
        }
        
        return null
    }
    
    // Alias for writeTextToUssdDialog for compatibility
    fun writeTextToUssdField(text: String): Boolean {
        return writeTextToUssdDialog(text)
    }
    
    fun setHeadlessMode(enabled: Boolean) {
        synchronized(this) {
            headlessMode = enabled
            Log.d(TAG, "Headless mode ${if (enabled) "enabled" else "disabled"}")
        }
    }
    
    fun isHeadlessModeEnabled(): Boolean = headlessMode
    
    /**
     * Automatically closes the USSD dialog after capturing its content
     * to create a completely headless experience
     */
    private fun autoDismissUssdDialog(rootNode: AccessibilityNodeInfo) {
        try {
            Log.d(TAG, "=== AUTO-DISMISS: Trying to close USSD dialog ===")
            
            // Strategy 1: Search and press "Cancel" button
            val cancelButtons = listOf("Cancel", "Cancelar", "Back", "Atrás", "Dismiss", "Close")
            for (buttonText in cancelButtons) {
                if (findAndClickButton(rootNode, buttonText)) {
                    Log.d(TAG, "AUTO-DISMISS: Dialog closed successfully with button '$buttonText'")
                    return
                }
            }
            
            // Strategy 2: Use system BACK action
            if (performGlobalAction(GLOBAL_ACTION_BACK)) {
                Log.d(TAG, "AUTO-DISMISS: Dialog closed successfully with BACK action")
                return
            }
            
            // Strategy 3: Search for generic clickable button that can close the dialog
            if (findAndClickDismissibleButton(rootNode)) {
                Log.d(TAG, "AUTO-DISMISS: Dialog closed successfully with generic close button")
                return
            }
            
            // Strategy 4: Try closing using gestures (for special cases)
            if (performGlobalAction(GLOBAL_ACTION_HOME)) {
                Log.d(TAG, "AUTO-DISMISS: Trying to close with HOME action")
                return
            }
            
            Log.w(TAG, "AUTO-DISMISS: Could not find method to automatically close the dialog")
            
        } catch (e: Exception) {
            Log.e(TAG, "AUTO-DISMISS: Error closing dialog automatically: ${e.message}", e)
        }
    }
    
    private fun findAndClickButton(rootNode: AccessibilityNodeInfo, buttonText: String): Boolean {
        return try {
            val buttonNode = findButtonByText(rootNode, buttonText)
            if (buttonNode != null) {
                val clicked = buttonNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                buttonNode.recycle()
                clicked
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error clicking button '$buttonText': ${e.message}")
            false
        }
    }
    
    private fun findAndClickDismissibleButton(rootNode: AccessibilityNodeInfo): Boolean {
        return try {
            // Search for buttons that can close the dialog
            val dismissibleTexts = listOf("OK", "Accept", "Aceptar", "Close", "Done", "Finish", "Exit")
            
            for (text in dismissibleTexts) {
                val buttonNode = findButtonByText(rootNode, text)
                if (buttonNode != null) {
                    val clicked = buttonNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    buttonNode.recycle()
                    if (clicked) {
                        Log.d(TAG, "AUTO-DISMISS: Button '$text' pressed to close dialog")
                        return true
                    }
                }
            }
            
            // Search for any clickable button that might be a close button
            return findAndClickAnyDismissButton(rootNode)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error finding dismissible button: ${e.message}")
            false
        }
    }
    
    private fun findAndClickAnyDismissButton(rootNode: AccessibilityNodeInfo): Boolean {
        try {
            // Search for clickable nodes that might be close buttons
            if (rootNode.isClickable && rootNode.className?.toString()?.contains("Button", ignoreCase = true) == true) {
                val buttonText = rootNode.text?.toString()?.trim()
                if (buttonText != null && buttonText.length <= 15) { // Avoid very long texts that are not buttons
                    val clicked = rootNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    if (clicked) {
                        Log.d(TAG, "AUTO-DISMISS: Generic button '$buttonText' pressed")
                        return true
                    }
                }
            }
            
            // Search recursively in child nodes
            for (i in 0 until rootNode.childCount) {
                val child = rootNode.getChild(i)
                if (child != null) {
                    if (findAndClickAnyDismissButton(child)) {
                        child.recycle()
                        return true
                    }
                    child.recycle()
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error finding any dismiss button: ${e.message}")
        }
        
        return false
    }
    
    /**
     * Starts a USSD session in headless mode
     */
    fun startHeadlessUssdSession() {
        setHeadlessMode(true)
        Log.d(TAG, "=== HEADLESS USSD SESSION STARTED ===")
    }
    
    /**
     * Ends the USSD session in headless mode
     */
    fun stopHeadlessUssdSession() {
        setHeadlessMode(false)
        clearUssdResponseCallback()
        Log.d(TAG, "=== HEADLESS USSD SESSION ENDED ===")
    }
    
    private fun findButtonByText(node: AccessibilityNodeInfo, targetText: String): AccessibilityNodeInfo? {
        if (node.isClickable && node.text?.toString()?.equals(targetText, ignoreCase = true) == true) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val result = findButtonByText(child, targetText)
                if (result != null) {
                    child.recycle()
                    return result
                }
                child.recycle()
            }
        }
        
        return null
    }
    
    // Function to check if we are interacting with a system USSD dialog and not with Flutter UI
    private fun isRealUssdDialog(rootNode: AccessibilityNodeInfo): Boolean {
        try {
            val packageName = rootNode.packageName?.toString()
            
            // If the package is from the Flutter app, it's NOT a system USSD dialog
            if (packageName != null && (packageName.contains("flutter") || packageName.contains("example"))) {
                Log.d(TAG, "DETECTED: Flutter UI detected (package: $packageName), NOT a system USSD dialog")
                return false
            }
            
            // Search for system USSD dialog indicators
            val ussdIndicators = listOf(
                "com.android.phone",
                "dialer", 
                "telephony",
                "ussd",
                "mmi"
            )
            
            if (packageName != null) {
                for (indicator in ussdIndicators) {
                    if (packageName.contains(indicator, ignoreCase = true)) {
                        Log.d(TAG, "DETECTED: System USSD dialog (package: $packageName)")
                        return true
                    }
                }
            }
            
            // Search for typical elements of system USSD dialogs
            return hasSystemDialogCharacteristics(rootNode)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking if it's a real USSD dialog: ${e.message}")
            return false
        }
    }
    
    private fun hasSystemDialogCharacteristics(node: AccessibilityNodeInfo): Boolean {
        try {
            var hasEditText = false
            var hasSystemButtons = false
            
            // Recursively check dialog system characteristics
            checkDialogCharacteristics(node) { editTextFound, systemButtonsFound ->
                hasEditText = editTextFound
                hasSystemButtons = systemButtonsFound
            }
            
            val isSystemDialog = hasEditText && hasSystemButtons
            Log.d(TAG, "Dialog characteristics - EditText: $hasEditText, System buttons: $hasSystemButtons, Is system dialog: $isSystemDialog")
            return isSystemDialog
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking dialog characteristics: ${e.message}")
            return false
        }
    }
    
    private fun checkDialogCharacteristics(node: AccessibilityNodeInfo, callback: (Boolean, Boolean) -> Unit) {
        var hasEditText = false
        var hasSystemButtons = false
        
        // Check if this node is an EditText
        if (node.className?.toString()?.contains("EditText") == true && 
            node.isEditable && node.isFocusable) {
            hasEditText = true
        }
        
        // Check if this node is a system button (without emojis or Flutter descriptions)
        if (node.isClickable && node.className?.toString()?.contains("Button") == true) {
            val text = node.text?.toString() ?: ""
            val desc = node.contentDescription?.toString() ?: ""
            
            // System buttons have simple texts, without emojis
            val systemButtonTexts = listOf("OK", "Cancel", "Send", "Accept", "Aceptar", "Cancelar", "Enviar")
            val isSystemButton = systemButtonTexts.any { systemText ->
                text.equals(systemText, ignoreCase = true) || desc.equals(systemText, ignoreCase = true)
            }
            
            // Should not have emojis (typical of Flutter UI)
            val hasEmojis = text.any { it.code > 127 } || desc.any { it.code > 127 }
            
            if (isSystemButton && !hasEmojis) {
                hasSystemButtons = true
            }
        }
        
        // Check children recursively
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                checkDialogCharacteristics(child) { childEditText, childSystemButtons ->
                    if (childEditText) hasEditText = true
                    if (childSystemButtons) hasSystemButtons = true
                }
                child.recycle()
            }
        }
        
        callback(hasEditText, hasSystemButtons)
    }
    
    // Function to monitor and wait for the appearance of system USSD dialogs
    fun waitForUssdDialog(callback: (Boolean) -> Unit) {
        Log.d(TAG, "=== WAITING FOR SYSTEM USSD DIALOG ===")
        waitingForUssdDialog = true
        ussdDialogWaitCallback = callback
        
        // Timeout to stop waiting
        Handler(Looper.getMainLooper()).postDelayed({
            if (waitingForUssdDialog) {
                Log.w(TAG, "TIMEOUT: No system USSD dialog detected in ${ussdDialogWaitTimeout}ms")
                waitingForUssdDialog = false
                ussdDialogWaitCallback?.invoke(false)
                ussdDialogWaitCallback = null
            }
        }, ussdDialogWaitTimeout)
    }
    
    fun stopWaitingForUssdDialog() {
        waitingForUssdDialog = false
        ussdDialogWaitCallback = null
    }
    
    // ==================== METHODS FOR MULTI-SESSION ====================
    
    /**
     * Starts a multi-session USSD session
     * 
     * This method configures the service to keep a USSD dialog open
     * and allow multiple interactions with it.
     * 
     * @param callback Function that will be executed when a response is received
     */
    fun startMultiSession(callback: (String) -> Unit) {
        synchronized(this) {
            Log.d(TAG, "=== STARTING MULTI-SESSION USSD SESSION ===")
            isMultiSessionActive = true
            multiSessionResponseCallback = callback
            responseAlreadySent = false
            Log.d(TAG, "Multi-session started, waiting for USSD dialogs")
            
            // Safety timeout for cases where the real response never arrives
            Handler(Looper.getMainLooper()).postDelayed({
                synchronized(this) {
                    if (isMultiSessionActive && !responseAlreadySent && multiSessionResponseCallback != null) {
                        Log.w(TAG, "TIMEOUT: No real USSD response received in 15 seconds")
                        responseAlreadySent = true
                        try {
                            multiSessionResponseCallback?.invoke("TIMEOUT: No response received from operator")
                        } catch (e: Exception) {
                            Log.e(TAG, "Error sending timeout: ${e.message}")
                        }
                    }
                }
            }, 15000) // 15 second timeout
        }
    }
    
    /**
     * Sends a message in the active USSD session
     * 
     * @param message The message to send
     * @return true if the message was sent successfully
     */
    fun sendMessageInSession(message: String): Boolean {
        return try {
            if (!isMultiSessionActive) {
                Log.w(TAG, "No active multi-session to send message: $message")
                return false
            }
            
            val rootNode = rootInActiveWindow
            if (rootNode == null) {
                Log.w(TAG, "Cannot get active window to send message")
                return false
            }
            
            // Check if we are in a real USSD dialog
            if (!isRealUssdDialog(rootNode)) {
                Log.w(TAG, "No active USSD dialog to send message")
                return false
            }
            
            // NEW: Check that it's NOT a progress dialog
            if (isProgressDialog(rootNode)) {
                Log.w(TAG, "Progress dialog detected, cannot send message yet. Waiting for real menu...")
                return false
            }
            
            Log.d(TAG, "Sending message in multi-session: '$message'")
            
            // Reset flag to allow new response
            synchronized(this) {
                responseAlreadySent = false
            }
            
            // Write the message in the input field
            val messageWritten = writeTextToUssdDialog(message)
            if (!messageWritten) {
                Log.w(TAG, "Could not write message in USSD dialog")
                return false
            }
            
            // Wait a moment for the text to be processed
            Handler(Looper.getMainLooper()).postDelayed({
                // Press send button (normally "Send" or "Enviar")
                val sendButtons = listOf("Send", "Enviar", "OK", "Accept", "Aceptar", "Submit", "Confirm", "Confirmar")
                var buttonPressed = false
                
                for (buttonText in sendButtons) {
                    if (clickUssdButtonImproved(buttonText)) {
                        Log.d(TAG, "Button '$buttonText' pressed to send message")
                        buttonPressed = true
                        break
                    }
                }
                
                if (!buttonPressed) {
                    Log.w(TAG, "Send button not found, trying generic method")
                    clickUssdButtonImproved("OK") // Fallback
                }
                
                // Specific timeout for message sent response
                Handler(Looper.getMainLooper()).postDelayed({
                    synchronized(this) {
                        if (isMultiSessionActive && !responseAlreadySent && multiSessionResponseCallback != null) {
                            Log.w(TAG, "TIMEOUT: No response received after sending message '$message'")
                            responseAlreadySent = true
                            try {
                                multiSessionResponseCallback?.invoke("TIMEOUT: No response after sending '$message'")
                            } catch (e: Exception) {
                                Log.e(TAG, "Error sending message timeout: ${e.message}")
                            }
                        }
                    }
                }, 10000) // 10 second timeout for messages
                
            }, 500) // 500ms delay
            
            return true
            
        } catch (e: Exception) {
            Log.e(TAG, "Error sending message in multi-session: ${e.message}", e)
            false
        }
    }
    
    /**
     * Cancels the active multi-session USSD session
     * 
     * @return true if the session was cancelled successfully
     */
    fun cancelMultiSession(): Boolean {
        return try {
            synchronized(this) {
                Log.d(TAG, "=== CANCELLING MULTI-SESSION USSD SESSION ===")
                isMultiSessionActive = false
                multiSessionResponseCallback = null
                currentMultiSessionEvent = null
                responseAlreadySent = false
            }
            
            // Try to close any open USSD dialog
            val rootNode = rootInActiveWindow
            if (rootNode != null && isRealUssdDialog(rootNode)) {
                Log.d(TAG, "Closing active USSD dialog")
                autoDismissUssdDialog(rootNode)
            }
            
            // Notify Flutter that the session ended
            sendToAllSinks(mapOf(
                "type" to "multi_session_cancelled",
                "message" to "Multi-session USSD session cancelled",
                "timestamp" to System.currentTimeMillis()
            ))
            
            Log.d(TAG, "Multi-session cancelled successfully")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling multi-session: ${e.message}", e)
            false
        }
    }
    
    /**
     * Checks if there is currently an active multi-session
     */
    fun hasActiveMultiSession(): Boolean = isMultiSessionActive
    
    /**
     * Handles USSD content extraction specifically for multi-sessions
     */
    private fun handleMultiSessionUssdContent(rootNode: AccessibilityNodeInfo?) {
        if (rootNode == null || !isMultiSessionActive) return
        
        try {
            // In multi-session mode, we don't automatically close the dialog
            // We only extract the content and send it via callback
            
            val ussdText = findUssdText(rootNode)
            if (ussdText.isNotEmpty()) {
                Log.d(TAG, "MULTI-SESSION: USSD content extracted: $ussdText")
                
                // Filter progress messages that are not real responses
                val progressMessages = listOf(
                    "executing ussd code",
                    "ejecutando código ussd",
                    "processing",
                    "please wait",
                    "wait",
                    "espere",
                    "loading",
                    "cargando",
                    "sending",
                    "enviando",
                    "connecting",
                    "conectando"
                )
                
                val isProgressMessage = progressMessages.any { 
                    ussdText.lowercase().contains(it) 
                }
                
                if (isProgressMessage) {
                    Log.d(TAG, "MULTI-SESSION: Progress message detected, waiting for real response...")
                    return
                }
                
                // Only process if it's a real response (not a progress message)
                synchronized(this) {
                    if (multiSessionResponseCallback != null && !responseAlreadySent) {
                        responseAlreadySent = true
                        Log.d(TAG, "Sending real USSD response via multi-session callback")
                        
                        try {
                            multiSessionResponseCallback?.invoke(ussdText)
                            Log.d(TAG, "Multi-session callback executed successfully")
                        } catch (e: Exception) {
                            Log.e(TAG, "Error invoking multi-session callback: ${e.message}", e)
                        }
                    }
                }
                
                // Send event to Flutter
                sendToAllSinks(mapOf(
                    "type" to "multi_session_response",
                    "message" to ussdText,
                    "timestamp" to System.currentTimeMillis()
                ))
                
                // Save current event for future interactions
                currentMultiSessionEvent = null // Will be updated on next event
                
            } else {
                Log.d(TAG, "MULTI-SESSION: No valid USSD text found")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling multi-session USSD content: ${e.message}", e)
        }
    }
    
    /**
     * Modifies the extractUssdContent method to handle multi-session sessions
     */
    private fun extractUssdContentWithMultiSession(rootNode: AccessibilityNodeInfo?) {
        if (rootNode == null) return
        
        try {
            // If there is an active multi-session session, use the specific handler
            if (isMultiSessionActive) {
                handleMultiSessionUssdContent(rootNode)
                return
            }
            
            // If there is no multi-session session, use the original method
            extractUssdContent(rootNode)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error in extractUssdContentWithMultiSession: ${e.message}", e)
        }
    }
    
    /**
     * Debug function to list all nodes of a dialog
     * Useful for diagnosing why the input field is not found
     */
    private fun debugLogAllNodes(node: AccessibilityNodeInfo, depth: Int) {
        try {
            val indent = "  ".repeat(depth)
            val className = node.className?.toString() ?: "null"
            val text = node.text?.toString() ?: ""
            val contentDesc = node.contentDescription?.toString() ?: ""
            val hintText = node.hintText?.toString() ?: ""
            
            Log.d(TAG, "${indent}[D$depth] $className | text='$text' | desc='$contentDesc' | hint='$hintText' | " +
                    "editable=${node.isEditable} | focusable=${node.isFocusable} | enabled=${node.isEnabled} | " +
                    "clickable=${node.isClickable} | children=${node.childCount}")
            
            // List available actions
            val actions = node.actionList.map { it.id }.joinToString(",")
            if (actions.isNotEmpty()) {
                Log.d(TAG, "${indent}    Actions: [$actions]")
            }
            
            // Recursively for children (limited to 5 levels to avoid spam)
            if (depth < 5) {
                for (i in 0 until node.childCount) {
                    val child = node.getChild(i)
                    if (child != null) {
                        debugLogAllNodes(child, depth + 1)
                        child.recycle()
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error in debugLogAllNodes: ${e.message}")
        }
    }
    
    /**
     * Checks if the current dialog is a progress dialog
     * (which only shows "Executing USSD code..." and has no input field)
     */
    private fun isProgressDialog(rootNode: AccessibilityNodeInfo): Boolean {
        try {
            // Search for progress dialog indicators
            val progressIndicators = listOf(
                "ejecutando código ussd",
                "processing ussd",
                "please wait",
                "espere",
                "cargando",
                "loading"
            )
            
            val dialogText = findUssdText(rootNode).lowercase()
            val hasProgressIndicator = progressIndicators.any { dialogText.contains(it) }
            
            // Check if there is a ProgressBar in the dialog
            val hasProgressBar = hasProgressBar(rootNode)
            
            // It is a progress dialog if:
            // 1. Has progress indicators in the text, OR
            // 2. Has a ProgressBar, AND
            // 3. Does NOT have input field
            val hasInputField = findEditTextNode(rootNode) != null
            
            val isProgress = (hasProgressIndicator || hasProgressBar) && !hasInputField
            
            if (isProgress) {
                Log.d(TAG, "✋ DETECTED: Progress dialog - text='$dialogText', hasProgressBar=$hasProgressBar, hasInputField=$hasInputField")
            }
            
            return isProgress
            
        } catch (e: Exception) {
            Log.w(TAG, "Error checking if it's a progress dialog: ${e.message}")
            return false
        }
    }
    
    /**
     * Checks if there is a ProgressBar in the dialog
     */
    private fun hasProgressBar(node: AccessibilityNodeInfo): Boolean {
        val className = node.className?.toString()
        if (className?.contains("ProgressBar", ignoreCase = true) == true) {
            return true
        }
        
        // Search recursively
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val hasProgress = hasProgressBar(child)
                child.recycle()
                if (hasProgress) return true
            }
        }
        
        return false
    }
}
