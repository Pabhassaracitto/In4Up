import '../models/grammar_category.dart';
import '../models/sentence_structure.dart';

class StructureToken {
  final String surface;
  final String normalized;
  final String lemma;
  final GrammarCategory category;
  final String? subCategory;
  final double confidence;
  final int startOffset;
  final int endOffset;
  final int sourceIndex;

  const StructureToken({
    required this.surface,
    required this.normalized,
    required this.lemma,
    required this.category,
    this.subCategory,
    required this.confidence,
    required this.startOffset,
    required this.endOffset,
    required this.sourceIndex,
  });

  bool get isPunctuation => category == GrammarCategory.punctuation ||
      (normalized.isEmpty && RegExp(r'^\W+$').hasMatch(surface));

  bool get isWord => normalized.isNotEmpty && !isPunctuation;

  StructureToken copyWith({
    String? surface,
    String? normalized,
    String? lemma,
    GrammarCategory? category,
    String? subCategory,
    double? confidence,
    int? startOffset,
    int? endOffset,
    int? sourceIndex,
  }) {
    return StructureToken(
      surface: surface ?? this.surface,
      normalized: normalized ?? this.normalized,
      lemma: lemma ?? this.lemma,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      confidence: confidence ?? this.confidence,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      sourceIndex: sourceIndex ?? this.sourceIndex,
    );
  }
}

class VerbGroup {
  final int startIndex;
  final int endIndex;
  final int mainIndex;
  final Tense tense;
  final Aspect aspect;
  final Voice voice;
  final String? modal;
  final String? negator;
  final bool questionInversion;

  const VerbGroup({
    required this.startIndex,
    required this.endIndex,
    required this.mainIndex,
    required this.tense,
    required this.aspect,
    required this.voice,
    this.modal,
    this.negator,
    this.questionInversion = false,
  });

  bool contains(int index) => index >= startIndex && index <= endIndex;

  int get length => endIndex - startIndex + 1;

  String lemmaOf(List<StructureToken> tokens) => tokens[mainIndex].lemma.isNotEmpty
      ? tokens[mainIndex].lemma
      : tokens[mainIndex].normalized;
}

class VerbGroupReader {
  const VerbGroupReader();

  List<VerbGroup> readAll(List<StructureToken> tokens) {
    final groups = <VerbGroup>[];
    for (var i = 0; i < tokens.length; i++) {
      final group = readAtStart(tokens, i);
      if (group == null) continue;
      if (groups.any((existing) =>
          existing.startIndex == group.startIndex &&
          existing.endIndex == group.endIndex)) {
        continue;
      }
      if (groups.any((existing) =>
          existing.startIndex < group.startIndex &&
          existing.contains(group.mainIndex) &&
          existing.length >= group.length)) {
        continue;
      }
      groups.add(group);
    }
    groups.sort((a, b) {
      final start = a.startIndex.compareTo(b.startIndex);
      if (start != 0) return start;
      return b.length.compareTo(a.length);
    });
    return groups;
  }

  VerbGroup? readAt(List<StructureToken> tokens, int anchorIndex) {
    final containing = readAll(tokens)
        .where((group) => group.contains(anchorIndex))
        .toList(growable: false);
    if (containing.isEmpty) return null;
    containing.sort((a, b) {
      final len = b.length.compareTo(a.length);
      if (len != 0) return len;
      return (a.mainIndex - anchorIndex).abs().compareTo(
            (b.mainIndex - anchorIndex).abs(),
          );
    });
    return containing.first;
  }

  VerbGroup? readAtStart(List<StructureToken> tokens, int index) {
    if (index < 0 || index >= tokens.length) return null;
    final w = tokens[index].normalized;
    if (w.isEmpty || tokens[index].isPunctuation) return null;

    final usedTo = _readUsedTo(tokens, index);
    if (usedTo != null) return usedTo;

    final semi = _readSemiModal(tokens, index);
    if (semi != null) return semi;

    if (_isModal(w)) return _readModal(tokens, index);
    if (_isDo(w)) return _readDoSupport(tokens, index);
    if (_isHave(w) || w == "'s") {
      final haveGroup = _readHaveOrBe(tokens, index);
      if (haveGroup != null) return haveGroup;
      if (w != "'s") {
        return VerbGroup(
          startIndex: index,
          endIndex: index,
          mainIndex: index,
          tense: w == 'had' ? Tense.past : Tense.present,
          aspect: Aspect.simple,
          voice: Voice.active,
        );
      }
    }
    if (_isBe(w)) return _readBe(tokens, index);

    if (_isVerbLike(tokens, index)) {
      return VerbGroup(
        startIndex: index,
        endIndex: index,
        mainIndex: index,
        tense: _simpleVerbTense(tokens[index]),
        aspect: Aspect.simple,
        voice: Voice.active,
      );
    }
    return null;
  }

