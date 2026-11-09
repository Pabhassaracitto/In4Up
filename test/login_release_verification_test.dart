// IN4-15 (LOGIN-CRASH-002) — đăng nhập release vẫn văng app.
//
// Bối cảnh (đã xác minh trong repo, KHÔNG phải suy đoán):
// - Debug build của owner là `com.in4up.dev` (flavor `dev`) và ĐÃ đăng nhập
//   được (avatar hiện) — nên KHÔNG thể dùng kết quả debug để kết luận
//   release cũng được.
// - Keystore release `in4up-release.jks` có SHA-1
//   88d5ee0da168b320c52f51b7aab404675862e5b0 (đã thêm vào Firebase Console).
// - Bản google-services.json FALLBACK trong CI chỉ khai báo hash cũ
//   8a1bc02e… ⇒ nếu secret CI thiếu/sai, APK release được ký bằng key có
//   SHA-1 mà Firebase KHÔNG biết ⇒ Google Sign-In trả DEVELOPER_ERROR ⇒
//   nút đăng nhập văng app, còn mọi thứ khác vẫn chạy.
//
// Fix bên code (agent làm được):
//  1. CI gate: SHA-1 keystore ký phải CÓ trong google-services.json, lệch
//     ⇒ fail build (script android_verify_signing_matches_google_services.sh).
//  2. Fallback JSON trong CI thêm SHA-1 release HIỆN TẠI (88d5ee0d…).
//  3. App log trạng thái auth + flavor lúc khởi động và mỗi lần trạng thái
//     đổi ⇒ logcat trả lời ngay "bản nào / phiên khôi phục chưa / lỗi ở
//     bước nào", tách bạch đăng nhập MỚI với khôi phục phiên.
//
// Test thuần pin các ràng buộc cấu trúc này.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File('.github/workflows/build_final_complete.yml')
      .readAsStringSync();
  final auth = File('lib/services/auth_service.dart').readAsStringSync();
  final main = File('lib/main.dart').readAsStringSync();
  final script = File(
          'scripts/ci/android_verify_signing_matches_google_services.sh')
      .readAsStringSync();

  group('IN4-15 — CI gate: SHA-1 ký phải khớp google-services.json', () {
    test('script tồn tại + so khớp SHA-1 keystore với certificate_hash', () {
      expect(script.contains('keytool'), isTrue,
          reason: 'Phải đọc SHA-1 từ keystore thật.');
      expect(script.contains('certificate_hash'), isTrue);
      expect(script.contains('88d5ee0d') || script.contains('KEY_SHA1'), isTrue);
      // Lệch ⇒ FAIL (không chỉ warning).
      expect(script.contains('exit 1'), isTrue);
    });

    test('workflow có gọi gate sau khi chuẩn bị signing', () {
      expect(
        workflow.contains('android_verify_signing_matches_google_services.sh'),
        isTrue,
      );
      final prep = workflow.indexOf('android_prepare_signing.sh');
      final gate = workflow.indexOf(
          'android_verify_signing_matches_google_services.sh');
      expect(prep, greaterThan(0));
      expect(gate, greaterThan(prep),
          reason: 'Gate phải chạy SAU khi đã có keystore + google-services.');
    });

    test('fallback google-services.json trong CI có SHA-1 release HIỆN TẠI', () {
      expect(
        workflow.contains('88d5ee0da168b320c52f51b7aab404675862e5b0'),
        isTrue,
        reason: 'Fallback JSON phải chứa SHA-1 keystore release đang dùng '
            '(nếu không, secret thiếu ⇒ build ra APK không đăng nhập được).',
      );
    });
  });

  group('IN4-15 — tự sửa JSON khi secret CI là bản CŨ', () {
    test('script sửa tồn tại + lấy SHA-1 từ keystore (không hard-code)', () {
      final fix = File(
              'scripts/ci/android_ensure_signing_sha1_in_google_services.sh')
          .readAsStringSync();
      expect(fix.contains('keytool'), isTrue,
          reason: 'SHA-1 phải lấy TỪ keystore CI đang ký, không hard-code.');
      expect(fix.contains('certificate_hash'), isTrue);
      expect(fix.contains('com.in4up'), isTrue);
      // Không được hard-code một SHA-1 cụ thể (sẽ hỏng khi rotate key).
      expect(fix.contains('88d5ee0d'), isFalse,
          reason: 'SHA-1 phải tính động từ keystore, không ghi cứng.');
    });

    test('workflow gọi bước sửa TRƯỚC gate verify', () {
      final fixIdx = workflow.indexOf(
          'android_ensure_signing_sha1_in_google_services.sh');
      final gateIdx = workflow.indexOf(
          'android_verify_signing_matches_google_services.sh');
      expect(fixIdx, greaterThan(0));
      expect(gateIdx, greaterThan(fixIdx),
          reason: 'Sửa JSON phải chạy trước gate verify (gate kiểm kết quả).');
    });

    test('bước sửa đồng bộ lại bản copy theo flavor (Gradle ưu tiên flavor)',
        () {
      final fix = File(
              'scripts/ci/android_ensure_signing_sha1_in_google_services.sh')
          .readAsStringSync();
      expect(fix.contains('android/app/src/'), isTrue,
          reason: 'Phải copy lại JSON đã sửa sang src/<flavor>/ — nếu không, '
              'Gradle vẫn dùng bản JSON CŨ ở flavor dir ⇒ sửa vô ích.');
    });

    test('cả 2 script phải BỎ DẤU ":" khi so khớp SHA-1', () {
      // keytool in SHA-1 dạng `88:D5:EE:0D:…` (CÓ dấu ':'), còn
      // `certificate_hash` trong google-services.json lưu KHÔNG dấu ':'.
      // Không bỏ dấu ':' ⇒ gate LUÔN fail dù JSON đã có đúng hash.
      final fix = File(
              'scripts/ci/android_ensure_signing_sha1_in_google_services.sh')
          .readAsStringSync();
      for (final s in [script, fix]) {
        expect(s.contains("tr -d ':'"), isTrue,
            reason: 'Phải chuẩn hoá SHA-1 (bỏ dấu ":") trước khi so khớp '
                'với certificate_hash trong google-services.json.');
      }
    });
  });

  group('IN4-15 — chẩn đoán runtime (biết đúng bản nào + trạng thái phiên)',
      () {
    test('AuthService có logAuthState in flavor + signedIn + uid', () {
      expect(auth.contains('Future<void> logAuthState('), isTrue);
      expect(auth.contains('[in4up-auth] STATE['), isTrue);
      expect(auth.contains('flavor='), isTrue);
      expect(auth.contains('signedIn='), isTrue);
    });

    test('main.dart gọi logAuthState lúc khởi động + theo dõi thay đổi', () {
      expect(main.contains("logAuthState('startup')"), isTrue);
      expect(main.contains('authStateChanges.listen('), isTrue,
          reason: 'Phải log khi phiên được khôi phục (không chỉ lúc start).');
    });

    test('không được coi avatar debug là bằng chứng release (có ghi rõ appId)',
        () {
      // KANBAN + issue đều yêu cầu phân biệt applicationId.
      expect(auth.contains("'com.in4up'") || main.contains('FLAVOR'), isTrue,
          reason: 'Phải có thông tin flavor/applicationId trong log.');
    });
  });
}
