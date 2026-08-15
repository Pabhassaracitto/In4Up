enum PlaybackMode { enOnly, viOnly, interleaved, custom }

enum SilenceGap {
  relax(500, 'Content'),
  think(1500, 'Content'),
  quiz(3000, 'Content');

  final int ms;
  final String label;
  const SilenceGap(this.ms, this.label);
}

class PlaybackRecipe {
  final PlaybackMode mode;
  final int enRepeats;
  final int viRepeats;
  final int lineRepeats;
  final int totalPasses; // 0 = ∞
  final SilenceGap silenceGap;
  final double speed;

  const PlaybackRecipe({
    this.mode        = PlaybackMode.enOnly,
    this.enRepeats   = 1,
    this.viRepeats   = 1,
    this.lineRepeats = 1,
    this.totalPasses = 1,
    this.silenceGap  = SilenceGap.relax,
    this.speed       = 1.0,
  });

  // ── Presets ───────────────────────────────────────────────
  static const enOnly = PlaybackRecipe();

  static const viOnly = PlaybackRecipe(
    mode: PlaybackMode.viOnly,
    enRepeats: 0,
  );

  static const bilingual = PlaybackRecipe(
    mode: PlaybackMode.interleaved,
    silenceGap: SilenceGap.think,
  );

  static const intensive = PlaybackRecipe(
    mode: PlaybackMode.custom,
    enRepeats: 2,
    viRepeats: 1,
    silenceGap: SilenceGap.think,
  );

  static const quiz = PlaybackRecipe(
    mode: PlaybackMode.custom,
    enRepeats: 1,
    viRepeats: 1,
    silenceGap: SilenceGap.quiz,
    speed: 0.75,
  );

  static const shadowing = PlaybackRecipe(
    mode: PlaybackMode.enOnly,
    lineRepeats: 3,
    speed: 0.75,
  );

  // ── copyWith ─────────────────────────────────────────────
  PlaybackRecipe copyWith({
    PlaybackMode? mode,
    int? enRepeats,
    int? viRepeats,
    int? lineRepeats,
    int? totalPasses,
    SilenceGap? silenceGap,
    double? speed,
  }) =>
      PlaybackRecipe(
        mode:        mode        ?? this.mode,
        enRepeats:   enRepeats   ?? this.enRepeats,
        viRepeats:   viRepeats   ?? this.viRepeats,
        lineRepeats: lineRepeats ?? this.lineRepeats,
        totalPasses: totalPasses ?? this.totalPasses,
        silenceGap:  silenceGap  ?? this.silenceGap,
        speed:       (speed      ?? this.speed).clamp(0.5, 2.0),
      );

  // ── Persistence ───────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'mode':        mode.name,
    'enRepeats':   enRepeats,
    'viRepeats':   viRepeats,
    'lineRepeats': lineRepeats,
    'totalPasses': totalPasses,
    'silenceGap':  silenceGap.name,
    'speed':       speed,
  };

  factory PlaybackRecipe.fromJson(Map<String, dynamic> j) => PlaybackRecipe(
    mode: PlaybackMode.values.byName(
      j['mode'] as String? ?? 'enOnly',
    ),
    enRepeats:   j['enRepeats']   as int?    ?? 1,
    viRepeats:   j['viRepeats']   as int?    ?? 1,
    lineRepeats: j['lineRepeats'] as int?    ?? 1,
    totalPasses: j['totalPasses'] as int?    ?? 1,
    silenceGap: SilenceGap.values.byName(
      j['silenceGap'] as String? ?? 'relax',
    ),
    speed: (j['speed'] as num?)?.toDouble() ?? 1.0,
  );
}