# USSD Handler

A complete Flutter plugin for handling USSD codes on Android and iOS with advanced features including multi-USSD sessions.

## Features

### ✅ Basic Features
- **Standard USSD code execution** - Native functionality on Android and iOS
- **Direct USSD** - Execute USSD codes in background (Android 8+)
- **Direct USSD with iOS fallback** - Unified cross-platform functionality
- **Support verification** - Detect if device supports USSD
- **System information** - Complete diagnostics of permissions and status
- **Cross-platform support** - Full Android, iOS with documented limitations

### 🌟 Advanced Features (Android)
- **Multi-USSD Sessions** - Keep USSD dialogs open for multiple interactions
- **Accessibility Service** - Automatic capture of USSD responses from system
- **Automatic permission management** - Smart request for necessary permissions
- **Multi-SIM Support** - Execute USSD on specific SIMs with `subscriptionId`

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  ussd_handler: ^1.0.0
```

### Android Configuration

#### Basic Permissions
Add these permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CALL_PHONE" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
```

#### Accessibility Service (For Multi-USSD Sessions)
Add the accessibility service in `android/app/src/main/AndroidManifest.xml` inside `<application>`:

```xml
<service
    android:name="com.example.ussd_handler.UssdAccessibilityService"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"
    android:exported="false">
    <intent-filter>
        <action android:name="android.accessibilityservice.AccessibilityService" />
    </intent-filter>
</service>
```

### iOS

For iOS, the plugin provides limited functionality due to system restrictions:

```xml
<!-- No specific permissions required for iOS -->
<!-- The plugin uses available public APIs -->
```

**Behavior on iOS:**
- USSD codes open the native phone application
- Responses cannot be captured automatically
- System information is available
- Basic support for Dual SIM devices
- Optional fallback for `executeUssdDirect` using `executeUssd`

## Basic Usage

### Static API

The plugin uses a completely static API:

```dart
import 'package:ussd_handler/ussd_handler.dart';

// ✅ Correct - Static methods
final response = await UssdHandler.executeUssd('*#06#');

// ❌ Incorrect - Don't instantiate the class
// final handler = UssdHandler(); // Error!
```

### Standard USSD

**Description**: Execute USSD codes using native system functionality. On Android shows standard USSD dialog, on iOS opens phone app.

```dart
// Execute basic USSD code
final response = await UssdHandler.executeUssd('*#06#');

if (response.success) {
  print('USSD Response: ${response.response}');
} else {
  print('Error: ${response.errorMessage}');
}
```

**With Multi-SIM**:
```dart
// Specify specific SIM (Android)
final response = await UssdHandler.executeUssd(
  '*#06#',
  subscriptionId: 1, // Use SIM in slot 1
);

// Automatic (will show native selector if multiple SIMs)
final response = await UssdHandler.executeUssd('*#06#');
```

**Behavior by platform**:
- **Android**: Shows native USSD dialog, captures response automatically
- **iOS**: Opens phone application, doesn't capture response (system limitation)

### Direct USSD (Android 8+)

**Description**: Execute USSD codes in background without showing system dialogs. Only works on Android 8+ with special permissions.

#### Basic Usage (Android Only)
```dart
// Execute USSD in background
final response = await UssdHandler.executeUssdDirect('*123#');

if (response != null) {
  print('Direct response: $response');
} else {
  print('No response received or not supported');
}
```

#### Cross-platform Usage with iOS Fallback
```dart
// Works on Android and iOS using fallback
final response = await UssdHandler.executeUssdDirect(
  '*#06#',
  iosFallbackToStandard: true, // ✨ New parameter
);

if (response != null) {
  print('Response: $response');
  // Android: Direct USSD response
  // iOS: Descriptive message of submission
}
```

#### Advanced Configuration
```dart
final response = await UssdHandler.executeUssdDirect(
  '*123#',
  timeoutSeconds: 45,           // Custom timeout
  subscriptionId: 2,            // Specific SIM (Android)
  iosFallbackToStandard: true,  // Fallback for iOS
);
```

**Behavior by platform**:

| Platform | iosFallbackToStandard: false | iosFallbackToStandard: true |
|----------|-----------------------------|-----------------------------|
| **Android** | Direct USSD (normal) | Direct USSD (ignores parameter) |
| **iOS** | Returns `null` | Uses `executeUssd` internally |

**Advantages of iOS fallback**:
- ✅ Unified code for both platforms
- ✅ No need for `if (Platform.isIOS)` conditionals
- ✅ Backward compatibility (default `false`)
- ✅ Optional functionality as needed

## Multi-USSD Sessions 🌟 (Android Only)

Multi-USSD sessions allow keeping USSD dialogs open to navigate complex menus automatically. **This functionality requires accessibility services on Android**.

### Prerequisites

