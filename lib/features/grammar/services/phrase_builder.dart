import '../models/grammar_category.dart';
import '../models/phrase_info.dart';
import 'verb_group_reader.dart';

class PhraseBuildResult {
  final PhraseInfo? phrase;
  final PhraseInfo? outer;

  const PhraseBuildResult({this.phrase, this.outer});
}

class PhraseBuilder {
  PhraseBuilder({VerbGroupReader? verbReader})
      : _verbReader = verbReader ?? const VerbGroupReader();

  final VerbGroupReader _verbReader;

  PhraseBuildResult build(
    List<StructureToken> tokens, {
    required int anchorIndex,
  }) {
    if (anchorIndex < 0 || anchorIndex >= tokens.length) {
      return const PhraseBuildResult();
    }

    final primary = _firstNonNull([
      _findPhrasalVerb(tokens, anchorIndex),
      _findInfinitivePhrase(tokens, anchorIndex),
      _findGerundPhrase(tokens, anchorIndex),
      _findParticiplePhrase(tokens, anchorIndex),
      _findVerbPhrase(tokens, anchorIndex),
      _isPreposition(tokens[anchorIndex]) ? _findPrepositionalPhrase(tokens, anchorIndex) : null,
      _findAdverbPhrase(tokens, anchorIndex),
      _findNounPhrase(tokens, anchorIndex),
      _findAdjectivePhrase(tokens, anchorIndex),
    ]);

    if (primary == null) return const PhraseBuildResult();
    final outer = _findOuter(tokens, primary, anchorIndex);
    return PhraseBuildResult(phrase: primary, outer: outer);
  }

  PhraseInfo? _firstNonNull(List<PhraseInfo?> items) {
    for (final item in items) {
      if (item != null) return item;
    }
    return null;
  }

  PhraseInfo? _findVerbPhrase(List<StructureToken> tokens, int anchorIndex) {
    final group = _verbReader.readAt(tokens, anchorIndex);
    if (group == null) return null;
    final prev = _previousWord(tokens, anchorIndex);
    if (group.startIndex == anchorIndex &&
        prev != null &&
        _determinerLike(tokens[prev].normalized)) {
      return null;
    }
    return _span(tokens, PhraseKind.vp, group.startIndex, group.endIndex, confidence: 0.86);
  }

  PhraseInfo? _findPhrasalVerb(List<StructureToken> tokens, int anchorIndex) {
    for (var i = 0; i < tokens.length; i++) {
      final base = VerbGroupReader.lemmaFor(tokens[i]);
      final particles = _phrasalParticles[base];
      if (particles == null) continue;
      if (tokens[i].normalized.endsWith('ing')) continue;
      final searchEnd = (i + 4).clamp(0, tokens.length - 1).toInt();
      for (var j = i + 1; j <= searchEnd; j++) {
        if (tokens[j].isPunctuation) break;
        if (!particles.contains(tokens[j].normalized)) continue;
        if (anchorIndex != i && anchorIndex != j) continue;
        return _span(tokens, PhraseKind.phrasalV, i, j, confidence: 0.9);
      }
    }
    return null;
  }

  PhraseInfo? _findInfinitivePhrase(List<StructureToken> tokens, int anchorIndex) {
    if (!_isVerbLike(tokens, anchorIndex)) return null;
    final toIndex = _previousWord(tokens, anchorIndex);
    if (toIndex == null || tokens[toIndex].normalized != 'to') return null;
    if (toIndex > 0) {
      final before = tokens[_previousWord(tokens, toIndex) ?? toIndex];
      if (before.normalized == 'going' || before.normalized == 'used') return null;
    }
    var end = anchorIndex;
    final objectStart = _nextWord(tokens, anchorIndex + 1);
    if (objectStart != null && _canStartObject(tokens[objectStart])) {
      end = _consumeNounLike(tokens, objectStart);
    }
    return _span(tokens, PhraseKind.infp, toIndex, end, confidence: 0.86);
  }

