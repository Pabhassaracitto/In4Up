import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';

AiProviderConfig provider(String id, {String? model}) => AiProviderConfig(
      id: id,
      label: id.toUpperCase(),
      baseUrl: 'https://example.invalid/v1',
      chatModel: model ?? 'm',
    );

void main() {
  test('kéo thả giữ đủ provider, bỏ id lạ/trùng', () {
    final list = [provider('a'), provider('b'), provider('c')];
    final reordered = reorderAiProviders(list, ['c', 'a', 'ghost', 'c']);
    expect(reordered.map((p) => p.id), ['c', 'a', 'b']);

    final unknown = reorderAiProviders(list, const []);
    expect(unknown.map((p) => p.id), ['a', 'b', 'c']);
  });

  test('thứ tự ưu tiên đi cùng routing JSON (đồng bộ)', () {
    final routing = AiRoutingPrefs(providerOrder: const ['b', 'a']);
    final decoded = AiRoutingPrefs.fromJson(routing.toJson());
    expect(decoded.providerOrder, ['b', 'a']);
    expect(
      decoded.copyWith(providerOrder: const ['a']).providerOrder,
      ['a'],
    );
  });

  test('merge cloud không làm mất thứ tự đã kéo', () {
    final local = AiSettingsSnapshot(
      providers: [provider('a'), provider('b')],
      routing: const AiRoutingPrefs(providerOrder: ['b', 'a']),
      updatedAtMs: 100,
    );
    final remote = AiSettingsSnapshot(
      providers: [provider('a'), provider('b')],
      routing: AiRoutingPrefs(providerOrder: const []),
      updatedAtMs: 200,
    );
    final merged = mergeAiSettings(local: local, remote: remote).merged;
    expect(merged.providers.map((p) => p.id), ['b', 'a']);
    expect(merged.routing.providerOrder, ['b', 'a']);
  });

  test('fallback làm lạnh provider lỗi, có trần số lần thử', () {
    final tracker = AiProviderFallbackTracker(cooldownMs: 1000);
    tracker.markFailed('p1', nowMs: 1000);
    expect(tracker.isCooling('p1', nowMs: 1500), isTrue);
    expect(tracker.isCooling('p1', nowMs: 2200), isFalse);
    expect(tracker.coolingIds(nowMs: 1500), {'p1'});
    tracker.clear('p1');
    expect(tracker.coolingIds(nowMs: 1500), isEmpty);
    expect(tracker.attemptsPerRequest, 3);
  });
}