**1. Verify Support**
```dart
final systemInfo = await UssdHandler.getSystemInfo();
final supportsMultiSession = systemInfo?.multiSessionSupported ?? false;

if (!supportsMultiSession) {
  print('Multi-session not supported on this device');
  return;
}
```

**2. Enable Accessibility Service**
```dart
// Check if enabled
final isEnabled = await UssdHandler.isAccessibilityServiceEnabled();

if (!isEnabled) {
  // Open settings automatically
  final opened = await UssdHandler.openAccessibilitySettings();
  if (opened) {
    print('Please enable "USSD Handler" service and return to the app');
  }
}
```

### 🚀 Automatic Flow (Recommended)

**Execute a complete multi-session flow in a single method**:

```dart
Future<void> executeBankingFlow() async {
  try {
    String result = '';
    
    // 1. Start session with bank code
    final startResult = await UssdHandler.startMultiSessionUssd('*123#');
    
    if (startResult.success) {
      result += 'Session started: ${startResult.message}\n';
      
      // 2. Wait for initial response and navigate
      await Future.delayed(Duration(seconds: 3));
      
      // 3. Select option "1" (example: check balance)
      final message1 = await UssdHandler.sendMessageInSession('1');
      if (message1.success) {
        result += 'Option 1 sent: ${message1.message}\n';
        
        await Future.delayed(Duration(seconds: 2));
        
        // 4. Confirm with another option if necessary
        final message2 = await UssdHandler.sendMessageInSession('1');
        if (message2.success) {
          result += 'Confirmation sent: ${message2.message}\n';
        }
      }
      
      // 5. Cancel session
      await Future.delayed(Duration(seconds: 2));
      final cancelResult = await UssdHandler.cancelMultiSession();
      result += 'Session finished: ${cancelResult.message}';
    }
    
    print('Flow completed:\n$result');
  } catch (e) {
    print('Flow error: $e');
  }
}
```

### ⚙️ Advanced Manual Control

**For cases requiring custom logic between steps**:

```dart
Future<void> customNavigation() async {
  try {
    // 1. Start multi-USSD session
    final startResult = await UssdHandler.startMultiSessionUssd('*123#');
    
    if (startResult.success) {
      print('Session started: ${startResult.message}');
      
      // 2. Check session status
      final isActive = await UssdHandler.isMultiSessionActive();
      print('Session active: $isActive');
      
      if (isActive) {
        // 3. Wait for initial response
        await Future.delayed(Duration(seconds: 3));
        
        // 4. Make decision based on response
        String option = '1'; // Custom logic here
        
        final msgResult = await UssdHandler.sendMessageInSession(option);
        
        if (msgResult.success) {
          print('Message sent: ${msgResult.message}');
          
          // 5. Continue navigation based on response
          await Future.delayed(Duration(seconds: 2));
          
          // More messages if necessary
          await UssdHandler.sendMessageInSession('2');
          
          // 6. Finish when done
          await UssdHandler.cancelMultiSession();
          print('Session finished');
        }
      }
    } else {
      print('Error starting session: ${startResult.error}');
    }
  } catch (e) {
    print('Error: $e');
    // Ensure session is cancelled in case of error
    await UssdHandler.cancelMultiSession();
  }
}
```

**Control Methods**:
- `startMultiSessionUssd(String ussdCode)` - Start session
- `sendMessageInSession(String message)` - Send messages
- `isMultiSessionActive()` - Check status
- `cancelMultiSession()` - End session

### Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:ussd_handler/ussd_handler.dart';

class USSDExample extends StatefulWidget {
  @override
  _USSDExampleState createState() => _USSDExampleState();
}

class _USSDExampleState extends State<USSDExample> {
  
  String result = '';

  Future<void> executeMultiSessionUSSD() async {
    try {
      // Check accessibility service
      final isServiceEnabled = await UssdHandler.isAccessibilityServiceEnabled();
      if (!isServiceEnabled) {
        await UssdHandler.openAccessibilitySettings();
        return;
      }

      // Start session
      final startResult = await UssdHandler.startMultiSessionUssd('*123#');
      
      if (startResult.success) {
        setState(() {
          result = 'Session started successfully';
        });

        // Wait and send message
        await Future.delayed(Duration(seconds: 2));
        
        final msgResult = await UssdHandler.sendMessageInSession('1');
        if (msgResult.success) {
          setState(() {
            result += '\\nMessage sent: ${msgResult.message}';
          });
        }

        // Cancel after some time
        await Future.delayed(Duration(seconds: 3));
        await UssdHandler.cancelMultiSession();
        
        setState(() {
          result += '\\nSession cancelled';
        });
      }
    } catch (e) {
      setState(() {
        result = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Multi-Session USSD')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: executeMultiSessionUSSD,
              child: Text('Execute Multi-Session USSD'),
            ),
            SizedBox(height: 20),
            Text(result),
          ],
        ),
      ),
    );
  }
}
```

## 📚 Complete API Reference

### Response Classes

#### `UssdResponse`
Result of standard USSD code execution.

```dart
class UssdResponse {
  final String? response;      // USSD response
  final bool success;          // If successful
  final String? errorMessage;  // Error message if failed
  
