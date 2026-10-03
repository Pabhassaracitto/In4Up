import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// On-demand model storage seam for Phase 2.
///
/// It only manages the file in app documents. Network download, checksum and
/// file-picker UI stay outside this class so the model source can be replaced
/// by a release CDN or a user import without changing the inference strategy.
class RmbgModelStore {
  RmbgModelStore({this.fileName = modelFileName});

  static const modelFileName = 'rmbg14.onnx';
  final String fileName;

  Future<File> get modelFile async {
    final documents = await getApplicationDocumentsDirectory();
    return File('${documents.path}/$fileName');
  }

  Future<bool> get isInstalled async => (await modelFile).exists();

  Future<String?> get installedPath async {
    final file = await modelFile;
    if (!await file.exists() || await file.length() == 0) return null;
    return file.path;
  }

  /// Imports a model atomically and returns its final path.
  ///
  /// The caller should validate the expected SHA-256 and model metadata before
  /// calling this method. A zero-byte file is rejected to avoid reporting a
  /// broken model as installed.
  Future<String?> importModel(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists() || await source.length() == 0) return null;

    final destination = await modelFile;
    final temporary = File('${destination.path}.part');
    try {
      await temporary.parent.create(recursive: true);
      await source.copy(temporary.path);
      if (await temporary.length() == 0) return null;
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
      return destination.path;
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}