  PhraseInfo? _findGerundPhrase(List<StructureToken> tokens, int anchorIndex) {
    final token = tokens[anchorIndex];
    if (!_isVing(token)) return null;
    final containingVerb = _verbReader.readAt(tokens, anchorIndex);
    if (containingVerb != null && containingVerb.startIndex < anchorIndex) {
      return null;
    }
    final prev = _previousWord(tokens, anchorIndex);
    if (prev != null) {
      final p = tokens[prev];
      if (VerbGroupReader.isBeWord(p.normalized) ||
          (_isNounish(p) && !_isFiniteVerbStart(tokens, prev))) {
        return null;
      }
    }
    var end = anchorIndex;
    final next = _nextWord(tokens, anchorIndex + 1);
    if (next != null && VerbGroupReader.isParticleWord(tokens[next].normalized)) {
      end = next;
    } else if (next != null && _isPreposition(tokens[next])) {
      end = _consumePreposition(tokens, next);
    } else if (next != null && _canStartObject(tokens[next])) {
      end = _consumeNounLike(tokens, next);
    }
    return _span(tokens, PhraseKind.gerp, anchorIndex, end, confidence: 0.84);
  }

  PhraseInfo? _findParticiplePhrase(List<StructureToken> tokens, int anchorIndex) {
    final token = tokens[anchorIndex];
    if (!_isVing(token) && !_isPastParticiple(token)) return null;
    final containingVerb = _verbReader.readAt(tokens, anchorIndex);
    if (containingVerb != null && containingVerb.startIndex < anchorIndex) {
      return null;
    }
    final prev = _previousWord(tokens, anchorIndex);
    if (prev == null || !_isNounish(tokens[prev])) return null;
    var end = anchorIndex;
    var next = _nextWord(tokens, anchorIndex + 1);
    while (next != null && _isAdverb(tokens[next])) {
      end = next;
      next = _nextWord(tokens, next + 1);
    }
    if (next != null && _isPreposition(tokens[next])) {
      end = _consumePreposition(tokens, next);
    }
    return _span(tokens, PhraseKind.partp, anchorIndex, end, confidence: 0.78);
  }

  PhraseInfo? _findPrepositionalPhrase(List<StructureToken> tokens, int anchorIndex) {
    var start = anchorIndex;
    if (tokens[anchorIndex].normalized == 'of') {
      final prev = _previousWord(tokens, anchorIndex);
      if (prev != null && tokens[prev].normalized == 'because') start = prev;
    }
    final end = _consumePreposition(tokens, start);
    return _span(tokens, PhraseKind.pp, start, end, confidence: 0.84);
  }

  PhraseInfo? _findNounPhrase(List<StructureToken> tokens, int anchorIndex) {
    final anchor = tokens[anchorIndex];
    final prevCue = _previousWord(tokens, anchorIndex);
    final nextCue = _nextWord(tokens, anchorIndex + 1);
    final nominalLeftCue = prevCue != null &&
        (_determinerLike(tokens[prevCue].normalized) ||
            _isPreposition(tokens[prevCue]) ||
            tokens[prevCue].surface.endsWith("'s") ||
            tokens[prevCue].surface.endsWith('’s')) &&
        (nextCue == null || !_isNounish(tokens[nextCue]));
    if (!_isNounish(anchor) && !_canStartObject(anchor) && !nominalLeftCue) {
      return null;
    }
    if (_isAdjectiveLike(tokens, anchorIndex) &&
        anchor.category != GrammarCategory.noun &&
        !nominalLeftCue) {
      return null;
    }
    var start = anchorIndex;
    var prev = _previousWord(tokens, start);
    while (prev != null && _canExtendNpLeft(tokens, prev, start)) {
      start = prev;
      if (_determinerLike(tokens[prev].normalized)) {
        final beforeDet = _previousWord(tokens, prev);
        if (beforeDet != null && _preDeterminers.contains(tokens[beforeDet].normalized)) {
          start = beforeDet;
        }
        break;
      }
      prev = _previousWord(tokens, start);
    }

    var end = anchorIndex;
    final next = _nextWord(tokens, end + 1);
    if (next != null && _relativeStarters.contains(tokens[next].normalized)) {
      end = _consumeRelativeTail(tokens, next);
    } else if (next != null && _isVing(tokens[next])) {
      end = _consumeParticipialTail(tokens, next);
    }

    return _span(tokens, PhraseKind.np, start, end, confidence: 0.82);
  }

