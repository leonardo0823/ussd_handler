# Contributing Guide - USSD Handler

Thank you for your interest in contributing to the USSD Handler plugin! This guide will help you understand how to participate in the project development.

## 📋 Table of Contents

- [🤝 Code of Conduct](#-code-of-conduct)
- [🚀 How to Contribute?](#-how-to-contribute)
- [🛠️ Environment Setup](#️-environment-setup)
- [📁 Project Structure](#-project-structure)
- [📝 Code Standards](#-code-standards)
- [🧪 Testing](#-testing)
- [🔄 Pull Request Process](#-pull-request-process)
- [🐛 Reporting Issues](#-reporting-issues)
- [📖 Documentation](#-documentation)
- [🔧 Development Configurations](#-development-configurations)
- [🎯 Roadmap and Priorities](#-roadmap-and-priorities)
- [📞 Contact and Support](#-contact-and-support)

## 🤝 Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). By participating, you are expected to uphold this code. Please report unacceptable behavior to [email@example.com].

## 🚀 How to Contribute?

There are many ways to contribute to the project:

### 🐛 Report Bugs
- Use the issue template for bugs
- Include detailed problem information
- Provide steps to reproduce the bug
- Include logs and screenshots when relevant

### ✨ Suggest Features
- Use the issue template for feature requests
- Clearly explain the use case
- Describe the proposed solution
- Consider alternatives

### 📝 Documentation Improvements
- Fix typographical errors
- Improve existing explanations
- Add code examples
- Translate documentation

### 🔧 Code Development
- Implement new features
- Fix existing bugs
- Improve performance
- Refactor code

## 🛠️ Environment Setup

### Prerequisites

- **Flutter SDK**: `>=3.3.0`
- **Dart SDK**: `^3.7.0`
- **Android Studio** or **VS Code** with Flutter extensions
- **Android SDK** (for Android development)
- **Xcode** (for iOS development, macOS only)

### Initial Setup

1. **Fork the repository**
   ```bash
   git clone https://github.com/leonardo0823/ussd_handler.git
   cd ussd_handler
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   cd example
   flutter pub get
   ```

3. **Verify configuration**
   ```bash
   flutter doctor
   flutter analyze
   flutter test
   ```

4. **Configure IDE**
   - Install Flutter and Dart extensions
   - Configure automatic formatting
   - Enable code analysis

### Android Configuration

1. **Configure emulator or physical device**
2. **Verify permissions in AndroidManifest.xml**
3. **Test USSD functionalities on real device**

### iOS Configuration

1. **Configure simulator or physical device**
2. **Configure app signing**
3. **Note**: USSD functionality is limited on iOS

## 📁 Project Structure

```
ussd_handler/
├── android/                    # Android native code
│   ├── src/main/kotlin/       
│   │   └── com/example/ussd_handler/
│   ├── src/main/AndroidManifest.xml
│   ├── src/main/res/
│   ├── src/test/kotlin/
│   ├── build.gradle
│   ├── settings.gradle
│   └── ussd_handler_android.iml
├── ios/                       # iOS native code
│   ├── Assets/
│   ├── Classes/
│   │   └── UssdHandlerPlugin.swift
│   ├── Resources/
│   │   └── PrivacyInfo.xcprivacy
│   └── ussd_handler.podspec
├── lib/                       # Main Dart code
│   ├── ussd_handler.dart                    # Main API with typed classes
│   ├── ussd_handler_platform_interface.dart # Platform interface
│   └── ussd_handler_method_channel.dart     # Channel implementation
├── example/                   # Example application
│   ├── lib/
│   │   └── main.dart         # Usage examples with typed API
│   ├── integration_test/     # Integration tests
│   │   ├── ios_ussd_test.dart
│   │   └── plugin_integration_test.dart
│   ├── test/
│   │   └── widget_test.dart
│   ├── android/              # Example Android configuration
│   ├── ios/                  # Example iOS configuration
│   └── pubspec.yaml
├── test/                     # Unit tests
│   ├── ussd_handler_test.dart
│   ├── ussd_handler_method_channel_test.dart
│   └── ussd_handler_accessibility_test.dart
├── .dart_tool/              # Dart tools
├── analysis_options.yaml    # Analyzer configuration
├── CHANGELOG.md             # Change log
├── CONTRIBUTING.md          # This contribution guide
├── LICENSE                  # MIT License
├── README.md               # Main documentation
├── pubspec.yaml            # Package configuration
└── ussd_handler.iml        # IntelliJ/Android Studio configuration
```

### Main Components

#### 🎯 Dart (lib/)

- **`ussd_handler.dart`**: Main API with static methods and typed response classes:
  - `UssdResponse` - Standard USSD code result
  - `SystemInfo` - Detailed system information (with `toString()`)
  - `AccessibilityEventChannelResult` - Accessibility configuration result
  - `MultiSessionResult` - Multi-session operation result
- **`ussd_handler_platform_interface.dart`**: Abstract platform interface
- **`ussd_handler_method_channel.dart`**: Implementation using MethodChannel

#### 🤖 Android (android/)

- **`UssdHandlerPlugin.kt`**: Native implementation in Kotlin (located in `src/main/kotlin/`)
- Handles USSD codes, permissions, multi-SIM, and accessibility services
- **`AndroidManifest.xml`**: Permissions and services configuration
- **`build.gradle`**: Android build configuration

#### 🍎 iOS (ios/)

- **`UssdHandlerPlugin.swift`**: Native implementation in Swift
- Limited functionality due to iOS restrictions
- **`PrivacyInfo.xcprivacy`**: Privacy information required by Apple
- **`ussd_handler.podspec`**: CocoaPod specification

#### 🧪 Testing (test/ and example/integration_test/)

- **Unit tests**: Verify business logic and type conversions
- **Accessibility tests**: Validate multi-session services
- **Integration tests**: Test functionality on real devices
- **Example tests**: Validate the demo application

## 📝 Code Standards

### Dart Style Guide

```dart
// ✅ Correct - Typed API
class UssdHandler {
  static Future<UssdResponse> executeUssd(String ussdCode, {int? subscriptionId}) {
    return UssdHandlerPlatform.instance.executeUssd(
      ussdCode,
      subscriptionId: subscriptionId,
    );
  }

  static Future<SystemInfo?> getSystemInfo() {
    return UssdHandlerPlatform.instance.getSystemInfo();
  }

  static Future<MultiSessionResult> startMultiSessionUssd(String ussdCode) {
    return UssdHandlerPlatform.instance.startMultiSessionUssd(ussdCode);
  }
}

// ✅ Correct - Response classes
class SystemInfo {
  final String platform;
  final bool ussdSupported;
  final bool multiSessionSupported;
  // ... more properties

  SystemInfo({
    required this.platform,
    required this.ussdSupported,
    required this.multiSessionSupported,
    // ... more parameters
  });

  @override
  String toString() {
    // Readable representation for debugging
    return 'SystemInfo: platform=$platform, ussdSupported=$ussdSupported';
  }
}

// ❌ Incorrect - Format and spacing
class UssdHandler{
  static Future<UssdResponse>executeUssd(String ussdCode,{int? subscriptionId}){
    return UssdHandlerPlatform.instance.executeUssd(ussdCode,subscriptionId:subscriptionId);
  }
}
```

### Naming Conventions

- **Classes**: `PascalCase` (ex: `UssdHandler`)
- **Methods**: `camelCase` (ex: `executeUssd`)
- **Variables**: `camelCase` (ex: `subscriptionId`)
- **Constants**: `lowerCamelCase` (ex: `defaultTimeout`)
- **Files**: `snake_case` (ex: `ussd_handler.dart`)

### Code Documentation

```dart
/// Executes a USSD code and returns the typed response
///
/// [ussdCode] - The USSD code to execute (ex: "*123#")
/// [subscriptionId] - (Optional) Subscription ID (SIM slot)
///
/// Returns a [UssdResponse] with the operation result.
/// The response includes typed properties: `success`, `response`, `errorMessage`.
///
/// Example:
/// ```dart
/// final response = await UssdHandler.executeUssd('*#06#');
/// if (response.success) {
///   print('IMEI: ${response.response}');
/// } else {
///   print('Error: ${response.errorMessage}');
/// }
/// ```
///
/// Throws [PlatformException] if there are platform errors.
static Future<UssdResponse> executeUssd(String ussdCode, {int? subscriptionId}) {
  // ...
}

/// Gets detailed system information
///
/// Returns a [SystemInfo] with typed device information,
/// including USSD support, SIM information, permissions, etc.
///
/// Example:
/// ```dart
/// final info = await UssdHandler.getSystemInfo();
/// if (info != null) {
///   print('Platform: ${info.platform}');
///   print('USSD supported: ${info.ussdSupported}');
///   // Use toString() for complete representation
///   print(info.toString());
/// }
/// ```
static Future<SystemInfo?> getSystemInfo() {
  // ...
}
```

### Error Handling

```dart
// ✅ Correct - with typed classes
try {
  final response = await UssdHandler.executeUssd('*123#');
  if (response.success) {
    print('Response: ${response.response}');
  } else {
    print('USSD Error: ${response.errorMessage}');
  }
} catch (e) {
  print('Error executing USSD: $e');
}

// ✅ Correct - system information
try {
  final systemInfo = await UssdHandler.getSystemInfo();
  if (systemInfo != null) {
    print('Platform: ${systemInfo.platform}');
    print('USSD supported: ${systemInfo.ussdSupported}');
    
    // Use toString() for debugging
    print(systemInfo.toString());
  } else {
    print('Could not get system information');
  }
} catch (e) {
  print('Error getting system info: $e');
}

// ✅ Correct - multi-USSD sessions
try {
  final result = await UssdHandler.startMultiSessionUssd('*123#');
  if (result.success) {
    print('Session started: ${result.message}');
    print('Initial response: ${result.ussdResponse}');
  } else {
    print('Error starting session: ${result.error}');
  }
} on PlatformException catch (e) {
  print('Platform error: ${e.message}');
} catch (e) {
  print('General error: $e');
}
```

## 🧪 Testing

### Running Tests

```bash
# Unit tests
flutter test

# Integration tests
cd example
flutter test integration_test/

# Code analysis
flutter analyze

# Code formatting
dart format .
```

### Writing Tests

#### Unit Test Example

```dart
test('executeUssd should return success response with typed data', () async {
  // Arrange
  MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
  UssdHandlerPlatform.instance = fakePlatform;

  // Act
  final response = await UssdHandler.executeUssd('*123#');

  // Assert
  expect(response.success, true);
  expect(response.response, isNotNull);
  expect(response.errorMessage, isNull);
});

test('getSystemInfo should return typed SystemInfo', () async {
  // Arrange
  MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
  UssdHandlerPlatform.instance = fakePlatform;

  // Act
  final systemInfo = await UssdHandler.getSystemInfo();

  // Assert
  expect(systemInfo, isNotNull);
  expect(systemInfo!.platform, isNotEmpty);
  expect(systemInfo.ussdSupported, isA<bool>());
  expect(systemInfo.toString(), contains('SystemInfo'));
});

test('startMultiSessionUssd should return typed MultiSessionResult', () async {
  // Arrange
  MockUssdHandlerPlatform fakePlatform = MockUssdHandlerPlatform();
  UssdHandlerPlatform.instance = fakePlatform;

  // Act
  final result = await UssdHandler.startMultiSessionUssd('*123#');

  // Assert
  expect(result.success, isA<bool>());
  expect(result.message, isNotEmpty);
  expect(result.sessionActive, isA<bool>());
});
```

#### Integration Test Example

```dart
testWidgets('USSD execution integration test', (WidgetTester tester) async {
  // This test should run on a real device
  final response = await UssdHandler.executeUssd('*#06#');
  expect(response.success, true);
});
```

### Test Coverage

- Maintain **coverage > 80%** for new code
- Include tests for happy and error cases
- Mock external dependencies
- Test on real devices for USSD functionality

## 🔄 Pull Request Process

### 1. Preparation

```bash
# Create feature branch
git checkout -b feature/new-functionality

# Develop and test
# ... code ...

# Commit with descriptive message
git commit -m "feat: add multi-SIM support for USSD direct"
```

### 2. Commit Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` new functionality
- `fix:` bug fix
- `docs:` documentation changes
- `test:` add or modify tests
- `refactor:` code refactoring
- `style:` formatting changes
- `chore:` maintenance tasks

### 3. Pre-PR Checklist

- [ ] Tests pass (`flutter test`)
- [ ] Clean analysis (`flutter analyze`)
- [ ] Code formatted (`dart format .`)
- [ ] Documentation updated
- [ ] Example updated (if applicable)
- [ ] CHANGELOG.md updated

### 4. Create Pull Request

- Use the PR template
- Clearly describe the changes
- Include screenshots/videos if applicable
- Reference related issues
- Add relevant reviewers

### 5. Review Process

- Respond to comments constructively
- Make requested changes
- Keep commits organized
- Wait for approval before merge

## 🐛 Reporting Issues

### Bug Report Template

```markdown
**Bug Description**
Clear and concise description of the bug.

**Steps to Reproduce**
1. Go to '...'
2. Click on '....'
3. Run '....'
4. See error

**Expected Behavior**
Clear description of what should happen.

**Screenshots**
If applicable, add screenshots to explain the problem.

**Environment Information**
- Device: [ex: Samsung Galaxy S21]
- OS: [ex: Android 12]
- Flutter: [ex: 3.16.0]
- Plugin version: [ex: 0.0.1]

**Additional Information**
Any other context about the problem.
```

### Feature Request Template

```markdown
**Is your feature request related to a problem?**
Clear description of the problem. Ex: "I'm frustrated when [...]"

**Describe the solution you'd like**
Clear and concise description of what you want to happen.

**Describe alternatives you've considered**
Description of alternative solutions or features you've considered.

**Additional context**
Any other context or screenshots about the feature request.
```

## 📖 Documentation

### Updating Documentation

#### README.md
- Keep examples updated
- Include new features
- Update API reference

#### API Documentation
```dart
/// Clear documentation in dartdoc format
/// 
/// Use [links] to other classes when relevant
/// Include code examples in ```dart
/// Specify exceptions that can be thrown
```

### Generate Documentation

```bash
# Generate API documentation
dart doc

# Check markdown links
# (use external tool like markdown-link-check)
```

## 🔧 Development Configurations

### VS Code Settings

```json
{
  "dart.formatOnSave": true,
  "dart.lineLength": 80,
  "editor.rulers": [80],
  "files.exclude": {
    "**/.dart_tool": true,
    "**/build": true
  }
}
```

### Android Studio Settings

- Enable automatic formatting on save
- Configure line length to 80 characters
- Install Flutter and Dart plugins

## 🎯 Roadmap and Priorities

### High Priority
- [ ] Stability on diverse Android devices
- [ ] Error handling improvements with specific types
- [ ] Performance optimization in type conversions
- [ ] Migration documentation from previous versions

### Medium Priority
- [ ] Improved iOS support with new APIs
- [ ] Typed configuration interface
- [ ] Response caching with persistence
- [ ] Additional USSD code validation

### Low Priority
- [ ] Operator templates with typed configuration
- [ ] Structured log export
- [ ] eSIM support with detailed information
- [ ] Performance metrics and analytics

## 📞 Contact and Support

- **Issues**: [GitHub Issues](https://github.com/leonardo0823/ussd_handler/issues)
- **Email**: [mrleonardo0823@gmail.com]

---

