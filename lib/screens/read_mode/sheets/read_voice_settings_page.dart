// lib/screens/read_mode/sheets/read_voice_settings_page.dart
//
// PSRC-236 / ADR-0030 D2 — trang «Giọng đọc & engine».
//
// Trước đây `TtsSettingsSection` (thứ tự engine, giọng theo ngôn ngữ, import
// model VieNeu, tạo giọng, cache, giấy phép) bị nhúng nguyên khối vào CUỐI
// bảng «Cài đặt Text Studio» ⇒ một trang cuộn rất dài, và thứ chỉnh MỘT LẦN
// nằm chung cột với thứ chỉnh hằng ngày (cỡ chữ, màu, IPA).
//
// Nay là một trang riêng, mở bằng một dòng trong Cài đặt. Không đổi nội dung,
// không tạo state mới: vẫn đúng widget `TtsSettingsSection` đọc/ghi
// `TtsService`. Trang có `Scaffold` riêng ⇒ SnackBar của các thao tác import
// hiện NGAY trên trang (trước đây nằm dưới bottom sheet).

import 'package:in4up/core/language/localized_material.dart';

import '../../../features/tts/widgets/tts_settings_section.dart';

class ReadVoiceSettingsPage extends StatelessWidget {
  const ReadVoiceSettingsPage({super.key});

  /// Mở trang đè lên bảng Cài đặt; nút quay lại trả về đúng bảng đó.
  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ReadVoiceSettingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          context.uiText('Giọng đọc & engine'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          key: Key('read-voice-settings-scroll'),
          padding: EdgeInsets.all(20),
          child: TtsSettingsSection(
            primaryColor: Color(0xFF6C63FF),
          ),
        ),
      ),
    );
  }
}
