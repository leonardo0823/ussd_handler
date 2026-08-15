import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_handler/ussd_handler.dart';
import 'package:ussd_handler/ussd_handler_platform_interface.dart';
import 'package:ussd_handler/ussd_handler_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockUssdHandlerPlatform
    with MockPlatformInterfaceMixin
    implements UssdHandlerPlatform {
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
    'platform': 'Android',
    'androidVersion': 33,
    'deviceModel': 'Mock Device',
    'deviceName': 'Mock Device Name',
    'simCount': 2,
    'supportsMultiSim': true,
    'ussdSupported': true,
    'ussdDirectSupported': true,
    'multiSessionSupported': true,
    'accessibilityServiceSupported': true,
    'canMakePhoneCalls': true,
    'hasCallPermission': true,
    'hasReadPhoneStatePermission': true,
    'phoneType': 1,
    'networkType': 13,
    'simState': 5,
    'hasAllRequiredPermissions': true,
    'networkOperatorName': 'Mock Operator',
    'simOperatorName': 'Mock SIM',
  });

  @override
  Future<bool> hasUssdDirectPermissions() => Future.value(true);

  @override
  Future<bool> isAccessibilityServiceEnabled() => Future.value(false);

  @override
  Future<bool> openAccessibilitySettings() => Future.value(true);

  @override
  Future<Map<String, dynamic>> setupAccessibilityEventChannel() =>
      Future.value({
        'success': true,
        'serviceEnabled': true,
        'message': 'Mock accessibility service available',
        'error': null,
        'channelId': 'mock_channel_123',
      });

  // ==================== MULTI-SESSION METHODS ====================

  @override
  Future<Map<String, dynamic>> startMultiSessionUssd(
    String ussdCode, {
    int? subscriptionId,
  }) => Future.value({
    'success': true,
    'message':
        'Mock multi-session started for $ussdCode (SIM: ${subscriptionId ?? "auto"})',
    'error': null,
    'sessionId': 'session_123',
    'ussdResponse': 'Mock USSD response',
    'sessionActive': true,
  });

  @override
  Future<Map<String, dynamic>> sendMessageInSession(String message) =>
      Future.value({
        'success': true,
        'message': 'Mock message sent: $message',
        'error': null,
        'sessionId': 'session_123',
        'ussdResponse': 'Mock response to: $message',
        'sessionActive': true,
      });

  @override
  Future<Map<String, dynamic>> cancelMultiSession() => Future.value({
    'success': true,
    'message': 'Mock multi-session cancelled',
    'error': null,
    'sessionId': 'session_123',
    'ussdResponse': null,
    'sessionActive': false,
  });

  @override
  Future<bool> isMultiSessionActive() => Future.value(false);

  @override
  Future<bool> checkPhonePermissions() {
    return Future.value(true);
  }

  @override
  Future<bool> isPermissionPermanentlyDenied() {
    return Future.value(false);
  }

  @override
  Future<bool> openAppSettings() {
    return Future.value(true);
  }

  @override
  Future<bool> requestPhonePermissions() {
    return Future.value(true);
  }

  @override
  Future<bool> shouldShowPermissionRationale() {
    return Future.value(false);
  }
}

