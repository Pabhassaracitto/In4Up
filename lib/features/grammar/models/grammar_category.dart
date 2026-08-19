import 'package:flutter/material.dart';

import '../../../models/word_analysis.dart';

enum GrammarCategoryGroup {
  contentWord,
  functionWord,
  structural,
  symbols,
}

enum GrammarCategory {
  noun,
  verb,
  adjective,
  adverb,
  pronoun,
  determiner,
  preposition,
  conjunction,
  auxiliary,
  modal,
  particle,
  interjection,
  number,
  punctuation,
  unknown,
}

extension GrammarCategoryGroupInfo on GrammarCategoryGroup {
  String get labelVi {
    switch (this) {
      case GrammarCategoryGroup.contentWord:
        return 'Content words';
      case GrammarCategoryGroup.functionWord:
        return 'Function words';
      case GrammarCategoryGroup.symbols:
        return 'Symbols';
      case GrammarCategoryGroup.structural:
        return 'Khác';
    }
  }

  String get helperVi {
    switch (this) {
      case GrammarCategoryGroup.contentWord:
        return 'Các từ mang nghĩa chính như noun, verb, adjective, adverb.';
      case GrammarCategoryGroup.functionWord:
        return 'Các từ làm khung ngữ pháp như pronoun, determiner, preposition...';
      case GrammarCategoryGroup.symbols:
        return 'Dấu câu và ký hiệu giúp chia nhịp câu.';
      case GrammarCategoryGroup.structural:
        return 'Nhóm dự phòng cho các mục chưa phân loại rõ.';
    }
  }

  IconData get icon {
    switch (this) {
      case GrammarCategoryGroup.contentWord:
        return Icons.auto_stories_outlined;
      case GrammarCategoryGroup.functionWord:
        return Icons.account_tree_outlined;
      case GrammarCategoryGroup.symbols:
        return Icons.more_horiz_rounded;
      case GrammarCategoryGroup.structural:
        return Icons.help_outline_rounded;
    }
  }
}

extension GrammarCategoryInfo on GrammarCategory {
  String get labelVi {
    switch (this) {
      case GrammarCategory.noun:
        return 'Danh từ';
      case GrammarCategory.verb:
        return 'Động từ';
      case GrammarCategory.adjective:
        return 'Tính từ';
      case GrammarCategory.adverb:
        return 'Trạng từ';
      case GrammarCategory.pronoun:
        return 'Đại từ';
      case GrammarCategory.determiner:
        return 'Từ hạn định';
      case GrammarCategory.preposition:
        return 'Giới từ';
      case GrammarCategory.conjunction:
        return 'Liên từ';
      case GrammarCategory.auxiliary:
        return 'Trợ động từ';
      case GrammarCategory.modal:
        return 'Động từ khuyết thiếu';
      case GrammarCategory.particle:
        return 'Tiểu từ';
      case GrammarCategory.interjection:
        return 'Thán từ';
      case GrammarCategory.number:
        return 'Số';
      case GrammarCategory.punctuation:
        return 'Dấu câu';
      case GrammarCategory.unknown:
        return 'Chưa rõ';
    }
  }

  String get labelEn {
    switch (this) {
      case GrammarCategory.noun:
        return 'Noun';
      case GrammarCategory.verb:
        return 'Verb';
      case GrammarCategory.adjective:
        return 'Adjective';
      case GrammarCategory.adverb:
        return 'Adverb';
      case GrammarCategory.pronoun:
        return 'Pronoun';
      case GrammarCategory.determiner:
        return 'Determiner';
      case GrammarCategory.preposition:
        return 'Preposition';
      case GrammarCategory.conjunction:
        return 'Conjunction';
      case GrammarCategory.auxiliary:
        return 'Auxiliary';
      case GrammarCategory.modal:
        return 'Modal';
      case GrammarCategory.particle:
        return 'Particle';
      case GrammarCategory.interjection:
        return 'Interjection';
      case GrammarCategory.number:
        return 'Number';
      case GrammarCategory.punctuation:
        return 'Punctuation';
      case GrammarCategory.unknown:
        return 'Unknown';
    }
  }

