import '../models/grammar_category.dart';

class GrammarLexiconEntry {
  final String normalized;
  final GrammarCategory category;
  final String? lemma;
  final String? subCategory;
  final double confidence;
  final String source;

  const GrammarLexiconEntry({
    required this.normalized,
    required this.category,
    this.lemma,
    this.subCategory,
    this.confidence = 0.85,
    this.source = 'phaseA_manual',
  });

  Map<String, dynamic> toJson() => {
        'normalized': normalized,
        'category': category.name,
        'lemma': lemma,
        'subCategory': subCategory,
        'confidence': confidence,
        'source': source,
      };

  factory GrammarLexiconEntry.fromJson(Map<String, dynamic> json) {
    return GrammarLexiconEntry(
      normalized: (json['normalized'] ?? '').toString(),
      category: GrammarCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => GrammarCategory.unknown,
      ),
      lemma: json['lemma']?.toString(),
      subCategory: json['subCategory']?.toString(),
      confidence: ((json['confidence'] as num?) ?? 0.85).toDouble(),
      source: (json['source'] ?? 'phaseA_import').toString(),
    );
  }
}

class GrammarLexiconService {
  GrammarLexiconService._() {
    _seedBuiltins();
  }
  static final GrammarLexiconService instance = GrammarLexiconService._();

  final Map<String, GrammarLexiconEntry> _entries = <String, GrammarLexiconEntry>{};

  bool get isEmpty => _entries.isEmpty;
  int get entryCount => _entries.length;

  void clear() {
    _entries.clear();
    _seedBuiltins();
  }

  GrammarLexiconEntry? lookup(String token) {
    final normalized = _normalize(token);
    if (normalized.isEmpty) return null;
    return _entries[normalized] ?? _lookupInflected(normalized);
  }

  void registerEntries(Iterable<GrammarLexiconEntry> entries) {
    for (final entry in entries) {
      final normalized = _normalize(entry.normalized);
      if (normalized.isEmpty) continue;
      _entries[normalized] = GrammarLexiconEntry(
        normalized: normalized,
        category: entry.category,
        lemma: entry.lemma ?? normalized,
        subCategory: entry.subCategory,
        confidence: entry.confidence,
        source: entry.source,
      );
    }
  }

  void registerFlatCategoryMap(
    Iterable<String> tokens,
    GrammarCategory category, {
    String source = 'phaseA_flat_map',
    double confidence = 0.9,
  }) {
    registerEntries(
      tokens.map(
        (token) => GrammarLexiconEntry(
          normalized: token,
          category: category,
          lemma: _normalize(token),
          confidence: confidence,
          source: source,
        ),
      ),
    );
  }

  Iterable<GrammarLexiconEntry> dumpEntries() => _entries.values;

  String _normalize(String token) {
    return token.toLowerCase().replaceAll(RegExp(r"[^\w']"), '').trim();
  }

  GrammarLexiconEntry? _lookupInflected(String normalized) {
    for (final candidate in _deriveCandidates(normalized)) {
      final base = _entries[candidate.base];
      if (base == null) continue;
      if (!_canInflect(base.category)) continue;
      return GrammarLexiconEntry(
        normalized: normalized,
        category: base.category,
        lemma: base.lemma ?? candidate.base,
        subCategory: candidate.subCategory,
        confidence: candidate.confidence,
        source: 'phaseA_inflection_${base.source}',
      );
    }
    return null;
  }

