import 'package:file_picker/file_picker.dart';

import '../models/dict_info.dart';
import 'dictionary_service.dart';

/// Service import file từ điển từ device
class DictImportService {
  /// Chọn và import file .mdx
  static Future<DictInfo?> pickAndImportMdx({
    void Function(double progress, String message)? onProgress,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mdx'],
    );

    if (result == null || result.files.isEmpty) return null;
    final mdxPath = result.files.single.path;
    if (mdxPath == null) return null;

    return await DictionaryService.instance.importMdx(
      mdxPath,
      onProgress: onProgress,
    );
  }
}
