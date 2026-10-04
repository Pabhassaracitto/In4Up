import 'dart:typed_data';

/// Contract for every background-removal engine used by Wordlist.
///
/// Implementations must return a PNG with an alpha channel when processing
/// succeeds. Returning null means that the engine could not produce a result;
/// callers should keep the original image and show a non-blocking message.
abstract class BaseBackgroundRemover {
  Future<Uint8List?> removeBackground(Uint8List imageBytes);
}