  VerbGroup? _readUsedTo(List<StructureToken> tokens, int index) {
    if (tokens[index].normalized != 'used') return null;
    final previous = _previousWordIndex(tokens, index);
    if (previous != null && _isBe(tokens[previous].normalized)) return null;
    final toIndex = _nextWordIndex(tokens, index + 1);
    if (toIndex == null || tokens[toIndex].normalized != 'to') return null;
    final main = _nextWordIndex(tokens, toIndex + 1);
    if (main == null || !_isVerbLike(tokens, main)) {
      return null;
    }
    return VerbGroup(
      startIndex: index,
      endIndex: main,
      mainIndex: main,
      tense: Tense.past,
      aspect: Aspect.simple,
      voice: Voice.active,
      modal: 'used to',
    );
  }

  VerbGroup? _readSemiModal(List<StructureToken> tokens, int index) {
    final w = tokens[index].normalized;
    if (w == 'had') {
      final better = _nextWordIndex(tokens, index + 1);
      if (better != null && tokens[better].normalized == 'better') {
        final main = _nextVerbAfter(tokens, better + 1);
        if (main != null) {
          return VerbGroup(
            startIndex: index,
            endIndex: main,
            mainIndex: main,
            tense: Tense.modal,
            aspect: Aspect.simple,
            voice: Voice.active,
            modal: 'had better',
            negator: _firstNegator(tokens, index, main),
          );
        }
      }
    }
    if (w == 'would') {
      final next = _nextWordIndex(tokens, index + 1);
      if (next != null &&
          (tokens[next].normalized == 'rather' ||
              tokens[next].normalized == 'sooner')) {
        final main = _nextVerbAfter(tokens, next + 1);
        if (main != null) {
          return VerbGroup(
            startIndex: index,
            endIndex: main,
            mainIndex: main,
            tense: Tense.modal,
            aspect: Aspect.simple,
            voice: Voice.active,
            modal: 'would ${tokens[next].normalized}',
            negator: _firstNegator(tokens, index, main),
          );
        }
      }
    }
    return null;
  }

