import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/i4u_shell_contracts.dart';

void main() {
  test('source fingerprint round-trips its handoff context', () {
    final source = I4uSourceFingerprint(
      sourceType: I4uSourceType.video,
      sourceId: 'video-1',
      sourceRevision: 'r2',
      timestampMs: 84000,
      selectedText: 'tri giác',
      locale: 'vi',
      returnPath: '/listen/video-1',
      createdAt: DateTime.utc(2026, 10, 4),
    );

    final restored = I4uSourceFingerprint.fromJson(source.toJson());
    expect(restored.sourceType, I4uSourceType.video);
    expect(restored.sourceId, 'video-1');
    expect(restored.timestampMs, 84000);
    expect(restored.returnPath, '/listen/video-1');
  });

  test('anchor clamps an invalid viewport ratio and tolerates old data', () {
    final anchor = I4uSemanticReadingAnchor.fromJson({
      'sourceId': 'book-1',
      'blockId': 'para_014',
      'characterOffset': 128,
      'viewportRelativeRatio': 4,
    });

    expect(anchor.sourceRevision, isNull);
    expect(anchor.characterOffset, 128);
    expect(anchor.viewportRelativeRatio, 1.0);
  });

  test('unknown source type falls back safely', () {
    final source = I4uSourceFingerprint.fromJson({
      'sourceType': 'future-type',
      'sourceId': 'source-1',
    });

    expect(source.sourceType, I4uSourceType.document);
    expect(source.returnPath, '/');
  });
}
