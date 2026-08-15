// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get commandCenter => 'КОМАНДНЫЙ ЦЕНТР';

  @override
  String get knowledgeOS => 'ОС Знаний';

  @override
  String get manageAIModels => 'Управление моделями ИИ';

  @override
  String loginFailed(String error) {
    return 'Ошибка входа: $error';
  }

  @override
  String get studioRoom => 'СТУДИЯ';

  @override
  String get listen => 'СЛУШАТЬ';

  @override
  String get read => 'ЧИТАТЬ';

  @override
  String get understand => 'ПОНИМАТЬ';

  @override
  String get remember => 'ПОМНИТЬ';

  @override
  String get quickNote => 'Быстрая заметка';

  @override
  String get listening => 'Слушаю...';

  @override
  String get done => 'Готово';

  @override
  String get wordList => 'Список слов';

  @override
  String get wordListSubtitle => 'Словарный список';

  @override
  String get timeline => 'Хронология';

  @override
  String get timelineSubtitle => 'Хронология обучения';

  @override
  String get wordListStats => 'Статистика слов';

  @override
  String get wordListStatsSubtitle => 'Детальная статистика';

  @override
  String get webReader => 'Веб-ридер';

  @override
  String get webReaderSubtitle => 'Чтение в сети + CEFR';

  @override
  String get youtube => 'YouTube';

  @override
  String get youtubeSubtitle => 'Исследовать английские каналы';

  @override
  String get pdfReader => 'PDF Ридер';

  @override
  String get pdfReaderSubtitle => 'Открытие и чтение PDF файлов';

  @override
  String get youglish => 'YouGlish';

  @override
  String get youglishSubtitle => 'Произношение носителей';

  @override
  String get overview => 'Обзор';

  @override
  String get overviewSubtitle => 'Прогресс обучения';

  @override
  String get wordMap => 'Карта слов';

  @override
  String get wordMapSubtitle => 'Знаю → Мелкий · Не знаю → Крупный';

  @override
  String get triangle => 'Треугольник';

  @override
  String get triangleSubtitle => 'Карта + Быстрая оценка';

  @override
  String get vennDiagram => 'Диаграмма Венна';

  @override
  String get vennDiagramSubtitle => 'Зоны навыков';

  @override
  String get review => 'Повторение';

  @override
  String get reviewSubtitle => 'Интервальное повторение SM-2';

  @override
  String get shadowing => 'Теневой повтор';

  @override
  String get shadowingSubtitle => 'Практика теневого повтора';

  @override
  String get dictation => 'Диктант';

  @override
  String get dictationSubtitle => 'Слушай и печатай';

  @override
  String get audioLibrary => 'Аудиотека';

  @override
  String get home => 'Главная';

  @override
  String get tools => 'Инструменты';

  @override
  String get nowPlaying => 'Сейчас играет';

  @override
  String get typeVocabulary => 'Словарный запас';

  @override
  String get typePhrase => 'Фраза';

  @override
  String get typeSentence => 'Предложение';

  @override
  String get typeParagraph => 'Абзац';

  @override
  String get typeDharma => 'Дхарма';

  @override
  String get typeGrammar => 'Грамматика';

  @override
  String get diffEasy => 'Легко';

  @override
  String get diffMedium => 'Средне';

  @override
  String get diffHard => 'Сложно';

  @override
  String get vocabWord => 'Слово';

  @override
  String get vocabPhrase => 'Фраза';

  @override
  String get vocabSentence => 'Предложение';

  @override
  String get vocabParagraph => 'Абзац';
}
