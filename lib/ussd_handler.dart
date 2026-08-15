import 'ussd_handler_platform_interface.dart';

/// Result of executing a USSD code
class UssdResponse {
  final String? response;
  final bool success;
  final String? errorMessage;

  UssdResponse({this.response, required this.success, this.errorMessage});

  factory UssdResponse.fromMap(Map<String, dynamic> map) {
    return UssdResponse(
      response: map['response'],
      success: map['success'] ?? false,
      errorMessage: map['errorMessage'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'response': response,
      'success': success,
      'errorMessage': errorMessage,
    };
  }
}

/// Detailed system information for diagnostics
class SystemInfo {
  final String platform;
  final int? androidVersion;
  final String? iosVersion;
  final String deviceModel;
  final String deviceName;
  final int simCount;
  final bool supportsMultiSim;
  final bool ussdSupported;
  final bool ussdDirectSupported;
  final bool multiSessionSupported;
  final bool accessibilityServiceSupported;
  final bool canMakePhoneCalls;
  final bool? hasCallPermission;
  final bool? hasReadPhoneStatePermission;
  final List<String>? limitations;
  final Map<String, dynamic> additionalInfo;

  SystemInfo({
    required this.platform,
    this.androidVersion,
    this.iosVersion,
    required this.deviceModel,
    required this.deviceName,
    required this.simCount,
    required this.supportsMultiSim,
    required this.ussdSupported,
    required this.ussdDirectSupported,
    required this.multiSessionSupported,
    required this.accessibilityServiceSupported,
    required this.canMakePhoneCalls,
    this.hasCallPermission,
    this.hasReadPhoneStatePermission,
    this.limitations,
    this.additionalInfo = const {},
  });

  factory SystemInfo.fromMap(Map<String, dynamic> map) {
    return SystemInfo(
      platform: map['platform'] ?? 'Unknown',
      androidVersion: map['androidVersion'],
      iosVersion: map['iosVersion'],
      deviceModel: map['deviceModel'] ?? 'Unknown',
      deviceName: map['deviceName'] ?? 'Unknown',
      simCount: map['simCount'] ?? 0,
      supportsMultiSim: map['supportsMultiSim'] ?? false,
      ussdSupported: map['ussdSupported'] ?? false,
      ussdDirectSupported: map['ussdDirectSupported'] ?? false,
      multiSessionSupported: map['multiSessionSupported'] ?? false,
      accessibilityServiceSupported:
          map['accessibilityServiceSupported'] ?? false,
      canMakePhoneCalls: map['canMakePhoneCalls'] ?? false,
      hasCallPermission: map['hasCallPermission'],
      hasReadPhoneStatePermission: map['hasReadPhoneStatePermission'],
      limitations: map['limitations']?.cast<String>(),
      additionalInfo: Map<String, dynamic>.from(map)
        ..removeWhere(
          (key, value) => [
            'platform',
            'androidVersion',
            'iosVersion',
            'deviceModel',
            'deviceName',
            'simCount',
            'supportsMultiSim',
            'ussdSupported',
            'ussdDirectSupported',
            'multiSessionSupported',
            'accessibilityServiceSupported',
            'canMakePhoneCalls',
            'hasCallPermission',
            'hasReadPhoneStatePermission',
            'limitations',
          ].contains(key),
        ),
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> result = {
      'platform': platform,
      'deviceModel': deviceModel,
      'deviceName': deviceName,
      'simCount': simCount,
      'supportsMultiSim': supportsMultiSim,
      'ussdSupported': ussdSupported,
      'ussdDirectSupported': ussdDirectSupported,
      'multiSessionSupported': multiSessionSupported,
      'accessibilityServiceSupported': accessibilityServiceSupported,
      'canMakePhoneCalls': canMakePhoneCalls,
    };

    if (androidVersion != null) {
      result['androidVersion'] = androidVersion;
    }
    if (iosVersion != null) {
      result['iosVersion'] = iosVersion;
    }
    if (hasCallPermission != null) {
      result['hasCallPermission'] = hasCallPermission;
    }
    if (hasReadPhoneStatePermission != null) {
      result['hasReadPhoneStatePermission'] = hasReadPhoneStatePermission;
    }
    if (limitations != null) {
      result['limitations'] = limitations;
    }

    result.addAll(additionalInfo);
    return result;
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('SystemInfo:');
    buffer.writeln('  Platform: $platform');
    if (androidVersion != null) {
      buffer.writeln('  Android Version: $androidVersion');
    }
    if (iosVersion != null) {
      buffer.writeln('  iOS Version: $iosVersion');
    }
    buffer.writeln('  Model: $deviceModel');
    buffer.writeln('  Name: $deviceName');
    buffer.writeln('  SIMs: $simCount');
    buffer.writeln('  Multi-SIM: $supportsMultiSim');
    buffer.writeln('  USSD supported: $ussdSupported');
    buffer.writeln('  USSD direct: $ussdDirectSupported');
    buffer.writeln('  Multi-session: $multiSessionSupported');
    buffer.writeln('  Accessibility service: $accessibilityServiceSupported');
    buffer.writeln('  Can make phone calls: $canMakePhoneCalls');
    if (hasCallPermission != null) {
      buffer.writeln('  Call permission: $hasCallPermission');
    }
    if (hasReadPhoneStatePermission != null) {
      buffer.writeln('  Phone state permission: $hasReadPhoneStatePermission');
    }
    if (limitations != null && limitations!.isNotEmpty) {
      buffer.writeln('  Limitations: ${limitations!.join(', ')}');
    }
    if (additionalInfo.isNotEmpty) {
      buffer.writeln('  Additional information:');
      additionalInfo.forEach((key, value) {
        buffer.writeln('    $key: $value');
      });
    }
    return buffer.toString();
  }
}

/// Result of accessibility event channel configuration
class AccessibilityEventChannelResult {
  final bool success;
  final String message;
  final String? error;
  final bool serviceEnabled;
  final String? channelId;

