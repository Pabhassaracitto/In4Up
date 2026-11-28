import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static let widgetAppGroupSuite = "group.com.in4up.shared"
  private static let widgetSnapshotKey = "widget_snapshot_json"
  private static let widgetDeckIndexKey = "widget_srs_deck_index"
  private static let widgetIsFlippedKey = "widget_srs_is_flipped"

  /// ADR-0018 P1 — kênh nhận link `in4up://dict?w=…` từ iOS.
  ///
  /// Native chỉ chuyển URL THÔ sang Dart; mọi kiểm tra an toàn (độ dài từ,
  /// đuôi tệp, `..`) nằm ở `lib/features/dictionary/services/dict_deep_link.dart`.
  /// Cùng hợp đồng với Android (`MainActivity.kt`, kênh `in4up/deeplink`).
  private var deepLinkChannel: FlutterMethodChannel?

  /// PLAN-050 P4 · ADR-0040 — kênh đồng bộ `WidgetSnapshot` sang iOS WidgetKit.
  private var homeWidgetChannel: FlutterMethodChannel?

  /// Link đến khi app còn chưa dựng xong Flutter engine (app bị giết → người
  /// dùng bấm link). Dart hỏi `getInitialLink` ngay sau `runApp`.
  private var pendingDeepLink: String?
  private var filesChannel: FlutterMethodChannel?
  private var pendingIncomingFile: [String: Any?]?
  private var incomingFileListenerReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "in4up/deeplink",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "getInitialLink" else {
          result(FlutterMethodNotImplemented)
          return
        }
        // Trả một lần rồi xoá — mở lại app không được tra lại từ cũ.
        let link = self?.pendingDeepLink
        self?.pendingDeepLink = nil
        result(link)
      }
      deepLinkChannel = channel

      let exportChannel = FlutterMethodChannel(
        name: "in4up/files",
        binaryMessenger: controller.binaryMessenger
      )
      exportChannel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "getInitialIncomingFile":
          self?.incomingFileListenerReady = true
          let payload = self?.pendingIncomingFile
          self?.pendingIncomingFile = nil
          result(payload)
        case "openExportLocation":
          let args = call.arguments as? [String: Any]
          let location = (args?["location"] as? String) ?? ""
          if !location.isEmpty,
             let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
             let filesUrl = URL(string: "shareddocuments://\(encoded)"),
             UIApplication.shared.canOpenURL(filesUrl) {
            UIApplication.shared.open(filesUrl, options: [:]) { ok in
              result(ok)
            }
          } else {
            result(false)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      filesChannel = exportChannel

      let widgetsChannel = FlutterMethodChannel(
        name: "in4up/home_widget",
        binaryMessenger: controller.binaryMessenger
      )
      widgetsChannel.setMethodCallHandler { [weak self] call, result in
        self?.handleHomeWidgetCall(call, result: result)
      }
      homeWidgetChannel = widgetsChannel
    }

    if let url = launchOptions?[.url] as? URL {
      if url.isFileURL {
        if let payload = copyIncomingFileToAppStorage(url: url) {
          pendingIncomingFile = payload
        }
      } else {
        pendingDeepLink = url.absoluteString
      }
    } else if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
              let shortcutLink = resolveShortcutDeepLink(shortcutItem) {
      pendingDeepLink = shortcutLink
    }
    return launched
  }

  /// PLAN-050 · ADR-0040: nhận Home Screen Quick Action (nhấn giữ biểu tượng iOS).
  override func application(
    _ application: UIApplication,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    guard let link = resolveShortcutDeepLink(shortcutItem) else {
      completionHandler(false)
      return
    }
    if let channel = deepLinkChannel {
      channel.invokeMethod("onLink", arguments: link)
    } else {
      pendingDeepLink = link
    }
    completionHandler(true)
  }

  private func resolveShortcutDeepLink(_ item: UIApplicationShortcutItem) -> String? {
    if let custom = item.userInfo?["deepLink"] as? String,
       custom.hasPrefix("in4up://") {
      return custom
    }
    return deepLinkForShortcutType(item.type)
  }

  private func deepLinkForShortcutType(_ type: String) -> String? {
    switch type {
    case "com.in4up.shortcut.dict_search":
      return "in4up://action/dict_search?autofocus=1&src=ios_shortcut"
    case "com.in4up.shortcut.voice_capture":
      return "in4up://action/voice_capture?autostart=1&src=ios_shortcut"
    case "com.in4up.shortcut.ocr_scan":
      return "in4up://action/ocr_scan?src=ios_shortcut"
    case "com.in4up.shortcut.review_due":
      return "in4up://action/review_due?mode=srs&src=ios_shortcut"
    default:
      return nil
    }
  }

  /// PLAN-050 P4 · ADR-0040: xử lý MethodChannel `in4up/home_widget` cho iOS WidgetKit.
  private func handleHomeWidgetCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "syncSnapshot":
      guard let args = call.arguments as? [String: Any],
            let json = args["json"] as? String,
            !json.isEmpty,
            json.utf8.count <= 16384
      else {
        result(false)
        return
      }
      if let groupDefaults = UserDefaults(suiteName: Self.widgetAppGroupSuite) {
        groupDefaults.set(json, forKey: Self.widgetSnapshotKey)
        groupDefaults.set(false, forKey: Self.widgetIsFlippedKey)
      }
      UserDefaults.standard.set(json, forKey: Self.widgetSnapshotKey)
      UserDefaults.standard.set(false, forKey: Self.widgetIsFlippedKey)

      updateDynamicShortcutItems(fromSnapshotJson: json)
      WidgetCenter.shared.reloadAllTimelines()
      result(true)

    case "getStatus":
      WidgetCenter.shared.getCurrentConfigurations { response in
        var counts: [String: Int] = [
          "quick_bar": 0,
          "continue_learning": 0,
          "flashcard_srs": 0,
          "streak_pulse": 0,
        ]
        if case .success(let infos) = response {
          for info in infos {
            switch info.kind {
            case "in4up_quick_bar":
              counts["quick_bar", default: 0] += 1
            case "in4up_continue_learning":
              counts["continue_learning", default: 0] += 1
            case "in4up_flashcard_srs":
              counts["flashcard_srs", default: 0] += 1
            case "in4up_streak_pulse":
              counts["streak_pulse", default: 0] += 1
            default:
              break
            }
          }
        }
        DispatchQueue.main.async {
          result([
            "supported": true,
            "requestPinSupported": false,
            "counts": counts,
          ])
        }
      }

    case "requestPinWidget", "requestPinShortcut":
      // iOS yêu cầu người dùng tự thêm Widget từ màn hình chính / màn hình khoá.
      result(false)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func updateDynamicShortcutItems(fromSnapshotJson json: String) {
    guard let data = json.data(using: .utf8),
          let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let rawSlots = root["quickSlots"] as? [[String: Any]]
    else {
      return
    }
    var dynamicItems: [UIApplicationShortcutItem] = []
    for slot in rawSlots.prefix(3) {
      guard let id = slot["id"] as? String,
            let label = slot["label"] as? String,
            let deepLink = slot["deepLink"] as? String,
            !label.isEmpty,
            deepLink.hasPrefix("in4up://")
      else {
        continue
      }
      let iconKey = (slot["iconKey"] as? String) ?? "sparkle"
      let symbolName: String
      switch iconKey {
      case "mic": symbolName = "mic.fill"
      case "ocr": symbolName = "doc.viewfinder"
      case "translate": symbolName = "character.bubble.fill"
      case "leaf": symbolName = "leaf.fill"
      case "book": symbolName = "book.fill"
      case "video": symbolName = "play.rectangle.fill"
      case "headphones": symbolName = "headphones"
      default: symbolName = "sparkles"
      }
      let item = UIApplicationShortcutItem(
        type: "com.in4up.shortcut.dynamic.\(id)",
        localizedTitle: label,
        localizedSubtitle: nil,
        icon: UIApplicationShortcutIcon(systemImageName: symbolName),
        userInfo: ["deepLink": deepLink as NSSecureCoding]
      )
      dynamicItems.append(item)
    }
    DispatchQueue.main.async {
      UIApplication.shared.shortcutItems = dynamicItems
    }
  }

  /// App ĐANG CHẠY và người dùng bấm link (scheme `in4up`) hoặc chọn "Mở bằng In4Up"
  /// cho một tệp `file://` từ ứng dụng Tệp / Chia sẻ.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let handledByPlugins = super.application(app, open: url, options: options)
    if url.isFileURL {
      guard let payload = copyIncomingFileToAppStorage(url: url) else {
        return handledByPlugins
      }
      if let channel = filesChannel, incomingFileListenerReady {
        channel.invokeMethod("onIncomingFile", arguments: payload)
      } else {
        pendingIncomingFile = payload
      }
      return true
    }
    let scheme = url.scheme?.lowercased()
    guard scheme == "in4up" || scheme == "i4u" else {
      return handledByPlugins
    }
    if let channel = deepLinkChannel {
      channel.invokeMethod("onLink", arguments: url.absoluteString)
    } else {
      pendingDeepLink = url.absoluteString
    }
    return true
  }

  /// Chép tệp `file://` từ ngoài vào Application Support của app trước khi quyền
  /// security-scoped hết hạn.
  private func copyIncomingFileToAppStorage(url: URL) -> [String: Any?]? {
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        url.stopAccessingSecurityScopedResource()
      }
    }
    let fm = FileManager.default
    guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return nil
    }
    let incomingDir = appSupport.appendingPathComponent("in4up_incoming", isDirectory: true)
    do {
      try fm.createDirectory(at: incomingDir, withIntermediateDirectories: true)
      let rawName = url.lastPathComponent.isEmpty ? "incoming_file" : url.lastPathComponent
      var target = incomingDir.appendingPathComponent(rawName)
      if fm.fileExists(atPath: target.path) {
        let ext = target.pathExtension
        let stem = target.deletingPathExtension().lastPathComponent
        var idx = 2
        while idx < 10000 {
          let candidateName = ext.isEmpty ? "\(stem) (\(idx))" : "\(stem) (\(idx)).\(ext)"
          let candidate = incomingDir.appendingPathComponent(candidateName)
          if !fm.fileExists(atPath: candidate.path) {
            target = candidate
            break
          }
          idx += 1
        }
      }
      try fm.copyItem(at: url, to: target)
      return [
        "localPath": target.path,
        "displayName": target.lastPathComponent,
        "mimeType": nil,
        "originalUri": url.absoluteString,
        "source": "ios_open",
      ]
    } catch {
      return nil
    }
  }
}