  // Conversion methods
  factory UssdResponse.fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap();
}
```

#### `SystemInfo`
Detailed system information for diagnostics.

```dart
class SystemInfo {
  final String platform;                    // 'android' | 'ios'
  final int? androidVersion;                // API level (Android only)
  final String? iosVersion;                 // iOS version (iOS only)
  final String deviceModel;                 // Device model
  final String deviceName;                  // Device name
  final int simCount;                       // Number of SIMs
  final bool supportsMultiSim;              // Multi-SIM support
  final bool ussdSupported;                 // Basic USSD support
  final bool ussdDirectSupported;           // Direct USSD support
  final bool multiSessionSupported;         // Multi-session support
  final bool accessibilityServiceSupported; // Accessibility service
  final bool canMakePhoneCalls;             // Can make calls
  final bool? hasCallPermission;            // Call permission (Android)
  final bool? hasReadPhoneStatePermission;  // State permission (Android)
  final List<String>? limitations;          // Limitations (iOS)
  final Map<String, dynamic> additionalInfo; // Additional info
  
  // Conversion and display methods
  factory SystemInfo.fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap();
  @override String toString(); // Readable representation
}
```

#### `AccessibilityEventChannelResult`
Result of accessibility event channel configuration.

```dart
class AccessibilityEventChannelResult {
  final bool success;          // If successful
  final String message;        // Result message
  final String? error;         // Error if failed
  final bool serviceEnabled;   // Service enabled
  final String? channelId;     // Channel ID
  
  // Conversion methods
  factory AccessibilityEventChannelResult.fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap();
}
```

#### `MultiSessionResult`
Result of multi-USSD session operations.

```dart
class MultiSessionResult {
  final bool success;          // If successful
  final String message;        // Result message
  final String? error;         // Error if failed
  final String? sessionId;     // Session ID
  final String? ussdResponse;  // USSD response
  final bool sessionActive;    // Session active
  
  // Conversion methods
  factory MultiSessionResult.fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap();
}
```

### Main Methods

#### `executeUssd(String ussdCode, {int? subscriptionId})`
Execute a USSD code using native system functionality.

**Parameters:**
- `ussdCode` (String, required): USSD code to execute (e.g.: "*123#")
- `subscriptionId` (int?, optional): SIM ID to use on multi-SIM devices

**Returns:** `Future<UssdResponse>`

**Example:**
```dart
final response = await UssdHandler.executeUssd('*#06#', subscriptionId: 1);
if (response.success) {
  print('IMEI: ${response.response}');
} else {
  print('Error: ${response.errorMessage}');
}
```

#### `executeUssdDirect(String ussdCode, {int timeoutSeconds = 30, int? subscriptionId, bool iosFallbackToStandard = false})`
Execute a direct USSD code without showing dialogs (Android) or with fallback on iOS.

**Parameters:**
- `ussdCode` (String, required): USSD code to execute
- `timeoutSeconds` (int, optional): Timeout in seconds (default: 30)
- `subscriptionId` (int?, optional): Specific SIM ID
- `iosFallbackToStandard` (bool, optional): Use executeUssd as fallback on iOS (default: false)

**Returns:** `Future<String?>` - Direct response or null

**Example:**
```dart
// Android only (original behavior)
final response = await UssdHandler.executeUssdDirect('*123#');