  VerbGroup? _readModal(List<StructureToken> tokens, int index) {
    var cursor = index + 1;
    final skippedSubject = _questionSubjectIndex(tokens, index);
    final question = skippedSubject != null;
    if (skippedSubject != null) cursor = skippedSubject + 1;
    cursor = _skipAdverbsAndNegators(tokens, cursor);

    final first = _nextWordIndex(tokens, cursor);
    if (first == null) return null;
    final modalWord = tokens[index].normalized;

    if (_isHave(tokens[first].normalized)) {
      var afterHave = _skipAdverbsAndNegators(tokens, first + 1);
      final v = _nextWordIndex(tokens, afterHave);
      if (v != null) {
        if (tokens[v].normalized == 'been') {
          final afterBeen = _nextWordIndex(tokens, _skipAdverbsAndNegators(tokens, v + 1));
          if (afterBeen != null && _isVing(tokens[afterBeen])) {
            return VerbGroup(
              startIndex: index,
              endIndex: afterBeen,
              mainIndex: afterBeen,
              tense: modalWord == 'will' || modalWord == 'shall'
                  ? Tense.future
                  : Tense.modal,
              aspect: Aspect.perfectContinuous,
              voice: Voice.active,
              modal: modalWord,
              negator: _firstNegator(tokens, index, afterBeen),
              questionInversion: question,
            );
          }
        }
        if (_isPastParticiple(tokens[v])) {
          return VerbGroup(
            startIndex: index,
            endIndex: v,
            mainIndex: v,
            tense: modalWord == 'will' || modalWord == 'shall'
                ? Tense.future
                : Tense.modal,
            aspect: Aspect.perfect,
            voice: Voice.active,
            modal: modalWord,
            negator: _firstNegator(tokens, index, v),
            questionInversion: question,
          );
        }
      }
    }

    if (_isBe(tokens[first].normalized)) {
      final afterBe = _nextWordIndex(tokens, _skipAdverbsAndNegators(tokens, first + 1));
      if (afterBe != null && _isVing(tokens[afterBe])) {
        return VerbGroup(
          startIndex: index,
          endIndex: afterBe,
          mainIndex: afterBe,
          tense: modalWord == 'will' || modalWord == 'shall'
              ? Tense.future
              : Tense.modal,
          aspect: Aspect.continuous,
          voice: Voice.active,
          modal: modalWord,
          negator: _firstNegator(tokens, index, afterBe),
          questionInversion: question,
        );
      }
      if (afterBe != null && _isPastParticiple(tokens[afterBe])) {
        return VerbGroup(
          startIndex: index,
          endIndex: afterBe,
          mainIndex: afterBe,
          tense: Tense.modal,
          aspect: Aspect.simple,
          voice: Voice.passive,
          modal: modalWord,
          negator: _firstNegator(tokens, index, afterBe),
          questionInversion: question,
        );
      }
    }

    final main = _nextVerbAfter(tokens, cursor);
    if (main == null) return null;
    return VerbGroup(
      startIndex: index,
      endIndex: main,
      mainIndex: main,
      tense: modalWord == 'will' || modalWord == 'shall' ? Tense.future : Tense.modal,
      aspect: Aspect.simple,
      voice: Voice.active,
      modal: modalWord,
      negator: _firstNegator(tokens, index, main),
      questionInversion: question,
    );
  }

  VerbGroup? _readDoSupport(List<StructureToken> tokens, int index) {
    var cursor = index + 1;
    final skippedSubject = _questionSubjectIndex(tokens, index);
    final question = skippedSubject != null;
    if (skippedSubject != null) cursor = skippedSubject + 1;
    cursor = _skipAdverbsAndNegators(tokens, cursor);
    final main = _nextVerbAfter(tokens, cursor);
    if (main == null) return null;
    return VerbGroup(
      startIndex: index,
      endIndex: main,
      mainIndex: main,
      tense: tokens[index].normalized == 'did' ? Tense.past : Tense.present,
      aspect: Aspect.simple,
      voice: Voice.active,
      negator: _firstNegator(tokens, index, main),
      questionInversion: question,
    );
  }

  VerbGroup? _readHaveOrBe(List<StructureToken> tokens, int index) {
    final w = tokens[index].normalized;
    var cursor = index + 1;
    final skippedSubject = _questionSubjectIndex(tokens, index);
    final question = skippedSubject != null;
    if (skippedSubject != null) cursor = skippedSubject + 1;
    cursor = _skipAdverbsAndNegators(tokens, cursor);
    final next = _nextWordIndex(tokens, cursor);

    if (next != null && tokens[next].normalized == 'been') {
      final afterBeen = _nextWordIndex(tokens, _skipAdverbsAndNegators(tokens, next + 1));
      if (afterBeen != null && _isVing(tokens[afterBeen])) {
        return VerbGroup(
          startIndex: index,
          endIndex: afterBeen,
          mainIndex: afterBeen,
          tense: w == 'had' ? Tense.past : Tense.present,
          aspect: Aspect.perfectContinuous,
          voice: Voice.active,
          negator: _firstNegator(tokens, index, afterBeen),
          questionInversion: question,
        );
      }
      return VerbGroup(
        startIndex: index,
        endIndex: next,
        mainIndex: next,
        tense: w == 'had' ? Tense.past : Tense.present,
        aspect: Aspect.perfect,
        voice: Voice.active,
        negator: _firstNegator(tokens, index, next),
        questionInversion: question,
      );
    }

    if (next != null && _isPastParticiple(tokens[next])) {
      return VerbGroup(
        startIndex: index,
        endIndex: next,
        mainIndex: next,
        tense: w == 'had' ? Tense.past : Tense.present,
        aspect: Aspect.perfect,
        voice: Voice.active,
        negator: _firstNegator(tokens, index, next),
        questionInversion: question,
      );
    }

    // Contracted 's is "is" unless the following word proves perfect aspect.
    if (w == "'s") return _readBe(tokens, index);
    return null;
  }