  AccessibilityEventChannelResult({
    required this.success,
    required this.message,
    this.error,
    required this.serviceEnabled,
    this.channelId,
  });

  factory AccessibilityEventChannelResult.fromMap(Map<String, dynamic> map) {
    return AccessibilityEventChannelResult(
      success: map['success'] ?? false,
      message: map['message'] ?? '',
      error: map['error'],
      serviceEnabled: map['serviceEnabled'] ?? false,
      channelId: map['channelId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'message': message,
      'error': error,
      'serviceEnabled': serviceEnabled,
      'channelId': channelId,
    };
  }
}

/// Result of multi-USSD session operations
class MultiSessionResult {
  final bool success;
  final String message;
  final String? error;
  final String? sessionId;
  final String? ussdResponse;
  final bool sessionActive;

  MultiSessionResult({
    required this.success,
    required this.message,
    this.error,
    this.sessionId,
    this.ussdResponse,
    required this.sessionActive,
  });

  factory MultiSessionResult.fromMap(Map<String, dynamic> map) {
    return MultiSessionResult(
      success: map['success'] ?? false,
      message: map['message'] ?? '',
      error: map['error'],
      sessionId: map['sessionId'],
      ussdResponse: map['ussdResponse'],
      sessionActive: map['sessionActive'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'message': message,
      'error': error,
      'sessionId': sessionId,
      'ussdResponse': ussdResponse,
      'sessionActive': sessionActive,
    };
  }
}

class UssdHandler {
  // Private constructor to prevent instantiation
  UssdHandler._();

  static Future<String?> getPlatformVersion() {
    return UssdHandlerPlatform.instance.getPlatformVersion();
  }

  /// Executes a USSD code
  ///
  /// [ussdCode] - The USSD code to execute (e.g.: "*123#")
  /// [subscriptionId] - (Optional) Subscription ID (SIM slot).
  /// If not provided and there are multiple SIMs, the native selector will be shown.
  /// If there is only one SIM, it is used by default.
  ///
  /// Returns a [UssdResponse] with the operation result
  static Future<UssdResponse> executeUssd(
    String ussdCode, {
    int? subscriptionId,
  }) {
    return UssdHandlerPlatform.instance.executeUssd(
      ussdCode,
      subscriptionId: subscriptionId,
    );
  }

