import '../../models/i4u_shell_contracts.dart';

class I4uAnchorResolution {
  const I4uAnchorResolution({required this.offset, required this.confidence, required this.strategy});

  final int offset;
  final double confidence;
  final String strategy;

  bool get isReliable => confidence >= 0.8;
}

/// Resolves semantic anchors without promising pixel-perfect restoration.
class I4uSemanticAnchorResolver {
  const I4uSemanticAnchorResolver();

  I4uAnchorResolution? resolve({
    required I4uSemanticReadingAnchor anchor,
    required String currentSourceId,
    required String text,
    String? currentBlockId,
    String? currentRevision,
  }) {
    if (anchor.sourceId != currentSourceId || text.isEmpty) return null;

    if (currentBlockId == anchor.blockId &&
        (anchor.sourceRevision == null || anchor.sourceRevision == currentRevision)) {
      return I4uAnchorResolution(
        offset: anchor.characterOffset.clamp(0, text.length).toInt(),
        confidence: 1,
        strategy: 'block-id',
      );
    }

    final term = anchor.selectedTerm?.trim();
    if (term != null && term.isNotEmpty) {
      final index = text.toLowerCase().indexOf(term.toLowerCase());
      if (index >= 0) {
        return I4uAnchorResolution(offset: index, confidence: 0.86, strategy: 'selected-term');
      }
    }

    return null;
  }
}
