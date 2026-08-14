import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_handler/ussd_handler_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelUssdHandler platform = MethodChannelUssdHandler();
  const MethodChannel channel = MethodChannel('ussd_handler');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getPlatformVersion':
              return '42';
            case 'executeUssd':
              return {
                'success': true,
                'response':
                    'Mock USSD response for ${methodCall.arguments['ussdCode']}',
              };
            case 'isUssdSupported':
              return true;
            case 'executeUssdDirect':
              return 'Mock direct USSD response for ${methodCall.arguments['ussdCode']}';
            case 'getSystemInfo':
              return {
                'androidVersion': 33,
                'androidVersionSupported': true,
                'hasAllRequiredPermissions': true,
              };
            case 'hasUssdDirectPermissions':
              return true;
            case 'startUssdSession':
              return {
                'success': true,
                'message':
                    'Mock session started for ${methodCall.arguments['ussdCode']}',
                'isSessionActive': true,
                'state': 'waiting',
                'sessionId': 'mock-session-123',
              };
            case 'respondUssdSession':
              return {
                'success': true,
                'message':
                    'Mock response to: ${methodCall.arguments['response']}',
                'isSessionActive': false,
                'state': 'completed',
                'sessionId': 'mock-session-123',
              };
            case 'cancelUssdSession':
              return true;
            case 'hasActiveUssdSession':
              return false;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('executeUssd', () async {
    final response = await platform.executeUssd('*123#');
    expect(response.success, true);
    expect(response.response, 'Mock USSD response for *123#');
  });

  test('isUssdSupported', () async {
    expect(await platform.isUssdSupported(), true);
  });

  test('executeUssdDirect', () async {
    final response = await platform.executeUssdDirect('*123#', 30);
    expect(response, 'Mock direct USSD response for *123#');
  });

  test('getSystemInfo', () async {
    final info = await platform.getSystemInfo();
    expect(info, isNotNull);
    expect(info!['androidVersion'], 33);
    expect(info['hasAllRequiredPermissions'], true);
  });

  test('hasUssdDirectPermissions', () async {
    final hasPermissions = await platform.hasUssdDirectPermissions();
    expect(hasPermissions, true);
  });
}
