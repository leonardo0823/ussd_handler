import 'package:flutter/material.dart';

import 'dart:async';

import 'package:ussd_handler/ussd_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await requestPermissionsFlow();

  runApp(const MyApp());
}

Future<void> requestPermissionsFlow() async {
  bool granted = await UssdHandler.checkPhonePermissions();

  if (!granted) {
    // 1. Try to request the permit in the usual way.
    granted = await UssdHandler.requestPhonePermissions();

    if (!granted) {
      // 2. If it was not granted, check if it has been permanently denied ("Do not ask again").
      bool isPermanent = await UssdHandler.isPermissionPermanentlyDenied();

      if (isPermanent) {
        // Display a custom dialog notifying the user that they need to go to settings.
        print("The user selected 'Do not ask again'. Redirecting...");
        await UssdHandler.openAppSettings();
      } else {
        print("The user denied the permission temporarily.");
      }
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String _ussdResult = '';
  String _ussdDirectResult = '';

  String _systemInfo = '';
  bool _isUssdSupported = false;

  // Variables for multi-SIM
  int? _selectedSubscriptionId;
  List<Map<String, dynamic>> _simInfoList = [];
  int _simCount = 1;
  bool _supportsMultiSim = false;
  final _ussdController = TextEditingController();
  final _ussdDirectController = TextEditingController();
  final _ussdSessionController = TextEditingController();
  final _multiSessionController = TextEditingController();
  final _multiSessionMessageController = TextEditingController();

  // Variables for multi-session sessions
  String _multiSessionResult = '';
  bool _isMultiSessionActive = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    bool ussdSupported = false;

    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion =
          await UssdHandler.getPlatformVersion() ?? 'Unknown platform version';
      ussdSupported = await UssdHandler.isUssdSupported();

      // Get system information including multi-SIM
      final systemInfo = await UssdHandler.getSystemInfo();
      if (systemInfo != null) {
        _simCount = systemInfo.simCount;
        _supportsMultiSim = systemInfo.supportsMultiSim;

        if (systemInfo.additionalInfo['simInfoList'] != null) {
          _simInfoList = List<Map<String, dynamic>>.from(
            systemInfo.additionalInfo['simInfoList'],
          );
        }
      }
    } catch (e) {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
      _isUssdSupported = ussdSupported;
    });
  }

  Future<void> _executeUssd() async {
    if (_ussdController.text.isEmpty) {
      setState(() {
        _ussdResult = 'Please enter a USSD code';
      });
      return;
    }

    try {
      final response = await UssdHandler.executeUssd(
        _ussdController.text,
        subscriptionId: _selectedSubscriptionId,
      );

      setState(() {
        if (response.success) {
          _ussdResult = 'Success: ${response.response ?? 'USSD code executed'}';
        } else {
          _ussdResult = 'Error: ${response.errorMessage ?? 'Unknown error'}';
        }
      });
    } catch (e) {
      setState(() {
        _ussdResult = 'Error: $e';
      });
    }
  }

  Future<void> _executeUssdDirect() async {
    if (_ussdDirectController.text.isEmpty) {
      setState(() {
        _ussdDirectResult = 'Please enter a USSD code';
      });
      return;
    }

    setState(() {
      _ussdDirectResult = 'Checking permissions and executing direct USSD...';
    });

    // Check permissions before executing
    final hasPermissions = await UssdHandler.hasUssdDirectPermissions();
    if (!hasPermissions) {
      setState(() {
        _ussdDirectResult =
            'Requesting necessary permissions...\n\n'
            'The system will ask you to grant permissions:\n'
            '• CALL_PHONE (required)\n'
            '• READ_PHONE_STATE (required)\n\n'
            'Accept both permissions to use direct USSD.';
      });
    }

    try {
      final response = await UssdHandler.executeUssdDirect(
        _ussdDirectController.text,
        timeoutSeconds: 30,
        subscriptionId: _selectedSubscriptionId,
        iosFallbackToStandard: true, // Enable fallback for iOS
      );

      setState(() {
        if (response != null) {
          _ussdDirectResult = 'Direct response: $response';
        } else {
          _ussdDirectResult =
              'No response received or an error occurred.\n\n'
              'Possible causes:\n'
              '• The USSD code is not valid\n'
              '• The carrier does not support this code\n'
              '• Network issues\n'
              '• Insufficient permissions\n\n'
              'Use "Get Detailed Information" for more details.';
        }
      });
    } catch (e) {
      setState(() {
        String errorMsg = e.toString();

        if (errorMsg.contains('PERMISSION_DENIED')) {
          _ussdDirectResult =
              'Permission Error:\n$e\n\n'
              'To use direct USSD you need to grant these permissions:\n'
              '• CALL_PHONE (required)\n'
              '• READ_PHONE_STATE (required)\n\n'
              'Go to Settings > Apps > Permissions to grant them manually.';
        } else if (errorMsg.contains('USSD_FAILED')) {
          _ussdDirectResult =
              'USSD Error:\n$e\n\n'
              'This may indicate that:\n'
              '• The USSD code is not valid for your carrier\n'
              '• The USSD service is not available\n'
              '• There are network connectivity issues';
        } else if (errorMsg.contains('UNSUPPORTED_VERSION')) {
          _ussdDirectResult =
              'Version Error:\n$e\n\n'
              'Direct USSD requires Android 8.0 (API 26) or higher.';
        } else if (errorMsg.contains('SIM_NOT_READY')) {
          _ussdDirectResult =
              'SIM Error:\n$e\n\n'
              'Check that your SIM is inserted and working correctly.';
        } else {
          _ussdDirectResult = 'Unknown error:\n$e';
        }
      });
    }
  }

  Future<void> _getSystemInfo() async {
    setState(() {
      _systemInfo = 'Getting system information...';
    });

    try {
      final systemInfo = await UssdHandler.getSystemInfo();
      setState(() {
        if (systemInfo != null) {
          _systemInfo = _formatSystemInfo(systemInfo);
        } else {
          _systemInfo = 'Could not get system information';
        }
      });
    } catch (e) {
      setState(() {
        _systemInfo = 'Error getting system information: $e';
      });
    }
  }

  String _formatSystemInfo(SystemInfo systemInfo) {
    final buffer = StringBuffer();

    buffer.writeln('📱 SYSTEM INFORMATION');
    buffer.writeln('═══════════════════════════════');
    buffer.writeln('');

    // Basic system information
    buffer.writeln('🔧 Operating System:');
    buffer.writeln('  • Platform: ${systemInfo.platform}');
    if (systemInfo.platform.toLowerCase() == 'android' &&
        systemInfo.androidVersion != null) {
      buffer.writeln('  • Android Version: API ${systemInfo.androidVersion}');
    } else if (systemInfo.platform.toLowerCase() == 'ios' &&
        systemInfo.iosVersion != null) {
      buffer.writeln('  • iOS Version: ${systemInfo.iosVersion}');
    }
    buffer.writeln('  • Device: ${systemInfo.deviceModel}');
    buffer.writeln('  • Name: ${systemInfo.deviceName}');
    buffer.writeln('');

    // USSD Support
    buffer.writeln('📞 USSD Support:');
    buffer.writeln(
      '  • Basic USSD: ${systemInfo.ussdSupported ? "✅ Supported" : "❌ Not supported"}',
    );
    buffer.writeln(
      '  • Direct USSD: ${systemInfo.ussdDirectSupported ? "✅ Supported" : "❌ Not supported"}',
    );
    buffer.writeln(
      '  • Multi-session: ${systemInfo.multiSessionSupported ? "✅ Supported" : "❌ Not supported"}',
    );
    buffer.writeln(
      '  • Accessibility Service: ${systemInfo.accessibilityServiceSupported ? "✅ Supported" : "❌ Not supported"}',
    );
    buffer.writeln('');

    // SIM Information
    buffer.writeln('📱 SIM Information:');
    buffer.writeln('  • Number of SIMs: ${systemInfo.simCount}');
    buffer.writeln(
      '  • Multi-SIM: ${systemInfo.supportsMultiSim ? "✅ Supported" : "❌ Not supported"}',
    );

    // Detailed SIM information if available
    final simInfoList = systemInfo.additionalInfo['simInfoList'];
    if (simInfoList != null && simInfoList is List && simInfoList.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('  📋 SIM Details:');
      for (var simInfo in simInfoList) {
        if (simInfo is Map<String, dynamic>) {
          final slotIndex = simInfo['slotIndex'] ?? 'N/A';
          final displayName = simInfo['displayName'] ?? 'No name';
          final carrierName = simInfo['carrierName'] ?? 'Unknown carrier';
          final countryIso = simInfo['countryIso'] ?? 'N/A';
          final isEmbedded = simInfo['isEmbedded'] ?? false;

          buffer.writeln('    🔸 SIM $slotIndex:');
          buffer.writeln('      • Name: $displayName');
          buffer.writeln('      • Carrier: $carrierName');
          buffer.writeln('      • Country: ${countryIso.toUpperCase()}');
          buffer.writeln(
            '      • Type: ${isEmbedded ? "eSIM" : "Physical SIM"}',
          );
        }
      }
    }

    buffer.writeln('');

    // Permissions
    buffer.writeln('🔐 Permission Status:');
    buffer.writeln(
      '  • Make calls: ${systemInfo.canMakePhoneCalls ? "✅ Can make calls" : "❌ Cannot make calls"}',
    );

    if (systemInfo.hasCallPermission != null) {
      buffer.writeln(
        '  • Call permission: ${systemInfo.hasCallPermission! ? "✅ Granted" : "❌ Denied"}',
      );
    }

    if (systemInfo.hasReadPhoneStatePermission != null) {
      buffer.writeln(
        '  • Phone state permission: ${systemInfo.hasReadPhoneStatePermission! ? "✅ Granted" : "❌ Denied"}',
      );
    }

    final hasAccessibilityPermission =
        systemInfo.additionalInfo['hasAccessibilityPermission'] ?? false;
    buffer.writeln(
      '  • Accessibility service: ${hasAccessibilityPermission ? "✅ Enabled" : "❌ Disabled"}',
    );

    // Limitations
    if (systemInfo.limitations != null && systemInfo.limitations!.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('⚠️ Limitations:');
      for (final limitation in systemInfo.limitations!) {
        buffer.writeln('  • $limitation');
      }
    }

    // Additional information
    if (systemInfo.additionalInfo.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('ℹ️ Additional Information:');

      systemInfo.additionalInfo.forEach((key, value) {
        // Skip already shown information
        if (!['simInfoList', 'hasAccessibilityPermission'].contains(key)) {
          buffer.writeln('  • $key: $value');
        }
      });
    }

    buffer.writeln('');
    buffer.writeln('═══════════════════════════════');
    buffer.writeln('⏰ Updated: ${DateTime.now().toString().split('.')[0]}');

    return buffer.toString();
  }

  // ==================== COMPLETE MULTI-SESSION FLOW METHOD ====================

  /// Executes a complete multi-session flow similar to ussd_advanced
  /// This method mimics the behavior of:
  /// 1. UssdAdvanced.multisessionUssd()
  /// 2. UssdAdvanced.sendMessage() (if there's a message)
  /// 3. UssdAdvanced.cancelSession()
  Future<void> _executeMultiSessionFlow() async {
    if (_multiSessionController.text.isEmpty) {
      setState(() {
        _multiSessionResult = 'Please enter a USSD code';
      });
      return;
    }

    setState(() {
      _multiSessionResult = 'Starting complete multi-session flow...\n';
      _isMultiSessionActive = true;
    });

    try {
      // Check accessibility service
      final isServiceEnabled =
          await UssdHandler.isAccessibilityServiceEnabled();
      if (!isServiceEnabled) {
        setState(() {
          _isMultiSessionActive = false;
          _multiSessionResult =
              'ERROR: Accessibility service is not enabled.\n\n'
              'To use multi-session you need:\n'
              '1. Enable the USSD accessibility service\n'
              '2. Grant phone permissions\n\n'
              'Press "Configure Accessibility" to open settings.';
        });
        return;
      }

      // STEP 1: Start multi-USSD session (equivalent to UssdAdvanced.multisessionUssd)
      setState(() {
        _multiSessionResult += '📱 Step 1: Starting multi-USSD session...\n';
      });

      final startResult = await UssdHandler.startMultiSessionUssd(
        _multiSessionController.text,
        subscriptionId: _selectedSubscriptionId,
      );

      if (startResult.success != true) {
        setState(() {
          _isMultiSessionActive = false;
          _multiSessionResult +=
              '❌ Error starting session: ${startResult.error ?? startResult.message}\n';
        });
        return;
      }

      setState(() {
        _multiSessionResult += '✅ Session started successfully\n';
        _multiSessionResult +=
            '📄 Initial response: ${startResult.message}\n\n';
      });

      // Wait a moment for the session to be established
      await Future.delayed(const Duration(seconds: 2));

      // STEP 2: Send message if specified (equivalent to UssdAdvanced.sendMessage)
      if (_multiSessionMessageController.text.isNotEmpty) {
        setState(() {
          _multiSessionResult +=
              '📤 Step 2: Sending message "${_multiSessionMessageController.text}"...\n';
        });

        // Try to send the message with automatic retries
        bool messageSent = false;
        int maxRetries = 5;
        int retryDelay = 2; // seconds

        for (
          int attempt = 1;
          attempt <= maxRetries && !messageSent;
          attempt++
        ) {
          setState(() {
            _multiSessionResult += '   🔄 Attempt $attempt of $maxRetries...\n';
          });

          final sendResult = await UssdHandler.sendMessageInSession(
            _multiSessionMessageController.text,
          );

          if (sendResult.success == true) {
            messageSent = true;
            setState(() {
              _multiSessionResult +=
                  '✅ Message sent successfully on attempt $attempt\n';
              _multiSessionResult += '📄 Response: ${sendResult.message}\n\n';
            });
          } else {
            final errorMsg = sendResult.error ?? sendResult.message;

            if (attempt < maxRetries) {
              setState(() {
                _multiSessionResult +=
                    '   ⏳ Error on attempt $attempt: $errorMsg\n';
                _multiSessionResult +=
                    '   ⏳ Waiting ${retryDelay}s before next attempt...\n';
              });
              await Future.delayed(Duration(seconds: retryDelay));
            } else {
              setState(() {
                _multiSessionResult +=
                    '❌ Final error after $maxRetries attempts: $errorMsg\n\n';
              });
            }
          }
        }

        // Wait a moment before canceling
        await Future.delayed(const Duration(seconds: 2));
      } else {
        setState(() {
          _multiSessionResult += '⏭️ Step 2: Skipped (no message to send)\n\n';
        });

        // If no message, wait a bit longer to see the initial response
        await Future.delayed(const Duration(seconds: 3));
      }

      // STEP 3: Cancel session (equivalent to UssdAdvanced.cancelSession)
      setState(() {
        _multiSessionResult += '🔚 Step 3: Canceling session...\n';
      });

      final cancelResult = await UssdHandler.cancelMultiSession();

      setState(() {
        _isMultiSessionActive = false;
        if (cancelResult.success == true) {
          _multiSessionResult += '✅ Session canceled successfully\n';
          _multiSessionResult += '📄 ${cancelResult.message}\n\n';
          _multiSessionResult +=
              '🎉 MULTI-SESSION FLOW COMPLETED SUCCESSFULLY!';
        } else {
          _multiSessionResult +=
              '⚠️ Error canceling session: ${cancelResult.error ?? cancelResult.message}\n\n';
          _multiSessionResult += '⚠️ Flow completed with warnings.';
        }
      });
    } catch (e) {
      setState(() {
        _isMultiSessionActive = false;
        _multiSessionResult += '\n❌ Error during flow: $e\n\n';
        _multiSessionResult += '💡 Make sure that:\n';
        _multiSessionResult += '• The accessibility service is enabled\n';
        _multiSessionResult += '• You have phone permissions\n';
        _multiSessionResult += '• The USSD code is valid for your carrier';
      });
    }
  }

  // ==================== METHODS FOR MULTI-SESSION ====================

  Future<void> _startMultiSession() async {
    if (_multiSessionController.text.isEmpty) {
      setState(() {
        _multiSessionResult = 'Please enter a USSD code';
      });
      return;
    }

    setState(() {
      _multiSessionResult = 'Starting multi-session...';
    });

    try {
      // Check if accessibility service is enabled
      final isServiceEnabled =
          await UssdHandler.isAccessibilityServiceEnabled();
      if (!isServiceEnabled) {
        setState(() {
          _multiSessionResult =
              'ERROR: Accessibility service is not enabled.\n\n'
              'To use multi-session you need:\n'
              '1. Enable the USSD accessibility service\n'
              '2. Grant phone permissions\n\n'
              'Press "Configure Accessibility" to open settings.';
        });
        return;
      }

      final result = await UssdHandler.startMultiSessionUssd(
        _multiSessionController.text,
        subscriptionId: _selectedSubscriptionId,
      );

      setState(() {
        if (result.success == true) {
          _isMultiSessionActive = true;
          _multiSessionResult =
              'Multi-session started successfully!\n'
              'Code: ${_multiSessionController.text}\n'
              'Message: ${result.message}\n\n'
              'Now you can send messages in the active session.';
        } else {
          _multiSessionResult =
              'Error starting multi-session:\n${result.error ?? result.message}';
        }
      });

      // Check session status after a moment
      Future.delayed(const Duration(seconds: 2), () async {
        _checkMultiSessionStatus();
      });
    } catch (e) {
      setState(() {
        _multiSessionResult = 'Error: $e';
      });
    }
  }

  Future<void> _sendMessageInSession() async {
    if (_multiSessionMessageController.text.isEmpty) {
      setState(() {
        _multiSessionResult = 'Please enter a message to send';
      });
      return;
    }

    setState(() {
      _multiSessionResult = 'Sending message in session...';
    });

    try {
      final result = await UssdHandler.sendMessageInSession(
        _multiSessionMessageController.text,
      );

      setState(() {
        if (result.success == true) {
          _multiSessionResult =
              'Message sent successfully!\n'
              'Message: ${_multiSessionMessageController.text}\n'
              'Response: ${result.message}\n\n'
              'You can continue sending more messages or cancel the session.';
          _multiSessionMessageController.clear();
        } else {
          _multiSessionResult =
              'Error sending message:\n${result.error ?? result.message}';
        }
      });
    } catch (e) {
      setState(() {
        _multiSessionResult = 'Error: $e';
      });
    }
  }

  Future<void> _cancelMultiSession() async {
    setState(() {
      _multiSessionResult = 'Canceling multi-session...';
    });

    try {
      final result = await UssdHandler.cancelMultiSession();

      setState(() {
        _isMultiSessionActive = false;
        if (result.success == true) {
          _multiSessionResult =
              'Multi-session canceled successfully!\n'
              'Message: ${result.message}';
        } else {
          _multiSessionResult =
              'Error canceling session:\n${result.error ?? result.message}';
        }
      });
    } catch (e) {
      setState(() {
        _isMultiSessionActive = false;
        _multiSessionResult = 'Error: $e';
      });
    }
  }

  Future<void> _checkMultiSessionStatus() async {
    try {
      final isActive = await UssdHandler.isMultiSessionActive();
      setState(() {
        _isMultiSessionActive = isActive;
        if (!isActive && _multiSessionResult.contains('successfully started')) {
          _multiSessionResult +=
              '\n\nNOTE: The session was automatically closed.';
        }
      });
    } catch (e) {
      // Ignore errors when checking status
    }
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      final opened = await UssdHandler.openAccessibilitySettings();
      if (opened) {
        setState(() {
          _multiSessionResult =
              'Accessibility configuration opened.\n\n'
              'Steps to enable:\n'
              '1. Look for "USSD Handler" in the list\n'
              '2. Activate the service\n'
              '3. Accept permissions\n'
              '4. Return to the app and try again';
        });
      } else {
        setState(() {
          _multiSessionResult = 'Could not open accessibility configuration';
        });
      }
    } catch (e) {
      setState(() {
        _multiSessionResult = 'Error opening configuration: $e';
      });
    }
  }

  // ==================== BASIC METHODS ====================

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('USSD Handler - Essential Functions'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: SingleChildScrollView(
          padding: const .all(16.0),
          child: Column(
            children: [
              // ==================== SYSTEM INFORMATION ====================
              Card(
                child: Padding(
                  padding: const .all(16.0),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      const Text(
                        'System Information',
                        style: TextStyle(fontSize: 18, fontWeight: .bold),
                      ),
                      const SizedBox(height: 16),
                      Text('Platform Version: $_platformVersion'),
                      Text(
                        'USSD Support: ${_isUssdSupported ? "✅ Supported" : "❌ Not supported"}',
                      ),
                      if (_supportsMultiSim) ...[
                        Text('SIMs detected: $_simCount'),
                        Text('Multi-SIM: ✅ Supported'),
                      ] else ...[
                        Text('Multi-SIM: ❌ Not supported or 1 SIM'),
                      ],

                      // ==================== SIM SELECTOR ====================
                      if (_supportsMultiSim && _simInfoList.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Select SIM:',
                          style: TextStyle(fontWeight: .bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int?>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'SIM to use',
                          ),
                          initialValue: _selectedSubscriptionId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Automatic (native selector)'),
                            ),
                            ..._simInfoList.map((simInfo) {
                              final slotIndex = simInfo['slotIndex'] as int;
                              final displayName =
                                  simInfo['displayName'] as String;
                              final carrierName =
                                  simInfo['carrierName'] as String;
                              return DropdownMenuItem<int?>(
                                value: slotIndex,
                                child: Text(
                                  'SIM $slotIndex: $displayName ($carrierName)',
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedSubscriptionId = value;
                            });
                          },
                        ),
                      ] else if (_supportsMultiSim) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int?>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'SIM to use',
                          ),
                          initialValue: _selectedSubscriptionId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Automatic (native selector)'),
                            ),
                            for (int i = 1; i <= _simCount; i++)
                              DropdownMenuItem<int?>(
                                value: i,
                                child: Text('SIM $i'),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedSubscriptionId = value;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: .infinity,
                        child: ElevatedButton(
                          onPressed: _getSystemInfo,
                          child: const Text('Get Detailed Information'),
                        ),
                      ),
                      if (_systemInfo.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const .all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: .circular(8),
                            border: .all(color: Colors.grey[300]!),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _systemInfo,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================== BASIC USSD ====================
              Card(
                child: Padding(
                  padding: const .all(16.0),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      const Text(
                        'Basic USSD',
                        style: TextStyle(fontSize: 18, fontWeight: .bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const .all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: .circular(6),
                          border: .all(color: Colors.blue[200]!),
                        ),
                        child: const Text(
                          '📱 STANDARD METHOD: Uses the native Android USSD functionality. '
                          'Opens the system dialog and automatically handles the response.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ussdController,
                        decoration: const InputDecoration(
                          labelText: 'USSD Code',
                          hintText: 'Ex: *#06# (for IMEI)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: .infinity,
                        child: ElevatedButton(
                          onPressed: _executeUssd,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('📱 Execute USSD'),
                        ),
                      ),
                      if (_ussdResult.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const .all(12),
                          decoration: BoxDecoration(
                            color: _ussdResult.contains('Success')
                                ? Colors.green[50]
                                : Colors.red[50],
                            borderRadius: .circular(8),
                            border: .all(
                              color: _ussdResult.contains('Success')
                                  ? Colors.green[200]!
                                  : Colors.red[200]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              const Text(
                                'Basic USSD Result:',
                                style: TextStyle(fontWeight: .bold),
                              ),
                              const SizedBox(height: 8),
                              Text(_ussdResult),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================== DIRECT USSD ====================
              Card(
                child: Padding(
                  padding: const .all(16.0),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      const Text(
                        'Direct USSD (No Dialog)',
                        style: TextStyle(fontSize: 18, fontWeight: .bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const .all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: .circular(6),
                          border: .all(color: Colors.orange[200]!),
                        ),
                        child: const Text(
                          '🚀 DIRECT METHOD: Executes USSD codes without showing the native dialog. '
                          'Requires special permissions (CALL_PHONE). Compatible with Android 8.0+.',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ussdDirectController,
                        decoration: const InputDecoration(
                          labelText: 'Direct USSD Code',
                          hintText: 'Ex: *#06# (IMEI without dialog)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flash_on),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: .infinity,
                        child: ElevatedButton(
                          onPressed: _executeUssdDirect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('🚀 Direct USSD'),
                        ),
                      ),
                      if (_ussdDirectResult.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const .all(12),
                          decoration: BoxDecoration(
                            color: _ussdDirectResult.contains('Direct response')
                                ? Colors.green[50]
                                : Colors.red[50],
                            borderRadius: .circular(8),
                            border: .all(
                              color:
                                  _ussdDirectResult.contains('Direct response')
                                  ? Colors.green[200]!
                                  : Colors.red[200]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              const Text(
                                'Direct USSD Result:',
                                style: TextStyle(fontWeight: .bold),
                              ),
                              const SizedBox(height: 8),
                              Text(_ussdDirectResult),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================== MULTI-USSD SESSIONS ====================
              Card(
                child: Padding(
                  padding: const .all(16.0),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      const Text(
                        'Multi-USSD Sessions',
                        style: TextStyle(fontSize: 18, fontWeight: .bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const .all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: .circular(6),
                          border: .all(color: Colors.green[200]!),
                        ),
                        child: const Text(
                          '🌟 MULTI-USSD: Handles multiple USSD sessions simultaneously. '
                          'Ideal for services that require continuous interaction.',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _multiSessionController,
                        decoration: const InputDecoration(
                          labelText: 'Multi-Session USSD Code',
                          hintText: 'Ex: *123# (balance and more)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.group),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _multiSessionMessageController,
                        decoration: const InputDecoration(
                          labelText: 'Message to Send (optional)',
                          hintText: 'Ex: 1 (for option 1)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.message),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Main multi-session button (similar to ussd_advanced)
                      SizedBox(
                        width: .infinity,
                        child: ElevatedButton(
                          onPressed: _isMultiSessionActive
                              ? null
                              : () async {
                                  await _executeMultiSessionFlow();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const .symmetric(vertical: 16),
                          ),
                          child: Text(
                            _isMultiSessionActive
                                ? '🟢 Session in Progress...'
                                : '🚀 Execute Complete\nMulti-Session',
                            textAlign: .center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Individual buttons for manual control
                      const Text(
                        'Manual Control (Advanced):',
                        style: TextStyle(fontWeight: .bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isMultiSessionActive
                                  ? null
                                  : _startMultiSession,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('▶️ Start'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isMultiSessionActive
                                  ? _sendMessageInSession
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('📤 Send'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isMultiSessionActive
                                  ? _cancelMultiSession
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('❌ Cancel'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      SizedBox(
                        width: .infinity,
                        child: ElevatedButton(
                          onPressed: _openAccessibilitySettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('⚙️ Configure Accessibility'),
                        ),
                      ),

                      if (_multiSessionResult.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const .all(12),
                          decoration: BoxDecoration(
                            color:
                                _multiSessionResult.contains('successfully') ||
                                    _multiSessionResult.contains('Success')
                                ? Colors.green[50]
                                : _multiSessionResult.contains('ERROR') ||
                                      _multiSessionResult.contains('Error')
                                ? Colors.red[50]
                                : Colors.blue[50],
                            borderRadius: .circular(8),
                            border: .all(
                              color:
                                  _multiSessionResult.contains(
                                        'successfully',
                                      ) ||
                                      _multiSessionResult.contains('Success')
                                  ? Colors.green[200]!
                                  : _multiSessionResult.contains('ERROR') ||
                                        _multiSessionResult.contains('Error')
                                  ? Colors.red[200]!
                                  : Colors.blue[200]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              Text(
                                _isMultiSessionActive
                                    ? 'Multi-USSD Session Status:'
                                    : 'Multi-Session Result:',
                                style: const TextStyle(fontWeight: .bold),
                              ),
                              const SizedBox(height: 8),
                              Text(_multiSessionResult),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================== RECOMMENDED CODES ====================
              const Card(
                child: Padding(
                  padding: .all(16.0),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        'Recommended USSD Codes for Testing',
                        style: TextStyle(fontSize: 18, fontWeight: .bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '🔥 UNIVERSAL CODES (work on all devices):',
                        style: TextStyle(
                          fontWeight: .bold,
                          color: Colors.green,
                        ),
                      ),
                      Text('• *#06# - Device IMEI (ALWAYS works)'),
                      Text('• *#*#4636#*#* - Phone information'),
                      SizedBox(height: 8),
                      Text(
                        '📱 CODES BY CARRIER (may vary):',
                        style: TextStyle(
                          fontWeight: .bold,
                          color: Colors.orange,
                        ),
                      ),
                      Text('Mexico:'),
                      Text('  • Telcel: *133# (balance), *264# (recharge)'),
                      Text('  • Movistar: *123# (balance), *611# (service)'),
                      Text('  • AT&T: *123# (balance)'),
                      SizedBox(height: 4),
                      Text('Colombia:'),
                      Text('  • Claro: *444# (balance), *611# (service)'),
                      Text('  • Movistar: *321# (balance)'),
                      Text('  • Tigo: *611# (information)'),
                      SizedBox(height: 4),
                      Text('Spain:'),
                      Text('  • Movistar: *133# (balance), *22123# (data)'),
                      Text('  • Vodafone: *111# (balance)'),
                      Text('  • Orange: *111# (balance)'),
                      SizedBox(height: 8),
                      Text(
                        '🚨 DO YOU GET ERROR CODE -1?',
                        style: TextStyle(fontWeight: .bold, color: Colors.red),
                      ),
                      Text(
                        'This error means that your carrier does NOT support the code you tried. '
                        'This is NORMAL and does NOT indicate a problem with the plugin.',
                        style: TextStyle(fontSize: 12, fontStyle: .italic),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '✅ QUICK SOLUTION:',
                        style: TextStyle(fontWeight: .bold, color: Colors.blue),
                      ),
                      Text('1. Try with *#06# (IMEI) - always works'),
                      Text('2. Look for specific codes from your carrier'),
                      Text('3. Contact your carrier for valid codes'),
                      SizedBox(height: 8),
                      Text(
                        '⚠️ IMPORTANT NOTE:',
                        style: TextStyle(fontWeight: .bold, color: Colors.red),
                      ),
                      Text(
                        'If a USSD code fails, it does NOT mean the plugin is broken. '
                        'It means your carrier does not support that specific code. '
                        'Each carrier has different codes and some services '
                        'require prior activation.',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '💡 TIPS:',
                        style: TextStyle(fontWeight: .bold, color: Colors.blue),
                      ),
                      Text('• Contact your carrier for valid codes'),
                      Text('• Dial the code manually first to verify'),
                      Text('• Codes may change over time'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ussdController.dispose();
    _ussdDirectController.dispose();
    _ussdSessionController.dispose();
    _multiSessionController.dispose();
    _multiSessionMessageController.dispose();
    super.dispose();
  }
}
