import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_handler/ussd_handler.dart';
import 'package:ussd_handler/ussd_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockUssdHandlerPlatformForAccessibility
    with MockPlatformInterfaceMixin
    implements UssdHandlerPlatform {
  bool _isAccessibilityEnabled = false;
  bool _isMultiSessionActive = false;
  Map<String, dynamic>? _lastStartedSession;

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<UssdResponse> executeUssd(
    String ussdCode, {
    int? subscriptionId,
  }) => Future.value(
    UssdResponse(
      success: true,
      response:
          'Mock USSD response for $ussdCode (SIM: ${subscriptionId ?? "auto"})',
    ),
  );

  @override
  Future<bool> isUssdSupported() => Future.value(true);

  @override
  Future<String?> executeUssdDirect(
    String ussdCode,
    int timeoutSeconds, {
    int? subscriptionId,
    bool iosFallbackToStandard = false,
  }) => Future.value(
    'Mock direct USSD response for $ussdCode (SIM: ${subscriptionId ?? "auto"}, iOS fallback: $iosFallbackToStandard)',
  );

  @override
  Future<Map<String, dynamic>?> getSystemInfo() => Future.value({
    'androidVersion': 33,
    'androidVersionSupported': true,
    'phoneType': 1,
    'networkType': 13,
    'simState': 5,
    'hasCallPermission': true,
    'hasReadPhoneStatePermission': true,
    'hasAllRequiredPermissions': true,
    'networkOperatorName': 'Mock Operator',
    'simOperatorName': 'Mock SIM',
  });

  @override
  Future<bool> hasUssdDirectPermissions() => Future.value(true);

  @override
  Future<bool> isAccessibilityServiceEnabled() =>
      Future.value(_isAccessibilityEnabled);

  @override
  Future<bool> openAccessibilitySettings() {
    // Simulate that the user enabled the service
    _isAccessibilityEnabled = true;
    return Future.value(true);
  }

  @override
  Future<Map<String, dynamic>> setupAccessibilityEventChannel() =>
      Future.value({
        'success': _isAccessibilityEnabled,
        'serviceEnabled': _isAccessibilityEnabled,
        'message': _isAccessibilityEnabled
            ? 'Accessibility service is enabled'
            : 'Accessibility service not enabled',
        'error': _isAccessibilityEnabled ? null : 'Service not enabled',
        'channelId': _isAccessibilityEnabled ? 'channel_123' : null,
      });

  @override
  Future<Map<String, dynamic>> startMultiSessionUssd(
    String ussdCode, {
    int? subscriptionId,
  }) {
    if (!_isAccessibilityEnabled) {
      return Future.value({
        'success': false,
        'error': 'Accessibility service not enabled',
        'message': 'Failed to start session',
        'sessionId': null,
        'ussdResponse': null,
        'sessionActive': false,
      });
    }

    _isMultiSessionActive = true;
    _lastStartedSession = {
      'ussdCode': ussdCode,
      'subscriptionId': subscriptionId,
      'startTime': DateTime.now().millisecondsSinceEpoch,
    };

    return Future.value({
      'success': true,
      'message': 'Multi-session started for $ussdCode',
      'error': null,
      'sessionId': 'session_${DateTime.now().millisecondsSinceEpoch}',
      'ussdResponse': 'Mock USSD response for $ussdCode',
      'sessionActive': true,
    });
  }

  @override
  Future<Map<String, dynamic>> sendMessageInSession(String message) {
    if (!_isMultiSessionActive) {
      return Future.value({
        'success': false,
        'error': 'No active multi-session',
        'message': 'Failed to send message',
        'sessionId': null,
        'ussdResponse': null,
        'sessionActive': false,
      });
    }

    return Future.value({
      'success': true,
      'message': 'Message sent: $message',
      'error': null,
      'sessionId': 'session_${DateTime.now().millisecondsSinceEpoch}',
      'ussdResponse': 'Mock response to: $message',
      'sessionActive': true,
    });
  }

  @override
  Future<Map<String, dynamic>> cancelMultiSession() {
    _isMultiSessionActive = false;
    _lastStartedSession = null;

    return Future.value({
      'success': true,
      'message': 'Multi-session cancelled',
      'error': null,
      'sessionId': null,
      'ussdResponse': null,
      'sessionActive': false,
    });
  }

  @override
  Future<bool> isMultiSessionActive() => Future.value(_isMultiSessionActive);

  // Helper methods for testing
  void resetMockState() {
    _isAccessibilityEnabled = false;
    _isMultiSessionActive = false;
    _lastStartedSession = null;
  }

  Map<String, dynamic>? get lastStartedSession => _lastStartedSession;

  @override
  Future<bool> checkPhonePermissions() {
    return Future.value(true);
  }

  @override
  Future<bool> isPermissionPermanentlyDenied() {
    // For testing, we can simulate that permissions are not permanently denied
    return Future.value(false);
  }

  @override
  Future<bool> openAppSettings() {
    // Simulate opening app settings successfully
    return Future.value(true);
  }

  @override
  Future<bool> requestPhonePermissions() {
    // Simulate requesting permissions successfully
    return Future.value(true);
  }

  @override
  Future<bool> shouldShowPermissionRationale() {
    // Simulate that we don't need to show rationale
    return Future.value(false);
  }
}

