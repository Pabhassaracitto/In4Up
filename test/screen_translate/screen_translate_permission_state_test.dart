// XLAT-SCR-003 — máy trạng thái QUYỀN của "dịch màn hình toàn hệ thống".
//
// Vì sao cần máy bắt này: triệu chứng 0.10.3 là "bấm bong bóng ⇒ không có gì
// xảy ra", và cả ba nguyên nhân gốc (chặn background activity start, thiếu
// consent theo phiên trên Android 14, mất quyền overlay) đều IM LẶNG. Phần
// Kotlin CHƯA có CI biên dịch nên quyết định "thiếu gì / bước tiếp theo là gì"
// được đẩy hẳn sang Dart để CI bắt được.
//
// Thuần Dart (không plugin, không BuildContext) ⇒ chạy được trên host VM bằng
// `flutter test test/screen_translate/`.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/screen_translate/screen_translate_channel.dart';
import 'package:in4up/features/screen_translate/screen_translate_models.dart';
import 'package:in4up/features/screen_translate/screen_translate_permission.dart';

ScreenTranslateNativeStatus status({
  bool supported = true,
  bool overlayGranted = true,
  bool running = false,
  bool captureConsented = false,
  bool consentDenied = false,
  bool notificationsEnabled = true,
  bool blockedBySystem = false,
  String blockReason = '',
  int sdkInt = 34,
}) =>
    ScreenTranslateNativeStatus(
      supported: supported,
      overlayGranted: overlayGranted,
      running: running,
      captureConsented: captureConsented,
      consentDenied: consentDenied,
      notificationsEnabled: notificationsEnabled,
      blockedBySystem: blockedBySystem,
      blockReason: blockReason,
      sdkInt: sdkInt,
    );