  VerbGroup? _readBe(List<StructureToken> tokens, int index) {
    var cursor = index + 1;
    final skippedSubject = _questionSubjectIndex(tokens, index);
    final question = skippedSubject != null;
    if (skippedSubject != null) cursor = skippedSubject + 1;
    cursor = _skipAdverbsAndNegators(tokens, cursor);
    final next = _nextWordIndex(tokens, cursor);

    if (next != null && tokens[next].normalized == 'going') {
      final to = _nextWordIndex(tokens, next + 1);
      final main = to == null ? null : _nextVerbAfter(tokens, to + 1);
      if (to != null && tokens[to].normalized == 'to' && main != null) {
        return VerbGroup(
          startIndex: index,
          endIndex: main,
          mainIndex: main,
          tense: Tense.future,
          aspect: Aspect.simple,
          voice: Voice.active,
          modal: 'be going to',
          negator: _firstNegator(tokens, index, main),
          questionInversion: question,
        );
      }
    }

    if (next != null && _isVing(tokens[next])) {
      return VerbGroup(
        startIndex: index,
        endIndex: next,
        mainIndex: next,
        tense: _beTense(tokens[index]),
        aspect: Aspect.continuous,
        voice: Voice.active,
        negator: _firstNegator(tokens, index, next),
        questionInversion: question,
      );
    }

    if (next != null && _isPastParticiple(tokens[next])) {
      return VerbGroup(
        startIndex: index,
        endIndex: next,
        mainIndex: next,
        tense: _beTense(tokens[index]),
        aspect: Aspect.simple,
        voice: Voice.passive,
        negator: _firstNegator(tokens, index, next),
        questionInversion: question,
      );
    }

    return VerbGroup(
      startIndex: index,
      endIndex: index,
      mainIndex: index,
      tense: _beTense(tokens[index]),
      aspect: Aspect.simple,
      voice: Voice.active,
      negator: _firstNegator(tokens, index, index),
      questionInversion: question,
    );
  }

  int? _questionSubjectIndex(List<StructureToken> tokens, int auxIndex) {
    if (!_looksLikeFrontedAux(tokens, auxIndex)) return null;
    final subject = _nextWordIndex(tokens, auxIndex + 1);
    if (subject == null || !_isSubjectLike(tokens[subject])) return null;
    return subject;
  }

  bool _looksLikeFrontedAux(List<StructureToken> tokens, int index) {
    final first = _firstWordIndex(tokens);
    if (first == index) return true;
    if (first != null && _isWh(tokens[first].normalized)) {
      final second = _nextWordIndex(tokens, first + 1);
      return second == index;
    }
    return false;
  }

  int? _nextVerbAfter(List<StructureToken> tokens, int from) {
    for (var i = from; i < tokens.length; i++) {
      if (tokens[i].isPunctuation) break;
      if (_isAdverb(tokens[i].normalized) || _isNegator(tokens[i].normalized)) {
        continue;
      }
      if (_isVerbLike(tokens, i)) return i;
      if (_isNounBoundary(tokens[i])) return null;
    }
    return null;
  }

  int _skipAdverbsAndNegators(List<StructureToken> tokens, int from) {
    var i = from;
    while (i < tokens.length) {
      if (tokens[i].isPunctuation) break;
      final w = tokens[i].normalized;
      if (_isAdverb(w) || _isNegator(w)) {
        i++;
        continue;
      }
      break;
    }
    return i;
  }

  int? _nextWordIndex(List<StructureToken> tokens, int from) {
    for (var i = from; i < tokens.length; i++) {
      if (tokens[i].isWord) return i;
    }
    return null;
  }

  int? _previousWordIndex(List<StructureToken> tokens, int from) {
    for (var i = from - 1; i >= 0; i--) {
      if (tokens[i].isWord) return i;
    }
    return null;
  }

  int? _firstWordIndex(List<StructureToken> tokens) => _nextWordIndex(tokens, 0);

  String? _firstNegator(List<StructureToken> tokens, int start, int end) {
    for (var i = start; i <= end && i < tokens.length; i++) {
      if (_isNegator(tokens[i].normalized)) return tokens[i].surface;
    }
    return null;
  }

