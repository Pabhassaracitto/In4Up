import '../models/grammar_category.dart';
import '../models/sentence_structure.dart';
import 'verb_group_reader.dart';

class SentenceTypingResult {
  final SentenceStructure? sentence;
  final ClauseRole? clauseRole;
  final int? conditionalType;

  const SentenceTypingResult({
    this.sentence,
    this.clauseRole,
    this.conditionalType,
  });
}

class SentenceTyper {
  SentenceTyper({VerbGroupReader? verbReader})
      : _verbReader = verbReader ?? const VerbGroupReader();

  final VerbGroupReader _verbReader;

  SentenceTypingResult analyze(
    List<StructureToken> tokens, {
    required int anchorIndex,
    required int spanStart,
    required int spanEnd,
  }) {
    final groups = _verbReader.readAll(tokens);
    final mainGroup = _selectMainGroup(tokens, groups);
    final type = _sentenceType(tokens);
    final question = _questionKind(tokens, type);
    final polarityData = _polarity(tokens, mainGroup, question);
    final pattern = mainGroup == null ? null : _pattern(tokens, mainGroup, type);
    final clauseRole = _clauseRole(tokens, anchorIndex, mainGroup);
    final conditional = _conditionalType(tokens, groups);

    final sentence = SentenceStructure(
      type: type,
      question: question,
      polarity: polarityData.$1,
      negator: polarityData.$2,
      tense: type == SentenceType.imperative
          ? Tense.none
          : (mainGroup?.tense ?? Tense.none),
      aspect: mainGroup?.aspect ?? Aspect.simple,
      voice: mainGroup?.voice ?? Voice.active,
      modal: mainGroup?.modal,
      pattern: pattern,
      spanStart: spanStart,
      spanEnd: spanEnd,
      confidence: mainGroup == null ? 0.62 : 0.86,
    );

    return SentenceTypingResult(
      sentence: sentence,
      clauseRole: clauseRole,
      conditionalType: conditional,
    );
  }

  VerbGroup? _selectMainGroup(List<StructureToken> tokens, List<VerbGroup> groups) {
    if (groups.isEmpty) return null;
    if (_isItCleft(tokens)) return groups.first;
    if (groups.length >= 2 &&
        groups.first.length == 1 &&
        tokens[groups.first.mainIndex].normalized.endsWith('ing')) {
      return groups[1];
    }

    final comma = _firstPunctuation(tokens, {',', ';', ':'});
    final first = _firstWord(tokens);
    if (first != null && _initialAdverbialStarter(tokens[first].normalized) && comma != null) {
      final afterComma = groups.where((g) => g.startIndex > comma).toList();
      if (afterComma.isNotEmpty) return afterComma.first;
    }

    final relative = _firstRelativeMarker(tokens);
    if (relative != null) {
      final before = groups.where((g) => g.startIndex < relative).toList();
      if (before.isNotEmpty) return before.first;
      final after = groups.where((g) => g.startIndex > relative).toList();
      if (after.length >= 2) return after.last;
    }

    final nominalThat = _nominalThatIndex(tokens);
    if (nominalThat != null) {
      final before = groups.where((g) => g.startIndex < nominalThat).toList();
      if (before.isNotEmpty) return before.first;
    }

    if (first != null &&
        (VerbGroupReader.isAuxWord(tokens[first].normalized) ||
            VerbGroupReader.isModalWord(tokens[first].normalized))) {
      return groups.first;
    }

    if (first != null && VerbGroupReader.isWhWord(tokens[first].normalized)) {
      final next = _nextWord(tokens, first + 1);
      if (next != null &&
          (VerbGroupReader.isAuxWord(tokens[next].normalized) ||
              VerbGroupReader.isModalWord(tokens[next].normalized))) {
        return groups.first;
      }
    }

    final subjectBacked = groups.where((group) {
      final previous = _previousWord(tokens, group.startIndex);
      return previous != null && _isSubjectCandidate(tokens[previous]);
    }).toList();
    if (subjectBacked.isNotEmpty) return subjectBacked.first;

    return groups.first;
  }

