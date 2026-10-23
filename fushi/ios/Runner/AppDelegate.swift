import CoreText
import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler, FlutterImplicitEngineDelegate {
  private var initialUrl: String?
  private var urlEventSink: FlutterEventSink?

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

  private func installChannels(binaryMessenger: FlutterBinaryMessenger) {
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
        // Dart 发 {items}；iOS 的 quick actions 整表替换即可，不存在「固定」的残留。
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
