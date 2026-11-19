// test/tts/psrc245_engine_order_merge_test.dart
//
// PSRC-245 — VieNeu-TTS bị xếp CUỐI chuỗi engine với prefs cũ.
//
// Hợp đồng: engine MỚI phải được chèn theo mức ưu tiên MẶC ĐỊNH, không phải
// nối xuống cuối; thứ tự tương đối người dùng đã sắp phải giữ nguyên.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tts/tts_engine_order_merge.dart';
import 'package:in4up/features/tts/tts_settings.dart';

List<TtsEngineInfo> _defaults() => const [
      TtsEngineInfo(id: 'vieneu_tts', name: 'VieNeu', description: '', isOnline: false, priority: 0),
      TtsEngineInfo(id: 'piper_tts', name: 'Piper', description: '', isOnline: false, priority: 1),
      TtsEngineInfo(id: 'offline_tts', name: 'Máy', description: '', isOnline: false, priority: 2),
      TtsEngineInfo(id: 'edge_tts', name: 'Edge', description: '', priority: 3),
      TtsEngineInfo(id: 'google_tts', name: 'Google', description: '', priority: 4),
    ];

List<String> _ids(List<TtsEngineInfo> engines) =>
    engines.map((e) => e.id).toList(growable: false);

void main() {
  group('mergePersistedEngineOrder', () {
    test('prefs cũ KHÔNG có vieneu (≤1.28) ⇒ vieneu đứng ĐẦU, không nối cuối',
        () {
      final merged = mergePersistedEngineOrder(
        defaults: _defaults(),
        persistedIds: const ['piper_tts', 'offline_tts', 'edge_tts'],
        persistedEnabled: const {'piper_tts': true, 'offline_tts': true},
      );
      expect(_ids(merged), [
        'vieneu_tts',
        'piper_tts',
        'offline_tts',
        'edge_tts',
        'google_tts',
      ]);
      // priority phải liên tục 0..n-1 theo đúng thứ tự trả về.
      for (var i = 0; i < merged.length; i++) {
        expect(merged[i].priority, i, reason: 'priority lệch ở ${merged[i].id}');
      }
    });

    test('giữ thứ tự tương đối người dùng đã sắp (offline trước piper)', () {
      final merged = mergePersistedEngineOrder(
        defaults: _defaults(),
        persistedIds: const ['offline_tts', 'piper_tts'],
        persistedEnabled: const {'offline_tts': true},
      );
      // vieneu (0) vẫn chen lên trước; offline/piper giữ đúng thứ tự cũ.
      expect(_ids(merged).take(3).toList(), [
        'vieneu_tts',
        'offline_tts',
        'piper_tts',
      ]);
    });

    test('engine online mới (edge) KHÔNG chen lên trước engine offline đang có',
        () {
      final merged = mergePersistedEngineOrder(
        defaults: _defaults(),
        persistedIds: const ['vieneu_tts', 'piper_tts', 'offline_tts'],
        persistedEnabled: const {},
      );
      expect(_ids(merged).take(3).toList(), [
        'vieneu_tts',
        'piper_tts',
        'offline_tts',
      ]);
      expect(_ids(merged).last, 'google_tts');
    });

    test('giữ trạng thái bật/tắt đã lưu của engine cũ', () {
      final merged = mergePersistedEngineOrder(
        defaults: _defaults(),
        persistedIds: const ['piper_tts', 'offline_tts'],
        persistedEnabled: const {'piper_tts': false},
      );
      final byId = {for (final e in merged) e.id: e};
      expect(byId['piper_tts']!.isEnabled, isFalse);
      expect(byId['offline_tts']!.isEnabled, isTrue);
    });

    test('di trú: prefs đã lưu vieneu ở CUỐI (bản lỗi) ⇒ chèn lại theo mặc định',
        () {
      final merged = mergePersistedEngineOrder(
        defaults: _defaults(),
        persistedIds: const ['piper_tts', 'offline_tts', 'edge_tts', 'vieneu_tts'],
        persistedEnabled: const {'vieneu_tts': true},
        reinsertAsNew: kEngineOrderReinsertOnMigration,
      );
      expect(_ids(merged).first, 'vieneu_tts');
      expect(merged.first.isEnabled, isTrue);
    });

    test('bỏ id lạ và id trùng trong prefs, không làm mất engine mặc định', () {
      final merged = mergePersistedEngineOrder(
        defaults: _defaults(),
        persistedIds: const ['khong_ton_tai', 'piper_tts', 'piper_tts'],
        persistedEnabled: const {},
      );
      expect(_ids(merged).contains('khong_ton_tai'), isFalse);
      expect(_ids(merged).where((id) => id == 'piper_tts').length, 1);
      expect(merged.length, _defaults().length);
    });
  });
}