// Cross-platform with fallback
final response = await UssdHandler.executeUssdDirect(
  '*123#',
  iosFallbackToStandard: true,
);
```

#### `isUssdSupported()`
Check if device supports USSD codes.

**Returns:** `Future<bool>`

#### `getPlatformVersion()`
Get platform version.

**Returns:** `Future<String?>`

### System Information Methods

#### `getSystemInfo()`
Get detailed system information for diagnostics.

**Returns:** `Future<SystemInfo?>`

**Usage example:**
```dart
final systemInfo = await UssdHandler.getSystemInfo();
if (systemInfo != null) {
  print('Platform: ${systemInfo.platform}');
  print('Model: ${systemInfo.deviceModel}');
  print('USSD supported: ${systemInfo.ussdSupported}');
  print('Multi-session: ${systemInfo.multiSessionSupported}');
  
  // Use toString() for complete representation
  print(systemInfo.toString());
  
  // Access specific information
  if (systemInfo.platform == 'android') {
    print('Android API: ${systemInfo.androidVersion}');
    print('Call permissions: ${systemInfo.hasCallPermission}');
  }
  
  // Additional information
  systemInfo.additionalInfo.forEach((key, value) {
    print('$key: $value');
  });
}
```

#### `hasUssdDirectPermissions()`
Check if it has all necessary permissions for direct USSD.

**Returns:** `Future<bool>`

**Android only**: Checks CALL_PHONE and READ_PHONE_STATE permissions.

### Multi-Session Methods (Android Only)

#### `startMultiSessionUssd(String ussdCode, {int? subscriptionId})`
Start a multi-USSD session.

**Parameters:**
- `ussdCode` (String): USSD code to execute
- `subscriptionId` (int?, optional): Specific SIM for multi-SIM

**Returns:** `Future<MultiSessionResult>`

**Example:**
```dart
final result = await UssdHandler.startMultiSessionUssd('*123#');
if (result.success) {
  print('Session started: ${result.message}');
  print('Session ID: ${result.sessionId}');
  print('Initial response: ${result.ussdResponse}');
} else {
  print('Error: ${result.error}');
}
```

#### `sendMessageInSession(String message)`
Send a message in the active multi-USSD session.

**Parameters:**
- `message` (String): Message/option to send (e.g.: "1", "2", "*", "#")

**Returns:** `Future<MultiSessionResult>`

**Example:**
```dart
final result = await UssdHandler.sendMessageInSession('1');
if (result.success) {
  print('Message sent: ${result.message}');
  print('New response: ${result.ussdResponse}');
} else {
  print('Error: ${result.error}');
}
```

#### `isMultiSessionActive()`
Check if there's an active multi-USSD session.

**Returns:** `Future<bool>`

#### `cancelMultiSession()`
Cancel the active multi-USSD session.

**Returns:** `Future<MultiSessionResult>`

**Example:**
```dart
final result = await UssdHandler.cancelMultiSession();
if (result.success) {
  print('Session cancelled: ${result.message}');
} else {
  print('Error cancelling: ${result.error}');
}
```

**Complete flow example:**
```dart
// 1. Start
final start = await UssdHandler.startMultiSessionUssd('*123#');
if (start.success) {
  print('Started: ${start.ussdResponse}');
  
  // 2. Navigate
  final nav = await UssdHandler.sendMessageInSession('1');
  if (nav.success) {
    print('Navigated: ${nav.ussdResponse}');
  }
  
  // 3. Finish
  final end = await UssdHandler.cancelMultiSession();
  print('Finished: ${end.message}');
}
```

### Diagnostic Methods

#### `getSystemInfo()`
Gets detailed system information for diagnostics.

**Returns:** `SystemInfo?`

#### `hasUssdDirectPermissions()`
Checks if it has all necessary permissions.

**Returns:** `bool`

## ⚠️ Limitations and Considerations

### Android
- **Required permissions**: CALL_PHONE and READ_PHONE_STATE
- **Android 8+**: Direct USSD requires additional permissions
- **Accessibility services**: Require manual user enablement
- **Carrier-specific**: Some USSD codes may vary by carrier

### iOS
- **No automatic capture**: iOS doesn't allow intercepting USSD responses
- **Native app only**: USSD codes open the phone application
- **No direct USSD**: Not available due to system restrictions
- **No multi-session**: iOS doesn't support persistent USSD dialogs
- **Limited information**: SIM data restricted by the system

### General
- **Carrier dependent**: Not all USSD codes work with all carriers
- **Real device testing**: Recommended for complete validation
- **Regional variations**: USSD codes may vary by country/region

## 📋 Common USSD Codes

### Universal
- `*#06#` - Device IMEI
- `*#21#` - Call forwarding status
- `*#30#` - Caller ID status
- `*#31#` - Caller ID blocking status

### Device Information
- `*#*#4636#*#*` - Phone information (Android)
- `*#12580*369#` - Software/hardware information
- `*#0*#` - Service menu (Samsung)

### Network and Connectivity
- `*#*#7780#*#*` - Factory reset (Caution!)
- `*#*#34971539#*#*` - Detailed camera information
- `*#*#0588#*#*` - Proximity sensor test

⚠️ **Important**: Test USSD codes in a controlled environment. Some may affect device settings.

## 🤝 Contributing

Contributions are welcome! Please read:

**CONTRIBUTING.md** - Complete contribution guide

### Contribution Areas
- 📱 Testing on real iOS devices
- 🔧 Android API improvements
- 📚 Documentation and examples
- 🧪 Additional tests
- 🌍 Support for regional USSD codes

## 📄 License

This project is under the MIT License. See the `LICENSE` file for more details.

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/leonardo0823/ussd_handler/issues)
- **Documentation**: See `.md` files in the repository
- **Examples**: `example/` folder

---

**Developed with ❤️ for the Flutter community**