void main() {
  group('USSD Handler - Accessibility Service Tests', () {
    late MockUssdHandlerPlatformForAccessibility mockPlatform;

    setUp(() {
      mockPlatform = MockUssdHandlerPlatformForAccessibility();
      UssdHandlerPlatform.instance = mockPlatform;
    });

    tearDown(() {
      mockPlatform.resetMockState();
    });

    group('Accessibility Service Management', () {
      test(
        'should return false when accessibility service is disabled initially',
        () async {
          final isEnabled = await UssdHandler.isAccessibilityServiceEnabled();
          expect(isEnabled, false);
        },
      );

      test(
        'should enable accessibility service when opening settings',
        () async {
          // Initially disabled
          expect(await UssdHandler.isAccessibilityServiceEnabled(), false);

          // Open settings (simulates user enabling the service)
          final opened = await UssdHandler.openAccessibilitySettings();
          expect(opened, true);

          // Now should be enabled
          expect(await UssdHandler.isAccessibilityServiceEnabled(), true);
        },
      );

      test(
        'should setup event channel successfully when service is enabled',
        () async {
          // Enable service first
          await UssdHandler.openAccessibilitySettings();

          final result = await UssdHandler.setupAccessibilityEventChannel();
          expect(result.success, true);
          expect(result.serviceEnabled, true);
        },
      );

      test('should indicate service not enabled in event channel setup when disabled', () async {
        final result = await UssdHandler.setupAccessibilityEventChannel();
        expect(result.success, false);
        expect(result.serviceEnabled, false);
      });
    });

    group('Multi-Session USSD - Prerequisites', () {
      test('should fail to start multi-session when accessibility service is disabled', () async {
        final result = await UssdHandler.startMultiSessionUssd('*123#');
        expect(result.success, false);
        expect(result.error, 'Accessibility service not enabled');
      });

      test('should start multi-session successfully when accessibility service is enabled', () async {
        // Enable service first
        await UssdHandler.openAccessibilitySettings();

        final result = await UssdHandler.startMultiSessionUssd('*123#');
        expect(result.success, true);
        expect(result.message, contains('*123#'));
      });
    });

    group('Multi-Session USSD - Session Management', () {
      setUp(() async {
        // Enable accessibility service for multi-session tests
        await UssdHandler.openAccessibilitySettings();
      });

      test('should track session state correctly', () async {
        // Initially no active session
        expect(await UssdHandler.isMultiSessionActive(), false);

        // Start session
        await UssdHandler.startMultiSessionUssd('*123#');
        expect(await UssdHandler.isMultiSessionActive(), true);

        // Cancel session
        await UssdHandler.cancelMultiSession();
        expect(await UssdHandler.isMultiSessionActive(), false);
      });

      test('should fail to send message when no session is active', () async {
        final result = await UssdHandler.sendMessageInSession('1');
        expect(result.success, false);
        expect(result.error, 'No active multi-session');
      });

      test('should send message successfully when session is active', () async {
        // Start session
        await UssdHandler.startMultiSessionUssd('*123#');

        // Send message
        final result = await UssdHandler.sendMessageInSession('1');
        expect(result.success, true);
        expect(result.message, contains('1'));
        expect(result.ussdResponse, isNotNull);
      });

      test('should maintain session state across multiple messages', () async {
        // Start session
        await UssdHandler.startMultiSessionUssd('*123#');

        // Send multiple messages
        final result1 = await UssdHandler.sendMessageInSession('1');
        expect(result1.success, true);

        final result2 = await UssdHandler.sendMessageInSession('2');
        expect(result2.success, true);

        final result3 = await UssdHandler.sendMessageInSession('0');
        expect(result3.success, true);

        // Session should still be active
        expect(await UssdHandler.isMultiSessionActive(), true);
      });
    });

    group('Multi-Session USSD - Complete Workflows', () {
      setUp(() async {
        // Enable accessibility service for workflow tests
        await UssdHandler.openAccessibilitySettings();
      });

      test('should handle complete balance check workflow', () async {
        // Simulate balance check workflow: *123# -> 1 (check balance) -> cancel

        // 1. Start session
        final startResult = await UssdHandler.startMultiSessionUssd('*123#');
        expect(startResult.success, true);
        expect(await UssdHandler.isMultiSessionActive(), true);

        // 2. Select balance option
        final balanceResult = await UssdHandler.sendMessageInSession('1');
        expect(balanceResult.success, true);

        // 3. Cancel session
        final cancelResult = await UssdHandler.cancelMultiSession();
        expect(cancelResult.success, true);
        expect(await UssdHandler.isMultiSessionActive(), false);
      });

      test('should handle complete menu navigation workflow', () async {
        // Simulate complex menu navigation: *123# -> 2 -> 1 -> 3 -> cancel

        await UssdHandler.startMultiSessionUssd('*123#');

        // Navigate through multiple menu levels
        final step1 = await UssdHandler.sendMessageInSession('2');
        expect(step1.success, true);

        final step2 = await UssdHandler.sendMessageInSession('1');
        expect(step2.success, true);

        final step3 = await UssdHandler.sendMessageInSession('3');
        expect(step3.success, true);

        // Verify session is still active after multiple interactions
        expect(await UssdHandler.isMultiSessionActive(), true);

        // Clean up
        await UssdHandler.cancelMultiSession();
      });

      test('should handle error recovery in multi-session', () async {
        // Start session
        await UssdHandler.startMultiSessionUssd('*123#');

        // Send some messages
        await UssdHandler.sendMessageInSession('1');
        await UssdHandler.sendMessageInSession('2');

        // Cancel should work even after multiple interactions
        final cancelResult = await UssdHandler.cancelMultiSession();
        expect(cancelResult.success, true);

        // Verify clean state
        expect(await UssdHandler.isMultiSessionActive(), false);

        // Should be able to start new session
        final newSessionResult = await UssdHandler.startMultiSessionUssd(
          '*456#',
        );
        expect(newSessionResult.success, true);
      });
    });

    group('Integration with Standard USSD', () {
      test('should work alongside standard USSD methods', () async {
        // Standard USSD should work without accessibility service
        final standardResult = await UssdHandler.executeUssd('*#06#');
        expect(standardResult.success, true);

        // Direct USSD should also work
        final directResult = await UssdHandler.executeUssdDirect('*#06#');
        expect(directResult, isNotNull);

        // Multi-session requires accessibility service
        await UssdHandler.openAccessibilitySettings();
        final multiResult = await UssdHandler.startMultiSessionUssd('*123#');
        expect(multiResult.success, true);
      });
    });
  });
}
