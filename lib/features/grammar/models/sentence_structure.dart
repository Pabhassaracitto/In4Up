enum SentenceType {
  declarative,
  interrogative,
  exclamative,
  imperative,
}

enum QuestionKind {
  none,
  yesNo,
  wh,
  tag,
  alternative,
}

enum Polarity {
  affirmative,
  negative,
}

enum Tense {
  present,
  past,
  future,
  modal,
  none,
}

enum Aspect {
  simple,
  continuous,
  perfect,
  perfectContinuous,
}

enum Voice {
  active,
  passive,
}

enum ClauseRole {
  relative,
  nominal,
  adverbial,
}

extension SentenceTypeInfo on SentenceType {
  String get wireName => name;

  String get labelKey {
    switch (this) {
      case SentenceType.declarative:
        return 'Câu khẳng định';
      case SentenceType.interrogative:
        return 'Câu hỏi';
      case SentenceType.exclamative:
        return 'Câu cảm thán';
      case SentenceType.imperative:
        return 'Câu mệnh lệnh';
    }
  }
}

extension QuestionKindInfo on QuestionKind {
  String get wireName {
    switch (this) {
      case QuestionKind.none:
        return 'none';
      case QuestionKind.yesNo:
        return 'yesno';
      case QuestionKind.wh:
        return 'wh';
      case QuestionKind.tag:
        return 'tag';
      case QuestionKind.alternative:
        return 'alternative';
    }
  }

  String get labelKey {
    switch (this) {
      case QuestionKind.none:
        return 'Không';
      case QuestionKind.yesNo:
        return 'Câu hỏi Yes/No';
      case QuestionKind.wh:
        return 'Câu hỏi WH';
      case QuestionKind.tag:
        return 'Hỏi đuôi';
      case QuestionKind.alternative:
        return 'Câu hỏi lựa chọn';
    }
  }
}

extension PolarityInfo on Polarity {
  String get wireName => name;

  String get labelKey {
    switch (this) {
      case Polarity.affirmative:
        return 'Khẳng định';
      case Polarity.negative:
        return 'Phủ định';
    }
  }
}

extension TenseInfo on Tense {
  String get wireName => name;

  String get labelKey {
    switch (this) {
      case Tense.present:
        return 'Hiện tại';
      case Tense.past:
        return 'Quá khứ';
      case Tense.future:
        return 'Tương lai';
      case Tense.modal:
        return 'Động từ khuyết thiếu';
      case Tense.none:
        return 'Không rõ';
    }
  }
}

extension AspectInfo on Aspect {
  String get wireName {
    switch (this) {
      case Aspect.simple:
        return 'simple';
      case Aspect.continuous:
        return 'continuous';
      case Aspect.perfect:
        return 'perfect';
      case Aspect.perfectContinuous:
        return 'perfect_continuous';
    }
  }

  String get labelKey {
    switch (this) {
      case Aspect.simple:
        return 'đơn';
      case Aspect.continuous:
        return 'tiếp diễn';
      case Aspect.perfect:
        return 'hoàn thành';
      case Aspect.perfectContinuous:
        return 'hoàn thành tiếp diễn';
    }
  }
}

extension VoiceInfo on Voice {
  String get wireName => name;

  String get labelKey {
    switch (this) {
      case Voice.active:
        return 'chủ động';
      case Voice.passive:
        return 'bị động';
    }
  }
}

extension ClauseRoleInfo on ClauseRole {
  String get wireName => name;

  String get labelKey {
    switch (this) {
      case ClauseRole.relative:
        return 'Mệnh đề quan hệ';
      case ClauseRole.nominal:
        return 'Mệnh đề danh từ';
      case ClauseRole.adverbial:
        return 'Mệnh đề trạng ngữ';
    }
  }
}

class SentenceStructure {
  final SentenceType type;
  final QuestionKind question;
  final Polarity polarity;
  final String? negator;
  final Tense tense;
  final Aspect aspect;
  final Voice voice;
  final String? modal;
  final String? pattern;
  final int spanStart;
  final int spanEnd;
  final double confidence;

  const SentenceStructure({
    required this.type,
    this.question = QuestionKind.none,
    this.polarity = Polarity.affirmative,
    this.negator,
    this.tense = Tense.none,
    this.aspect = Aspect.simple,
    this.voice = Voice.active,
    this.modal,
    this.pattern,
    required this.spanStart,
    required this.spanEnd,
    this.confidence = 0.85,
  });

  bool get hasTenseAspect => tense != Tense.none;

  String textIn(String source) {
    final start = spanStart.clamp(0, source.length).toInt();
    final end = spanEnd.clamp(start, source.length).toInt();
    return source.substring(start, end);
  }

  Map<String, dynamic> toJson({String? sourceText}) => {
        'type': type.wireName,
        'question': question.wireName,
        'polarity': polarity.wireName,
        if (negator != null) 'negator': negator,
        'tense': tense.wireName,
        'aspect': aspect.wireName,
        'voice': voice.wireName,
        if (modal != null) 'modal': modal,
        if (pattern != null) 'pattern': pattern,
        'spanStart': spanStart,
        'spanEnd': spanEnd,
        if (sourceText != null) 'span': textIn(sourceText),
        'confidence': confidence,
      };
}
