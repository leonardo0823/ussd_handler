# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.2] - 2026-15-08

### ✨ Added
- **Native Permission Management**: Added full standalone methods to check and request `CALL_PHONE` and `READ_PHONE_STATE` permissions natively (`checkPhonePermissions` and `requestPhonePermissions`) without third-party dependencies.
- **Permanent Denial Detection**: Added `isPermissionPermanentlyDenied` to detect if the user selected the "Don't ask again" option during the native permission dialog.
- **Permission Rationale Support**: Added `shouldShowPermissionRationale` utilizing Android's native rationale API to know when to show educational UI to the user.
- **System Settings Redirect**: Added `openAppSettings` to easily forward users to the application details screen so they can grant blocked permissions manually.

### 🔧 Changed
- **Manifest Conflict Resolution**: Fixed a critical `Manifest merger failed` error by restructuring how permissions and metadata are handled across application boundaries.
- **Documentation**: Updated the API reference and code block examples inside `README.md` to reflect the new native permission helper methods.

### 🗑️ Removed
- **Manifest `tools:replace`**: Removed the incorrect `<meta-data tools:replace="android:resource" />` tag inside the package's internal `AndroidManifest.xml` which was breaking the main application's build process.

---

## [0.0.1] - 2026-14-08

### ✨ Added

#### Main Features
- **Standard USSD**: Basic USSD code execution with system response
- **Direct USSD**: Getting USSD responses without showing system dialogs (Android)
- **Multi-Session USSD**: Maintaining active USSD sessions for automated menu navigation
- **Multi-SIM Support**: Complete functionality for devices with multiple SIMs
  - Automatic single SIM selection
  - Native selector for multiple SIMs
  - Manual SIM specification (subscriptionId)

#### Accessibility Services
- **USSD Accessibility Service**: Automatic capture of USSD responses from the system
- **Automated Navigation**: Automatic navigation through complex USSD menus
- **Accessibility Configuration**: Automatic opening of system configurations

#### System Information
- **Device Diagnostics**: Detailed information about permissions, network, SIM, etc.
- **Permission Verification**: Checking and automatic request of necessary permissions
- **USSD Support Verification**: Detection of device USSD capabilities

#### Static API
- **Static Utility Class**: All methods are static, no instantiation required
- **Simplified API**: Direct use with `UssdHandler.method()` without creating objects

### 🛡️ Security
- **Permission Management**: Automatic request and verification of required permissions
- **Input Validation**: Validation of USSD codes and input parameters
- **Error Handling**: Robust error handling and edge cases

### 📱 Supported Platforms
- **Android**: Complete support with all features
- **iOS**: Basic support (operating system limitations)

### 🎯 Technical Features
- **Configurable Timeout**: Custom timeout configuration for direct USSD
- **Detailed Logging**: Logging system for diagnostics and debugging
- **Thread Safety**: Safe operations for concurrent use
- **Backward Compatibility**: Compatibility with previous Android versions

### 📖 Documentation
- **Complete README**: Comprehensive documentation with usage examples
- **Contribution Guide**: Detailed process for contributors
- **API Reference**: Complete API documentation

### 🧪 Testing
- **Unit Tests**: Complete coverage of main features
- **Accessibility Tests**: Specific tests for accessibility services
- **Integration Tests**: Verification on real devices
- **Complete Mocks**: Mock system for testing without hardware

### 📋 Compatibility
- **Flutter**: `>=3.44.0`
- **Dart**: `^3.13.0`
- **Android**: API 24+ (Android 7.0+)
- **iOS**: iOS 15.0+

### 🔧 Configuration
- **Android Permissions**:
  - `CALL_PHONE`: Required for USSD codes
  - `READ_PHONE_STATE`: Device information

### 📊 Release Metrics
- **Code Files**: 15+ main files
- **Tests**: 38+ automated tests
- **Documentation**: 3
- **Examples**: Complete example application

---

### 🎉 First Release

This is the first public release of the USSD Handler plugin. It includes all fundamental features for handling USSD codes in Flutter applications, with advanced support for multi-SIM, multi-USSD sessions, and accessibility services.

**Featured Characteristics**:
- 🚀 Simple and powerful static API
- 📱 Complete multi-SIM support
- 🔄 Automated USSD sessions
- 🛡️ Robust permission management
- 📖 Comprehensive documentation
- 🧪 Complete tests

**Next Steps**:
- Community feedback
- Improvements based on real usage
- Performance optimizations
- iOS functionality expansion

---

**Development Notes**:
- Initial development version (0.0.1)

#### iOS-Specific Features
- **iosFallbackToStandard Parameter**: Allows `executeUssdDirect` to use `executeUssd` as fallback on iOS
  - `iosFallbackToStandard: false` (default): Maintains Android compatibility, returns null on iOS
  - `iosFallbackToStandard: true`: Uses executeUssd internally on iOS, providing unified functionality
  - Only affects iOS, ignored on Android
  - Allows cross-platform code without platform conditionals
