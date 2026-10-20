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
    TtsPriority.offlineOnly =>
      enabled.where((engine) => !engine.isOnline).toList(),
  };

  if (priority == TtsPriority.offlineOnly || preferredEngineId == null) {
    return ordered;
  }

  final preferred = enabled.where((engine) => engine.id == preferredEngineId);
  if (preferred.isEmpty) return ordered;
  final selected = preferred.first;
  return [
    selected,
    ...ordered.where((engine) => engine.id != selected.id),
  ];
}
