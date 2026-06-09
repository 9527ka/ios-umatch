import Flutter
import UIKit
import ActivityKit

// ⚠️ 必须与 widgets/UMMatchActivityAttributes.swift 逐字段一致。
// 两个 target 各持一份相同定义；ActivityKit 通过非限定类型名匹配。
@available(iOS 16.1, *)
struct UMMatchActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var statusText: String
    }

    var home: String
    var away: String
    var comp: String
    var kickoffEpoch: Double
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  // 推送通道：原生拿到 APNs device token 后回传给 Dart (PushRegistrar)。
  private var pushChannel: FlutterMethodChannel?
  // 深链通道：umatch://<token> → 回传 Dart (DeepLinkService) 做激活。
  private var deeplinkChannel: FlutterMethodChannel?
  // 冷启动经深链拉起时的初始 URL，待 Dart 主动取走一次。
  private var initialLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 冷启动若经 umatch:// 深链拉起，先记录初始 URL（Dart 端 getInitialLink 取走）
    if let url = launchOptions?[.url] as? URL {
      initialLink = url.absoluteString
    }

    // flutter_local_notifications: 设置通知中心代理以支持前台展示与调度回调
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      // MethodChannel: TestFlight 检测 + APNs token 环境判定
      let envChannel = FlutterMethodChannel(name: "com.uu.umatch/env", binaryMessenger: controller.binaryMessenger)
      envChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "isTestFlight":
          let isTF = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
          result(isTF)
        case "apnsEnvironment":
          // token 真实环境取自签名描述文件的 aps-environment，而非编译模式。
          result(AppDelegate.apnsEnvironment())
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      // MethodChannel: 灵动岛 / 锁屏 Live Activity
      let laChannel = FlutterMethodChannel(name: "com.uu.umatch/liveactivity", binaryMessenger: controller.binaryMessenger)
      laChannel.setMethodCallHandler { call, result in
        guard #available(iOS 16.1, *) else { result(false); return }
        switch call.method {
        case "isEnabled":
          result(ActivityAuthorizationInfo().areActivitiesEnabled)
        case "start":
          let a = call.arguments as? [String: Any] ?? [:]
          LiveActivityManager.start(
            home: a["home"] as? String ?? "",
            away: a["away"] as? String ?? "",
            comp: a["comp"] as? String ?? "",
            kickoffEpoch: a["kickoffEpoch"] as? Double ?? 0
          )
          result(true)
        case "end":
          LiveActivityManager.endAll()
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      // MethodChannel: APNs 远程注册 (静默获取 device token 上报心跳)
      let pushChannel = FlutterMethodChannel(name: "com.uu.umatch/push", binaryMessenger: controller.binaryMessenger)
      pushChannel.setMethodCallHandler { call, result in
        if call.method == "registerForRemote" {
          application.registerForRemoteNotifications()
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      self.pushChannel = pushChannel

      // MethodChannel: 深链激活 (umatch://<token>)
      let deeplinkChannel = FlutterMethodChannel(name: "com.uu.umatch/deeplink", binaryMessenger: controller.binaryMessenger)
      deeplinkChannel.setMethodCallHandler { [weak self] call, result in
        if call.method == "getInitialLink" {
          NSLog("UMSHELL getInitialLink -> \(self?.initialLink ?? "nil")")
          result(self?.initialLink)
          self?.initialLink = nil // 只消费一次，避免重复触发
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      self.deeplinkChannel = deeplinkChannel
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 运行中(热启动)经 umatch:// 深链拉起：把 URL 回传 Dart 处理激活。
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme?.lowercased() == "umatch" {
      NSLog("UMSHELL open url: \(url.absoluteString)")
      // 冷启动兜底：Dart 未就绪时 onLink 会丢，留给 getInitialLink 兜
      initialLink = url.absoluteString
      deeplinkChannel?.invokeMethod("onLink", arguments: url.absoluteString)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  // APNs 注册成功：device token → hex → 回传 Dart。
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    pushChannel?.invokeMethod("onToken", arguments: hex)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("UMatch APNs register failed: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  /// APNs token 的真实环境，决定后端用哪个推送网关。
  ///
  /// 权威来源是签名时 `aps-environment` entitlement（描述文件），**不是** Dart
  /// 的 kDebugMode —— Release 调试包仍用 development 描述文件、拿到的是 sandbox
  /// token，靠编译模式判断会误报 production 导致 BadDeviceToken。
  ///
  /// - 有 `embedded.mobileprovision`（Xcode / Ad Hoc / TestFlight-pre 安装）：解析其
  ///   aps-environment，`development` → `sandbox`，否则 `production`。
  /// - 无该文件（App Store 包不内嵌描述文件）→ `production`。
  /// - 解析失败统一兜底 `production`。
  static func apnsEnvironment() -> String {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          // mobileprovision 是 CMS 包裹的 ASCII plist，截取 <plist>…</plist> 段解析。
          let raw = String(data: data, encoding: .isoLatin1),
          let start = raw.range(of: "<plist"),
          let end = raw.range(of: "</plist>"),
          let plistData = String(raw[start.lowerBound..<end.upperBound]).data(using: .isoLatin1),
          let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
          let dict = plist as? [String: Any],
          let entitlements = dict["Entitlements"] as? [String: Any],
          let aps = entitlements["aps-environment"] as? String
    else {
      return "production"
    }
    return aps == "development" ? "sandbox" : "production"
  }
}

@available(iOS 16.1, *)
enum LiveActivityManager {
  /// 为下一场比赛开启/复用一个 Live Activity（幂等：同 kickoff 已在则跳过）。
  static func start(home: String, away: String, comp: String, kickoffEpoch: Double) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled, kickoffEpoch > 0 else { return }

    // 已有同场活动则不重复开启
    for activity in Activity<UMMatchActivityAttributes>.activities {
      if abs(activity.attributes.kickoffEpoch - kickoffEpoch) < 1 { return }
    }
    // 切换到新比赛：先结束旧的
    endAll()

    let attrs = UMMatchActivityAttributes(home: home, away: away, comp: comp, kickoffEpoch: kickoffEpoch)
    let state = UMMatchActivityAttributes.ContentState(statusText: "")
    do {
      if #available(iOS 16.2, *) {
        _ = try Activity.request(
          attributes: attrs,
          content: ActivityContent(state: state, staleDate: Date(timeIntervalSince1970: kickoffEpoch)),
          pushType: nil
        )
      } else {
        _ = try Activity.request(attributes: attrs, contentState: state, pushType: nil)
      }
    } catch {
      NSLog("UMatch LiveActivity start error: \(error.localizedDescription)")
    }
  }

  static func endAll() {
    for activity in Activity<UMMatchActivityAttributes>.activities {
      Task {
        if #available(iOS 16.2, *) {
          await activity.end(nil, dismissalPolicy: .immediate)
        } else {
          await activity.end(dismissalPolicy: .immediate)
        }
      }
    }
  }
}
