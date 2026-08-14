import CallKit
import CoreTelephony
import Flutter
import UIKit

public class UssdHandlerPlugin: NSObject, FlutterPlugin {
  private let networkInfo = CTTelephonyNetworkInfo()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "ussd_handler", binaryMessenger: registrar.messenger())
    let instance = UssdHandlerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]

    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    case "executeUssd":
      handleExecuteUssd(args: args, result: result)

    case "executeUssdDirect":
      handleExecuteUssdDirect(args: args, result: result)

    case "isUssdSupported":
      result(isUssdSupported())

    case "getSystemInfo":
      result(getSystemInfo())

    case "hasUssdDirectPermissions":
      result(hasUssdDirectPermissions())

    case "isAccessibilityServiceEnabled":
      result(false)  // iOS does not support accessibility services like Android

    case "openAccessibilitySettings":
      result(false)  // Not applicable on iOS

    case "setupAccessibilityEventChannel":
      result([
        "success": false,
        "message": "Accessibility services not available on iOS",
      ])

    case "startMultiSessionUssd":
      result([
        "success": false,
        "error": "Multi-USSD sessions not supported on iOS",
      ])

    case "sendMessageInSession":
      result([
        "success": false,
        "error": "Multi-USSD sessions not supported on iOS",
      ])

    case "cancelMultiSession":
      result([
        "success": false,
        "error": "Multi-USSD sessions not supported on iOS",
      ])

    case "isMultiSessionActive":
      result(false)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleExecuteUssd(args: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = args,
      let ussdCode = args["ussdCode"] as? String
    else {
      result([
        "success": false,
        "errorMessage": "Invalid USSD code",
      ])
      return
    }

    let subscriptionId = args["subscriptionId"] as? Int
    executeUssd(ussdCode: ussdCode, subscriptionId: subscriptionId, result: result)
  }

  private func handleExecuteUssdDirect(args: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = args,
      let ussdCode = args["ussdCode"] as? String
    else {
      result(nil)
      return
    }

    let iosFallbackToStandard = args["iosFallbackToStandard"] as? Bool ?? false
    let subscriptionId = args["subscriptionId"] as? Int

    if iosFallbackToStandard {
      // Use executeUssd as fallback on iOS
      executeUssd(ussdCode: ussdCode, subscriptionId: subscriptionId) { ussdResult in
        // Convert executeUssd result to executeUssdDirect format
        if let ussdResultDict = ussdResult as? [String: Any],
          let success = ussdResultDict["success"] as? Bool,
          success,
          let response = ussdResultDict["response"] as? String
        {
          // Return only the response as String for executeUssdDirect
          result(response)
        } else {
          // If executeUssd failed, return nil
          result(nil)
        }
      }
    } else {
      // iOS does not support direct USSD without fallback - always returns nil
      result(nil)
    }
  }

  private func executeUssd(ussdCode: String, subscriptionId: Int?, result: @escaping FlutterResult)
  {
    if !isUssdSupported() {
      result([
        "success": false,
        "errorMessage": "USSD is not supported on this iOS device",
      ])
      return
    }

    // On iOS, USSD codes are executed using URL schemes
    // Note: iOS will open the phone app, but we cannot capture the response
    if let url = URL(string: "tel:\(ussdCode)") {
      DispatchQueue.main.async {
        if UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url) { success in
            if success {
              result([
                "success": true,
                "response":
                  "USSD code sent to phone app: \(ussdCode). Note: iOS does not allow automatic response capture.",
              ])
            } else {
              result([
                "success": false,
                "errorMessage": "Could not open phone application",
              ])
            }
          }
        } else {
          result([
            "success": false,
            "errorMessage": "Cannot execute USSD codes on this device",
          ])
        }
      }
    } else {
      result([
        "success": false,
        "errorMessage": "Invalid USSD code: \(ussdCode)",
      ])
    }
  }

  private func isUssdSupported() -> Bool {
    // Check if the device can make phone calls
    guard let url = URL(string: "tel://") else { return false }
    return UIApplication.shared.canOpenURL(url)
  }

  private func hasUssdDirectPermissions() -> Bool {
    // iOS does not require special permissions for USSD, but has limitations
    return isUssdSupported()
  }

  private func getSystemInfo() -> [String: Any] {
    var systemInfo: [String: Any] = [:]

    // Basic device information
    systemInfo["platform"] = "iOS"
    systemInfo["iosVersion"] = UIDevice.current.systemVersion
    systemInfo["deviceModel"] = UIDevice.current.model
    systemInfo["deviceName"] = UIDevice.current.name

    // Device capabilities
    systemInfo["canMakePhoneCalls"] = isUssdSupported()
    systemInfo["ussdSupported"] = isUssdSupported()
    systemInfo["ussdDirectSupported"] = false  // iOS does not support direct USSD
    systemInfo["multiSessionSupported"] = false  // iOS does not support multi-session
    systemInfo["accessibilityServiceSupported"] = false  // iOS does not support accessibility services like Android

    // Network and carrier information
    if let carrier = networkInfo.subscriberCellularProvider {
      systemInfo["carrierName"] = carrier.carrierName ?? "Unknown"
      systemInfo["countryCode"] = carrier.isoCountryCode ?? "Unknown"
      systemInfo["mobileNetworkCode"] = carrier.mobileNetworkCode ?? "Unknown"
      systemInfo["mobileCountryCode"] = carrier.mobileCountryCode ?? "Unknown"
    }

    // SIM information (limited on iOS)
    systemInfo["simCount"] = 1  // iOS does not expose detailed information about multiple SIMs
    systemInfo["supportsDualSim"] = false  // Simplified for iOS

    // iOS-specific limitations
    systemInfo["limitations"] = [
      "iOS does not allow automatic USSD response capture",
      "USSD codes open the native phone application",
      "No support for multi-USSD sessions",
      "No accessibility services for USSD",
      "Limited information about multiple SIMs",
    ]

    return systemInfo
  }
}
