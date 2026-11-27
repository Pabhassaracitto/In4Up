// lib/features/tts/voice_catalog_grouping.dart
//
// AUDIT v1.30.1 (mục 5) — «Tab đọc: danh sách giọng Microsoft Edge chiếm nhiều
// chỗ ⇒ cho thu gọn/bung».
//
// `ReaderVoiceTile` đổ TOÀN BỘ `readerVoiceCatalog` vào một `SimpleDialog`
// phẳng: Edge có 35 giọng / 17 ngôn ngữ (cộng thêm danh sách live tải về có
// thể nhiều hơn) ⇒ hộp thoại dài hơn màn hình, người dùng phải cuộn mù để tìm
// đúng một giọng tiếng Nhật.
//
// File này là phần THUẦN DỮ LIỆU của việc gom nhóm: nhóm theo ngôn ngữ, đếm
// số giọng mỗi nhóm, và quyết định nhóm nào mở sẵn (nhóm đang chọn + nhóm có
// ít giọng). Tách khỏi widget để test trên host VM — widget kia import plugin
// TTS nên không chạy được ở đó.

import 'engines/tts_engine.dart' show TtsVoice;

/// Một nhóm giọng cùng ngôn ngữ (dùng cho danh sách thu gọn).
class VoiceLanguageGroup {
  /// Mã ngôn ngữ như engine trả về (`vi-VN`, `en-US`…). Dòng «mặc định» của
  /// engine có thể rỗng ⇒ giữ nguyên chuỗi rỗng để không trộn vào nhóm khác.
  final String language;

  /// Giọng thuộc nhóm, giữ nguyên thứ tự engine trả về.
  final List<TtsVoice> voices;

  const VoiceLanguageGroup({required this.language, required this.voices});

  int get count => voices.length;

  /// Nhãn hiển thị: `vi-VN` → `VI`; rỗng → `—`.
  String get shortLabel {
    final value = language.trim();
    if (value.isEmpty) return '—';
    return value.split(RegExp('[-_]')).first.toUpperCase();
  }

  /// Nhãn phụ (tên ngôn ngữ tiếng Anh nếu engine có gắn trong tên giọng —
  /// không đoán bừa, chỉ trả về `null` để UI tự quyết định).
  String? get displayLanguage => language.trim().isEmpty ? null : language;
}

/// Gom danh sách giọng theo ngôn ngữ, giữ thứ tự xuất hiện ĐẦU TIÊN.
///
/// Vì sao không `groupBy` rồi sort theo bảng chữ cái: thứ tự của engine đã là
/// thứ tự "dùng nhiều trước" (Edge xếp en-US, vi-VN đầu tiên). Sort lại sẽ đẩy
/// tiếng Ả Rập lên trước mặt người học tiếng Anh.
List<VoiceLanguageGroup> groupVoicesByLanguage(Iterable<TtsVoice> voices) {
  final order = <String>[];
  final buckets = <String, List<TtsVoice>>{};
  for (final voice in voices) {
    final key = voice.language.trim();
    var bucket = buckets[key];
    if (bucket == null) {
      bucket = <TtsVoice>[];
      buckets[key] = bucket;
      order.add(key);
    }
    bucket.add(voice);
  }
  return [
    for (final key in order)
      VoiceLanguageGroup(
        language: key,
        voices: List<TtsVoice>.unmodifiable(buckets[key]!),
      ),
  ];
}

/// Nhóm nào nên MỞ SẴN khi mở bảng chọn.
///
/// Mục tiêu: mở ra là thấy ngay lựa chọn đang dùng (để đổi sang giọng khác
/// cùng ngôn ngữ), cộng tối đa [maxOpenGroups] nhóm — nhóm ít giọng trước, vì
/// nhóm 1–2 giọng không đáng thêm một lần chạm.
///
/// [selectedVoiceId] là `pref.voice`; null/rỗng ⇒ không có nhóm "đang chọn".
Set<String> defaultExpandedVoiceGroups(
  List<VoiceLanguageGroup> groups, {
  String? selectedVoiceId,
  int maxOpenGroups = 2,
}) {
  final opened = <String>{};
  final selected = selectedVoiceId?.trim() ?? '';
  if (selected.isNotEmpty) {
    for (final group in groups) {
      if (group.voices.any((voice) => voice.id == selected)) {
        opened.add(group.language);
        break;
      }
    }
  }
  if (opened.length >= maxOpenGroups) return opened;
  final bySize = [...groups]
    ..sort((a, b) => a.count.compareTo(b.count));
  for (final group in bySize) {
    if (opened.length >= maxOpenGroups) break;
    // Nhóm rỗng/một giọng vẫn đáng mở (một lần chạm ít hơn), nhưng nhóm quá
    // lớn (>= 6 giọng) thì để người dùng chủ động mở.
    if (group.count > 6) continue;
    opened.add(group.language);
  }
  return opened;
}