void main() {
  const resolver = ScreenTranslatePermissionResolver();

  group('ScreenTranslatePermissionResolver — 5 trạng thái', () {
    test('không phải Android ⇒ unsupported, khoá mọi thao tác', () {
      final snap = resolver.resolve(status(supported: false));
      expect(snap.state, ScreenTranslatePermissionState.unsupported);
      expect(snap.action, ScreenTranslateRecoveryAction.none);
      expect(snap.canToggle, isFalse);
      expect(snap.isReady, isFalse);
    });

    test('thiếu quyền overlay ⇒ mở đúng màn hình Cài đặt', () {
      final snap = resolver.resolve(
        status(overlayGranted: false, running: true),
      );
      expect(snap.state, ScreenTranslatePermissionState.needsOverlayPermission);
      expect(
        snap.action,
        ScreenTranslateRecoveryAction.openOverlaySettings,
      );
      expect(snap.canToggle, isFalse);
      expect(snap.bubbleNeedsSetup, isTrue);
    });

    test('đang chạy mà thiếu consent ⇒ needsCaptureConsent', () {
      final snap = resolver.resolve(status(running: true));
      expect(snap.state, ScreenTranslatePermissionState.needsCaptureConsent);
      expect(
        snap.action,
        ScreenTranslateRecoveryAction.requestCaptureConsent,
      );
      expect(snap.bubbleNeedsSetup, isTrue);
      expect(snap.canToggle, isTrue);
    });

    test('vừa bị TỪ CHỐI consent ⇒ tách riêng khỏi "chưa xin"', () {
      final snap = resolver.resolve(
        status(running: true, consentDenied: true),
      );
      expect(snap.state, ScreenTranslatePermissionState.consentDenied);
      // Vẫn cho thử lại — không khoá user lại.
      expect(
        snap.action,
        ScreenTranslateRecoveryAction.requestCaptureConsent,
      );
    });

    test('đủ quyền ⇒ ready, không có hành động', () {
      final snap = resolver.resolve(
        status(running: true, captureConsented: true),
      );
      expect(snap.state, ScreenTranslatePermissionState.ready);
      expect(snap.action, ScreenTranslateRecoveryAction.none);
      expect(snap.isReady, isTrue);
      expect(snap.bubbleNeedsSetup, isFalse);
    });

    test('chưa bật bong bóng ⇒ KHÔNG bị coi là thiếu quyền', () {
      // Nếu không có luật này, màn hình Cài đặt sẽ luôn báo "thiếu quyền chụp
      // màn hình" dù user chưa bao giờ bật tính năng — báo lỗi ma.
      final snap = resolver.resolve(status(running: false));
      expect(snap.state, ScreenTranslatePermissionState.ready);
      expect(snap.action, ScreenTranslateRecoveryAction.none);
    });

    test('thiếu overlay thắng thiếu consent (vẽ không được thì chụp cũng vô ích)',
        () {
      final snap = resolver.resolve(
        status(overlayGranted: false, running: true, consentDenied: true),
      );
      expect(snap.state, ScreenTranslatePermissionState.needsOverlayPermission);
    });
  });

  group('cảnh báo PHỤ (không đổi state)', () {
    test('tắt thông báo trên Android 13+ ⇒ action mở Cài đặt thông báo', () {
      // Notification bị ẩn cũng là một dạng "im lặng" — phải sửa trước.
      final snap = resolver.resolve(
        status(
          running: true,
          captureConsented: true,
          notificationsEnabled: false,
        ),
      );
      expect(snap.state, ScreenTranslatePermissionState.ready);
      expect(snap.notificationsBlocked, isTrue);
      expect(
        snap.action,
        ScreenTranslateRecoveryAction.openNotificationSettings,
      );
    });

    test('có thông báo ⇒ không cảnh báo', () {
      final snap = resolver.resolve(
        status(running: true, captureConsented: true),
      );
      expect(snap.notificationsBlocked, isFalse);
      expect(snap.action, ScreenTranslateRecoveryAction.none);
    });

    test('blockedBySystem + blockReason đi xuyên suốt để UI nói đúng chuyện',
        () {
      final snap = resolver.resolve(
        status(running: true, blockedBySystem: true, blockReason: 'consent_blocked'),
      );
      expect(snap.blockedBySystem, isTrue);
      expect(snap.status.blockReason, 'consent_blocked');
    });
  });

  group('Android 14 (API 34) — consent mỗi phiên', () {
    test('sdk 34 ⇒ requiresConsentEachSession', () {
      final snap = resolver.resolve(status(sdkInt: 34));
      expect(snap.requiresConsentEachSession, isTrue);
    });

    test('sdk 35 (Android 15) ⇒ vẫn mỗi phiên', () {
      final snap = resolver.resolve(status(sdkInt: 35));
      expect(snap.requiresConsentEachSession, isTrue);
    });

    test('sdk 33 (Android 13) ⇒ không áp dụng', () {
      final snap = resolver.resolve(status(sdkInt: 33));
      expect(snap.requiresConsentEachSession, isFalse);
    });

    test('hằng số mốc khớp tài liệu Android (API 34)', () {
      expect(ScreenTranslatePermissionResolver.kConsentPerSessionSdk, 34);
    });
  });

  group('ScreenTranslateNativeStatus — giao thức với Kotlin', () {
    test('toMap dùng ĐÚNG bộ khoá mà Kotlin gửi sang', () {
      final map = status().toMap();
      expect(map.keys.toSet(), ScreenTranslateNativeStatus.wireKeys);
    });

    test('fromMap đọc đủ 9 khoá của statusMap()', () {
      final restored = ScreenTranslateNativeStatus.fromMap(<Object?, Object?>{
        'supported': true,
        'overlayGranted': true,
        'running': true,
        'captureConsented': true,
        'consentDenied': false,
        'notificationsEnabled': false,
        'blockedBySystem': true,
        'blockReason': 'overlay',
        'sdkInt': 34,
      });
      expect(restored.supported, isTrue);
      expect(restored.running, isTrue);
      expect(restored.captureConsented, isTrue);
      expect(restored.consentDenied, isFalse);
      expect(restored.notificationsEnabled, isFalse);
      expect(restored.blockedBySystem, isTrue);
      expect(restored.blockReason, 'overlay');
      expect(restored.sdkInt, 34);
    });

    test('round-trip toMap → fromMap giữ nguyên', () {
      final original = status(
        running: true,
        captureConsented: true,
        notificationsEnabled: false,
        blockedBySystem: true,
        blockReason: 'consent_blocked',
        sdkInt: 35,
      );
      final restored = ScreenTranslateNativeStatus.fromMap(original.toMap());
      expect(restored.toMap(), original.toMap());
    });

    test('map rỗng / native cũ thiếu khoá ⇒ quy về mặc định an toàn', () {
      // Sai tên khoá ở Kotlin là rớt im lặng về supported=false — test này
      // khoá hành vi "không ném, không crash".
      final empty = ScreenTranslateNativeStatus.fromMap(<Object?, Object?>{});
      expect(empty.supported, isFalse);
      expect(empty.running, isFalse);
      expect(empty.captureConsented, isFalse);
      expect(empty.notificationsEnabled, isTrue);
      expect(empty.sdkInt, 0);
      expect(resolver.resolve(empty).state,
          ScreenTranslatePermissionState.unsupported);
    });

    test('kiểu lạ (String/num thay vì bool) ⇒ không ném', () {
      final weird = ScreenTranslateNativeStatus.fromMap(<Object?, Object?>{
        'supported': 'true',
        'running': 1,
        'captureConsented': 0,
        'notificationsEnabled': 'yes',
        'sdkInt': '34',
      });
      expect(weird.supported, isTrue);
      expect(weird.running, isTrue);
      expect(weird.captureConsented, isFalse);
      // Chuỗi lạ cho notificationsEnabled ⇒ coi là BẬT (mặc định an toàn).
      expect(weird.notificationsEnabled, isTrue);
      expect(weird.sdkInt, 0);
    });

    test('fallback = chưa hỗ trợ (dùng khi native chưa đăng ký method)', () {
      expect(ScreenTranslateNativeStatus.fallback.supported, isFalse);
      expect(ScreenTranslateNativeStatus.fallback.notificationsEnabled, isTrue);
    });
  });

  group('ScreenTranslateChannel — tên method mới + host VM', () {
    test('method status / requestConsent khớp với Kotlin', () {
      expect(ScreenTranslateProtocol.methodStatus, 'status');
      expect(ScreenTranslateProtocol.methodRequestConsent, 'requestConsent');
    });

    test('host VM (không Android): status() trả fallback, không ném', () async {
      final channel = ScreenTranslateChannel(
        channel: const MethodChannel('in4up/screentranslate/test-unused'),
      );
      expect(ScreenTranslateChannel.platformSupported, isFalse);
      final snap = await channel.status();
      expect(snap.supported, isFalse);
      expect(
        ScreenTranslatePermissionResolver()
            .resolve(snap)
            .state,
        ScreenTranslatePermissionState.unsupported,
      );
      expect(await channel.requestConsent(), isFalse);
    });
  });
}