  /// Checks if the device supports USSD codes
  static Future<bool> isUssdSupported() {
    return UssdHandlerPlatform.instance.isUssdSupported();
  }

  /// Executes a USSD code directly and gets the response
  /// without showing the native system dialog (Android only)
  ///
  /// [ussdCode] - The USSD code to execute (e.g.: "*123#")
  /// [timeoutSeconds] - Timeout in seconds to wait for response (default: 30)
  /// [subscriptionId] - (Optional) Subscription ID (SIM slot).
  /// If not provided and there are multiple SIMs, the native selector will be shown.
  /// If there is only one SIM, it is used by default.
  /// [iosFallbackToStandard] - (iOS only) If true, uses executeUssd as fallback.
  /// Default is false to maintain consistency with Android.
  ///
  /// Returns the USSD response as String or null if no response
  ///
  /// NOTE: This functionality requires additional permissions on Android
  /// and may not work on all devices or Android versions.
  /// On iOS, if iosFallbackToStandard is false, it always returns an error.
  static Future<String?> executeUssdDirect(
    String ussdCode, {
    int timeoutSeconds = 30,
    int? subscriptionId,
    bool iosFallbackToStandard = false,
  }) {
    return UssdHandlerPlatform.instance.executeUssdDirect(
      ussdCode,
      timeoutSeconds,
      subscriptionId: subscriptionId,
      iosFallbackToStandard: iosFallbackToStandard,
    );
  }

  /// Gets system information for diagnostics
  ///
  /// Returns information about permissions, network status, SIM, etc.
  /// Useful for diagnosing USSD issues
  ///
  /// Example:
  /// ```dart
  /// final systemInfo = await UssdHandler.getSystemInfo();
  /// if (systemInfo != null) {
  ///   print('Platform: ${systemInfo.platform}');
  ///   print('USSD support: ${systemInfo.ussdSupported}');
  ///   print('Multi-SIM: ${systemInfo.supportsMultiSim}');
  /// }
  /// ```
  static Future<SystemInfo?> getSystemInfo() async {
    final result = await UssdHandlerPlatform.instance.getSystemInfo();
    return result != null ? SystemInfo.fromMap(result) : null;
  }

  /// Checks if the plugin has the necessary permissions to execute direct USSD
  ///
  /// Returns `true` if all permissions are granted, `false` if permissions are missing.
  /// The plugin will automatically request missing permissions when executing direct USSD.
  static Future<bool> hasUssdDirectPermissions() async {
    return UssdHandlerPlatform.instance.hasUssdDirectPermissions();
  }

  /// Checks whether both required phone permissions (`CALL_PHONE` and `READ_PHONE_STATE`)
  /// are currently granted by the user.
  ///
  /// Returns `true` if all permissions are granted, otherwise returns `false`.
  ///
  /// ### Example:
  /// ```dart
  /// bool hasPermissions = await UssdHandler.checkPhonePermissions();
  /// if (!hasPermissions) {
  ///   // Permissions are missing, request them.
  /// }
  /// ```
  static Future<bool> checkPhonePermissions() async {
    return UssdHandlerPlatform.instance.checkPhonePermissions();
  }

  /// Requests the necessary Android phone permissions native-side without external dependencies.
  ///
  /// This will trigger the standard Android system permission dialog to ask the user
  /// for `CALL_PHONE` and `READ_PHONE_STATE` permissions.
  ///
  /// Returns `true` if the user grants the permissions. If the user denies them or
  /// has previously selected "Don't ask again", this returns `false`.
  ///
  /// Throws a `PlatformException` if a native channel error occurs during the request.
  ///
  /// See also:
  /// * [isPermissionPermanentlyDenied] to check if the user blocked the permission dialog.
  static Future<bool> requestPhonePermissions() async {
    return UssdHandlerPlatform.instance.requestPhonePermissions();
  }

