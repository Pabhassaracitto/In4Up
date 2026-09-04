import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:in4up/features/tipitaka/models/language_pack.dart';

/// TEMP CI-BISECT STUB — archive usage stubbed to isolate the analyzer error.
class TipitakaLanguagePackService {
  const TipitakaLanguagePackService();

  Future<TipitakaDownloadedPack> download(
    TipitakaLanguagePack pack, {
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    throw UnimplementedError('CI bisect stub');
  }
}
