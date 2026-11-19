/// Stable ids of the engines already shipped with the app. This is a routing
/// preference, not a provider registry: unknown/removed ids never create engines.
const translationEngineDefaultPriority = <String>[
  'deeplx',
  'google_free',
  'mymemory',
  'libre',
  'hymt',
  'mlkit',
  'llm_mt',
];

List<String> normalizeTranslationEnginePriority(Iterable<String> saved) =>
    List<String>.unmodifiable(<String>{
      ...saved.where(translationEngineDefaultPriority.contains),
      ...translationEngineDefaultPriority,
    });

/// Dictionary translation remains a last resort, never a sentence engine that
/// can accidentally be dragged ahead of Google / on-device sentence models.
List<T> orderTranslationEngines<T>(
  Iterable<T> engines,
  List<String>? priority, {
  required String Function(T) idOf,
}) {
  final remaining = engines.toList();
  if (priority == null) return remaining;
  final ordered = <T>[];
  for (final id in priority) {
    final index = remaining.indexWhere((engine) => idOf(engine) == id);
    if (index >= 0) ordered.add(remaining.removeAt(index));
  }
  // Injected/test engines and future registered engines retain their order.
  return ordered..addAll(remaining);
}
