// lib/features/iconize/iconize_service.dart
//
// ICONIZE-001d — vòng đời engine Iconize cho tầng UI (blueprint mục 3.8).
//
// Singleton ChangeNotifier:
//  - Nạp LƯỜI: chỉ load asset khi user bật toggle lần đầu (không trả chi
//    phí 1.6MB parse cho người không dùng tính năng).
//  - Asset hỏng (magic sai/corrupt) → status = disabled CHO CẢ SESSION +
//    UI hiện badge "tạm tắt do lỗi dữ liệu"; KHÔNG retry loop, KHÔNG crash.
//  - Giữ adapter VocabImageIconSource sống cùng engine; nội dung ảnh user
//    được làm mới qua [refreshVocabIcons] (gọi khi bật toggle / đổi vocab).
//
// Engine vẫn pure function — service này chỉ là chỗ ĐỨNG của nó trong app
// (ephemeral render layer, không ghi gì vào TranslationCache/Hive).

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/word_entry.dart';
import '../translation/data/offline_dictionary.dart';
import 'data/iconize_assets.dart';
import 'data/iconize_binary.dart';
import 'data/vocab_icon_source.dart';
import 'engine/iconize_bridge.dart';
import 'engine/iconize_engine.dart';
import 'engine/iconize_lang_guess.dart';
import 'models/iconize_span.dart';

enum IconizeEngineStatus {
  /// Chưa từng được yêu cầu — toggle chưa bật lần nào trong session.
  idle,

  /// Đang nạp asset (lần bật đầu tiên).
  loading,

  /// Engine sẵn sàng.
  ready,

  /// Asset hỏng — tắt cho cả session (blueprint 3.8), badge ở UI.
  disabled,
}

class IconizeService extends ChangeNotifier {
  static final IconizeService _instance = IconizeService._();

  factory IconizeService() => _instance;

  IconizeService._();

  IconizeEngineStatus _status = IconizeEngineStatus.idle;
  DefaultIconizeEngine? _engine;
  final VocabImageIconSource _vocabSource = VocabImageIconSource();
  Future<void>? _loading;

  IconizeEngineStatus get status => _status;
  bool get isReady => _status == IconizeEngineStatus.ready;
  bool get isDisabled => _status == IconizeEngineStatus.disabled;

  /// Bundle icon cho tầng render (tra "bundle:<tên>" → bytes SVG).
  IconsBundle? get iconsBundle => _engine?.iconsBundle;

  /// Nạp engine nếu chưa — idempotent, gọi thoải mái từ UI.
  Future<void> ensureLoaded() {
    if (_status == IconizeEngineStatus.ready ||
        _status == IconizeEngineStatus.disabled) {
      return Future.value();
    }
    return _loading ??= _load();
  }

  Future<void> _load() async {
    _status = IconizeEngineStatus.loading;
    notifyListeners();
    final engine = await IconizeAssets.loadEngine(
      userSources: [_vocabSource],
      bridge:
          EnglishBridgeDictionary.fromEnViEntries(OfflineDictionary.entries),
    );
    _engine = engine;
    _status = engine == null
        ? IconizeEngineStatus.disabled
        : IconizeEngineStatus.ready;
    notifyListeners();
  }

  /// Làm mới map ảnh user cho tầng 1 fallback.
  ///
  /// Nhận thẳng List<WordEntry> (caller lấy từ VocabularyProvider) — ở đây
  /// lọc: chỉ ảnh LOCAL (bỏ URL http — offline-first, không fetch trong
  /// render), resolve relative → absolute theo documents dir (cùng quy ước
  /// VocabImageService), kiểm tra file tồn tại NGOÀI vòng render.
  Future<void> refreshVocabIcons(List<WordEntry> words) async {
    try {
      final docsDir = (await getApplicationDocumentsDirectory()).path;
      final pairs = <MapEntry<String, String>>[];
      for (final w in words) {
        final raw = w.imageUrl?.trim();
        if (raw == null || raw.isEmpty) continue;
        if (raw.startsWith('http://') || raw.startsWith('https://')) continue;
        final abs = raw.startsWith('/') ? raw : '$docsDir/$raw';
        pairs.add(MapEntry(w.word, abs));
      }
      _vocabSource.update(pairs);
      if (_status == IconizeEngineStatus.ready) notifyListeners();
    } catch (e) {
      debugPrint('IconizeService.refreshVocabIcons error: $e');
    }
  }

  /// Icon hóa một câu. Trả null khi engine chưa sẵn sàng (UI giữ chữ).
  ///
  /// [declaredLang]: mã nguồn user khai báo ('AUTO'/null → đoán bảo thủ
  /// bằng [guessIconizeLang] — đoán sai chỉ làm mất icon, không icon sai).
  Future<IconizeResult?> iconizeSentence(
    String text, {
    String? declaredLang,
    IconizeDensity density = IconizeDensity.medium,
  }) async {
    final engine = _engine;
    if (engine == null || _status != IconizeEngineStatus.ready) return null;
    return engine.iconize(
      text,
      langCode: guessIconizeLang(text, declared: declaredLang),
      density: density,
    );
  }
}
