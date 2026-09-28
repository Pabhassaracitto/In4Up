class SentenceStructureSettings {
  static const String storageKey = 'sentence_structure_settings_v1';

  final bool sheetSectionEnabled;
  final double confidenceThreshold;

  const SentenceStructureSettings({
    this.sheetSectionEnabled = true,
    this.confidenceThreshold = 0.6,
  });

  factory SentenceStructureSettings.defaults() =>
      const SentenceStructureSettings();

  SentenceStructureSettings copyWith({
    bool? sheetSectionEnabled,
    double? confidenceThreshold,
  }) {
    return SentenceStructureSettings(
      sheetSectionEnabled: sheetSectionEnabled ?? this.sheetSectionEnabled,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
    );
  }

  Map<String, dynamic> toJson() => {
        'sheetSectionEnabled': sheetSectionEnabled,
        'confidenceThreshold': confidenceThreshold,
      };

  factory SentenceStructureSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SentenceStructureSettings.defaults();
    final threshold = (json['confidenceThreshold'] as num?)?.toDouble() ?? 0.6;
    return SentenceStructureSettings(
      sheetSectionEnabled: json['sheetSectionEnabled'] != false,
      confidenceThreshold: threshold.clamp(0.0, 1.0).toDouble(),
    );
  }
}
