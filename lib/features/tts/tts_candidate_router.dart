import 'tts_settings.dart';

/// Returns enabled engines in the effective fallback order.
///
/// A voice explicitly picked from the Edge catalogue is also an explicit
/// engine preference: try Edge before the offline fallback even when the
/// overall mode is `offlineFirst`. `offlineOnly` remains authoritative and
/// never returns an online engine.
List<TtsEngineInfo> orderTtsCandidates({
  required Iterable<TtsEngineInfo> engines,
  required TtsPriority priority,
  String? preferredEngineId,
  String? readerEngineId,
}) {
  final enabled = engines.where((engine) => engine.isEnabled).toList()
    ..sort((a, b) => a.priority.compareTo(b.priority));

  final List<TtsEngineInfo> ordered = switch (priority) {
    TtsPriority.offlineFirst => [
        ...enabled.where((engine) => !engine.isOnline),
        ...enabled.where((engine) => engine.isOnline),
      ],
    TtsPriority.onlineFirst || TtsPriority.onlineOnly => [
        ...enabled.where((engine) => engine.isOnline),
        ...enabled.where((engine) => !engine.isOnline),
      ],
    // `auto` đã được `TtsService` RESOLVE thành onlineFirst/offlineFirst theo
    // loại mạng TRƯỚC khi tới đây (xem `_resolveAutoPriority`). Rớt tới nhánh
    // này nghĩa là caller quên resolve ⇒ xử như `offlineFirst` (an toàn: không
    // đốt data di động) nhưng VẪN giữ online ở cuối làm dự phòng.
    TtsPriority.auto => [
        ...enabled.where((engine) => !engine.isOnline),
        ...enabled.where((engine) => engine.isOnline),
      ],
    TtsPriority.offlineOnly =>
      enabled.where((engine) => !engine.isOnline).toList(),
  };

  // Promote within the allowed set only. If the local choice cannot play,
  // continue with exactly the common route (including a pinned Edge voice).
  for (final id in [preferredEngineId, readerEngineId]) {
    final index = ordered.indexWhere((engine) => engine.id == id);
    if (index > 0) ordered.insert(0, ordered.removeAt(index));
  }
  return ordered;
}

/// An unavailable/failed candidate is not a settings change. Stop at the first
/// successful playback, and never start a fallback after cancellation.
Future<bool> playFirstAvailable(Iterable<TtsEngineInfo> candidates, {
  required bool Function() cancelled,
  required Future<bool> Function(TtsEngineInfo) play,
}) async {
  for (final candidate in candidates) {
    if (cancelled()) break;
    if (await play(candidate)) return true;
  }
  return false;
}
