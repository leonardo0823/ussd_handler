package com.example.ussd_handler

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telephony.TelephonyManager
import android.telephony.TelephonyManager.UssdResponseCallback
import android.view.accessibility.AccessibilityManager
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.util.UUID
import java.util.concurrent.TimeoutException

/** UssdHandlerPlugin */
class UssdHandlerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private var activity: android.app.Activity? = null
  private var pendingResult: Result? = null
  private var pendingUssdCode: String? = null
  private var pendingTimeoutSeconds: Int? = null
  private var pendingSubscriptionId: Int? = null
  private val PERMISSION_REQUEST_CODE = 1001
  private val USSD_DIRECT_PERMISSION_REQUEST_CODE = 1002

  // Variables for accessibility services
  private var accessibilityEventChannel: EventChannel? = null
  private var accessibilityEventSink: EventChannel.EventSink? = null
  private lateinit var accessibilityManager: AccessibilityManager

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ussd_handler")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "executeUssd" -> {
        val ussdCode = call.argument<String>("ussdCode")
        val subscriptionId = call.argument<Int>("subscriptionId")
        if (ussdCode != null) {
          executeUssd(ussdCode, subscriptionId, result)
        } else {
          result.error("INVALID_ARGUMENT", "USSD code cannot be null", null)
        }
      }
      "isUssdSupported" -> {
        result.success(isUssdSupported())
      }
      "executeUssdDirect" -> {
        val ussdCode = call.argument<String>("ussdCode")
        val timeoutSeconds = call.argument<Int>("timeoutSeconds") ?: 30
        val subscriptionId = call.argument<Int>("subscriptionId")
        if (ussdCode != null) {
          executeUssdDirect(ussdCode, timeoutSeconds, subscriptionId, result)
        } else {
          result.error("INVALID_ARGUMENT", "USSD code cannot be null", null)
        }
      }
      "getSystemInfo" -> {
        getSystemInfo(result)
      }
      "hasUssdDirectPermissions" -> {
        result.success(hasAllRequiredPermissions())
      }
      "isAccessibilityServiceEnabled" -> {
        result.success(isAccessibilityServiceEnabled())
      }
      "openAccessibilitySettings" -> {
        openAccessibilitySettings(result)
      }
      "setupAccessibilityEventChannel" -> {
        setupAccessibilityEventChannel(result)
      }
      // ==================== MULTI-SESSION METHODS ====================
      "startMultiSessionUssd" -> {
        val ussdCode = call.argument<String>("ussdCode")
        val subscriptionId = call.argument<Int>("subscriptionId")
        if (ussdCode != null) {
          startMultiSessionUssd(ussdCode, subscriptionId, result)
        } else {
          result.error("INVALID_ARGUMENT", "USSD code cannot be null", null)
        }
      }
      "sendMessageInSession" -> {
        val message = call.argument<String>("message")
        if (message != null) {
          sendMessageInSession(message, result)
        } else {
          result.error("INVALID_ARGUMENT", "Message cannot be null", null)
        }
      }
      "cancelMultiSession" -> {
        cancelMultiSession(result)
      }
      "isMultiSessionActive" -> {
        result.success(isMultiSessionActive())
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun executeUssd(ussdCode: String, subscriptionId: Int?, result: Result) {
    if (!isUssdSupported()) {
      result.success(mapOf(
        "success" to false,
        "errorMessage" to "USSD is not supported on this device"
      ))
      return
    }

    if (!hasCallPermission()) {
      pendingResult = result
      requestCallPermission()
      return
    }

    try {
      val resolvedSubscriptionId = resolveSubscriptionId(subscriptionId)
      val intent = createUssdIntent(ussdCode, resolvedSubscriptionId)
      
      if (intent.resolveActivity(context.packageManager) != null) {
        context.startActivity(intent)
        
        val simInfo = if (resolvedSubscriptionId != null) {
          " (SIM $resolvedSubscriptionId)"
        } else {
          " (native SIM selector)"
        }
        
        result.success(mapOf(
          "success" to true,
          "response" to "USSD code executed: $ussdCode$simInfo"
        ))
      } else {
        result.success(mapOf(
          "success" to false,
          "errorMessage" to "No application found to handle the USSD call"
        ))
      }
    } catch (e: Exception) {
      result.success(mapOf(
        "success" to false,
        "errorMessage" to "Error executing USSD: ${e.message}"
      ))
    }
  }

  @RequiresApi(Build.VERSION_CODES.O)
  private fun executeUssdDirect(ussdCode: String, timeoutSeconds: Int, subscriptionId: Int?, result: Result) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
      result.error("UNSUPPORTED_VERSION", "Direct USSD functionality requires Android 8.0 (API 26) or higher", null)
      return
    }

    if (!isUssdSupported()) {
      result.error("UNSUPPORTED_DEVICE", "USSD is not supported on this device", null)
      return
    }

    if (!hasAllRequiredPermissions()) {
      val missingPermissions = mutableListOf<String>()
      if (!hasCallPermission()) missingPermissions.add("CALL_PHONE")
      if (!hasReadPhoneStatePermission()) missingPermissions.add("READ_PHONE_STATE")
      
      // Request permissions automatically
      pendingResult = result
      pendingUssdCode = ussdCode
      pendingTimeoutSeconds = timeoutSeconds
      pendingSubscriptionId = subscriptionId
      requestUssdDirectPermissions()
      return
    }

    executeUssdDirectInternal(ussdCode, timeoutSeconds, subscriptionId, result)
  }

  @RequiresApi(Build.VERSION_CODES.O)
  private fun executeUssdDirectInternal(ussdCode: String, timeoutSeconds: Int, subscriptionId: Int?, result: Result) {

    // Check network status
    try {
      val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
      val resolvedSubscriptionId = resolveSubscriptionId(subscriptionId)
      
      // Get the specific TelephonyManager for the SIM if necessary
      val targetTelephonyManager = if (resolvedSubscriptionId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        try {
          // Try to get the TelephonyManager for the specific subscription
          val subId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            // In modern versions, use the real subscription ID from the system
            resolvedSubscriptionId - 1 // Convert from base 1 to base 0
          } else {
            resolvedSubscriptionId
          }
          telephonyManager.createForSubscriptionId(subId) ?: telephonyManager
        } catch (e: Exception) {
          android.util.Log.w("UssdHandler", "Could not get TelephonyManager for subscriptionId $resolvedSubscriptionId: ${e.message}")
          telephonyManager
        }
      } else {
        telephonyManager
      }
      
      val networkState = targetTelephonyManager.networkType
      val simState = targetTelephonyManager.simState
      
      if (simState != TelephonyManager.SIM_STATE_READY) {
        result.error("SIM_NOT_READY", "SIM is not ready. Status: $simState", null)
        return
      }
      
      if (networkState == TelephonyManager.NETWORK_TYPE_UNKNOWN) {
        result.error("NETWORK_UNAVAILABLE", "Network not available", null)
        return
      }
      
      android.util.Log.d("UssdHandler", "Executing direct USSD with subscriptionId: $resolvedSubscriptionId")
    } catch (e: SecurityException) {
      result.error("PERMISSION_DENIED", "Error checking network status: ${e.message}", null)
      return
    }

    try {
      val resolvedSubscriptionId = resolveSubscriptionId(subscriptionId)
      
      // Get the specific TelephonyManager for the SIM if necessary
      val targetTelephonyManager = if (resolvedSubscriptionId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        try {
          // Try to get the TelephonyManager for the specific subscription
          val subId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            // In modern versions, use the real subscription ID from the system
            resolvedSubscriptionId - 1 // Convert from base 1 to base 0
          } else {
            resolvedSubscriptionId
          }
          val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
          telephonyManager.createForSubscriptionId(subId) ?: telephonyManager
        } catch (e: Exception) {
          android.util.Log.w("UssdHandler", "Could not get TelephonyManager for subscriptionId $resolvedSubscriptionId: ${e.message}")
          context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        }
      } else {
        context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
      }
      
      val handler = Handler(Looper.getMainLooper())
      var timeoutHandler: Handler? = null
      var isCompleted = false

      val callback = object : UssdResponseCallback() {
        override fun onReceiveUssdResponse(telephonyManager: TelephonyManager, request: String?, response: CharSequence?) {
          if (!isCompleted) {
            isCompleted = true
            timeoutHandler?.removeCallbacksAndMessages(null)
            
            val responseText = response?.toString() ?: ""
            if (responseText.isEmpty()) {
              result.error("EMPTY_RESPONSE", "Empty USSD response", null)
            } else {
              result.success(responseText)
            }
          }
        }

        override fun onReceiveUssdResponseFailed(telephonyManager: TelephonyManager, request: String?, failureCode: Int) {
          if (!isCompleted) {
            isCompleted = true
            timeoutHandler?.removeCallbacksAndMessages(null)
            
            val requestText = request ?: "unknown_request"
            val errorMessage = when (failureCode) {
              TelephonyManager.USSD_RETURN_FAILURE -> "Network error when executing USSD. Possible causes: invalid USSD code, operator network issues, or the code is not supported by the operator."
              TelephonyManager.USSD_ERROR_SERVICE_UNAVAIL -> "USSD service not available at the moment. Try again later."
              else -> "Unknown error executing USSD (code: $failureCode). Check that the USSD code is valid and you have network coverage."
            }
            result.error("USSD_FAILED", errorMessage, mapOf("failureCode" to failureCode, "request" to requestText))
          }
        }
      }

      // Configure timeout
      timeoutHandler = Handler(Looper.getMainLooper())
      timeoutHandler.postDelayed({
        if (!isCompleted) {
          isCompleted = true
          result.error("TIMEOUT", "Timeout waiting for USSD response after $timeoutSeconds seconds", null)
        }
      }, (timeoutSeconds * 1000).toLong())

      // Execute USSD with the specific TelephonyManager
      targetTelephonyManager.sendUssdRequest(ussdCode, callback, handler)

    } catch (e: SecurityException) {
      result.error("PERMISSION_DENIED", "Insufficient permissions to execute USSD: ${e.message}", null)
    } catch (e: Exception) {
      result.error("EXECUTION_ERROR", "Error executing direct USSD: ${e.message}", null)
    }
  }

  private fun isUssdSupported(): Boolean {
    return try {
      val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
      telephonyManager.phoneType != TelephonyManager.PHONE_TYPE_NONE
    } catch (e: Exception) {
      false
    }
  }

  private fun hasCallPermission(): Boolean {
    return ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.CALL_PHONE
    ) == PackageManager.PERMISSION_GRANTED
  }

  private fun hasReadPhoneStatePermission(): Boolean {
    return ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.READ_PHONE_STATE
    ) == PackageManager.PERMISSION_GRANTED
  }

  private fun hasAllRequiredPermissions(): Boolean {
    return hasCallPermission() && hasReadPhoneStatePermission()
  }

  private fun requestCallPermission() {
    activity?.let { act ->
      ActivityCompat.requestPermissions(
        act,
        arrayOf(Manifest.permission.CALL_PHONE),
        PERMISSION_REQUEST_CODE
      )
    }
  }

  private fun requestUssdDirectPermissions() {
    activity?.let { act ->
      val permissionsToRequest = mutableListOf<String>()
      
      if (!hasCallPermission()) {
        permissionsToRequest.add(Manifest.permission.CALL_PHONE)
      }
      if (!hasReadPhoneStatePermission()) {
        permissionsToRequest.add(Manifest.permission.READ_PHONE_STATE)
      }
      
      if (permissionsToRequest.isNotEmpty()) {
        ActivityCompat.requestPermissions(
          act,
          permissionsToRequest.toTypedArray(),
          USSD_DIRECT_PERMISSION_REQUEST_CODE
        )
      }
    }
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
  ): Boolean {
    if (requestCode == PERMISSION_REQUEST_CODE) {
      val result = pendingResult
      pendingResult = null
      
      if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
        result?.success(mapOf(
          "success" to true,
          "response" to "Permission granted. You can now execute USSD codes."
        ))
      } else {
        result?.success(mapOf(
          "success" to false,
          "errorMessage" to "Call permission denied. Required to execute USSD codes."
        ))
      }
      return true
    } else if (requestCode == USSD_DIRECT_PERMISSION_REQUEST_CODE) {
      val result = pendingResult
      pendingResult = null
      
      if (grantResults.isNotEmpty()) {
        // Check if we have the essential permissions (CALL_PHONE and READ_PHONE_STATE)
        var hasCallPermission = false
        var hasReadPhoneStatePermission = false
        
        permissions.forEachIndexed { index, permission ->
          if (grantResults[index] == PackageManager.PERMISSION_GRANTED) {
            when (permission) {
              Manifest.permission.CALL_PHONE -> hasCallPermission = true
              Manifest.permission.READ_PHONE_STATE -> hasReadPhoneStatePermission = true
            }
          }
        }
        
        // Check if we have at least the essential permissions
        if (hasCallPermission && hasReadPhoneStatePermission) {
          // We have the essential permissions, try to execute USSD
          val ussdCode = pendingUssdCode
          val timeoutSeconds = pendingTimeoutSeconds ?: 30
          val subscriptionId = pendingSubscriptionId
          
          // Reset variables
          pendingUssdCode = null
          pendingTimeoutSeconds = null
          pendingSubscriptionId = null
          
          if (ussdCode != null && result != null) {
            executeUssdDirectInternal(ussdCode, timeoutSeconds, subscriptionId, result)
          } else {
            result?.error("INVALID_ARGUMENT", "USSD code cannot be null", null)
          }
        } else {
          // Missing essential permissions
          val deniedPermissions = mutableListOf<String>()
          if (!hasCallPermission) deniedPermissions.add("CALL_PHONE")
          if (!hasReadPhoneStatePermission) deniedPermissions.add("READ_PHONE_STATE")
          
          // Reset variables
          pendingUssdCode = null
          pendingTimeoutSeconds = null
          pendingSubscriptionId = null
          
          result?.error(
            "PERMISSION_DENIED",
            "Essential permissions denied for direct USSD: ${deniedPermissions.joinToString(", ")}. CALL_PHONE and READ_PHONE_STATE are required to use this functionality.",
            null
          )
        }
      }
      return true
    }
    return false
  }

  private fun getSystemInfo(result: Result) {
    try {
      val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
      val info = mutableMapOf<String, Any>()
      
      // Basic system information (always available)
      info["androidVersion"] = Build.VERSION.SDK_INT
      info["androidVersionSupported"] = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
      info["hasCallPermission"] = hasCallPermission()
      info["hasReadPhoneStatePermission"] = hasReadPhoneStatePermission()
      info["hasAllRequiredPermissions"] = hasAllRequiredPermissions()
      
      // Phone information (with individual error handling)
      try {
        info["phoneType"] = telephonyManager.phoneType
      } catch (e: Exception) {
        info["phoneType"] = "Not available: ${e.message}"
      }
      
      // Network type (may fail on some devices)
      try {
        @Suppress("DEPRECATION")
        info["networkType"] = telephonyManager.networkType
      } catch (e: Exception) {
        info["networkType"] = "Not available: ${e.message}"
      }
      
      // SIM status
      try {
        info["simState"] = telephonyManager.simState
      } catch (e: Exception) {
        info["simState"] = "Not available: ${e.message}"
      }
      
      // Additional information if we have permissions
      if (hasReadPhoneStatePermission()) {
        try {
          info["networkOperatorName"] = telephonyManager.networkOperatorName ?: "Unknown"
        } catch (e: Exception) {
          info["networkOperatorName"] = "Not available: ${e.message}"
        }
        
        try {
          info["simOperatorName"] = telephonyManager.simOperatorName ?: "Unknown"
        } catch (e: Exception) {
          info["simOperatorName"] = "Not available: ${e.message}"
        }
        
        // Additional device information
        try {
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            info["dataEnabled"] = telephonyManager.isDataEnabled
          }
        } catch (e: Exception) {
          info["dataEnabled"] = "Not available: ${e.message}"
        }
        
        // IMEI (requires special permissions on Android 10+)
        try {
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            info["imei"] = telephonyManager.imei ?: "Not available"
          } else {
            @Suppress("DEPRECATION")
            info["imei"] = telephonyManager.deviceId ?: "Not available"
          }
        } catch (e: Exception) {
          info["imei"] = "Not available: ${e.message}"
        }
      } else {
        info["operatorInfo"] = "Not available (READ_PHONE_STATE permission required)"
        info["imei"] = "Not available (READ_PHONE_STATE permission required)"
      }
      
      // Device information (always available)
      info["manufacturer"] = Build.MANUFACTURER
      info["model"] = Build.MODEL
      info["product"] = Build.PRODUCT
      info["androidVersionName"] = Build.VERSION.RELEASE
      
      // Accessibility service status
      info["accessibilityServiceEnabled"] = isAccessibilityServiceEnabled()
      
      // ==================== MULTI-SIM INFORMATION ====================
      try {
        val simCount = getSimCount()
        info["simCount"] = simCount
        info["supportsMultiSim"] = simCount > 1
        
        // If there are multiple SIMs and we have permissions, get additional information
        if (simCount > 1 && hasReadPhoneStatePermission() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
          try {
            val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as android.telephony.SubscriptionManager
            val activeSubscriptions = subscriptionManager.activeSubscriptionInfoList
            
            if (activeSubscriptions != null) {
              val simInfoList = mutableListOf<Map<String, Any>>()
              activeSubscriptions.forEachIndexed { index, subInfo ->
                val simInfo = mapOf(
                  "slotIndex" to (subInfo.simSlotIndex + 1), // Convert to base 1
                  "displayName" to (subInfo.displayName?.toString() ?: "SIM ${index + 1}"),
                  "carrierName" to (subInfo.carrierName?.toString() ?: "Unknown"),
                  "subscriptionId" to subInfo.subscriptionId
                )
                simInfoList.add(simInfo)
              }
              info["simInfoList"] = simInfoList
            }
          } catch (e: Exception) {
            info["simInfoError"] = "Error getting SIM information: ${e.message}"
          }
        }
      } catch (e: Exception) {
        info["simCount"] = "Error: ${e.message}"
        info["supportsMultiSim"] = false
      }
      
      result.success(info)
    } catch (e: Exception) {
      android.util.Log.e("UssdHandler", "General error in getSystemInfo: ${e.message}", e)
      result.error("SYSTEM_INFO_ERROR", "Error getting system information: ${e.message}", null)
    }
  }

  // ==================== ACCESSIBILITY METHODS ====================
  
  private fun isAccessibilityServiceEnabled(): Boolean {
    return try {
      if (!::context.isInitialized) {
        android.util.Log.w("UssdHandler", "Context not initialized")
        return false
      }
      
      val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
      val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
      
      enabledServices.any { serviceInfo ->
        serviceInfo.resolveInfo.serviceInfo.name == UssdAccessibilityService::class.java.name
      }
    } catch (e: Exception) {
      android.util.Log.e("UssdHandler", "Error checking accessibility service: ${e.message}")
      false
    }
  }
  
  private fun openAccessibilitySettings(result: Result) {
    try {
      if (!::context.isInitialized) {
        result.error("CONTEXT_ERROR", "Context not initialized", null)
        return
      }
      
      val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
      intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
      context.startActivity(intent)
      result.success(true)
    } catch (e: Exception) {
      android.util.Log.e("UssdHandler", "Error opening accessibility settings: ${e.message}")
      result.error("SETTINGS_ERROR", "Could not open accessibility settings: ${e.message}", null)
    }
  }
  
  private fun setupAccessibilityEventChannel(result: Result) {
    try {
      // Configure the EventChannel for accessibility events
      if (accessibilityEventChannel == null) {
        // The EventChannel will be configured in onAttachedToEngine when implemented
        android.util.Log.d("UssdHandler", "Event channel setup requested")
      }
      
      val serviceEnabled = isAccessibilityServiceEnabled()
      result.success(mapOf(
        "success" to true,
        "serviceEnabled" to serviceEnabled,
        "message" to if (serviceEnabled) "Accessibility service available" else "Accessibility service not enabled"
      ))
    } catch (e: Exception) {
      android.util.Log.e("UssdHandler", "Error setting up accessibility event channel: ${e.message}")
      result.error("CHANNEL_ERROR", "Error setting up accessibility event channel: ${e.message}", null)
    }
  }
  
  // ==================== MULTI-SESSION METHODS ====================
  
  private fun startMultiSessionUssd(ussdCode: String, subscriptionId: Int?, result: Result) {
    try {
      if (!isAccessibilityServiceEnabled()) {
        result.error("ACCESSIBILITY_DISABLED", 
          "Accessibility service must be enabled", null)
        return
      }
      
      if (!hasCallPermission()) {
        result.error("PERMISSION_DENIED", 
          "CALL_PHONE permission required", null)
        return
      }
      
      val accessibilityService = UssdAccessibilityService.getInstance()
      if (accessibilityService == null) {
        result.error("SERVICE_UNAVAILABLE", 
          "Accessibility service not available", null)
        return
      }
      
      val resolvedSubscriptionId = resolveSubscriptionId(subscriptionId)
      android.util.Log.d("UssdHandler", "Starting multi-session: $ussdCode with subscriptionId: $resolvedSubscriptionId")
      
      accessibilityService.startMultiSession { response ->
        android.util.Log.d("UssdHandler", "Multi-session response: $response")
      }
      
      val intent = createUssdIntent(ussdCode, resolvedSubscriptionId)
      
      if (intent.resolveActivity(context.packageManager) != null) {
        context.startActivity(intent)
        
        val simInfo = if (resolvedSubscriptionId != null) {
          " (SIM $resolvedSubscriptionId)"
        } else {
          " (native SIM selector)"
        }
        
        result.success(mapOf(
          "success" to true,
          "message" to "Session started$simInfo"
        ))
      } else {
        result.error("NO_DIALER", "Dialer application not found", null)
      }
      
    } catch (e: Exception) {
      result.error("MULTI_SESSION_ERROR", "Error: ${e.message}", null)
    }
  }
  
  private fun sendMessageInSession(message: String, result: Result) {
    try {
      val accessibilityService = UssdAccessibilityService.getInstance()
      if (accessibilityService == null) {
        result.error("SERVICE_UNAVAILABLE", "Service not available", null)
        return
      }
      
      if (!accessibilityService.hasActiveMultiSession()) {
        result.error("NO_ACTIVE_SESSION", "No active session", null)
        return
      }
      
      val messageSent = accessibilityService.sendMessageInSession(message)
      
      result.success(mapOf(
        "success" to messageSent,
        "message" to if (messageSent) "Message sent" else "Error sending"
      ))
      
    } catch (e: Exception) {
      result.error("MESSAGE_ERROR", "Error: ${e.message}", null)
    }
  }
  
  private fun cancelMultiSession(result: Result) {
    try {
      val accessibilityService = UssdAccessibilityService.getInstance()
      if (accessibilityService == null) {
        result.error("SERVICE_UNAVAILABLE", "Service not available", null)
        return
      }
      
      val cancelled = accessibilityService.cancelMultiSession()
      
      result.success(mapOf(
        "success" to cancelled,
        "message" to if (cancelled) "Session cancelled" else "Error cancelling"
      ))
      
    } catch (e: Exception) {
      result.error("CANCEL_ERROR", "Error: ${e.message}", null)
    }
  }
  
  private fun isMultiSessionActive(): Boolean {
    return try {
      val accessibilityService = UssdAccessibilityService.getInstance()
      accessibilityService?.hasActiveMultiSession() ?: false
    } catch (e: Exception) {
      false
    }
  }

  // ==================== HELPER METHODS FOR MULTI-SIM ====================
  
  /**
   * Gets the number of SIMs available on the device
   */
  private fun getSimCount(): Int {
    return try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        telephonyManager.phoneCount
      } else {
        1 // In previous versions we assume only one SIM
      }
    } catch (e: Exception) {
      android.util.Log.w("UssdHandler", "Error getting number of SIMs: ${e.message}")
      1
    }
  }
  
  /**
   * Determines the subscriptionId to use based on the provided parameter and the number of SIMs
   */
  private fun resolveSubscriptionId(requestedSubscriptionId: Int?): Int? {
    val simCount = getSimCount()
    
    return when {
      // If a subscriptionId was specified, use it
      requestedSubscriptionId != null -> {
        if (requestedSubscriptionId > 0 && requestedSubscriptionId <= simCount) {
          requestedSubscriptionId
        } else {
          android.util.Log.w("UssdHandler", "Invalid subscriptionId: $requestedSubscriptionId, must be between 1 and $simCount")
          null
        }
      }
      // If there is only one SIM, use subscriptionId = 1
      simCount == 1 -> 1
      // If there are multiple SIMs and none was specified, leave null to show native selector
      else -> null
    }
  }
  
  /**
   * Creates a USSD Intent with subscriptionId support
   */
  private fun createUssdIntent(ussdCode: String, subscriptionId: Int?): Intent {
    val intent = Intent(Intent.ACTION_CALL).apply {
      data = Uri.parse("tel:${Uri.encode(ussdCode)}")
      flags = Intent.FLAG_ACTIVITY_NEW_TASK
    }
    
    // If we have a specific subscriptionId and the API supports it, add it to the intent
    if (subscriptionId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      try {
        intent.putExtra("subscription", subscriptionId - 1) // Android uses base 0
        android.util.Log.d("UssdHandler", "Using subscriptionId: $subscriptionId (base 0: ${subscriptionId - 1})")
      } catch (e: Exception) {
        android.util.Log.w("UssdHandler", "Error setting subscriptionId in intent: ${e.message}")
      }
    }
    
    return intent
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  // ActivityAware methods
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivity() {
    activity = null
  }
}