  PhraseInfo? _findAdjectivePhrase(List<StructureToken> tokens, int anchorIndex) {
    if (!_isAdjectiveLike(tokens, anchorIndex)) return null;
    var start = anchorIndex;
    final prev = _previousWord(tokens, anchorIndex);
    if (prev != null && _degreeAdverbs.contains(tokens[prev].normalized)) {
      start = prev;
    }
    var end = anchorIndex;
    final next = _nextWord(tokens, anchorIndex + 1);
    if (next != null && tokens[next].normalized == 'than') {
      final obj = _nextWord(tokens, next + 1);
      end = obj ?? next;
    } else if (next != null && _isPreposition(tokens[next])) {
      end = _consumePreposition(tokens, next);
    } else if (next != null && tokens[next].normalized == 'to') {
      final v = _nextWord(tokens, next + 1);
      end = v ?? next;
    }
    return _span(tokens, PhraseKind.adjp, start, end, confidence: 0.84);
  }

  PhraseInfo? _findAdverbPhrase(List<StructureToken> tokens, int anchorIndex) {
    if (!_isAdverb(tokens[anchorIndex])) return null;
    var start = anchorIndex;
    final prev = _previousWord(tokens, anchorIndex);
    if (prev != null && _degreeAdverbs.contains(tokens[prev].normalized)) {
      start = prev;
    }
    return _span(tokens, PhraseKind.advp, start, anchorIndex, confidence: 0.82);
  }

  PhraseInfo? _findOuter(
    List<StructureToken> tokens,
    PhraseInfo primary,
    int anchorIndex,
  ) {
    final startToken = _tokenIndexAtOffset(tokens, primary.startOffset);
    final endToken = _tokenIndexEndingAt(tokens, primary.endOffset);
    if (startToken == null || endToken == null) return null;

    if (primary.kind == PhraseKind.np) {
      final prev = _previousWord(tokens, startToken);
      if (prev != null && _isPreposition(tokens[prev])) {
        var ppStart = prev;
        if (tokens[prev].normalized == 'of') {
          final before = _previousWord(tokens, prev);
          if (before != null && tokens[before].normalized == 'because') ppStart = before;
        }
        return _span(tokens, PhraseKind.pp, ppStart, endToken, confidence: 0.78);
      }
      final next = _nextWord(tokens, endToken + 1);
      if (next != null && _isPreposition(tokens[next])) {
        final ppEnd = _consumePreposition(tokens, next);
        return _span(tokens, PhraseKind.pp, next, ppEnd, confidence: 0.66);
      }
      final coord = _coordOuter(tokens, startToken, endToken);
      if (coord != null) return coord;
    }

    if (primary.kind == PhraseKind.adjp || primary.kind == PhraseKind.advp) {
      final coord = _coordOuter(tokens, startToken, endToken);
      if (coord != null) return coord;
    }

    return null;
  }

  PhraseInfo? _coordOuter(List<StructureToken> tokens, int start, int end) {
    final next = _nextWord(tokens, end + 1);
    if (next != null && tokens[next].normalized == 'and') {
      final rhs = _nextWord(tokens, next + 1);
      if (rhs != null && !tokens[rhs].isPunctuation) {
        return _span(tokens, PhraseKind.coord, start, rhs, confidence: 0.74);
      }
    }
    final prev = _previousWord(tokens, start);
    if (prev != null && tokens[prev].normalized == 'and') {
      final lhs = _previousWord(tokens, prev);
      if (lhs != null && !tokens[lhs].isPunctuation) {
        return _span(tokens, PhraseKind.coord, lhs, end, confidence: 0.74);
      }
    }
    return null;
  }

  int _consumePreposition(List<StructureToken> tokens, int prepIndex) {
    var end = prepIndex;
    var i = _nextWord(tokens, prepIndex + 1);
    while (i != null && !tokens[i].isPunctuation) {
      if (i != prepIndex + 1 && _isClauseBoundary(tokens[i])) break;
      end = i;
      final next = _nextWord(tokens, i + 1);
      if (next == null) break;
      if (_isPreposition(tokens[next]) && next > prepIndex + 1) break;
      if (_isFiniteVerbStart(tokens, next) && next > prepIndex + 1) break;
      i = next;
    }
    return end;
  }