  List<_DerivedCandidate> _deriveCandidates(String normalized) {
    final results = <_DerivedCandidate>[];

    void add(String base, String subCategory, double confidence) {
      final clean = _normalize(base);
      if (clean.isEmpty || clean == normalized) return;
      results.add(_DerivedCandidate(clean, subCategory, confidence));
    }

    if (normalized.length > 3 && normalized.endsWith('ies')) {
      add('${normalized.substring(0, normalized.length - 3)}y', 'plural_or_3sg', 0.76);
    }
    if (normalized.length > 2 && normalized.endsWith('es')) {
      add(normalized.substring(0, normalized.length - 2), 'plural_or_3sg', 0.72);
      add(normalized.substring(0, normalized.length - 1), 'plural_or_3sg', 0.68);
    }
    if (normalized.length > 2 && normalized.endsWith('s')) {
      add(normalized.substring(0, normalized.length - 1), 'plural_or_3sg', 0.7);
    }
    if (normalized.length > 4 && normalized.endsWith('ing')) {
      final stem = normalized.substring(0, normalized.length - 3);
      add(stem, 'gerund_or_participle', 0.75);
      add('${stem}e', 'gerund_or_participle', 0.73);
      if (stem.length > 2 && stem[stem.length - 1] == stem[stem.length - 2]) {
        add(stem.substring(0, stem.length - 1), 'gerund_or_participle', 0.71);
      }
    }
    if (normalized.length > 3 && normalized.endsWith('ed')) {
      final stem = normalized.substring(0, normalized.length - 2);
      add(stem, 'past_or_participle', 0.75);
      add('${stem}e', 'past_or_participle', 0.73);
      if (stem.length > 2 && stem[stem.length - 1] == stem[stem.length - 2]) {
        add(stem.substring(0, stem.length - 1), 'past_or_participle', 0.7);
      }
    }
    if (normalized.length > 3 && normalized.endsWith('er')) {
      add(normalized.substring(0, normalized.length - 2), 'comparative', 0.62);
      add('${normalized.substring(0, normalized.length - 2)}e', 'comparative', 0.6);
    }
    if (normalized.length > 4 && normalized.endsWith('est')) {
      add(normalized.substring(0, normalized.length - 3), 'superlative', 0.6);
      add('${normalized.substring(0, normalized.length - 3)}e', 'superlative', 0.58);
    }
    if (normalized.length > 4 && normalized.endsWith('ly')) {
      add(normalized.substring(0, normalized.length - 2), 'derived_adverb', 0.58);
    }

    return results;
  }

  bool _canInflect(GrammarCategory category) {
    switch (category) {
      case GrammarCategory.noun:
      case GrammarCategory.verb:
      case GrammarCategory.adjective:
      case GrammarCategory.adverb:
        return true;
      case GrammarCategory.pronoun:
      case GrammarCategory.determiner:
      case GrammarCategory.preposition:
      case GrammarCategory.conjunction:
      case GrammarCategory.auxiliary:
      case GrammarCategory.modal:
      case GrammarCategory.particle:
      case GrammarCategory.interjection:
      case GrammarCategory.number:
      case GrammarCategory.punctuation:
      case GrammarCategory.unknown:
        return false;
    }
  }