  /// Checks whether the app should display an educational UI or rationale explaining
  /// why these permissions are required.
  ///
  /// This triggers the native `ActivityCompat.shouldShowRequestPermissionRationale` API.
  /// It returns `true` if the user has previously denied the permission request but
  /// **has not** checked the "Don't ask again" checkbox yet.
  ///
  /// Returns `false` if the permissions have never been requested, are already granted,
  /// or are permanently denied.
  static Future<bool> shouldShowPermissionRationale() async {
    return UssdHandlerPlatform.instance.shouldShowPermissionRationale();
  }

  /// Determines if the phone permissions have been permanently denied by the user.
  ///
  /// Returns `true` if the user denied the permissions and checked the **"Don't ask again"**
  /// option (or if the system permanently restricts the app from requesting them).
  /// When this happens, the native system dialog can no longer be displayed, and you must
  /// redirect the user to the system settings using [openAppSettings].
  ///
  /// Returns `false` if permissions are granted or can still be requested via [requestPhonePermissions].
  static Future<bool> isPermissionPermanentlyDenied() async {
    return UssdHandlerPlatform.instance.isPermissionPermanentlyDenied();
  }

  /// Opens the current Android application details screen within the system settings.
  ///
  /// Use this method as a fallback when [isPermissionPermanentlyDenied] returns `true`,
  /// allowing the user to manually enable the `CALL_PHONE` and `READ_PHONE_STATE` permissions.
  ///
  /// Returns `true` if the settings screen was successfully opened.
  ///
  /// Throws a `PlatformException` with the code `SETTINGS_ERROR` if the system intent fails.
  ///
  /// ### Example:
  /// ```dart
  /// if (await UssdHandler.isPermissionPermanentlyDenied()) {
  ///   await UssdHandler.openAppSettings();
  /// }
  /// ```
  static Future<bool> openAppSettings() async {
    return UssdHandlerPlatform.instance.openAppSettings();
  }

  // ==================== ACCESSIBILITY METHODS ====================

  /// Checks if the USSD accessibility service is enabled
  ///
  /// This service allows automatic capture of USSD responses
  /// from the system, providing a better user experience.
  ///
  /// Returns true if the service is enabled.
  ///
  /// Example:
  /// ```dart
  /// final isEnabled = await UssdHandler.isAccessibilityServiceEnabled();
  /// if (!isEnabled) {
  ///   // Show message to enable the service
  ///   await UssdHandler.openAccessibilitySettings();
  /// }
  /// ```
  static Future<bool> isAccessibilityServiceEnabled() {
    return UssdHandlerPlatform.instance.isAccessibilityServiceEnabled();
  }

  /// Opens the system accessibility services settings
  ///
  /// Allows the user to enable the USSD accessibility service.
  /// Returns true if the settings could be opened.
  ///
  /// Example:
  /// ```dart
  /// final opened = await UssdHandler.openAccessibilitySettings();
  /// if (opened) {
  ///   print('Accessibility settings opened');
  /// }
  /// ```
  static Future<bool> openAccessibilitySettings() {
    return UssdHandlerPlatform.instance.openAccessibilitySettings();
  }

  /// Configures the event channel for the accessibility service
  ///
  /// Allows receiving events from the accessibility service when
  /// system USSD dialogs are detected.
  ///
  /// Returns an [AccessibilityEventChannelResult] with information about the configuration status.
  ///
  /// Example:
  /// ```dart
  /// final setup = await UssdHandler.setupAccessibilityEventChannel();
  /// if (setup.success) {
  ///   print('Event channel configured: ${setup.message}');
  ///   print('Service enabled: ${setup.serviceEnabled}');
  /// } else {
  ///   print('Error: ${setup.error}');
  /// }
  /// ```
  static Future<AccessibilityEventChannelResult>
  setupAccessibilityEventChannel() async {
    final result = await UssdHandlerPlatform.instance
        .setupAccessibilityEventChannel();
    return AccessibilityEventChannelResult.fromMap(result);
  }

  // ==================== MULTI-SESSION METHODS ====================

