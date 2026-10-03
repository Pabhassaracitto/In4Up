import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'base_background_remover.dart';
import 'background_removal_engine.dart';
import 'mlkit_background_remover.dart';

/// Small strategy coordinator used by UI and future Settings screens.
///
/// If an optional engine fails (for example model/RAM/ONNX errors), the
/// default ML Kit strategy is retried automatically. The original bytes stay
/// with the caller when both strategies fail.
class BackgroundRemovalService {
  BackgroundRemovalService({
    BaseBackgroundRemover? mlKit,
    BaseBackgroundRemover? rmbg,
  })  : mlKit = mlKit ?? MlKitBackgroundRemover(),
        rmbg = rmbg;

  static final BackgroundRemovalService instance = BackgroundRemovalService();

  final BaseBackgroundRemover mlKit;
  final BaseBackgroundRemover? rmbg;

  Future<Uint8List?> removeBackground(
    Uint8List imageBytes, {
    BackgroundRemovalEngine engine = BackgroundRemovalEngine.mlKit,
  }) async {
    if (imageBytes.isEmpty) return null;

    if (engine == BackgroundRemovalEngine.rmbg14 && rmbg != null) {
      try {
        final result = await rmbg!.removeBackground(imageBytes);
        if (result != null && result.isNotEmpty) return result;
      } catch (error, stackTrace) {
        debugPrint('RMBG-1.4 failed; falling back to ML Kit: $error\n$stackTrace');
      }
    }

    try {
      return await mlKit.removeBackground(imageBytes);
    } catch (error, stackTrace) {
      // Implementations normally return null, but the coordinator also guards
      // against an injected strategy throwing unexpectedly.
      debugPrint('ML Kit background removal failed: $error\n$stackTrace');
      return null;
    }
  }
}