  static Tense _beTense(StructureToken token) {
    switch (token.normalized) {
      case 'was':
      case 'were':
        return Tense.past;
      default:
        return Tense.present;
    }
  }

  static Tense _simpleVerbTense(StructureToken token) {
    final w = token.normalized;
    if (_pastForms.containsKey(w) ||
        (w.endsWith('ed') && w.length > 3 && !_adjectiveIng.contains(w))) {
      return Tense.past;
    }
    return Tense.present;
  }

  static bool isVerbLikeToken(List<StructureToken> tokens, int index) =>
      _isVerbLike(tokens, index);

  static bool isAdverbWord(String word) => _isAdverb(word);
  static bool isNegatorWord(String word) => _isNegator(word);
  static bool isPrepositionWord(String word) => _prepositions.contains(word);
  static bool isDeterminerWord(String word) => _determiners.contains(word);
  static bool isWhWord(String word) => _isWh(word);
  static bool isModalWord(String word) => _isModal(word);
  static bool isAuxWord(String word) => _isAux(word);
  static bool isBeWord(String word) => _isBe(word);
  static bool isHaveWord(String word) => _isHave(word);
  static bool isDoWord(String word) => _isDo(word);
  static bool isLinkingLemma(String lemma) => _linking.contains(lemma);
  static bool isDitransitiveLemma(String lemma) => _ditransitive.contains(lemma);
  static bool isComplexTransitiveLemma(String lemma) =>
      _complexTransitive.contains(lemma);
  static bool isSvoaLemma(String lemma) => _svoa.contains(lemma);
  static bool isParticleWord(String word) => _particles.contains(word);

  static String lemmaFor(StructureToken token) {
    final w = token.normalized;
    if (_isBe(w)) return 'be';
    if (_isHave(w)) return 'have';
    if (_isDo(w)) return 'do';
    if (token.lemma.isNotEmpty && token.lemma != w) return token.lemma;
    if (_pastForms.containsKey(w)) return _pastForms[w]!;
    if (_participleForms.containsKey(w)) return _participleForms[w]!;
    if (w.endsWith('ies') && w.length > 4) {
      return '${w.substring(0, w.length - 3)}y';
    }
    if (w.endsWith('ing') && w.length > 5) {
      final stem = w.substring(0, w.length - 3);
      if (stem.length > 2 && stem[stem.length - 1] == stem[stem.length - 2]) {
        return stem.substring(0, stem.length - 1);
      }
      if (_baseVerbs.contains('${stem}e')) return '${stem}e';
      return stem;
    }
    if (w.endsWith('ed') && w.length > 4) {
      final stem = w.substring(0, w.length - 2);
      if (_baseVerbs.contains('${stem}e')) return '${stem}e';
      return stem;
    }
    if (w.endsWith('es') && w.length > 3) {
      final base = w.substring(0, w.length - 2);
      if (_baseVerbs.contains(base)) return base;
    }
    if (w.endsWith('s') && w.length > 3) return w.substring(0, w.length - 1);
    return w;
  }

  static bool _isVerbLike(
    List<StructureToken> tokens,
    int index,
  ) {
    if (index < 0 || index >= tokens.length) return false;
    final token = tokens[index];
    final w = token.normalized;
    if (w.isEmpty || token.isPunctuation) return false;
    if (_isAux(w) || _isModal(w)) return true;
    if (_adjectiveIng.contains(w)) return false;
    if (_baseVerbs.contains(w) || _pastForms.containsKey(w) || _participleForms.containsKey(w)) {
      return true;
    }
    if (_isNonVerbFunctionWord(w)) return false;
    if (token.category == GrammarCategory.verb) return true;
    if (_isVing(token) || _isPastParticiple(token)) return true;
    if (index > 0) {
      final prev = tokens[index - 1].normalized;
      if (_isModal(prev) || _isDo(prev) || prev == 'to' || prev == 'rather') {
        return true;
      }
      if (_isSubjectLike(tokens[index - 1]) &&
          !isDeterminerWord(tokens[index - 1].normalized) &&
          (w.endsWith('s') || w.endsWith('ed'))) {
        return true;
      }
    }
    return false;
  }