  SentenceType _sentenceType(List<StructureToken> tokens) {
    final first = _firstWord(tokens);
    if (first == null) return SentenceType.declarative;
    final firstWord = tokens[first].normalized;
    final last = _lastWord(tokens);
    final endsBang = _endsWith(tokens, '!');
    final endsQuestion = _endsWith(tokens, '?');

    if (endsBang && (firstWord == 'what' || firstWord == 'how')) {
      return SentenceType.exclamative;
    }
    if (_isTagQuestion(tokens)) return SentenceType.declarative;
    if (_looksImperative(tokens, first)) return SentenceType.imperative;
    if (endsQuestion) return SentenceType.interrogative;
    if (VerbGroupReader.isAuxWord(firstWord) || VerbGroupReader.isModalWord(firstWord)) {
      return SentenceType.interrogative;
    }
    if (VerbGroupReader.isWhWord(firstWord)) {
      final next = _nextWord(tokens, first + 1);
      if (next != null &&
          (VerbGroupReader.isAuxWord(tokens[next].normalized) ||
              VerbGroupReader.isModalWord(tokens[next].normalized))) {
        return SentenceType.interrogative;
      }
    }
    if (last != null && tokens[last].surface.endsWith('?')) return SentenceType.interrogative;
    return SentenceType.declarative;
  }

  QuestionKind _questionKind(List<StructureToken> tokens, SentenceType type) {
    if (_isTagQuestion(tokens)) return QuestionKind.tag;
    if (type != SentenceType.interrogative) return QuestionKind.none;
    final first = _firstWord(tokens);
    if (first != null && VerbGroupReader.isWhWord(tokens[first].normalized)) {
      return QuestionKind.wh;
    }
    if (tokens.any((t) => t.normalized == 'or')) return QuestionKind.alternative;
    return QuestionKind.yesNo;
  }

  (Polarity, String?) _polarity(
    List<StructureToken> tokens,
    VerbGroup? mainGroup,
    QuestionKind question,
  ) {
    final tagStart = question == QuestionKind.tag ? _firstPunctuation(tokens, {','}) : null;
    final end = tagStart ?? tokens.length;
    for (var i = 0; i < end; i++) {
      final w = tokens[i].normalized;
      if (VerbGroupReader.isNegatorWord(w) || _negativePronouns.contains(w)) {
        return (Polarity.negative, tokens[i].surface);
      }
    }
    if (mainGroup?.negator != null) return (Polarity.negative, mainGroup!.negator);
    return (Polarity.affirmative, null);
  }

  ClauseRole? _clauseRole(
    List<StructureToken> tokens,
    int anchorIndex,
    VerbGroup? mainGroup,
  ) {
    if (anchorIndex < 0 || anchorIndex >= tokens.length) return null;
    final comma = _firstPunctuation(tokens, {',', ';', ':'});
    final first = _firstWord(tokens);
    if (first != null &&
        comma != null &&
        anchorIndex < comma &&
        _initialAdverbialStarter(tokens[first].normalized)) {
      return ClauseRole.adverbial;
    }

    final that = _nearestMarkerBefore(tokens, anchorIndex, {'that', 'whether'});
    if (that != null && _hasVerbBefore(tokens, that)) return ClauseRole.nominal;

    final relative = _nearestMarkerBefore(tokens, anchorIndex, _relativeMarkers);
    if (relative != null) return ClauseRole.relative;

    // Precision-first zero-relative heuristic: anchor verb sits between an
    // initial noun phrase and a later main linking verb.
    if (mainGroup != null && anchorIndex < mainGroup.startIndex) {
      final firstMain = mainGroup.startIndex;
      if (firstMain - anchorIndex <= 7 && _hasNounBefore(tokens, anchorIndex)) {
        return ClauseRole.relative;
      }
    }
    return null;
  }

  int? _conditionalType(List<StructureToken> tokens, List<VerbGroup> groups) {
    final first = _firstWord(tokens);
    if (first == null || tokens[first].normalized != 'if') return null;
    final comma = _firstPunctuation(tokens, {','});
    if (comma == null) return null;
    final mainGroups = groups.where((g) => g.startIndex > comma).toList();
    if (mainGroups.isEmpty) return null;
    final main = mainGroups.first;
    if (main.tense == Tense.future) return 1;
    if (main.modal == 'would' && groups.any((g) => g.tense == Tense.past && g.startIndex < comma)) {
      return 2;
    }
    return 0;
  }

