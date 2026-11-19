import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// ADR-0018 P1 — kênh nhận link `in4up://dict?w=…` từ iOS.
  ///
  /// Native chỉ chuyển URL THÔ sang Dart; mọi kiểm tra an toàn (độ dài từ,
  /// đuôi tệp, `..`) nằm ở `lib/features/dictionary/services/dict_deep_link.dart`.
  /// Cùng hợp đồng với Android (`MainActivity.kt`, kênh `in4up/deeplink`).
  private var deepLinkChannel: FlutterMethodChannel?

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
    }

    if let url = launchOptions?[.url] as? URL {
      if url.isFileURL {
        if let payload = copyIncomingFileToAppStorage(url: url) {
          pendingIncomingFile = payload
        }
      } else {
        pendingDeepLink = url.absoluteString
      }
    }
    return launched
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
