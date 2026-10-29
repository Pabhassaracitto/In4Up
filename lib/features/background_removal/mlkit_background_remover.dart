import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'base_background_remover.dart';

/// Google ML Kit Subject Segmentation strategy (Phase 1).
///
/// The Flutter plugin currently exposes Subject Segmentation on Android. The
/// service therefore returns null on other platforms instead of crashing the
/// Wordlist editor. ML Kit runs natively through a platform channel; the Dart
/// isolate is not used for the native call itself.
class MlKitBackgroundRemover implements BaseBackgroundRemover {
  MlKitBackgroundRemover({this.androidOnly = true});

  /// Useful for tests and for a future platform implementation.
  final bool androidOnly;

  SubjectSegmenter? _segmenter;
  Object? lastError;

  bool get isSupported => !androidOnly || Platform.isAndroid;

  @override
  Future<Uint8List?> removeBackground(Uint8List imageBytes) async {
    lastError = null;
    if (imageBytes.isEmpty || !isSupported) return null;

    File? inputFile;
    try {
      // InputImage.fromFilePath lets ML Kit decode JPEG/HEIC/PNG itself and
      // avoids passing a large compressed buffer through a method channel.
      final tempDir = await getTemporaryDirectory();
      inputFile = File(
        '${tempDir.path}/in4up_subject_${DateTime.now().microsecondsSinceEpoch}.image',
      );
      await inputFile.writeAsBytes(imageBytes, flush: true);

      final segmenter = _segmenter ??= SubjectSegmenter(
        options: SubjectSegmenterOptions(
          enableForegroundBitmap: true,
          // Keep the confidence mask enabled as a fallback for plugin/model
          // versions that do not return foregroundBitmap.
          enableForegroundConfidenceMask: true,
          enableMultipleSubjects: SubjectResultOptions(
            enableConfidenceMask: false,
            enableSubjectBitmap: false,
          ),
        ),
      );

      final result = await segmenter.processImage(
        InputImage.fromFilePath(inputFile.path),
      );
      final foreground = result.foregroundBitmap;
      if (foreground == null || foreground.isEmpty) return null;

      // Android returns a PNG from the plugin. Decode/re-encode it so this
      // strategy has one stable contract: a clean PNG byte stream.
      final decoded = img.decodeImage(foreground);
      if (decoded == null) return null;
      return Uint8List.fromList(img.encodePng(decoded));
    } catch (error, stackTrace) {
      lastError = error;
      debugPrint('MlKitBackgroundRemover failed: $error\n$stackTrace');
      return null;
    } finally {
      try {
        await inputFile?.delete();
      } catch (_) {
        // A temporary-file cleanup failure must not affect the user result.
      }
    }
  }

  /// Release the native ML Kit client when the feature is no longer needed.
  Future<void> dispose() async {
    final segmenter = _segmenter;
    _segmenter = null;
    if (segmenter != null) await segmenter.close();
  }
}
