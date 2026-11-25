import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ui = File('lib/features/cabin/screens/live_cabin_screen.dart').readAsStringSync();
  final english = jsonDecode(File('tool/legacy_ui_english_overrides.json').readAsStringSync()) as Map<String, dynamic>;
  final pack = jsonDecode(File('tool/priority_native_pack.json').readAsStringSync()) as Map<String, dynamic>;
  const labels = [
    'Micro', 'Âm thanh hệ thống', 'Bong bóng toàn hệ thống',
    'Phát âm thanh trên thiết bị để bắt đầu dịch...',
    'Không thu được âm thanh hệ thống', 'Cần cấp quyền micro để thu âm thanh hệ thống',
    'Cần Android 10 trở lên', 'Cấp quyền hiển thị trên ứng dụng khác',
    'Mở cài đặt rồi cho phép In4Up hiển thị trên ứng dụng khác.',
    'Một số ứng dụng có thể chặn thu âm. Khi đọc bản dịch, nhận diện và ghi âm nguồn tạm dừng.',
  ];
  test('source selector, overlay and feedback warning are present', () {
    for (final label in labels) {
      expect(ui, contains(label));
    }
    expect(ui, contains('_ensureOverlayPermission()'));
    expect(ui, contains('_service.isStartingSystemAudio'));
  });
  test('new labels have English fallback and priority locale translations', () {
    for (final label in labels) {
      expect(english[label], isA<String>(), reason: label);
      final translations = pack[label] as Map<String, dynamic>;
      for (final locale in ['en', 'hi', 'zh', 'zh_TW', 'si', 'my', 'th', 'ja']) {
        expect(translations[locale], isA<String>(), reason: '$label: $locale');
        expect((translations[locale] as String).trim(), isNotEmpty);
      }
    }
  });
}