  int _consumeNounLike(List<StructureToken> tokens, int start) {
    var end = start;
    var i = _nextWord(tokens, start + 1);
    while (i != null && !tokens[i].isPunctuation) {
      if (_isClauseBoundary(tokens[i]) || _isPreposition(tokens[i]) || _isFiniteVerbStart(tokens, i)) {
        break;
      }
      if (_isAdverb(tokens[i]) && !_degreeAdverbs.contains(tokens[i].normalized)) break;
      end = i;
      i = _nextWord(tokens, i + 1);
    }
    return end;
  }

  int _consumeParticipialTail(List<StructureToken> tokens, int start) {
    var end = start;
    var i = _nextWord(tokens, start + 1);
    while (i != null && !tokens[i].isPunctuation) {
      if (_isFiniteVerbStart(tokens, i)) break;
      if (_isPreposition(tokens[i])) {
        end = _consumePreposition(tokens, i);
        break;
      }
      if (_isAdverb(tokens[i]) || _canStartObject(tokens[i])) {
        end = i;
        i = _nextWord(tokens, i + 1);
        continue;
      }
      break;
    }
    return end;
  }

  int _consumeRelativeTail(List<StructureToken> tokens, int relativeStart) {
    var end = relativeStart;
    final groups = _verbReader.readAll(tokens);
    final laterGroups = groups.where((g) => g.startIndex > relativeStart).toList();
    if (laterGroups.length >= 2) {
      final mainAfterRelative = laterGroups.last;
      return (mainAfterRelative.startIndex - 1)
          .clamp(relativeStart, tokens.length - 1)
          .toInt();
    }
    if (laterGroups.length == 1 && laterGroups.first.startIndex > relativeStart + 2) {
      return (laterGroups.first.startIndex - 1)
          .clamp(relativeStart, tokens.length - 1)
          .toInt();
    }
    var i = _nextWord(tokens, relativeStart + 1);
    while (i != null && !tokens[i].isPunctuation) {
      end = i;
      i = _nextWord(tokens, i + 1);
    }
    return end;
  }

  bool _canExtendNpLeft(List<StructureToken> tokens, int prev, int currentStart) {
    final token = tokens[prev];
    final w = token.normalized;
    if (token.isPunctuation) return false;
    if (_isClauseBoundary(token) || _isPreposition(token)) return false;
    if (_determinerLike(w) || _isAdjectiveLike(tokens, prev) || _degreeAdverbs.contains(w)) {
      return true;
    }
    if (_isFiniteVerbStart(tokens, prev)) return false;
    if (token.category == GrammarCategory.pronoun && !_determinerLike(w)) return false;
    if (w.endsWith("'s")) return true;
    if (token.surface.endsWith("'s") || token.surface.endsWith('’s')) return true;
    if (_isNounish(token) && currentStart == prev + 1) return true;
    return false;
  }

  bool _determinerLike(String w) =>
      VerbGroupReader.isDeterminerWord(w) || _possessiveDeterminers.contains(w);

  bool _isFiniteVerbStart(List<StructureToken> tokens, int index) {
    final group = _verbReader.readAtStart(tokens, index);
    return group != null && group.startIndex == index;
  }

  bool _isClauseBoundary(StructureToken token) {
    final w = token.normalized;
    return w == 'and' || w == 'but' || w == 'or' || w == 'so' || w == 'if' ||
        w == 'when' || w == 'because' || w == 'although' || w == 'while' ||
        w == 'that' || w == 'who' || w == 'which';
  }

  bool _isPreposition(StructureToken token) =>
      VerbGroupReader.isPrepositionWord(token.normalized) ||
      token.category == GrammarCategory.preposition;

  bool _isAdverb(StructureToken token) =>
      VerbGroupReader.isAdverbWord(token.normalized) ||
      token.category == GrammarCategory.adverb;

  bool _isVing(StructureToken token) =>
      token.normalized.endsWith('ing') &&
      token.normalized.length > 4 &&
      !_adjectives.contains(token.normalized);

  bool _isPastParticiple(StructureToken token) =>
      token.normalized.endsWith('ed') ||
      const {'written', 'broken', 'left', 'built', 'been', 'born', 'said', 'seen', 'eaten', 'stolen'}
          .contains(token.normalized) ||
      token.subCategory == 'past_or_participle';

  bool _isVerbLike(List<StructureToken> tokens, int index) =>
      VerbGroupReader.isVerbLikeToken(tokens, index);

