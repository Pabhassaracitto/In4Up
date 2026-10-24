// lib/features/iconize/data/iconize_assets.dart
//
// ICONIZE-001b — nạp core bundle assets/iconize/ qua rootBundle và dựng
// DefaultIconizeEngine. Đây là file DUY NHẤT của engine chạm Flutter;
// toàn bộ logic còn lại thuần Dart (test được không cần device).
//
// Error handling theo blueprint mục 3.8: file hỏng/magic sai → trả null +
// log, KHÔNG throw ra UI, KHÔNG retry loop. Tầng UI (lane 001d) thấy null
// thì disable Iconize cho session + badge "tạm tắt do lỗi dữ liệu".

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../engine/iconize_bridge.dart';
import '../engine/iconize_engine.dart';
import '../engine/iconize_icon_source.dart';
import '../engine/iconize_lemmatizer.dart';
import 'iconize_binary.dart';

class IconizeAssets {
  static const String dir = 'assets/iconize';

  /// Dựng engine từ asset bundle. Trả null nếu BẤT KỲ file nào hỏng —
  /// caller phải coi null là "Iconize tắt cho session này".
  ///
  /// [userSources]/[bridge] (ICONIZE-001d): tiêm tầng icon user + bảng
  /// Bridge-to-English khi dựng — engine vẫn pure function, không state.
  static Future<DefaultIconizeEngine?> loadEngine({
    AssetBundle? bundle,
    List<IconizeIconSource> userSources = const [],
    EnglishBridgeDictionary? bridge,
  }) async {
    final b = bundle ?? rootBundle;
    try {
      final conc = await b.load('$dir/concreteness.bin');
      final index = await b.load('$dir/icon_index.bin');
      final icons = await b.load('$dir/icons_bundle.bin');
      final lemmas = await b.loadString('$dir/irregular_lemmas.json');
      return DefaultIconizeEngine(
        concreteness: ConcretenessTable(conc.buffer.asUint8List()),
        iconIndex: IconIndexTable(index.buffer.asUint8List()),
        iconsBundle: IconsBundle(icons.buffer.asUint8List()),
        lemmatizer: IconizeLemmatizer.fromJsonString(lemmas),
        userSources: userSources,
        bridge: bridge,
      );
    } on IconizeBinaryFormatException catch (e) {
      debugPrint('Iconize disabled: $e');
      return null;
    } catch (e) {
      debugPrint('Iconize disabled (asset load): $e');
      return null;
    }
  }
}
