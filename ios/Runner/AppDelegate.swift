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
    }

    if let url = launchOptions?[.url] as? URL {
      pendingDeepLink = url.absoluteString
    }
    return launched
  }

  /// App ĐANG CHẠY và người dùng bấm link (scheme `in4up`) hoặc một app khác
  /// mở URL của In4Up. Vẫn phải gọi `super` để plugin khác (OAuth, url_launcher)
  /// nhận được URL của chúng — chỉ nhận link của mình khi scheme khớp.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let handledByPlugins = super.application(app, open: url, options: options)
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
}