  /// Starts a multi-session USSD session
  ///
  /// [ussdCode] - The USSD code to start the session (e.g.: "*123#")
  /// [subscriptionId] - (Optional) Subscription ID (SIM slot).
  /// If not provided and there are multiple SIMs, the native selector will be shown.
  /// If there is only one SIM, it is used by default.
  ///
  /// Returns a [MultiSessionResult] with the operation result:
  /// - `success`: true if the session started correctly
  /// - `message`: descriptive message of the result
  /// - `error`: error message if it failed
  /// - `sessionId`: unique ID of the created session
  /// - `ussdResponse`: initial USSD response
  /// - `sessionActive`: current session status
  ///
  /// IMPORTANT: Requires the accessibility service to be enabled.
  /// Use [isAccessibilityServiceEnabled] to check before calling this method.
  ///
  /// Example:
  /// ```dart
  /// final result = await UssdHandler.startMultiSessionUssd('*123#');
  /// if (result.success) {
  ///   print('Session started: ${result.message}');
  ///   print('Session ID: ${result.sessionId}');
  ///   print('Response: ${result.ussdResponse}');
  /// } else {
  ///   print('Error: ${result.error}');
  /// }
  /// ```
  static Future<MultiSessionResult> startMultiSessionUssd(
    String ussdCode, {
    int? subscriptionId,
  }) async {
    final result = await UssdHandlerPlatform.instance.startMultiSessionUssd(
      ussdCode,
      subscriptionId: subscriptionId,
    );
    return MultiSessionResult.fromMap(result);
  }

  /// Sends a message in the active multi-session USSD session
  ///
  /// [message] - The message to send (numbers, text, etc.)
  ///
  /// Returns a [MultiSessionResult] with the operation result:
  /// - `success`: true if the message was sent correctly
  /// - `message`: descriptive message of the result
  /// - `error`: error message if it failed
  /// - `ussdResponse`: USSD response to the sent message
  /// - `sessionActive`: current session status
  ///
  /// IMPORTANT: Only works if there is an active multi-session session.
  /// Use [isMultiSessionActive] to check before sending.
  ///
  /// Example:
  /// ```dart
  /// final result = await UssdHandler.sendMessageInSession('1');
  /// if (result.success) {
  ///   print('Message sent: ${result.message}');
  ///   print('USSD response: ${result.ussdResponse}');
  ///   print('Session active: ${result.sessionActive}');
  /// } else {
  ///   print('Error: ${result.error}');
  /// }
  /// ```
  static Future<MultiSessionResult> sendMessageInSession(String message) async {
    final result = await UssdHandlerPlatform.instance.sendMessageInSession(
      message,
    );
    return MultiSessionResult.fromMap(result);
  }

  /// Cancels the active multi-session USSD session
  ///
  /// Returns a [MultiSessionResult] with the operation result:
  /// - `success`: true if the session was cancelled correctly
  /// - `message`: descriptive message of the result
  /// - `error`: error message if it failed
  /// - `sessionActive`: final session status (should be false if successful)
  ///
  /// Example:
  /// ```dart
  /// final result = await UssdHandler.cancelMultiSession();
  /// if (result.success) {
  ///   print('Session cancelled: ${result.message}');
  ///   print('Session active: ${result.sessionActive}'); // Should be false
  /// } else {
  ///   print('Error: ${result.error}');
  /// }
  /// ```
  static Future<MultiSessionResult> cancelMultiSession() async {
    final result = await UssdHandlerPlatform.instance.cancelMultiSession();
    return MultiSessionResult.fromMap(result);
  }

  /// Checks if there is an active multi-session USSD session
  ///
  /// Returns true if there is an active session, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// final isActive = await UssdHandler.isMultiSessionActive();
  /// if (isActive) {
  ///   print('There is an active multi-session session');
  ///   // You can send messages or cancel the session
  /// } else {
  ///   print('No active session');
  ///   // You can start a new session
  /// }
  /// ```
  static Future<bool> isMultiSessionActive() {
    return UssdHandlerPlatform.instance.isMultiSessionActive();
  }
}
