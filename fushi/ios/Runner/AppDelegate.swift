import CoreText
import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler, FlutterImplicitEngineDelegate {
  private var initialUrl: String?
  private var urlEventSink: FlutterEventSink?
  /// 强引用：channel handler 只弱持有它，且它自己是文档选择器的 delegate（UIKit 弱引用）。
  private var directoryImport: FushiDirectoryImport?

  // TODO-057: brightness override applied during a video session. We snapshot
  // the user's brightness the first time the player asks (getBrightness) and
  // restore it on exit (restoreBrightness) so dragging never leaves the system
  // brightness permanently changed.
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    installChannels(binaryMessenger: engineBridge.applicationRegistrar.messenger())
  }

  /// 安装来源判据 = 系统写进 bundle 的 App Store 收据文件，不是猜测：
  /// - App Store 安装 → `.../receipt`
  /// - TestFlight 安装 → `.../sandboxReceipt`
  /// - 侧载 / 自签 / Xcode 直接跑 → 收据**文件不存在**（`appStoreReceiptURL` 仍给得
  ///   出路径，所以必须查文件是否真的在，只看文件名会把侧载误判成 TestFlight）。
  private static func currentInstallSource() -> String {
    guard let receiptUrl = Bundle.main.appStoreReceiptURL,
      FileManager.default.fileExists(atPath: receiptUrl.path)
    else {
      return "sideload"
    }
    return receiptUrl.lastPathComponent == "sandboxReceipt" ? "testFlight" : "appStore"
  }

  private func installChannels(binaryMessenger: FlutterBinaryMessenger) {
    // Kitapsen: no system OCR, speech transcription, floating ball (OCR +
    // lookup), lookup keyboard language, online-source challenge browser or
    // AnkiMobile bridge. Their Dart callers are compiled out of the edition, so
    // their native halves are not built either (App Review guideline 2.3.1).
    // 复制图片到剪贴板（视频截图 / 阅读器内联图）。与 macOS 同一份实现，
    // 方法名与入参逐字对齐 Windows 那份 CF_DIB 实现。
    FushiClipboardImage.register(binaryMessenger: binaryMessenger)
    // 目录导入（BUG-2786）：iOS 上沙盒外文件夹只能在安全作用域访问窗口内整卷拷进来。
    // 呈现者必须是最顶层的 VC——导入对话框本身就是 Flutter 路由，但若此刻上面还压着
    // 别的原生表单，从 root 直接 present 会被 UIKit 拒掉（静默不弹）。
    directoryImport = FushiDirectoryImport(binaryMessenger: binaryMessenger) {
      var top = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?.rootViewController
      while let presented = top?.presentedViewController {
        top = presented
      }
      return top
    }
    let splashChannel = FlutterMethodChannel(
      name: "app.fushi.reader/splash",
      binaryMessenger: binaryMessenger)
    splashChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "getSplashColor":
        // LaunchScreen.storyboard uses a white root view / LaunchBackground.
        result(0xFFFFFFFF)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let urlMethodChannel = FlutterMethodChannel(
      name: "app.fushi.reader/url_events",
      binaryMessenger: binaryMessenger)
    urlMethodChannel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "getInitialUrl":
        result(self?.initialUrl)
        self?.initialUrl = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 长按 app 图标的 Home Screen quick actions（Dart 门面
    // lib/src/platform/app_shortcuts.dart）。点击由 SceneDelegate 换成
    // `fushi://shortcut/<id>` 走下面的 url_events，不另起投递通道。
    let appShortcutsChannel = FlutterMethodChannel(
      name: "app.fushi.reader/app_shortcuts",
      binaryMessenger: binaryMessenger)
    appShortcutsChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "setShortcuts":
        // Dart 发 {items, disabledMessage}；后者只给 Android 置灰固定快捷方式用，
        // iOS 的 quick actions 整表替换即可，不存在「固定」的残留。
        let args = call.arguments as? [String: Any]
        let items = (args?["items"] as? [[String: String]]) ?? []
        UIApplication.shared.shortcutItems = items.compactMap { item in
          guard let id = item["id"], let title = item["title"],
            let url = item["url"]
          else { return nil }
          return UIApplicationShortcutItem(
            type: Self.appShortcutType(id),
            localizedTitle: title,
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: Self.appShortcutSymbol(id)),
            userInfo: ["url": url as NSString])
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let urlEventChannel = FlutterEventChannel(
      name: "app.fushi.reader/url_events/stream",
      binaryMessenger: binaryMessenger)
    urlEventChannel.setStreamHandler(self)

    let brightnessChannel = FlutterMethodChannel(
      name: "app.fushi.reader/screen_brightness",
      binaryMessenger: binaryMessenger)
    brightnessChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "getBrightness":
        // UIScreen.brightness is 0...1; main-thread read.
        result(Double(UIScreen.main.brightness))
      case "setBrightness":
        guard let value = call.arguments as? NSNumber else {
          result(FlutterError(
            code: "INVALID_ARG",
            message: "setBrightness requires a number 0..1",
            details: nil))
          return
        }
        let clamped = max(0.0, min(1.0, value.doubleValue))
        UIScreen.main.brightness = CGFloat(clamped)
        result(nil)
      case "restoreBrightness":
        // The Dart side passes the snapshot it took on entry; write it back.
        // nil means "do not touch" (no snapshot available) — leave as-is.
        if let value = call.arguments as? NSNumber {
          let clamped = max(0.0, min(1.0, value.doubleValue))
          UIScreen.main.brightness = CGFloat(clamped)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 更新落地入口分流（Dart 侧 IosUpdater.resolveDownloadLanding）。iOS 有三条互不
    // 相干的分发链路 —— App Store / TestFlight / GitHub 未签名 ipa 侧载 —— 而「该去
    // 哪儿更新」只由「这份 app 是从哪儿装来的」决定。这里回答的就是这一个事实。
    let updateChannel = FlutterMethodChannel(
      name: "app.fushi.reader/update",
      binaryMessenger: binaryMessenger)
    updateChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "getInstallSource":
        result(Self.currentInstallSource())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 字体库「浏览系统字体」（四端同一契约，见 Windows system_font_list.cpp /
    // Android MainActivity / macOS AppDelegate）：返回 [{family, supportsJapanese?}]。
    let fontsChannel = FlutterMethodChannel(
      name: "app.fushi.reader/fonts",
      binaryMessenger: binaryMessenger)
    fontsChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "listSystemFonts":
        // UIFont 是 UIKit，族名列表在主线程取；逐族 CoreText 字符集探测放后台。
        Self.listSystemFonts(families: UIFont.familyNames, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// `listSystemFonts`：过滤 `.` 开头的私有族，按族名大小写不敏感去重、排序，
  /// 后台逐族判日文覆盖，回主线程交结果。判不出覆盖的族省略 `supportsJapanese`。
  private static func listSystemFonts(
    families: [String], result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      let sorted = families
        .filter { !$0.isEmpty && !$0.hasPrefix(".") }
        .sorted { $0.caseInsensitiveCompare($1) == .orderedAscending }
      var seen = Set<String>()
      var entries: [[String: Any]] = []
      for family in sorted {
        guard seen.insert(family.lowercased()).inserted else { continue }
        var entry: [String: Any] = ["family": family]
        if let japanese = Self.fontFamilySupportsJapanese(family) {
          entry["supportsJapanese"] = japanese
        }
        entries.append(entry)
      }
      DispatchQueue.main.async { result(entries) }
    }
  }

  /// 该族的常规字形自身（不含系统回退）是否同时覆盖 U+3042「あ」与 U+6F22「漢」。
  /// 按族名描述符解析；若 CoreText 解析到的不是这个族（回退到了默认字体），返回 nil
  /// 表示「判不出」，而不是把回退字体的覆盖冒充成它的。
  private static func fontFamilySupportsJapanese(_ family: String) -> Bool? {
    let descriptor = CTFontDescriptorCreateWithAttributes(
      [kCTFontFamilyNameAttribute as String: family] as CFDictionary)
    let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
    let resolvedFamily = CTFontCopyFamilyName(font) as String
    guard resolvedFamily.caseInsensitiveCompare(family) == .orderedSame else {
      return nil
    }
    let charset = CTFontCopyCharacterSet(font) as CharacterSet
    let kana: Unicode.Scalar = "\u{3042}"
    let kanji: Unicode.Scalar = "\u{6F22}"
    return charset.contains(kana) && charset.contains(kanji)
  }

  override func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    deliverUrl(url.absoluteString)
    let handled = super.application(application, open: url, options: options)
    return handled || url.scheme == "fushi"
  }

  private static let appShortcutTypePrefix = "app.fushi.reader.shortcut."

  private static func appShortcutType(_ id: String) -> String {
    return appShortcutTypePrefix + id
  }

  private static func appShortcutSymbol(_ id: String) -> String {
    switch id {
    case "books": return "book"
    case "manga": return "photo.on.rectangle"
    case "video": return "film"
    default: return "app"
    }
  }

  /// 把快捷方式点击交给 Dart。返回 false = 不是本 app 发布的快捷方式。
  @discardableResult
  func deliverShortcut(_ item: UIApplicationShortcutItem) -> Bool {
    guard item.type.hasPrefix(Self.appShortcutTypePrefix) else { return false }
    let url = (item.userInfo?["url"] as? String)
      ?? "fushi://shortcut/" + item.type.dropFirst(Self.appShortcutTypePrefix.count)
    deliverUrl(url)
    return true
  }

  func deliverUrl(_ url: String) {
    if let sink = urlEventSink {
      sink(url)
    } else {
      initialUrl = url
    }
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    urlEventSink = events
    if let url = initialUrl {
      events(url)
      initialUrl = nil
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    urlEventSink = nil
    return nil
  }
}
