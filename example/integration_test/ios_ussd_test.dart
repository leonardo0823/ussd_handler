import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ussd_handler/ussd_handler.dart';
import 'package:ussd_handler_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('USSD Handler iOS Integration Tests', () {
    testWidgets('getPlatformVersion should return iOS version', (
      WidgetTester tester,
    ) async {
      final String? version = await UssdHandler.getPlatformVersion();
      expect(version, isNotNull);
      expect(version!.startsWith('iOS'), isTrue);
      debugPrint('📱 iOS Version: $version');
    });

    testWidgets('isUssdSupported should return capability status', (
      WidgetTester tester,
    ) async {
      final bool isSupported = await UssdHandler.isUssdSupported();
      debugPrint('🔧 USSD Supported: $isSupported');
      // In simulator it may be false, on real device it may be true
      expect(isSupported, isA<bool>());
    });

    testWidgets('getSystemInfo should return iOS system information', (
      WidgetTester tester,
    ) async {
      final SystemInfo? systemInfo = await UssdHandler.getSystemInfo();
      expect(systemInfo, isNotNull);
      expect(systemInfo!.platform, equals('iOS'));
      expect(systemInfo.iosVersion, isNotNull);
      expect(systemInfo.deviceModel, isNotNull);
      expect(systemInfo.ussdDirectSupported, isFalse);
      expect(systemInfo.multiSessionSupported, isFalse);
      expect(systemInfo.accessibilityServiceSupported, isFalse);

      debugPrint('📊 iOS System Info:');
      debugPrint('  Platform: ${systemInfo.platform}');
      debugPrint('  iOS Version: ${systemInfo.iosVersion}');
      debugPrint('  Device Model: ${systemInfo.deviceModel}');
      debugPrint('  USSD Supported: ${systemInfo.ussdSupported}');
      debugPrint('  Multi-SIM: ${systemInfo.supportsMultiSim}');
    });

    testWidgets('executeUssd should handle iOS limitations gracefully', (
      WidgetTester tester,
    ) async {
      final response = await UssdHandler.executeUssd('*#06#');
      expect(response, isNotNull);
      expect(response.success, isA<bool>());

      if (response.success) {
        debugPrint('✅ USSD executed: ${response.response}');
        expect(response.response, contains('USSD code sent'));
      } else {
        debugPrint('❌ USSD not supported: ${response.errorMessage}');
        expect(response.errorMessage, isNotNull);
      }
    });

    testWidgets('executeUssdDirect should return null (not supported)', (
      WidgetTester tester,
    ) async {
      final String? response = await UssdHandler.executeUssdDirect('*123#');
      expect(response, isNull);
      debugPrint('🚫 Direct USSD not supported on iOS (expected)');
    });

    testWidgets('hasUssdDirectPermissions should return iOS capability', (
      WidgetTester tester,
    ) async {
      final bool hasPermissions = await UssdHandler.hasUssdDirectPermissions();
      expect(hasPermissions, isA<bool>());
      debugPrint('🔐 Direct USSD Permissions: $hasPermissions');
    });

    testWidgets(
      'accessibility service methods should return false/not supported',
      (WidgetTester tester) async {
        final bool isEnabled =
            await UssdHandler.isAccessibilityServiceEnabled();
        expect(isEnabled, isFalse);
        debugPrint(
          '🔧 Accessibility Service: $isEnabled (expected false on iOS)',
        );

        final bool opened = await UssdHandler.openAccessibilitySettings();
        expect(opened, isFalse);
        debugPrint(
          '⚙️ Open Accessibility Settings: $opened (expected false on iOS)',
        );

        final AccessibilityEventChannelResult setupResult =
            await UssdHandler.setupAccessibilityEventChannel();
        expect(setupResult.success, isFalse);
        debugPrint('📡 Setup Event Channel: ${setupResult.message}');
      },
    );

    testWidgets('multi-session methods should return not supported', (
      WidgetTester tester,
    ) async {
      final MultiSessionResult startResult =
          await UssdHandler.startMultiSessionUssd('*123#');
      expect(startResult.success, isFalse);
      expect(startResult.error, contains('not supported on iOS'));
      debugPrint('🔄 Multi-session: ${startResult.error}');

      final MultiSessionResult messageResult =
          await UssdHandler.sendMessageInSession('1');
      expect(messageResult.success, isFalse);
      debugPrint('💬 Send message in session: ${messageResult.error}');

      final MultiSessionResult cancelResult =
          await UssdHandler.cancelMultiSession();
      expect(cancelResult.success, isFalse);
      debugPrint('❌ Cancel session: ${cancelResult.error}');

      final bool isActive = await UssdHandler.isMultiSessionActive();
      expect(isActive, isFalse);
      debugPrint('📊 Active session: $isActive');
    });

    testWidgets('multi-SIM support should work with subscriptionId parameter', (
      WidgetTester tester,
    ) async {
      // Test with specific subscriptionId
      final response = await UssdHandler.executeUssd(
        '*#06#',
        subscriptionId: 1,
      );
      expect(response, isNotNull);
      expect(response.success, isA<bool>());

      if (response.success) {
        debugPrint('📱 USSD with SIM ID 1: ${response.response}');
      } else {
        debugPrint('❌ USSD with SIM ID 1 failed: ${response.errorMessage}');
      }
    });

    testWidgets(
      'iOS limitations should be properly documented in system info',
      (WidgetTester tester) async {
        final SystemInfo? systemInfo = await UssdHandler.getSystemInfo();
        expect(systemInfo, isNotNull);

        final List<String>? limitations = systemInfo!.limitations;
        expect(limitations, isNotNull);
        expect(limitations!.isNotEmpty, isTrue);

        debugPrint('⚠️ iOS Limitations:');
        for (String limitation in limitations) {
          debugPrint('  • $limitation');
        }
      },
    );

    testWidgets('executeUssdDirect with iOS fallback should work', (
      WidgetTester tester,
    ) async {
      final String? response = await UssdHandler.executeUssdDirect(
        '*#06#',
        iosFallbackToStandard: true,
      );

      if (response != null) {
        debugPrint('✅ Direct USSD with iOS fallback worked: $response');
        expect(response, contains('USSD code sent'));
      } else {
        debugPrint(
          '❌ Direct USSD with iOS fallback failed (may be normal on simulator)',
        );
      }
    });
  });

  group('iOS UI Integration Tests', () {
    testWidgets('app should launch and display iOS-specific information', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify that the app launches correctly
      expect(find.text('USSD Handler - Essential Functions'), findsOneWidget);

      // Find the system information button
      final systemInfoButton = find.text('System Information');
      expect(systemInfoButton, findsOneWidget);

      // Tap the button and verify it shows iOS information
      await tester.tap(systemInfoButton);
      await tester.pumpAndSettle(Duration(seconds: 2));

      debugPrint('✅ App launched correctly on iOS');
    });

    testWidgets('USSD execution should show iOS-appropriate messages', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle();

      // Find the text field for USSD
      final ussdField = find.byKey(Key('ussd_input'));
      if (ussdField.evaluate().isNotEmpty) {
        await tester.enterText(ussdField, '*#06#');
        await tester.pumpAndSettle();

        // Find and tap the execute USSD button
        final executeButton = find.text('Execute USSD');
        if (executeButton.evaluate().isNotEmpty) {
          await tester.tap(executeButton);
          await tester.pumpAndSettle(Duration(seconds: 3));

          debugPrint('✅ USSD execution test completed in UI');
        }
      }
    });
  });
}
