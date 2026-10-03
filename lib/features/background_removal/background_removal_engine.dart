/// Engines that can be selected by the Wordlist image editor.
enum BackgroundRemovalEngine {
  mlKit,
  rmbg14,
}

extension BackgroundRemovalEngineLabel on BackgroundRemovalEngine {
  String get label {
    switch (this) {
      case BackgroundRemovalEngine.mlKit:
        return 'Google ML Kit (Nhanh)';
      case BackgroundRemovalEngine.rmbg14:
        return 'RMBG-1.4 (Sắc nét)';
    }
  }
}
