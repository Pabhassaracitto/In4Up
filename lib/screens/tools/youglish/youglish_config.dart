enum YouGlishLanguage {
  english('English', 'english'),
  french('French', 'french'),
  german('German', 'german'),
  spanish('Spanish', 'spanish'),
  italian('Italian', 'italian'),
  portuguese('Portuguese', 'portuguese'),
  chinese('Chinese', 'chinese'),
  japanese('Japanese', 'japanese'),
  korean('Korean', 'korean'),
  russian('Russian', 'russian'),
  arabic('Arabic', 'arabic');

  final String displayName;
  final String code;
  
  const YouGlishLanguage(this.displayName, this.code);
}

enum YouGlishAccent {
  us('American (US)', 'us'),
  uk('British (UK)', 'uk'),
  aus('Australian', 'aus');

  final String displayName;
  final String code;
  
  const YouGlishAccent(this.displayName, this.code);
}
