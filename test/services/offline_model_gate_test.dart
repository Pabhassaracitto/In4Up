// AUDIT-1.21.0 #2 + #7 (cụm model/offline) — chặn native khi model chưa nạp.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/offline_model_gate.dart';

void main() {
  group('asrFilesPlausible', () {
    test('model thật vượt ngưỡng', () {
      expect(
        asrFilesPlausible(
          encoderBytes: 32 * 1024 * 1024,
          decoderBytes: 2 * 1024 * 1024,
          joinerBytes: 2 * 1024 * 1024,
          tokensBytes: 256 * 1024,
        ),
        isTrue,
      );
    });
    test('bản import dở (encoder 2KB) bị loại', () {
      expect(
        asrFilesPlausible(
          encoderBytes: 2048,
          decoderBytes: 2048,
          joinerBytes: 2048,
          tokensBytes: 2048,
        ),
        isFalse,
      );
    });
    test('thiếu tokens / file rỗng bị loại', () {
      expect(
        asrFilesPlausible(
          encoderBytes: 8 * 1024 * 1024,
          decoderBytes: 8 * 1024 * 1024,
          joinerBytes: 8 * 1024 * 1024,
          tokensBytes: 0,
        ),
        isFalse,
      );
    });
  });

  group('assessOfflineModel', () {
    test('chưa cài model', () {
      final v = assessOfflineModel(
          installed: false, filesPlausible: false, needsOffline: true);
      expect(v.canUse, isFalse);
      expect(v.issue, OfflineModelIssue.notInstalled);
    });
    test('file có nhưng cụt ⇒ incompleteFiles', () {
      final v = assessOfflineModel(
          installed: true, filesPlausible: false, needsOffline: true);
      expect(v.issue, OfflineModelIssue.incompleteFiles);
      expect(v.technicalMessage, contains('truncated'));
    });
    test('model streaming vào OfflineRecognizer ⇒ chặn SIGABRT', () {
      final v = assessOfflineModel(
        installed: true,
        filesPlausible: true,
        isStreaming: true,
        needsOffline: true,
      );
      expect(v.issue, OfflineModelIssue.streamingOnly);
    });
    test('model streaming vẫn dùng được cho live online', () {
      final v = assessOfflineModel(
        installed: true,
        filesPlausible: true,
        isStreaming: true,
        needsOffline: false,
      );
      expect(v.canUse, isTrue);
    });
    test('Piper thiếu espeak-ng-data ⇒ không khả dụng', () {
      final v = assessOfflineModel(installed: false, filesPlausible: true);
      expect(v.issue, OfflineModelIssue.notInstalled);
    });
    test('đủ điều kiện ⇒ canUse', () {
      final v = assessOfflineModel(
          installed: true, filesPlausible: true, needsOffline: true);
      expect(v.canUse, isTrue);
      expect(v.issue, OfflineModelIssue.none);
    });
  });
}