  void _seedBuiltins() {
    registerFlatCategoryMap(
      const ['can', 'could', 'may', 'might', 'must', 'shall', 'should', 'will', 'would'],
      GrammarCategory.modal,
      source: 'phaseA_builtin_modal',
    );
    registerEntries(const [
      GrammarLexiconEntry(normalized: 'ought', category: GrammarCategory.modal, subCategory: 'semi_modal', source: 'phaseA_builtin_modal'),
      GrammarLexiconEntry(normalized: 'need', category: GrammarCategory.modal, subCategory: 'semi_modal', source: 'phaseA_builtin_modal', confidence: 0.78),
      GrammarLexiconEntry(normalized: 'dare', category: GrammarCategory.modal, subCategory: 'semi_modal', source: 'phaseA_builtin_modal', confidence: 0.78),
    ]);

    registerEntries(const [
      GrammarLexiconEntry(normalized: 'am', category: GrammarCategory.auxiliary, lemma: 'be', subCategory: 'be_aux', source: 'phaseA_builtin_aux'),
      GrammarLexiconEntry(normalized: 'is', category: GrammarCategory.auxiliary, lemma: 'be', subCategory: 'be_aux', source: 'phaseA_builtin_aux'),
      GrammarLexiconEntry(normalized: 'are', category: GrammarCategory.auxiliary, lemma: 'be', subCategory: 'be_aux', source: 'phaseA_builtin_aux'),
      GrammarLexiconEntry(normalized: 'was', category: GrammarCategory.auxiliary, lemma: 'be', subCategory: 'be_aux', source: 'phaseA_builtin_aux'),
      GrammarLexiconEntry(normalized: 'were', category: GrammarCategory.auxiliary, lemma: 'be', subCategory: 'be_aux', source: 'phaseA_builtin_aux'),
      GrammarLexiconEntry(normalized: 'be', category: GrammarCategory.auxiliary, lemma: 'be', subCategory: 'be_aux', source: 'phaseA_builtin_aux'),
      GrammarLexiconEntry(normalized: 'been', category: GrammarCategory.auxiliary, lemma: 'be', subCategory: 'be_aux', source: 'phaseA_builtin_aux'),
      GrammarLexiconEntry(normalized: 'being', category: GrammarCategory.auxiliary, lemma: 'be', subCategory: 'be_aux', source: 'phaseA_builtin_aux'),
      GrammarLexiconEntry(normalized: 'have', category: GrammarCategory.auxiliary, lemma: 'have', subCategory: 'have_aux', source: 'phaseA_builtin_aux'),
      GrammarLexiconEntry(normalized: 'has', category: GrammarCategory.auxiliary, lemma: 'have', subCategory: 'have_aux', source: 'phaseA_builtin_aux'),
      GrammarLexiconEntry(normalized: 'had', category: GrammarCategory.auxiliary, lemma: 'have', subCategory: 'have_aux', source: 'phaseA_builtin_aux'),
      GrammarLexiconEntry(normalized: 'do', category: GrammarCategory.auxiliary, lemma: 'do', subCategory: 'do_support', source: 'phaseA_builtin_aux'),
      GrammarLexiconEntry(normalized: 'does', category: GrammarCategory.auxiliary, lemma: 'do', subCategory: 'do_support', source: 'phaseA_builtin_aux'),
      GrammarLexiconEntry(normalized: 'did', category: GrammarCategory.auxiliary, lemma: 'do', subCategory: 'do_support', source: 'phaseA_builtin_aux'),
    ]);

    registerEntries(const [
      GrammarLexiconEntry(normalized: 'a', category: GrammarCategory.determiner, subCategory: 'article', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'an', category: GrammarCategory.determiner, subCategory: 'article', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'the', category: GrammarCategory.determiner, subCategory: 'article', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'this', category: GrammarCategory.determiner, subCategory: 'demonstrative', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'that', category: GrammarCategory.determiner, subCategory: 'demonstrative', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'these', category: GrammarCategory.determiner, subCategory: 'demonstrative', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'those', category: GrammarCategory.determiner, subCategory: 'demonstrative', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'some', category: GrammarCategory.determiner, subCategory: 'quantifier', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'any', category: GrammarCategory.determiner, subCategory: 'quantifier', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'every', category: GrammarCategory.determiner, subCategory: 'quantifier', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'each', category: GrammarCategory.determiner, subCategory: 'quantifier', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'either', category: GrammarCategory.determiner, subCategory: 'quantifier', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'neither', category: GrammarCategory.determiner, subCategory: 'quantifier', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'both', category: GrammarCategory.determiner, subCategory: 'quantifier', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'much', category: GrammarCategory.determiner, subCategory: 'quantifier', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'many', category: GrammarCategory.determiner, subCategory: 'quantifier', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'few', category: GrammarCategory.determiner, subCategory: 'quantifier', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'little', category: GrammarCategory.determiner, subCategory: 'quantifier', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'several', category: GrammarCategory.determiner, subCategory: 'quantifier', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'another', category: GrammarCategory.determiner, subCategory: 'quantifier', source: 'phaseA_builtin_det'),
      GrammarLexiconEntry(normalized: 'such', category: GrammarCategory.determiner, subCategory: 'qualifier', source: 'phaseA_builtin_det'),
    ]);

    registerEntries(const [
      GrammarLexiconEntry(normalized: 'i', category: GrammarCategory.pronoun, subCategory: 'personal_subject', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'you', category: GrammarCategory.pronoun, subCategory: 'personal', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'he', category: GrammarCategory.pronoun, subCategory: 'personal_subject', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'she', category: GrammarCategory.pronoun, subCategory: 'personal_subject', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'it', category: GrammarCategory.pronoun, subCategory: 'personal_subject', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'we', category: GrammarCategory.pronoun, subCategory: 'personal_subject', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'they', category: GrammarCategory.pronoun, subCategory: 'personal_subject', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'me', category: GrammarCategory.pronoun, subCategory: 'personal_object', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'him', category: GrammarCategory.pronoun, subCategory: 'personal_object', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'her', category: GrammarCategory.pronoun, subCategory: 'personal_object', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'us', category: GrammarCategory.pronoun, subCategory: 'personal_object', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'them', category: GrammarCategory.pronoun, subCategory: 'personal_object', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'my', category: GrammarCategory.pronoun, subCategory: 'possessive_determiner', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'your', category: GrammarCategory.pronoun, subCategory: 'possessive_determiner', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'his', category: GrammarCategory.pronoun, subCategory: 'possessive', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'our', category: GrammarCategory.pronoun, subCategory: 'possessive_determiner', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'their', category: GrammarCategory.pronoun, subCategory: 'possessive_determiner', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'mine', category: GrammarCategory.pronoun, subCategory: 'possessive', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'yours', category: GrammarCategory.pronoun, subCategory: 'possessive', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'ours', category: GrammarCategory.pronoun, subCategory: 'possessive', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'theirs', category: GrammarCategory.pronoun, subCategory: 'possessive', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'myself', category: GrammarCategory.pronoun, subCategory: 'reflexive', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'yourself', category: GrammarCategory.pronoun, subCategory: 'reflexive', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'ourselves', category: GrammarCategory.pronoun, subCategory: 'reflexive', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'themselves', category: GrammarCategory.pronoun, subCategory: 'reflexive', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'who', category: GrammarCategory.pronoun, subCategory: 'wh_pronoun', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'whom', category: GrammarCategory.pronoun, subCategory: 'wh_pronoun', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'whose', category: GrammarCategory.pronoun, subCategory: 'wh_pronoun', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'what', category: GrammarCategory.pronoun, subCategory: 'wh_pronoun', source: 'phaseA_builtin_pron'),
      GrammarLexiconEntry(normalized: 'which', category: GrammarCategory.pronoun, subCategory: 'wh_pronoun', source: 'phaseA_builtin_pron'),
    ]);

    registerEntries(const [
      GrammarLexiconEntry(normalized: 'in', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'on', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'at', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'for', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'from', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'with', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'by', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'to', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'about', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'under', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'over', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'between', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'through', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'across', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'within', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'without', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'during', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'toward', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
      GrammarLexiconEntry(normalized: 'towards', category: GrammarCategory.preposition, source: 'phaseA_builtin_prep'),
    ]);

    registerEntries(const [
      GrammarLexiconEntry(normalized: 'and', category: GrammarCategory.conjunction, subCategory: 'coordinator', source: 'phaseA_builtin_conj'),
      GrammarLexiconEntry(normalized: 'but', category: GrammarCategory.conjunction, subCategory: 'coordinator', source: 'phaseA_builtin_conj'),
      GrammarLexiconEntry(normalized: 'or', category: GrammarCategory.conjunction, subCategory: 'coordinator', source: 'phaseA_builtin_conj'),
      GrammarLexiconEntry(normalized: 'so', category: GrammarCategory.conjunction, subCategory: 'coordinator', source: 'phaseA_builtin_conj'),
      GrammarLexiconEntry(normalized: 'yet', category: GrammarCategory.conjunction, subCategory: 'coordinator', source: 'phaseA_builtin_conj'),
      GrammarLexiconEntry(normalized: 'nor', category: GrammarCategory.conjunction, subCategory: 'coordinator', source: 'phaseA_builtin_conj'),
      GrammarLexiconEntry(normalized: 'because', category: GrammarCategory.conjunction, subCategory: 'subordinator', source: 'phaseA_builtin_conj'),
      GrammarLexiconEntry(normalized: 'although', category: GrammarCategory.conjunction, subCategory: 'subordinator', source: 'phaseA_builtin_conj'),
      GrammarLexiconEntry(normalized: 'though', category: GrammarCategory.conjunction, subCategory: 'subordinator', source: 'phaseA_builtin_conj'),
      GrammarLexiconEntry(normalized: 'while', category: GrammarCategory.conjunction, subCategory: 'subordinator', source: 'phaseA_builtin_conj'),
      GrammarLexiconEntry(normalized: 'if', category: GrammarCategory.conjunction, subCategory: 'subordinator', source: 'phaseA_builtin_conj'),
      GrammarLexiconEntry(normalized: 'when', category: GrammarCategory.conjunction, subCategory: 'subordinator', source: 'phaseA_builtin_conj'),
      GrammarLexiconEntry(normalized: 'unless', category: GrammarCategory.conjunction, subCategory: 'subordinator', source: 'phaseA_builtin_conj'),
      GrammarLexiconEntry(normalized: 'since', category: GrammarCategory.conjunction, subCategory: 'subordinator', source: 'phaseA_builtin_conj'),
    ]);

    registerEntries(const [
      GrammarLexiconEntry(normalized: 'not', category: GrammarCategory.particle, subCategory: 'negation', source: 'phaseA_builtin_particle'),
      GrammarLexiconEntry(normalized: 'up', category: GrammarCategory.particle, subCategory: 'phrasal', source: 'phaseA_builtin_particle'),
      GrammarLexiconEntry(normalized: 'off', category: GrammarCategory.particle, subCategory: 'phrasal', source: 'phaseA_builtin_particle'),
      GrammarLexiconEntry(normalized: 'out', category: GrammarCategory.particle, subCategory: 'phrasal', source: 'phaseA_builtin_particle'),
      GrammarLexiconEntry(normalized: 'down', category: GrammarCategory.particle, subCategory: 'phrasal', source: 'phaseA_builtin_particle'),
      GrammarLexiconEntry(normalized: 'away', category: GrammarCategory.particle, subCategory: 'phrasal', source: 'phaseA_builtin_particle'),
      GrammarLexiconEntry(normalized: 'back', category: GrammarCategory.particle, subCategory: 'phrasal', source: 'phaseA_builtin_particle'),
    ]);

    registerFlatCategoryMap(
      const ['wow', 'oh', 'hey', 'ah', 'oops', 'alas', 'bravo', 'hurray'],
      GrammarCategory.interjection,
      source: 'phaseA_builtin_interjection',
      confidence: 0.82,
    );

    registerFlatCategoryMap(
      const [
        'time', 'people', 'person', 'world', 'mind', 'body', 'life', 'place', 'day', 'way', 'thing', 'man', 'woman',
        'child', 'children', 'student', 'teacher', 'language', 'word', 'sentence', 'story', 'practice', 'lesson',
        'habit', 'book', 'books', 'house', 'name', 'question', 'answer', 'idea', 'problem', 'reason', 'result',
        'friend', 'family', 'news', 'work', 'water', 'food', 'heart', 'attention', 'wisdom', 'mindfulness', 'dharma'
      ],
      GrammarCategory.noun,
      source: 'phaseA_seed_nouns',
      confidence: 0.74,
    );

    registerFlatCategoryMap(
      const [
        'make', 'take', 'give', 'find', 'think', 'know', 'feel', 'look', 'seem', 'become', 'learn', 'study', 'read',
        'write', 'speak', 'listen', 'walk', 'sit', 'stand', 'use', 'need', 'want', 'remember', 'understand', 'practice',
        'build', 'open', 'close', 'change', 'grow', 'hold', 'bring', 'leave', 'follow', 'offer', 'serve', 'keep'
      ],
      GrammarCategory.verb,
      source: 'phaseA_seed_verbs',
      confidence: 0.74,
    );

    registerFlatCategoryMap(
      const [
        'good', 'new', 'old', 'great', 'small', 'big', 'large', 'little', 'important', 'different', 'beautiful',
        'simple', 'clear', 'daily', 'strong', 'weak', 'true', 'false', 'possible', 'ready', 'common', 'quiet',
        'gentle', 'mindful', 'careful', 'useful', 'natural', 'human', 'happy', 'curious'
      ],
      GrammarCategory.adjective,
      source: 'phaseA_seed_adjectives',
      confidence: 0.72,
    );

    registerFlatCategoryMap(
      const [
        'very', 'just', 'also', 'often', 'sometimes', 'usually', 'already', 'probably', 'really', 'slowly', 'quickly',
        'carefully', 'daily', 'quietly', 'gently', 'simply', 'clearly', 'naturally', 'together', 'again', 'almost'
      ],
      GrammarCategory.adverb,
      source: 'phaseA_seed_adverbs',
      confidence: 0.72,
    );
  }
}

class _DerivedCandidate {
  final String base;
  final String subCategory;
  final double confidence;

  const _DerivedCandidate(this.base, this.subCategory, this.confidence);
}
