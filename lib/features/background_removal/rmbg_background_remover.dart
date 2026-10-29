import 'dart:typed_data';

import 'base_background_remover.dart';

/// Callback used by the optional RMBG-1.4 adapter.
///
/// The callback is intentionally injected so the default application does not
/// import or bundle an ONNX runtime. The Phase 2 implementation can create an
/// ONNX session inside a `compute` entry point and pass its result here.
typedef RmbgInference = Future<Uint8List?> Function({
  required Uint8List imageBytes,
  required String modelPath,
});

/// Phase 2 strategy seam for RMBG-1.4.
///
/// This class owns model availability and the strategy contract, but does not
/// ship `rmbg14.onnx` or link an ONNX runtime in the default APK. Inject an
/// [inference] runner when Phase 2 is enabled. A missing runner/model throws a
/// typed error so [BackgroundRemovalService] can fall back to ML Kit.
class RmbgBackgroundRemover implements BaseBackgroundRemover {
  RmbgBackgroundRemover({
    required this.modelPath,
    this.inference,
  });

  final String modelPath;
  final RmbgInference? inference;

  bool get isReady => modelPath.trim().isNotEmpty && inference != null;

  @override
  Future<Uint8List?> removeBackground(Uint8List imageBytes) async {
    if (modelPath.trim().isEmpty) {
      throw const RmbgModelUnavailableException('RMBG-1.4 chưa được cài đặt.');
    }
    final runner = inference;
    if (runner == null) {
      throw const RmbgModelUnavailableException(
        'ONNX runtime chưa được bật trong bản mặc định.',
      );
    }
    return runner(imageBytes: imageBytes, modelPath: modelPath);
  }
}

class RmbgModelUnavailableException implements Exception {
  const RmbgModelUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}
