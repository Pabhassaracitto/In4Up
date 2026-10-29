import 'package:flutter/foundation.dart'; // VoidCallback

abstract class TtsService {
  Future<void> speak(String text);
  void stop();
  Future<void> setSpeechRate(double rate);
  Future<void> setLanguage(String locale);
  set onStart(VoidCallback? cb);
  set onComplete(VoidCallback? cb);
  set onError(void Function(String error)? cb);
  Future<void> dispose();
}
