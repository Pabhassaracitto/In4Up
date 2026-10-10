import 'package:flutter/foundation.dart';

/// The five stable I4U workspaces. Global Chat is contextual, not a workspace.
enum I4uWorkspace { home, read, listen, understand, remember }

enum I4uSourceType { document, web, pdf, audio, video, pasted }

enum I4uOverlay { none, quickActions, commandPalette, chat, toolPanel, sheet, modal }

enum I4uPanelState { closed, open, pinned, replaced }

/// Stable identity used when handing context between workspaces.
@immutable
class I4uSourceFingerprint {
  const I4uSourceFingerprint({
    required this.sourceType,
    required this.sourceId,
    this.sourceRevision,
    this.page,
    this.timestampMs,
    this.selectedText,
    this.locale,
    required this.returnPath,
    this.createdAt,
  });

  final I4uSourceType sourceType;
  final String sourceId;
  final String? sourceRevision;
  final int? page;
  final int? timestampMs;
  final String? selectedText;
  final String? locale;
  final String returnPath;
  final DateTime? createdAt;

  Map<String, Object?> toJson() => {
        'sourceType': sourceType.name,
        'sourceId': sourceId,
        'sourceRevision': sourceRevision,
        'page': page,
        'timestampMs': timestampMs,
        'selectedText': selectedText,
        'locale': locale,
        'returnPath': returnPath,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory I4uSourceFingerprint.fromJson(Map<String, Object?> json) {
    return I4uSourceFingerprint(
      sourceType: _enumValue(I4uSourceType.values, json['sourceType'], I4uSourceType.document),
      sourceId: json['sourceId'] as String? ?? '',
      sourceRevision: json['sourceRevision'] as String?,
      page: json['page'] as int?,
      timestampMs: json['timestampMs'] as int?,
      selectedText: json['selectedText'] as String?,
      locale: json['locale'] as String?,
      returnPath: json['returnPath'] as String? ?? '/',
      createdAt: _date(json['createdAt']),
    );
  }
}

/// A semantic, rather than pixel, position in a source.
@immutable
class I4uSemanticReadingAnchor {
  const I4uSemanticReadingAnchor({
    required this.sourceId,
    this.sourceRevision,
    required this.blockId,
    required this.characterOffset,
    this.selectedTerm,
    this.locale,
    this.viewportRelativeRatio = 0.35,
    this.createdAt,
  });

  final String sourceId;
  final String? sourceRevision;
  final String blockId;
  final int characterOffset;
  final String? selectedTerm;
  final String? locale;
  final double viewportRelativeRatio;
  final DateTime? createdAt;

  Map<String, Object?> toJson() => {
        'sourceId': sourceId,
        'sourceRevision': sourceRevision,
        'blockId': blockId,
        'characterOffset': characterOffset,
        'selectedTerm': selectedTerm,
        'locale': locale,
        'viewportRelativeRatio': viewportRelativeRatio,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory I4uSemanticReadingAnchor.fromJson(Map<String, Object?> json) {
    final ratio = (json['viewportRelativeRatio'] as num?)?.toDouble() ?? 0.35;
    return I4uSemanticReadingAnchor(
      sourceId: json['sourceId'] as String? ?? '',
      sourceRevision: json['sourceRevision'] as String?,
      blockId: json['blockId'] as String? ?? '',
      characterOffset: json['characterOffset'] as int? ?? 0,
      selectedTerm: json['selectedTerm'] as String?,
      locale: json['locale'] as String?,
      viewportRelativeRatio: ratio.clamp(0.0, 1.0),
      createdAt: _date(json['createdAt']),
    );
  }
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;