  String? _pattern(
    List<StructureToken> tokens,
    VerbGroup group,
    SentenceType type,
  ) {
    final first = _firstWord(tokens);
    if (first != null && tokens[first].normalized == 'there') return 'There+V+S';
    if (_isItCleft(tokens)) return 'IT-CLEFT';
    if (type == SentenceType.imperative) {
      return _hasObjectAfter(tokens, group) ? 'VO' : 'V';
    }

    final lemma = VerbGroupReader.lemmaFor(tokens[group.mainIndex]);
    if (VerbGroupReader.isLinkingLemma(lemma) && !_isPhrasalVerbUse(tokens, group)) {
      final complementStart = _nextWord(tokens, group.endIndex + 1);
      if (complementStart != null && _isAdverbialStart(tokens[complementStart])) {
        return 'SVA';
      }
      return 'SVC';
    }

    final objectCount = _objectCountAfter(tokens, group);
    if (VerbGroupReader.isComplexTransitiveLemma(lemma) && _hasObjectComplement(tokens, group)) {
      return 'SVOC';
    }
    if (VerbGroupReader.isDitransitiveLemma(lemma) && objectCount >= 2) {
      return 'SVOO';
    }
    if (VerbGroupReader.isSvoaLemma(lemma) && objectCount >= 1 &&
        _hasAdverbialAfter(tokens, group, skipObject: true)) {
      return 'SVOA';
    }
    if (objectCount >= 1) return 'SVO';
    if (_hasAdverbialAfter(tokens, group, skipObject: false) && _requiresAdverbial(lemma)) {
      return 'SVA';
    }
    return 'SV';
  }

  bool _hasObjectAfter(List<StructureToken> tokens, VerbGroup group) =>
      _objectCountAfter(tokens, group) > 0;

  int _objectCountAfter(List<StructureToken> tokens, VerbGroup group) {
    var i = _afterVerbCluster(tokens, group);
    var count = 0;
    while (i != null && i < tokens.length) {
      final token = tokens[i];
      final w = token.normalized;
      if (token.isPunctuation || _clauseBreaks.contains(w)) break;
      if (w == 'to' && _nextWord(tokens, i + 1) != null) {
        count++;
        break;
      }
      if (VerbGroupReader.isParticleWord(w)) {
        final afterParticle = _nextWord(tokens, i + 1);
        if (afterParticle != null && _objectStarter(tokens[afterParticle])) {
          count++;
        }
        break;
      }
      if (_isAdverbialStart(token)) break;
      if (_objectStarter(token)) {
        count++;
        i = _afterObject(tokens, i);
        continue;
      }
      if (VerbGroupReader.isAdverbWord(w)) {
        i = _nextWord(tokens, i + 1);
        continue;
      }
      break;
    }
    return count;
  }

  bool _hasObjectComplement(List<StructureToken> tokens, VerbGroup group) {
    var i = _afterVerbCluster(tokens, group);
    if (i == null || !_objectStarter(tokens[i])) return false;
    i = _afterObject(tokens, i);
    if (i == null) return false;
    if (tokens[i].isPunctuation || _isAdverbialStart(tokens[i])) return false;
    final w = tokens[i].normalized;
    return _adjectiveComplements.contains(w) ||
        (_objectStarter(tokens[i]) && !VerbGroupReader.isDeterminerWord(w));
  }

  int? _afterObject(List<StructureToken> tokens, int start) {
    var i = _nextWord(tokens, start + 1);
    var last = start;
    while (i != null && i < tokens.length) {
      final token = tokens[i];
      if (token.isPunctuation || _clauseBreaks.contains(token.normalized)) break;
      if (_isAdverbialStart(token)) break;
      if (VerbGroupReader.isAdverbWord(token.normalized)) break;
      if (last == start && tokens[start].category == GrammarCategory.pronoun) {
        if (VerbGroupReader.isDeterminerWord(token.normalized) ||
            _adjectiveComplements.contains(token.normalized)) {
          break;
        }
      }
      last = i;
      i = _nextWord(tokens, i + 1);
      if (i != null &&
          VerbGroupReader.isDeterminerWord(tokens[i].normalized) &&
          _objectStarter(tokens[last])) {
        break;
      }
    }
    return _nextWord(tokens, last + 1);
  }