  bool _isNounish(StructureToken token) {
    final w = token.normalized;
    if (token.category == GrammarCategory.noun || token.category == GrammarCategory.pronoun) {
      return true;
    }
    if (_pronouns.contains(w) || _negativePronouns.contains(w)) return true;
    if (token.category == GrammarCategory.unknown &&
        !_isAdverb(token) &&
        !VerbGroupReader.isAuxWord(w) &&
        !VerbGroupReader.isModalWord(w) &&
        !VerbGroupReader.isPrepositionWord(w)) {
      return true;
    }
    return false;
  }

  bool _canStartObject(StructureToken token) {
    final w = token.normalized;
    return _isNounish(token) || _determinerLike(w) || _isAdjectiveWord(w);
  }

  bool _isAdjectiveLike(List<StructureToken> tokens, int index) {
    final token = tokens[index];
    final w = token.normalized;
    if (token.category == GrammarCategory.adjective) return true;
    if (_isAdjectiveWord(w)) return true;
    if (w.endsWith('er') || w.endsWith('est')) return true;
    final prev = _previousWord(tokens, index);
    if (prev != null && _degreeAdverbs.contains(tokens[prev].normalized)) return true;
    return false;
  }

  bool _isAdjectiveWord(String w) => _adjectives.contains(w) ||
      w.endsWith('ful') ||
      w.endsWith('less') ||
      w.endsWith('ous') ||
      w.endsWith('able') ||
      w.endsWith('ible') ||
      w.endsWith('ive') ||
      w.endsWith('al');

  int? _nextWord(List<StructureToken> tokens, int from) {
    for (var i = from; i < tokens.length; i++) {
      if (tokens[i].isWord) return i;
    }
    return null;
  }

  int? _previousWord(List<StructureToken> tokens, int from) {
    for (var i = from - 1; i >= 0; i--) {
      if (tokens[i].isWord) return i;
    }
    return null;
  }

  int? _tokenIndexAtOffset(List<StructureToken> tokens, int offset) {
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].startOffset == offset) return i;
    }
    return null;
  }

  int? _tokenIndexEndingAt(List<StructureToken> tokens, int offset) {
    for (var i = tokens.length - 1; i >= 0; i--) {
      if (tokens[i].endOffset == offset) return i;
    }
    return null;
  }

  PhraseInfo _span(
    List<StructureToken> tokens,
    PhraseKind kind,
    int start,
    int end, {
    double confidence = 0.82,
  }) {
    final safeStart = start.clamp(0, tokens.length - 1).toInt();
    final safeEnd = end.clamp(safeStart, tokens.length - 1).toInt();
    return PhraseInfo(
      kind: kind,
      startOffset: tokens[safeStart].startOffset,
      endOffset: tokens[safeEnd].endOffset,
      parts: [
        PhrasePart(
          startOffset: tokens[safeStart].startOffset,
          endOffset: tokens[safeEnd].endOffset,
        ),
      ],
      confidence: confidence,
    );
  }

  static const Map<String, Set<String>> _phrasalParticles = {
    'turn': {'on', 'off', 'down', 'up'},
    'look': {'after', 'for', 'up'},
    'pick': {'up'},
    'give': {'up', 'back'},
    'put': {'off', 'on', 'away'},
    'take': {'off'},
    'find': {'out'},
    'wake': {'up'},
  };

  static const Set<String> _relativeStarters = {
    'that', 'who', 'whom', 'whose', 'which', 'where',
  };
  static const Set<String> _possessiveDeterminers = {
    'my', 'your', 'his', 'her', 'its', 'our', 'their', 'whose',
  };
  static const Set<String> _preDeterminers = {
    'such', 'all', 'both',
  };
  static const Set<String> _pronouns = {
    'i', 'you', 'he', 'she', 'it', 'we', 'they', 'me', 'him', 'her', 'us',
    'them', 'who', 'whom', 'which', 'what',
  };
  static const Set<String> _negativePronouns = {'nobody', 'nothing', 'none'};
  static const Set<String> _degreeAdverbs = {
    'very', 'really', 'quite', 'rather', 'so', 'too', 'extremely', 'pretty',
    'fairly', 'slightly', 'almost', 'nearly',
  };
  static const Set<String> _adjectives = {
    'old', 'red', 'big', 'small', 'beautiful', 'smart', 'kind', 'happy', 'good',
    'tall', 'thin', 'boring', 'interesting', 'tired', 'new', 'ready',
  };
}
