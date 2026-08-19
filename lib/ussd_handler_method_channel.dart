import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ussd_handler_platform_interface.dart';
import 'ussd_handler.dart';

/// An implementation of [UssdHandlerPlatform] that uses method channels.
class MethodChannelUssdHandler extends UssdHandlerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ussd_handler');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<UssdResponse> executeUssd(
    String ussdCode, {
    int? subscriptionId,
  }) async {
    try {
      final Map<String, dynamic> arguments = {'ussdCode': ussdCode};
      if (subscriptionId != null) {
        arguments['subscriptionId'] = subscriptionId;
      }

      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'executeUssd',
        arguments,
      );

      if (result != null) {
        return UssdResponse.fromMap(Map<String, dynamic>.from(result));
      } else {
        return UssdResponse(
          success: false,
          errorMessage: 'No response received from native code',
        );
      }
    } on PlatformException catch (e) {
      return UssdResponse(success: false, errorMessage: 'Error: ${e.message}');
    }
  }

  @override
  Future<bool> isUssdSupported() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('isUssdSupported');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<String?> executeUssdDirect(
    String ussdCode,
    int timeoutSeconds, {
    int? subscriptionId,
    bool iosFallbackToStandard = false,
  }) async {
    try {
      final Map<String, dynamic> arguments = {
        'ussdCode': ussdCode,
        'timeoutSeconds': timeoutSeconds,
        'iosFallbackToStandard': iosFallbackToStandard,
      };
      if (subscriptionId != null) {
        arguments['subscriptionId'] = subscriptionId;
      }

      final result = await methodChannel.invokeMethod<String>(
        'executeUssdDirect',
        arguments,
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error executing direct USSD: ${e.message}');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> getSystemInfo() async {
    try {
      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getSystemInfo',
      );
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('Error getting system information: ${e.message}');
      return null;
    }
  }

  @override
  Future<bool> hasUssdDirectPermissions() async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'hasUssdDirectPermissions',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking direct USSD permissions: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> checkPhonePermissions() async {
    if (Platform.isIOS) return true; // iOS has no CALL_PHONE permission model
    try {
      final bool? hasPermission = await methodChannel.invokeMethod(
        'checkPhonePermissions',
      );
      return hasPermission ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking phone permissions: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> requestPhonePermissions() async {
    if (Platform.isIOS) return true; // iOS has no CALL_PHONE permission model
    try {
      final bool? granted = await methodChannel.invokeMethod(
        'requestPhonePermissions',
      );
      return granted ?? false;
    } on PlatformException catch (e) {
      debugPrint("Error requesting permissions: ${e.message}");
      return false;
    }
  }

  @override
  Future<bool> shouldShowPermissionRationale() async {
    if (Platform.isIOS) return false; // iOS has no permission rationale concept
    try {
      final bool? show = await methodChannel.invokeMethod(
        'shouldShowPermissionRationale',
      );
      return show ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking permission rationale: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> isPermissionPermanentlyDenied() async {
    if (Platform.isIOS) return false; // iOS has no permanent denial concept
    try {
      final bool? isPermanent = await methodChannel.invokeMethod(
        'isPermissionPermanentlyDenied',
      );
      return isPermanent ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking permanent denial: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> openAppSettings() async {
    if (Platform.isIOS) {
      return false; // no USSD permission settings to open on iOS
    }
    try {
      final bool? opened = await methodChannel.invokeMethod('openAppSettings');
      return opened ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error opening app settings: ${e.message}');
      return false;
    }
  }

  // ==================== ACCESSIBILITY METHODS ====================

  @override
  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'isAccessibilityServiceEnabled',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking accessibility service: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> openAccessibilitySettings() async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'openAccessibilitySettings',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error opening accessibility settings: ${e.message}');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> setupAccessibilityEventChannel() async {
    try {
      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'setupAccessibilityEventChannel',
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      debugPrint('Error setting up accessibility event channel: ${e.message}');
      return {'success': false, 'error': e.message};
    }
  }

  // ==================== MULTI-SESSION METHODS ====================

  @override
  Future<Map<String, dynamic>> startMultiSessionUssd(
    String ussdCode, {
    int? subscriptionId,
  }) async {
    try {
      final Map<String, dynamic> arguments = {'ussdCode': ussdCode};
      if (subscriptionId != null) {
        arguments['subscriptionId'] = subscriptionId;
      }

      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'startMultiSessionUssd',
        arguments,
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      debugPrint('Error starting multi-session: ${e.message}');
      return {'success': false, 'error': e.message};
    }
  }

  @override
  Future<Map<String, dynamic>> sendMessageInSession(String message) async {
    try {
      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'sendMessageInSession',
        {'message': message},
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      debugPrint('Error sending message in session: ${e.message}');
      return {'success': false, 'error': e.message};
    }
  }

  @override
  Future<Map<String, dynamic>> cancelMultiSession() async {
    try {
      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
        'cancelMultiSession',
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      debugPrint('Error canceling multi-session: ${e.message}');
      return {'success': false, 'error': e.message};
    }
  }

  @override
  Future<bool> isMultiSessionActive() async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'isMultiSessionActive',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking active session: ${e.message}');
      return false;
    }
  }
}