  bool _hasAdverbialAfter(
    List<StructureToken> tokens,
    VerbGroup group, {
    required bool skipObject,
  }) {
    var i = _afterVerbCluster(tokens, group);
    if (skipObject && i != null && _objectStarter(tokens[i])) {
      i = _afterObject(tokens, i);
    }
    while (i != null && i < tokens.length) {
      final token = tokens[i];
      if (token.isPunctuation || _clauseBreaks.contains(token.normalized)) return false;
      if (_isAdverbialStart(token)) return true;
      if (VerbGroupReader.isAdverbWord(token.normalized)) return true;
      i = _nextWord(tokens, i + 1);
    }
    return false;
  }

  int? _afterVerbCluster(List<StructureToken> tokens, VerbGroup group) {
    var cursor = group.endIndex + 1;
    final next = _nextWord(tokens, cursor);
    if (next != null && VerbGroupReader.isParticleWord(tokens[next].normalized)) {
      cursor = next + 1;
    }
    return _nextWord(tokens, cursor);
  }

  bool _objectStarter(StructureToken token) {
    final w = token.normalized;
    if (_negativePronouns.contains(w)) return true;
    if (w.endsWith('ing') && w.length > 4) return true;
    if (token.category == GrammarCategory.pronoun || token.category == GrammarCategory.noun) return true;
    if (VerbGroupReader.isDeterminerWord(w)) return true;
    if (_nounLikeWords.contains(w) || _adjectiveComplements.contains(w)) return true;
    return token.category == GrammarCategory.unknown &&
        !VerbGroupReader.isAdverbWord(w) &&
        !VerbGroupReader.isPrepositionWord(w) &&
        !VerbGroupReader.isAuxWord(w) &&
        !VerbGroupReader.isModalWord(w);
  }

  bool _isAdverbialStart(StructureToken token) =>
      VerbGroupReader.isPrepositionWord(token.normalized) ||
      _locativeAdverbs.contains(token.normalized);

  bool _requiresAdverbial(String lemma) => _adverbialVerbs.contains(lemma);

  bool _isPhrasalVerbUse(List<StructureToken> tokens, VerbGroup group) {
    if (VerbGroupReader.isBeWord(tokens[group.mainIndex].normalized)) return false;
    final next = _nextWord(tokens, group.endIndex + 1);
    return next != null && VerbGroupReader.isParticleWord(tokens[next].normalized);
  }

  bool _looksImperative(List<StructureToken> tokens, int first) {
    var start = first;
    final w = tokens[start].normalized;
    if (w == 'please' || w == 'never' || w == 'always' || w == 'just' || w == 'kindly') {
      final next = _nextWord(tokens, start + 1);
      if (next == null) return false;
      start = next;
    }
    final word = tokens[start].normalized;
    if (word == "let's") return true;
    if (VerbGroupReader.isDoWord(word)) {
      final next = _nextWord(tokens, start + 1);
      if (next != null && VerbGroupReader.isNegatorWord(tokens[next].normalized)) return true;
      return false;
    }
    if (VerbGroupReader.isAuxWord(word) || VerbGroupReader.isModalWord(word)) {
      return false;
    }
    if (word.endsWith('ing')) return false;
    if (VerbGroupReader.isVerbLikeToken(tokens, start) && !_hasExplicitSubjectBefore(tokens, start)) {
      return true;
    }
    return false;
  }

  bool _isSubjectCandidate(StructureToken token) {
    final w = token.normalized;
    if (VerbGroupReader.isWhWord(w)) return false;
    if (_negativePronouns.contains(w)) return true;
    if (token.category == GrammarCategory.pronoun || token.category == GrammarCategory.noun) {
      return true;
    }
    return token.category == GrammarCategory.unknown &&
        !VerbGroupReader.isAdverbWord(w) &&
        !VerbGroupReader.isPrepositionWord(w) &&
        !VerbGroupReader.isDeterminerWord(w);
  }

  bool _hasExplicitSubjectBefore(List<StructureToken> tokens, int verbIndex) {
    for (var i = 0; i < verbIndex; i++) {
      if (!tokens[i].isWord) continue;
      final w = tokens[i].normalized;
      if (w == 'please' || w == 'never' || w == 'always' || w == 'just') continue;
      return true;
    }
    return false;
  }

  bool _isTagQuestion(List<StructureToken> tokens) {
    final comma = _firstPunctuation(tokens, {','});
    if (comma == null) return false;
    final after = tokens.skip(comma + 1).where((t) => t.isWord).toList();
    if (after.length < 2 || after.length > 4) return false;
    final first = after.first.normalized;
    return VerbGroupReader.isAuxWord(first) ||
        VerbGroupReader.isModalWord(first) ||
        VerbGroupReader.isNegatorWord(first);
  }