  String get shortCode {
    switch (this) {
      case GrammarCategory.noun:
        return 'N';
      case GrammarCategory.verb:
        return 'V';
      case GrammarCategory.adjective:
        return 'Adj';
      case GrammarCategory.adverb:
        return 'Adv';
      case GrammarCategory.pronoun:
        return 'Pro';
      case GrammarCategory.determiner:
        return 'Det';
      case GrammarCategory.preposition:
        return 'Prep';
      case GrammarCategory.conjunction:
        return 'Conj';
      case GrammarCategory.auxiliary:
        return 'Aux';
      case GrammarCategory.modal:
        return 'Mod';
      case GrammarCategory.particle:
        return 'Part';
      case GrammarCategory.interjection:
        return 'Int';
      case GrammarCategory.number:
        return '#';
      case GrammarCategory.punctuation:
        return 'Punc';
      case GrammarCategory.unknown:
        return '?';
    }
  }

  GrammarCategoryGroup get group {
    switch (this) {
      case GrammarCategory.noun:
      case GrammarCategory.verb:
      case GrammarCategory.adjective:
      case GrammarCategory.adverb:
      case GrammarCategory.interjection:
      case GrammarCategory.number:
        return GrammarCategoryGroup.contentWord;
      case GrammarCategory.pronoun:
      case GrammarCategory.determiner:
      case GrammarCategory.preposition:
      case GrammarCategory.conjunction:
      case GrammarCategory.auxiliary:
      case GrammarCategory.modal:
      case GrammarCategory.particle:
        return GrammarCategoryGroup.functionWord;
      case GrammarCategory.punctuation:
        return GrammarCategoryGroup.symbols;
      case GrammarCategory.unknown:
        return GrammarCategoryGroup.structural;
    }
  }

  bool get isContentWord => group == GrammarCategoryGroup.contentWord;
  bool get isFunctionWord => group == GrammarCategoryGroup.functionWord;

  WordType get legacyWordType {
    switch (this) {
      case GrammarCategory.noun:
        return WordType.noun;
      case GrammarCategory.verb:
      case GrammarCategory.auxiliary:
      case GrammarCategory.modal:
      case GrammarCategory.particle:
        return WordType.verb;
      case GrammarCategory.adjective:
        return WordType.adjective;
      case GrammarCategory.adverb:
        return WordType.adverb;
      case GrammarCategory.pronoun:
        return WordType.pronoun;
      case GrammarCategory.determiner:
        return WordType.determiner;
      case GrammarCategory.preposition:
        return WordType.preposition;
      case GrammarCategory.conjunction:
        return WordType.conjunction;
      case GrammarCategory.interjection:
        return WordType.interjection;
      case GrammarCategory.number:
        return WordType.number;
      case GrammarCategory.punctuation:
        return WordType.punctuation;
      case GrammarCategory.unknown:
        return WordType.unknown;
    }
  }

  int get referenceStyleIndex {
    switch (this) {
      case GrammarCategory.verb:
        return 0;
      case GrammarCategory.adverb:
        return 1;
      case GrammarCategory.adjective:
        return 2;
      case GrammarCategory.noun:
        return 5;
      case GrammarCategory.preposition:
        return 4;
      case GrammarCategory.pronoun:
        return 7;
      case GrammarCategory.determiner:
        return 8;
      case GrammarCategory.conjunction:
        return 6;
      case GrammarCategory.auxiliary:
        return 10;
      case GrammarCategory.modal:
        return 11;
      case GrammarCategory.particle:
        return 9;
      case GrammarCategory.interjection:
        return 3;
      case GrammarCategory.number:
        return 1;
      case GrammarCategory.punctuation:
        return 8;
      case GrammarCategory.unknown:
        return 8;
    }
  }
}

List<GrammarCategory> grammarCategoriesForGroup(GrammarCategoryGroup group) {
  final categories = GrammarCategory.values
      .where((category) => category.group == group)
      .toList();
  categories.sort(
    (a, b) => a.referenceStyleIndex.compareTo(b.referenceStyleIndex),
  );
  return categories;
}

GrammarCategory grammarCategoryFromLegacyWordType(WordType type) {
  switch (type) {
    case WordType.noun:
      return GrammarCategory.noun;
    case WordType.verb:
      return GrammarCategory.verb;
    case WordType.adjective:
      return GrammarCategory.adjective;
    case WordType.adverb:
      return GrammarCategory.adverb;
    case WordType.preposition:
      return GrammarCategory.preposition;
    case WordType.conjunction:
      return GrammarCategory.conjunction;
    case WordType.pronoun:
      return GrammarCategory.pronoun;
    case WordType.determiner:
      return GrammarCategory.determiner;
    case WordType.interjection:
      return GrammarCategory.interjection;
    case WordType.number:
      return GrammarCategory.number;
    case WordType.punctuation:
      return GrammarCategory.punctuation;
    case WordType.unknown:
      return GrammarCategory.unknown;
  }
}
