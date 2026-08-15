import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ussd_handler_method_channel.dart';
import 'ussd_handler.dart';

abstract class UssdHandlerPlatform extends PlatformInterface {
  /// Constructs a UssdHandlerPlatform.
  UssdHandlerPlatform() : super(token: _token);

  static final Object _token = Object();

  static UssdHandlerPlatform _instance = MethodChannelUssdHandler();

  /// The default instance of [UssdHandlerPlatform] to use.
  ///
  /// Defaults to [MethodChannelUssdHandler].
  static UssdHandlerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [UssdHandlerPlatform] when
  /// they register themselves.
  static set instance(UssdHandlerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Executes a USSD code
  ///
  /// [ussdCode] - The USSD code to execute
  /// [subscriptionId] - (Optional) Subscription ID (SIM slot).
  /// If not provided and there are multiple SIMs, the native selector will be shown.
  /// If there is only one SIM, it is used by default.
  Future<UssdResponse> executeUssd(String ussdCode, {int? subscriptionId}) {
    throw UnimplementedError('executeUssd() has not been implemented.');
  }

  /// Checks if the device supports USSD codes
  Future<bool> isUssdSupported() {
    throw UnimplementedError('isUssdSupported() has not been implemented.');
  }

  /// Executes a USSD code directly and gets the response
  /// without showing the native system dialog (Android only)
  ///
  /// [ussdCode] - The USSD code to execute
  /// [timeoutSeconds] - Timeout in seconds
  /// [subscriptionId] - (Optional) Subscription ID (SIM slot).
  /// If not provided and there are multiple SIMs, the native selector will be shown.
  /// If there is only one SIM, it is used by default.
  /// [iosFallbackToStandard] - (iOS only) If true, uses executeUssd as fallback.
  Future<String?> executeUssdDirect(
    String ussdCode,
    int timeoutSeconds, {
    int? subscriptionId,
    bool iosFallbackToStandard = false,
  }) {
    throw UnimplementedError('executeUssdDirect() has not been implemented.');
  }

  /// Gets system information for diagnostics (Android only)
  Future<Map<String, dynamic>?> getSystemInfo() {
    throw UnimplementedError('getSystemInfo() has not been implemented.');
  }

  /// Checks if it has the necessary permissions for direct USSD
  Future<bool> hasUssdDirectPermissions() {
    throw UnimplementedError(
      'hasUssdDirectPermissions() has not been implemented.',
    );
  }

  /// Check if the package has the CALL_PHONE and READ_PHONE_STATE permissions.
  Future<bool> checkPhonePermissions() async {
    throw UnimplementedError(
      'checkPhonePermissions() has not been implemented.',
    );
  }

  /// Requests the necessary permissions natively, without third-party dependencies.
  Future<bool> requestPhonePermissions() async {
    throw UnimplementedError(
      'requestPhonePermissions() has not been implemented.',
    );
  }

  /// Indicates whether an explanation should be shown to the user (Temporarily denied)
  Future<bool> shouldShowPermissionRationale() async {
    throw UnimplementedError(
      'shouldShowPermissionRationale() has not been implemented.',
    );
  }

  /// Returns `true` if the user checked the **"Don't ask again"** option.
  /// Always returns `false` on iOS.
  Future<bool> isPermissionPermanentlyDenied() async {
    throw UnimplementedError(
      'isPermissionPermanentlyDenied() has not been implemented.',
    );
  }

  /// Opens the application settings screen in the operating system.
  Future<bool> openAppSettings() async {
    throw UnimplementedError('openAppSettings() has not been implemented.');
  }

  // ==================== ACCESSIBILITY METHODS ====================

  /// Checks if the accessibility service is enabled
  Future<bool> isAccessibilityServiceEnabled() {
    throw UnimplementedError(
      'isAccessibilityServiceEnabled() has not been implemented.',
    );
  }

  /// Opens the accessibility services settings
  Future<bool> openAccessibilitySettings() {
    throw UnimplementedError(
      'openAccessibilitySettings() has not been implemented.',
    );
  }

  /// Configures the event channel for the accessibility service
  Future<Map<String, dynamic>> setupAccessibilityEventChannel() {
    throw UnimplementedError(
      'setupAccessibilityEventChannel() has not been implemented.',
    );
  }

  // ==================== MULTI-SESSION METHODS ====================

  /// Starts a multi-session USSD session
  ///
  /// [ussdCode] - The USSD code to start the session
  /// [subscriptionId] - (Optional) Subscription ID (SIM slot).
  /// If not provided and there are multiple SIMs, the native selector will be shown.
  /// If there is only one SIM, it is used by default.
  ///
  /// Returns a map with the operation result.
  /// Requires the accessibility service to be enabled.
  Future<Map<String, dynamic>> startMultiSessionUssd(
    String ussdCode, {
    int? subscriptionId,
  }) {
    throw UnimplementedError(
      'startMultiSessionUssd() has not been implemented.',
    );
  }

  /// Sends a message in the active multi-session USSD session
  ///
  /// [message] - The message to send
  ///
  /// Returns a map with the operation result.
  /// Only works if there is an active multi-session session.
  Future<Map<String, dynamic>> sendMessageInSession(String message) {
    throw UnimplementedError(
      'sendMessageInSession() has not been implemented.',
    );
  }

  /// Cancels the active multi-session USSD session
  ///
  /// Returns a map with the operation result.
  Future<Map<String, dynamic>> cancelMultiSession() {
    throw UnimplementedError('cancelMultiSession() has not been implemented.');
  }

  /// Checks if there is an active multi-session USSD session
  ///
  /// Returns true if there is an active session.
  Future<bool> isMultiSessionActive() {
    throw UnimplementedError(
      'isMultiSessionActive() has not been implemented.',
    );
  }
}
