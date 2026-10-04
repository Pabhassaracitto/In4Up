/// Repeat counts for learn-by-heart playback.
///
/// [itemRepeatCount] `0` = loop the current range forever (whole verse or
/// selected chunk). Line repeats are always finite (`1…999`).
class RecitationRepeat {
  RecitationRepeat._();

  static int clampItem(int count) => count < 0 ? 0 : count;

  static int clampLine(int count) => count.clamp(1, 999);

  static int forLine(
    int line, {
    required int defaultCount,
    required Map<int, int> overrides,
  }) =>
      clampLine(overrides[line] ?? defaultCount);

  /// After finishing [completedPasses] (1-based), should another pass run?
  static bool anotherItemPass(int completedPasses, int itemRepeatCount) {
    if (itemRepeatCount == 0) return true;
    return completedPasses < itemRepeatCount;
  }

  static String itemLabel(int count, {int current = 0}) {
    final total = count == 0 ? '∞' : '$count×';
    if (current > 0) return '$current/$total';
    return total;
  }

  static String lineLabel(int count, {int current = 0}) {
    if (current > 0) return '$current/$count';
    return '$count×';
  }
}
