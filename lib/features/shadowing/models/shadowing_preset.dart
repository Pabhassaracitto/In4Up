class ShadowingPreset {
  final String id;
  final String name;
  final int repeatCount;
  final double playbackSpeed;
  final String description;
  final bool isBuiltIn;

  const ShadowingPreset({
    required this.id,
    required this.name,
    required this.repeatCount,
    required this.playbackSpeed,
    this.description = '',
    this.isBuiltIn = false,
  });

  factory ShadowingPreset.fromJson(Map<String, dynamic> json) {
    return ShadowingPreset(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Preset',
      repeatCount: (json['repeatCount'] as num?)?.toInt() ?? 3,
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      description: json['description']?.toString() ?? '',
      isBuiltIn: json['isBuiltIn'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'repeatCount': repeatCount,
        'playbackSpeed': playbackSpeed,
        'description': description,
        'isBuiltIn': isBuiltIn,
      };

  String get compactLabel => '${repeatCount}x · ${playbackSpeed.toStringAsFixed(1)}x';
}
