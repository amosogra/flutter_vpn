import Cocoa
import FlutterMacOS

public class FlutterVpnPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_vpn", binaryMessenger: registrar.messenger)
    let stateChannel = FlutterEventChannel(name: "flutter_vpn_states", binaryMessenger: registrar.messenger)

    let instance = FlutterVpnPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    stateChannel.setStreamHandler((VPNStateHandler() as! FlutterStreamHandler & NSObjectProtocol))
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
      break
    case "connect":
      let args = call.arguments! as! [NSString: NSString]
        VpnService.shared.connect(
          result: result,
          type: (args["Type"] as? String ?? "IKEv2"),
          server: args["Server"]! as String,
          username: args["Username"]! as String,
          password: args["Password"]! as String,
          secret: args["Secret"] as? String,
          description: args["Name"] as? String
        )
      break
    case "reconnect":
      VpnService.shared.reconnect(result: result)
      break
    case "disconnect":
      VpnService.shared.disconnect(result: result)
      break
    case "getCurrentState":
      VpnService.shared.getState(result: result)
      break
    case "checkState":
      VpnService.shared.checkState()
      break
    case "prepare":
      VpnService.shared.prepare(result: result)
      break
    case "prepared":
      VpnService.shared.prepare(result: result)
      break 
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