  bool _isItCleft(List<StructureToken> tokens) {
    final first = _firstWord(tokens);
    if (first == null || tokens[first].normalized != 'it') return false;
    final second = _nextWord(tokens, first + 1);
    if (second == null || !VerbGroupReader.isBeWord(tokens[second].normalized)) return false;
    return tokens.any((t) => t.normalized == 'who' || t.normalized == 'that');
  }

  bool _hasVerbBefore(List<StructureToken> tokens, int index) {
    for (var i = 0; i < index; i++) {
      if (VerbGroupReader.isVerbLikeToken(tokens, i)) return true;
    }
    return false;
  }

  bool _hasNounBefore(List<StructureToken> tokens, int index) {
    for (var i = 0; i < index; i++) {
      if (tokens[i].category == GrammarCategory.noun ||
          tokens[i].category == GrammarCategory.pronoun ||
          tokens[i].category == GrammarCategory.unknown) {
        return true;
      }
    }
    return false;
  }

  int? _nearestMarkerBefore(List<StructureToken> tokens, int index, Set<String> markers) {
    for (var i = index - 1; i >= 0; i--) {
      if (tokens[i].isPunctuation) break;
      if (markers.contains(tokens[i].normalized)) return i;
    }
    return null;
  }

  int? _nominalThatIndex(List<StructureToken> tokens) {
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].normalized == 'that' || tokens[i].normalized == 'whether') {
        final prev = _previousWord(tokens, i);
        if (prev != null && VerbGroupReader.isVerbLikeToken(tokens, prev)) return i;
      }
    }
    return null;
  }

  int? _firstRelativeMarker(List<StructureToken> tokens) {
    for (var i = 0; i < tokens.length; i++) {
      if (_relativeMarkers.contains(tokens[i].normalized)) return i;
    }
    return null;
  }

  bool _initialAdverbialStarter(String w) =>
      w == 'if' || w == 'when' || w == 'because' || w == 'although' ||
      w == 'while' || w == 'unless' || w == 'until' || w == 'since';

  bool _endsWith(List<StructureToken> tokens, String punctuation) =>
      tokens.isNotEmpty && tokens.last.surface == punctuation;

  int? _firstPunctuation(List<StructureToken> tokens, Set<String> chars) {
    for (var i = 0; i < tokens.length; i++) {
      if (chars.contains(tokens[i].surface)) return i;
    }
    return null;
  }

  int? _firstWord(List<StructureToken> tokens) => _nextWord(tokens, 0);

  int? _lastWord(List<StructureToken> tokens) {
    for (var i = tokens.length - 1; i >= 0; i--) {
      if (tokens[i].isWord) return i;
    }
    return null;
  }

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

  static const Set<String> _relativeMarkers = {
    'who', 'whom', 'whose', 'which', 'that', 'where',
  };
  static const Set<String> _negativePronouns = {'nobody', 'nothing', 'none', 'neither'};
  static const Set<String> _clauseBreaks = {
    'and', 'or', 'but', 'so',
    'if', 'when', 'because', 'although', 'while', 'unless', 'until', 'since',
    'that', 'who', 'which', 'where',
  };
  static const Set<String> _locativeAdverbs = {
    'home', 'here', 'there', 'outside', 'abroad', 'tonight', 'today',
    'tomorrow', 'yesterday', 'early', 'late',
  };
  static const Set<String> _adverbialVerbs = {'stay', 'put', 'live', 'go'};
  static const Set<String> _adjectiveComplements = {
    'happy', 'sad', 'ready', 'old', 'young', 'beautiful', 'interesting',
    'boring', 'smart', 'kind', 'good', 'tall', 'thin', 'president',
  };
  static const Set<String> _nounLikeWords = {
    'coffee', 'tea', 'lunch', 'dream', 'homework', 'movie', 'doctor', 'door',
    'wires', 'beach', 'letter', 'mary', 'paris', 'table', 'teacher', 'english',
    'books', 'uncle', 'rain', 'light', 'baby', 'keys', 'bread', 'milk', 'report',
    'friday', 'car', 'school', 'cousin', 'party', 'fish', 'grandmother', 'window',
    'storm', 'story', 'hobby', 'button', 'machine', 'answer', 'plan', 'trip',
  };
}