void main() {
  final UssdHandlerPlatform initialPlatform = UssdHandlerPlatform.instance;

  test('$MethodChannelUssdHandler is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelUssdHandler>());
  });

  test('getPlatformVersion', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    expect(await UssdHandler.getPlatformVersion(), '42');
  });

  test('executeUssd', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final response = await UssdHandler.executeUssd('*123#');
    expect(response.success, true);
    expect(response.response, 'Mock USSD response for *123# (SIM: auto)');
  });

  test('isUssdSupported', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    expect(await UssdHandler.isUssdSupported(), true);
  });

  test('executeUssdDirect', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final response = await UssdHandler.executeUssdDirect('*123#');
    expect(
      response,
      'Mock direct USSD response for *123# (SIM: auto, iOS fallback: false)',
    );
  });

  test('getSystemInfo', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final info = await UssdHandler.getSystemInfo();
    expect(info, isNotNull);
    expect(info!.platform, 'Android');
    expect(info.androidVersion, 33);
    expect(info.deviceModel, 'Mock Device');
    expect(info.supportsMultiSim, true);
    expect(info.ussdSupported, true);
    expect(info.hasCallPermission, true);
    expect(info.additionalInfo['hasAllRequiredPermissions'], true);
  });

  test('hasUssdDirectPermissions', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final hasPermissions = await UssdHandler.hasUssdDirectPermissions();
    expect(hasPermissions, true);
  });

  // ==================== TESTS FOR ACCESSIBILITY FEATURES ====================

  test('isAccessibilityServiceEnabled', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final isEnabled = await UssdHandler.isAccessibilityServiceEnabled();
    expect(isEnabled, false);
  });

  test('openAccessibilitySettings', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final opened = await UssdHandler.openAccessibilitySettings();
    expect(opened, true);
  });

  test('setupAccessibilityEventChannel', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final result = await UssdHandler.setupAccessibilityEventChannel();
    expect(result.success, true);
    expect(result.message, 'Mock accessibility service available');
    expect(result.serviceEnabled, true);
    expect(result.channelId, 'mock_channel_123');
  });

  // ==================== TESTS FOR MULTI-USSD SESSIONS ====================

  test('startMultiSessionUssd', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final result = await UssdHandler.startMultiSessionUssd('*123#');
    expect(result.success, true);
    expect(result.message, 'Mock multi-session started for *123# (SIM: auto)');
    expect(result.sessionId, 'session_123');
    expect(result.sessionActive, true);
  });

  test('sendMessageInSession', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final result = await UssdHandler.sendMessageInSession('1');
    expect(result.success, true);
    expect(result.message, 'Mock message sent: 1');
    expect(result.ussdResponse, 'Mock response to: 1');
    expect(result.sessionActive, true);
  });

  test('cancelMultiSession', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final result = await UssdHandler.cancelMultiSession();
    expect(result.success, true);
    expect(result.message, 'Mock multi-session cancelled');
    expect(result.sessionActive, false);
  });

  test('isMultiSessionActive', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final isActive = await UssdHandler.isMultiSessionActive();
    expect(isActive, false);
  });

  // ==================== COMPLETE MULTI-SESSION FLOW TEST ====================

  test('complete multi-session flow', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    // 1. Verify that there is no active session initially
    expect(await UssdHandler.isMultiSessionActive(), false);

    // 2. Start multi-USSD session
    final startResult = await UssdHandler.startMultiSessionUssd('*123#');
    expect(startResult.success, true);
    expect(startResult.sessionActive, true);

    // 3. Send message in session
    final messageResult = await UssdHandler.sendMessageInSession('1');
    expect(messageResult.success, true);
    expect(messageResult.sessionActive, true);

    // 4. Cancel session
    final cancelResult = await UssdHandler.cancelMultiSession();
    expect(cancelResult.success, true);
    expect(cancelResult.sessionActive, false);
  });

  // ==================== TESTS FOR MULTI-SIM ====================

  test('executeUssd with subscriptionId', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final response = await UssdHandler.executeUssd('*123#', subscriptionId: 2);
    expect(response.success, true);
    expect(response.response, 'Mock USSD response for *123# (SIM: 2)');
  });

  test('executeUssdDirect with subscriptionId', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final response = await UssdHandler.executeUssdDirect(
      '*123#',
      subscriptionId: 1,
    );
    expect(
      response,
      'Mock direct USSD response for *123# (SIM: 1, iOS fallback: false)',
    );
  });

  test('startMultiSessionUssd with subscriptionId', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final result = await UssdHandler.startMultiSessionUssd(
      '*123#',
      subscriptionId: 2,
    );
    expect(result.success, true);
    expect(result.message, 'Mock multi-session started for *123# (SIM: 2)');
    expect(result.sessionActive, true);
  });

  test('executeUssdDirect with iOS fallback', () async {
    MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
    UssdHandlerPlatform.instance = fakePlatform;

    final response = await UssdHandler.executeUssdDirect(
      '*123#',
      iosFallbackToStandard: true,
    );
    expect(response, contains('iOS fallback: true'));
  });
}