  static bool _isSubjectLike(StructureToken token) {
    final w = token.normalized;
    return token.category == GrammarCategory.pronoun ||
        token.category == GrammarCategory.noun ||
        token.category == GrammarCategory.unknown ||
        _properLike(token) ||
        _subjectPronouns.contains(w) ||
        _negativePronouns.contains(w);
  }

  static bool _isNonVerbFunctionWord(String w) =>
      _determiners.contains(w) ||
      _prepositions.contains(w) ||
      _subjectPronouns.contains(w) ||
      _negativePronouns.contains(w) ||
      const {'me', 'him', 'her', 'us', 'them', 'whom', 'which', 'what', 'who'}
          .contains(w);

  static bool _properLike(StructureToken token) =>
      token.category == GrammarCategory.unknown &&
      token.surface.isNotEmpty &&
      token.surface[0].toUpperCase() == token.surface[0] &&
      !_isWh(token.normalized);

  static bool _isNounBoundary(StructureToken token) {
    final w = token.normalized;
    return token.category == GrammarCategory.noun ||
        token.category == GrammarCategory.pronoun ||
        _determiners.contains(w) ||
        _prepositions.contains(w);
  }

  static bool _isVing(StructureToken token) {
    final w = token.normalized;
    if (!w.endsWith('ing') || w.length <= 4) return false;
    if (_adjectiveIng.contains(w)) return false;
    return true;
  }

  static bool _isPastParticiple(StructureToken token) {
    final w = token.normalized;
    if (_participleForms.containsKey(w)) return true;
    if (w.endsWith('ed') && w.length > 3) return true;
    if (token.subCategory == 'past_or_participle') return true;
    return false;
  }

  static bool _isAux(String w) => _isBe(w) || _isHave(w) || _isDo(w) || w == "'s";
  static bool _isBe(String w) => _beForms.contains(w) || w == "'s";
  static bool _isHave(String w) => _haveForms.contains(w);
  static bool _isDo(String w) => _doForms.contains(w);
  static bool _isModal(String w) => _modals.contains(w);
  static bool _isWh(String w) => _whWords.contains(w);
  static bool _isAdverb(String w) => _adverbs.contains(w) ||
      (w.endsWith('ly') && w.length > 4 && !_adverbExceptions.contains(w));
  static bool _isNegator(String w) => _negators.contains(w) || w == "n't";

  static const Set<String> _beForms = {
    'am', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
  };
  static const Set<String> _haveForms = {'have', 'has', 'had', 'having'};
  static const Set<String> _doForms = {'do', 'does', 'did'};
  static const Set<String> _modals = {
    'can', 'could', 'may', 'might', 'must', 'shall', 'should', 'will', 'would',
    'ought', 'need', 'dare',
  };
  static const Set<String> _negators = {
    'not', 'never', 'no', 'nothing', 'nobody', 'none', 'neither', 'nor',
    'hardly', 'scarcely', 'barely', 'rarely', 'seldom', 'without',
  };
  static const Set<String> _whWords = {
    'what', 'who', 'whom', 'whose', 'which', 'when', 'where', 'why', 'how',
  };
  static const Set<String> _determiners = {
    'a', 'an', 'the', 'this', 'that', 'these', 'those', 'my', 'your', 'his',
    'her', 'its', 'our', 'their', 'whose', 'some', 'any', 'no', 'every',
    'each', 'either', 'neither', 'both', 'all', 'most', 'few', 'little',
    'many', 'much', 'several', 'enough', 'another', 'such',
  };
  static const Set<String> _prepositions = {
    'about', 'above', 'across', 'after', 'against', 'along', 'among', 'around',
    'as', 'at', 'before', 'behind', 'below', 'beneath', 'beside', 'between',
    'beyond', 'by', 'despite', 'down', 'during', 'except', 'for', 'from', 'in',
    'inside', 'into', 'like', 'near', 'of', 'off', 'on', 'onto', 'out',
    'outside', 'over', 'past', 'since', 'through', 'to', 'toward', 'towards',
    'under', 'until', 'up', 'upon', 'with', 'within', 'without', 'than',
  };
  static const Set<String> _particles = {
    'up', 'down', 'off', 'out', 'in', 'on', 'over', 'away', 'back', 'through',
    'after',
  };
  static const Set<String> _adverbs = {
    'here', 'there', 'now', 'then', 'yesterday', 'today', 'tomorrow', 'soon',
    'later', 'early', 'late', 'again', 'outside', 'home', 'abroad', 'always',
    'usually', 'often', 'sometimes', 'never', 'ever', 'already', 'still',
    'just', 'probably', 'certainly', 'definitely', 'very', 'really', 'quite',
    'rather', 'so', 'too', 'extremely', 'almost', 'nearly', 'well', 'twice',
  };
  static const Set<String> _adverbExceptions = {
    'friendly', 'lonely', 'lovely', 'family', 'only', 'silly', 'ugly',
  };
  static const Set<String> _subjectPronouns = {
    'i', 'you', 'he', 'she', 'it', 'we', 'they', 'there',
  };
  static const Set<String> _negativePronouns = {
    'nobody', 'nothing', 'none', 'neither',
  };
  static const Set<String> _adjectiveIng = {
    'boring', 'interesting', 'amazing', 'exciting', 'tiring', 'surprising',
    'confusing', 'disappointing',
  };

  static const Map<String, String> _pastForms = {
    'was': 'be', 'were': 'be', 'had': 'have', 'did': 'do', 'went': 'go',
    'gave': 'give', 'saw': 'see', 'came': 'come', 'made': 'make',
    'said': 'say', 'told': 'tell', 'bought': 'buy', 'built': 'build',
    'broke': 'break', 'met': 'meet', 'left': 'leave', 'put': 'put',
    'stayed': 'stay', 'arrived': 'arrive', 'rained': 'rain', 'ran': 'run',
    'wrote': 'write', 'read': 'read', 'knew': 'know', 'thought': 'think',
    'stole': 'steal', 'ate': 'eat', 'sang': 'sing', 'swam': 'swim',
  };

  static const Map<String, String> _participleForms = {
    'been': 'be', 'done': 'do', 'gone': 'go', 'given': 'give', 'seen': 'see',
    'come': 'come', 'made': 'make', 'said': 'say', 'told': 'tell',
    'bought': 'buy', 'built': 'build', 'broken': 'break', 'left': 'leave',
    'put': 'put', 'written': 'write', 'known': 'know', 'stolen': 'steal',
    'eaten': 'eat', 'born': 'bear', 'finished': 'finish', 'submitted': 'submit',
  };

  static const Set<String> _baseVerbs = {
    'ask', 'arrive', 'be', 'become', 'break', 'bring', 'build', 'buy', 'call',
    'cancel', 'close', 'come', 'drive', 'eat', 'elect', 'enjoy', 'feel',
    'find', 'finish', 'fly', 'follow', 'get', 'give', 'go', 'grow', 'have',
    'help', 'keep', 'know', 'learn', 'leave', 'like', 'live', 'look', 'make',
    'meet', 'need', 'open', 'pick', 'play', 'put', 'rain', 'read', 'run',
    'say', 'see', 'seem', 'sing', 'sit', 'sleep', 'speak', 'stand', 'start',
    'stay', 'submit', 'swim', 'take', 'talk', 'teach', 'tell', 'think',
    'touch', 'turn', 'use', 'visit', 'wait', 'walk', 'want', 'watch', 'wish',
    'work', 'write',
  };

  static const Set<String> _linking = {
    'be', 'become', 'seem', 'look', 'feel', 'taste', 'sound', 'smell', 'get',
    'grow', 'turn', 'remain', 'stay', 'appear', 'prove',
  };
  static const Set<String> _ditransitive = {
    'give', 'send', 'tell', 'show', 'offer', 'bring', 'teach', 'buy', 'write',
    'read', 'pass', 'lend', 'promise', 'ask', 'make', 'cost',
  };
  static const Set<String> _complexTransitive = {
    'make', 'call', 'name', 'consider', 'find', 'keep', 'leave', 'elect',
    'appoint', 'think', 'believe', 'declare', 'prove',
  };
  static const Set<String> _svoa = {
    'put', 'place', 'set', 'lay', 'send', 'bring', 'take', 'throw', 'hang',
    'keep', 'drive', 'lead', 'carry', 'invite',
  };
}
