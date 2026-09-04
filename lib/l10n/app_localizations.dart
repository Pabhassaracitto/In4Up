import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_bo.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_km.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_lo.dart';
import 'app_localizations_mn.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_my.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_si.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';
import 'app_localizations_th.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('bn'),
    Locale('bo'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('km'),
    Locale('ko'),
    Locale('lo'),
    Locale('mn'),
    Locale('mr'),
    Locale('my'),
    Locale('pt'),
    Locale('ru'),
    Locale('si'),
    Locale('ta'),
    Locale('te'),
    Locale('th'),
    Locale('vi'),
    Locale('zh'),
    Locale('zh', 'TW')
  ];

  /// No description provided for @commandCenter.
  ///
  /// In en, this message translates to:
  /// **'COMMAND CENTER'**
  String get commandCenter;

  /// No description provided for @knowledgeOS.
  ///
  /// In en, this message translates to:
  /// **'Knowledge OS'**
  String get knowledgeOS;

  /// No description provided for @manageAIModels.
  ///
  /// In en, this message translates to:
  /// **'Manage AI Models'**
  String get manageAIModels;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String loginFailed(String error);

  /// No description provided for @studioRoom.
  ///
  /// In en, this message translates to:
  /// **'STUDIO ROOM'**
  String get studioRoom;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'LISTEN'**
  String get listen;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'READ'**
  String get read;

  /// No description provided for @understand.
  ///
  /// In en, this message translates to:
  /// **'UNDERSTAND'**
  String get understand;

  /// No description provided for @remember.
  ///
  /// In en, this message translates to:
  /// **'REMEMBER'**
  String get remember;

  /// No description provided for @quickNote.
  ///
  /// In en, this message translates to:
  /// **'Quick Note'**
  String get quickNote;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get listening;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @wordList.
  ///
  /// In en, this message translates to:
  /// **'Word List'**
  String get wordList;

  /// No description provided for @wordListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary List'**
  String get wordListSubtitle;

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @timelineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Timeline'**
  String get timelineSubtitle;

  /// No description provided for @wordListStats.
  ///
  /// In en, this message translates to:
  /// **'Wordlist Stats'**
  String get wordListStats;

  /// No description provided for @wordListStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed Statistics'**
  String get wordListStatsSubtitle;

  /// No description provided for @webReader.
  ///
  /// In en, this message translates to:
  /// **'Web Reader'**
  String get webReader;

  /// No description provided for @webReaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Web Reading + CEFR Highlight'**
  String get webReaderSubtitle;

  /// No description provided for @youtube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get youtube;

  /// No description provided for @youtubeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore English Channels'**
  String get youtubeSubtitle;

  /// No description provided for @pdfReader.
  ///
  /// In en, this message translates to:
  /// **'PDF Reader'**
  String get pdfReader;

  /// No description provided for @pdfReaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open & Read PDF Files'**
  String get pdfReaderSubtitle;

  /// No description provided for @youglish.
  ///
  /// In en, this message translates to:
  /// **'YouGlish'**
  String get youglish;

  /// No description provided for @youglishSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Native Pronunciation'**
  String get youglishSubtitle;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @overviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Progress'**
  String get overviewSubtitle;

  /// No description provided for @wordMap.
  ///
  /// In en, this message translates to:
  /// **'Word Map'**
  String get wordMap;

  /// No description provided for @wordMapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Known → Small · Unknown → Big'**
  String get wordMapSubtitle;

  /// No description provided for @triangle.
  ///
  /// In en, this message translates to:
  /// **'Triangle'**
  String get triangle;

  /// No description provided for @triangleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Map + Quick Assessment'**
  String get triangleSubtitle;

  /// No description provided for @vennDiagram.
  ///
  /// In en, this message translates to:
  /// **'Venn Diagram'**
  String get vennDiagram;

  /// No description provided for @vennDiagramSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skill Zoning'**
  String get vennDiagramSubtitle;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @reviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'SM-2 Spaced Repetition'**
  String get reviewSubtitle;

  /// No description provided for @shadowing.
  ///
  /// In en, this message translates to:
  /// **'Shadowing'**
  String get shadowing;

  /// No description provided for @shadowingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shadowing Practice'**
  String get shadowingSubtitle;

  /// No description provided for @dictation.
  ///
  /// In en, this message translates to:
  /// **'Dictation'**
  String get dictation;

  /// No description provided for @dictationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Listen & Type'**
  String get dictationSubtitle;

  /// No description provided for @audioLibrary.
  ///
  /// In en, this message translates to:
  /// **'Audio Library'**
  String get audioLibrary;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// No description provided for @typeVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary'**
  String get typeVocabulary;

  /// No description provided for @typePhrase.
  ///
  /// In en, this message translates to:
  /// **'Phrase'**
  String get typePhrase;

  /// No description provided for @typeSentence.
  ///
  /// In en, this message translates to:
  /// **'Sentence'**
  String get typeSentence;

  /// No description provided for @typeParagraph.
  ///
  /// In en, this message translates to:
  /// **'Paragraph'**
  String get typeParagraph;

  /// No description provided for @typeDharma.
  ///
  /// In en, this message translates to:
  /// **'Dharma'**
  String get typeDharma;

  /// No description provided for @typeGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get typeGrammar;

  /// No description provided for @diffEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get diffEasy;

  /// No description provided for @diffMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get diffMedium;

  /// No description provided for @diffHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get diffHard;

  /// No description provided for @vocabWord.
  ///
  /// In en, this message translates to:
  /// **'Word'**
  String get vocabWord;

  /// No description provided for @vocabPhrase.
  ///
  /// In en, this message translates to:
  /// **'Phrase'**
  String get vocabPhrase;

  /// No description provided for @vocabSentence.
  ///
  /// In en, this message translates to:
  /// **'Sentence'**
  String get vocabSentence;

  /// No description provided for @vocabParagraph.
  ///
  /// In en, this message translates to:
  /// **'Paragraph'**
  String get vocabParagraph;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get commonFilter;

  /// No description provided for @commonSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get commonSort;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get commonNoData;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get commonFailed;

  /// No description provided for @commonComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get commonComingSoon;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get commonRedo;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commonPrevious;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get commonSelectAll;

  /// No description provided for @commonDeselect.
  ///
  /// In en, this message translates to:
  /// **'Deselect'**
  String get commonDeselect;

  /// No description provided for @commonSaveNote.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get commonSaveNote;

  /// No description provided for @commonAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get commonAddNote;

  /// No description provided for @commonEditNote.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get commonEditNote;

  /// No description provided for @commonDeleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get commonDeleteNote;

  /// No description provided for @commonNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get commonNote;

  /// No description provided for @commonNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commonNotes;

  /// No description provided for @commonReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get commonReading;

  /// No description provided for @commonListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get commonListening;

  /// No description provided for @commonSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Speaking'**
  String get commonSpeaking;

  /// No description provided for @commonWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get commonWriting;

  /// No description provided for @commonUnderstanding.
  ///
  /// In en, this message translates to:
  /// **'Understanding'**
  String get commonUnderstanding;

  /// No description provided for @commonRemembering.
  ///
  /// In en, this message translates to:
  /// **'Remembering'**
  String get commonRemembering;

  /// No description provided for @commonLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get commonLearn;

  /// No description provided for @commonStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get commonStudy;

  /// No description provided for @commonReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get commonReview;

  /// No description provided for @commonPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get commonPractice;

  /// No description provided for @commonTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get commonTranslate;

  /// No description provided for @commonPronunciation.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation'**
  String get commonPronunciation;

  /// No description provided for @commonVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary'**
  String get commonVocabulary;

  /// No description provided for @commonGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get commonGrammar;

  /// No description provided for @commonExample.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get commonExample;

  /// No description provided for @commonMeaning.
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get commonMeaning;

  /// No description provided for @commonDefinition.
  ///
  /// In en, this message translates to:
  /// **'Definition'**
  String get commonDefinition;

  /// No description provided for @commonSynonym.
  ///
  /// In en, this message translates to:
  /// **'Synonym'**
  String get commonSynonym;

  /// No description provided for @commonAntonym.
  ///
  /// In en, this message translates to:
  /// **'Antonym'**
  String get commonAntonym;

  /// No description provided for @readMode.
  ///
  /// In en, this message translates to:
  /// **'Read Mode'**
  String get readMode;

  /// No description provided for @readLibrary.
  ///
  /// In en, this message translates to:
  /// **'Reading Library'**
  String get readLibrary;

  /// No description provided for @readEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add text to start reading\nSupports TXT, LRC, SRT'**
  String get readEmpty;

  /// No description provided for @readAddDocument.
  ///
  /// In en, this message translates to:
  /// **'Add document'**
  String get readAddDocument;

  /// No description provided for @readOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get readOpenFile;

  /// No description provided for @readPasteText.
  ///
  /// In en, this message translates to:
  /// **'Paste text'**
  String get readPasteText;

  /// No description provided for @readTextStudio.
  ///
  /// In en, this message translates to:
  /// **'Text Studio'**
  String get readTextStudio;

  /// No description provided for @readNoDocument.
  ///
  /// In en, this message translates to:
  /// **'No document'**
  String get readNoDocument;

  /// No description provided for @readLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get readLine;

  /// No description provided for @readTranslate.
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get readTranslate;

  /// No description provided for @readHideTranslation.
  ///
  /// In en, this message translates to:
  /// **'Hide translation'**
  String get readHideTranslation;

  /// No description provided for @readTts.
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get readTts;

  /// No description provided for @readSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get readSpeed;

  /// No description provided for @readVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get readVoice;

  /// No description provided for @readAutoScroll.
  ///
  /// In en, this message translates to:
  /// **'Auto scroll'**
  String get readAutoScroll;

  /// No description provided for @readFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get readFontSize;

  /// No description provided for @listenMode.
  ///
  /// In en, this message translates to:
  /// **'Listen Mode'**
  String get listenMode;

  /// No description provided for @listenLibrary.
  ///
  /// In en, this message translates to:
  /// **'Audio Library'**
  String get listenLibrary;

  /// No description provided for @listenNoAudio.
  ///
  /// In en, this message translates to:
  /// **'No audio yet'**
  String get listenNoAudio;

  /// No description provided for @listenAddAudio.
  ///
  /// In en, this message translates to:
  /// **'Add audio'**
  String get listenAddAudio;

  /// No description provided for @listenNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get listenNowPlaying;

  /// No description provided for @listenPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get listenPlay;

  /// No description provided for @listenPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get listenPause;

  /// No description provided for @listenStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get listenStop;

  /// No description provided for @listenContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue from {time}'**
  String listenContinue(Object time);

  /// No description provided for @listenFromStart.
  ///
  /// In en, this message translates to:
  /// **'From start'**
  String get listenFromStart;

  /// No description provided for @listenLoop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get listenLoop;

  /// No description provided for @listenNoContent.
  ///
  /// In en, this message translates to:
  /// **'No content\nCreate LRC from STT'**
  String get listenNoContent;

  /// No description provided for @understandMode.
  ///
  /// In en, this message translates to:
  /// **'Understand Mode'**
  String get understandMode;

  /// No description provided for @understandSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get understandSync;

  /// No description provided for @understandShadowing.
  ///
  /// In en, this message translates to:
  /// **'Shadowing'**
  String get understandShadowing;

  /// No description provided for @understandKaraoke.
  ///
  /// In en, this message translates to:
  /// **'Karaoke lyrics'**
  String get understandKaraoke;

  /// No description provided for @understandNoSync.
  ///
  /// In en, this message translates to:
  /// **'Long press a sentence in Sync tab\nor use Set Loop button'**
  String get understandNoSync;

  /// No description provided for @memoryGarden.
  ///
  /// In en, this message translates to:
  /// **'Memory Garden'**
  String get memoryGarden;

  /// No description provided for @memoryDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get memoryDue;

  /// No description provided for @memoryTotalWords.
  ///
  /// In en, this message translates to:
  /// **'Total words'**
  String get memoryTotalWords;

  /// No description provided for @memoryNeedReview.
  ///
  /// In en, this message translates to:
  /// **'Need review'**
  String get memoryNeedReview;

  /// No description provided for @memoryMastered.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get memoryMastered;

  /// No description provided for @memorySeed.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get memorySeed;

  /// No description provided for @memorySprout.
  ///
  /// In en, this message translates to:
  /// **'Sprout'**
  String get memorySprout;

  /// No description provided for @memoryBloom.
  ///
  /// In en, this message translates to:
  /// **'Bloom'**
  String get memoryBloom;

  /// No description provided for @memoryEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Save vocabulary from Read tab\nto start growing your knowledge garden'**
  String get memoryEmptyDesc;

  /// No description provided for @memoryOpenWordlist.
  ///
  /// In en, this message translates to:
  /// **'Open Wordlist to add new words'**
  String get memoryOpenWordlist;

  /// No description provided for @wordListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No vocabulary yet'**
  String get wordListEmpty;

  /// No description provided for @wordListSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search words, phrases...'**
  String get wordListSearchHint;

  /// No description provided for @wordListFilterStatus.
  ///
  /// In en, this message translates to:
  /// **'Filter by status'**
  String get wordListFilterStatus;

  /// No description provided for @wordListSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get wordListSort;

  /// No description provided for @wordListAddManual.
  ///
  /// In en, this message translates to:
  /// **'Add manually'**
  String get wordListAddManual;

  /// No description provided for @wordListImport.
  ///
  /// In en, this message translates to:
  /// **'Bulk import'**
  String get wordListImport;

  /// No description provided for @wordListPlayAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get wordListPlayAll;

  /// No description provided for @wordListDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get wordListDue;

  /// No description provided for @wordListLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get wordListLearning;

  /// No description provided for @wordListBlindSpot.
  ///
  /// In en, this message translates to:
  /// **'Blind spot'**
  String get wordListBlindSpot;

  /// No description provided for @webReaderDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard Home'**
  String get webReaderDashboard;

  /// No description provided for @webReaderGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get webReaderGoBack;

  /// No description provided for @webReaderGoForward.
  ///
  /// In en, this message translates to:
  /// **'Go forward'**
  String get webReaderGoForward;

  /// No description provided for @webReaderUrlHint.
  ///
  /// In en, this message translates to:
  /// **'URL or search to open quickly...'**
  String get webReaderUrlHint;

  /// No description provided for @webReaderSaveToGroup.
  ///
  /// In en, this message translates to:
  /// **'Save current page to group'**
  String get webReaderSaveToGroup;

  /// No description provided for @webReaderBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark current page'**
  String get webReaderBookmark;

  /// No description provided for @webReaderInTextStudio.
  ///
  /// In en, this message translates to:
  /// **'Open in Text Studio'**
  String get webReaderInTextStudio;

  /// No description provided for @webReaderNoResult.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get webReaderNoResult;

  /// No description provided for @webReaderContinueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get webReaderContinueReading;

  /// No description provided for @webReaderPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get webReaderPinned;

  /// No description provided for @webReaderWithNotes.
  ///
  /// In en, this message translates to:
  /// **'With notes'**
  String get webReaderWithNotes;

  /// No description provided for @webReaderCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get webReaderCreateGroup;

  /// No description provided for @webReaderAddLink.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get webReaderAddLink;

  /// No description provided for @webReaderEditGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get webReaderEditGroup;

  /// No description provided for @webReaderDeleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get webReaderDeleteGroup;

  /// No description provided for @webReaderGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get webReaderGroupName;

  /// No description provided for @webReaderGroupDesc.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get webReaderGroupDesc;

  /// No description provided for @webReaderCreateMyGroup.
  ///
  /// In en, this message translates to:
  /// **'Create my group'**
  String get webReaderCreateMyGroup;

  /// No description provided for @webReaderAddLinkToGroup.
  ///
  /// In en, this message translates to:
  /// **'Add link to group'**
  String get webReaderAddLinkToGroup;

  /// No description provided for @webReaderLinkName.
  ///
  /// In en, this message translates to:
  /// **'Link name'**
  String get webReaderLinkName;

  /// No description provided for @webReaderUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get webReaderUrl;

  /// No description provided for @webReaderCreateAndSave.
  ///
  /// In en, this message translates to:
  /// **'Create & save'**
  String get webReaderCreateAndSave;

  /// No description provided for @webReaderPinnedArticle.
  ///
  /// In en, this message translates to:
  /// **'Pinned article'**
  String get webReaderPinnedArticle;

  /// No description provided for @webReaderReadNotes.
  ///
  /// In en, this message translates to:
  /// **'Reading notes'**
  String get webReaderReadNotes;

  /// No description provided for @webReaderYourNote.
  ///
  /// In en, this message translates to:
  /// **'Your note'**
  String get webReaderYourNote;

  /// No description provided for @webReaderDeleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get webReaderDeleteNote;

  /// No description provided for @webReaderSaveNoteBtn.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get webReaderSaveNoteBtn;

  /// No description provided for @webReaderMarkUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark as unread'**
  String get webReaderMarkUnread;

  /// No description provided for @webReaderMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get webReaderMarkRead;

  /// No description provided for @webReaderPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get webReaderPin;

  /// No description provided for @webReaderUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get webReaderUnpin;

  /// No description provided for @pdfOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening PDF...'**
  String get pdfOpening;

  /// No description provided for @pdfExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting text...'**
  String get pdfExtracting;

  /// No description provided for @pdfCannotExtract.
  ///
  /// In en, this message translates to:
  /// **'Cannot extract text from this PDF.\nIt may be a scanned PDF (image).'**
  String get pdfCannotExtract;

  /// No description provided for @pdfTextMode.
  ///
  /// In en, this message translates to:
  /// **'Text mode — full highlighting & TTS features'**
  String get pdfTextMode;

  /// No description provided for @pdfOpenInReadMode.
  ///
  /// In en, this message translates to:
  /// **'Open in Read Mode →'**
  String get pdfOpenInReadMode;

  /// No description provided for @pdfNoteForSelection.
  ///
  /// In en, this message translates to:
  /// **'Note for selection'**
  String get pdfNoteForSelection;

  /// No description provided for @pdfEnterNote.
  ///
  /// In en, this message translates to:
  /// **'Enter note / translation / insight...'**
  String get pdfEnterNote;

  /// No description provided for @pdfSavedSelectionNote.
  ///
  /// In en, this message translates to:
  /// **'📝 Saved note for selection'**
  String get pdfSavedSelectionNote;

  /// No description provided for @pdfSelectionOpened.
  ///
  /// In en, this message translates to:
  /// **'✅ Opened selection in Text Studio'**
  String get pdfSelectionOpened;

  /// No description provided for @pdfReaderDeepPos.
  ///
  /// In en, this message translates to:
  /// **'PDF Reader · Deep POS'**
  String get pdfReaderDeepPos;

  /// No description provided for @pdfLoadedToStudio.
  ///
  /// In en, this message translates to:
  /// **'Loaded into Text Studio'**
  String get pdfLoadedToStudio;

  /// No description provided for @pdfCannotOpen.
  ///
  /// In en, this message translates to:
  /// **'Cannot open PDF'**
  String get pdfCannotOpen;

  /// No description provided for @pdfViewSavedNotes.
  ///
  /// In en, this message translates to:
  /// **'View saved notes'**
  String get pdfViewSavedNotes;

  /// No description provided for @pdfNoteSelection.
  ///
  /// In en, this message translates to:
  /// **'Note selection'**
  String get pdfNoteSelection;

  /// No description provided for @pdfSavedToWordlist.
  ///
  /// In en, this message translates to:
  /// **'Saved to WordList'**
  String get pdfSavedToWordlist;

  /// No description provided for @pdfContextAdded.
  ///
  /// In en, this message translates to:
  /// **'Context added to WordList'**
  String get pdfContextAdded;

  /// No description provided for @pdfSaveToMemory.
  ///
  /// In en, this message translates to:
  /// **'Save to Memory Garden'**
  String get pdfSaveToMemory;

  /// No description provided for @pdfSavedToMemory.
  ///
  /// In en, this message translates to:
  /// **'Saved to Memory Garden'**
  String get pdfSavedToMemory;

  /// No description provided for @pdfNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get pdfNoNotes;

  /// No description provided for @pdfLongPressHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a word on PDF or add note from selection in Text Mode.'**
  String get pdfLongPressHint;

  /// No description provided for @translationEngineSettings.
  ///
  /// In en, this message translates to:
  /// **'Translation engine settings'**
  String get translationEngineSettings;

  /// No description provided for @translationError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String translationError(Object error);

  /// No description provided for @translationChangedTo.
  ///
  /// In en, this message translates to:
  /// **'{flag} Changed translation and voice to {language}'**
  String translationChangedTo(Object flag, Object language);

  /// No description provided for @translationTranslateAll.
  ///
  /// In en, this message translates to:
  /// **'Translate all (skip existing)'**
  String get translationTranslateAll;

  /// No description provided for @translationRetranslateAll.
  ///
  /// In en, this message translates to:
  /// **'Retranslate all'**
  String get translationRetranslateAll;

  /// No description provided for @translationClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all translations'**
  String get translationClearAll;

  /// No description provided for @translationEngine.
  ///
  /// In en, this message translates to:
  /// **'Translation engine'**
  String get translationEngine;

  /// No description provided for @translationDeepLXUrl.
  ///
  /// In en, this message translates to:
  /// **'DeepLX Server URL (optional)'**
  String get translationDeepLXUrl;

  /// No description provided for @translationLeaveEmpty.
  ///
  /// In en, this message translates to:
  /// **'Leave empty → use Google Free'**
  String get translationLeaveEmpty;

  /// No description provided for @translationTargetViaFlag.
  ///
  /// In en, this message translates to:
  /// **'Target language is selected via flag button on translation bar.'**
  String get translationTargetViaFlag;

  /// No description provided for @translationStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get translationStop;

  /// No description provided for @translationSelectTarget.
  ///
  /// In en, this message translates to:
  /// **'Select target'**
  String get translationSelectTarget;

  /// No description provided for @translationTranslated.
  ///
  /// In en, this message translates to:
  /// **'Translated'**
  String get translationTranslated;

  /// No description provided for @translationTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translationTranslate;

  /// No description provided for @translationHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get translationHide;

  /// No description provided for @translationBelow.
  ///
  /// In en, this message translates to:
  /// **'Below'**
  String get translationBelow;

  /// No description provided for @translationColumn.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get translationColumn;

  /// No description provided for @translationLanguage.
  ///
  /// In en, this message translates to:
  /// **'Translation language'**
  String get translationLanguage;

  /// No description provided for @translationSearchLang.
  ///
  /// In en, this message translates to:
  /// **'Search languages…'**
  String get translationSearchLang;

  /// No description provided for @translationSourceIsTarget.
  ///
  /// In en, this message translates to:
  /// **'Source and target languages are the same.'**
  String get translationSourceIsTarget;

  /// No description provided for @ttsReadingSpeed.
  ///
  /// In en, this message translates to:
  /// **'Reading speed'**
  String get ttsReadingSpeed;

  /// No description provided for @ttsVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get ttsVoice;

  /// No description provided for @ttsAutoSplit.
  ///
  /// In en, this message translates to:
  /// **'Auto split lines'**
  String get ttsAutoSplit;

  /// No description provided for @ttsSplitMode.
  ///
  /// In en, this message translates to:
  /// **'Split mode'**
  String get ttsSplitMode;

  /// No description provided for @ttsMinWords.
  ///
  /// In en, this message translates to:
  /// **'Min {count} words before split'**
  String ttsMinWords(Object count);

  /// No description provided for @ttsMaxWords.
  ///
  /// In en, this message translates to:
  /// **'Max {count} words/line'**
  String ttsMaxWords(Object count);

  /// No description provided for @ttsPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get ttsPreview;

  /// No description provided for @ttsApply.
  ///
  /// In en, this message translates to:
  /// **'Apply ({count} lines)'**
  String ttsApply(Object count);

  /// No description provided for @ttsMode.
  ///
  /// In en, this message translates to:
  /// **'Playback mode'**
  String get ttsMode;

  /// No description provided for @ttsOrder.
  ///
  /// In en, this message translates to:
  /// **'Playback order'**
  String get ttsOrder;

  /// No description provided for @ttsDragToSort.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get ttsDragToSort;

  /// No description provided for @ttsApiKeys.
  ///
  /// In en, this message translates to:
  /// **'API Keys (optional, free)'**
  String get ttsApiKeys;

  /// No description provided for @ttsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear TTS cache!'**
  String get ttsClearCache;

  /// No description provided for @ttsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get ttsClear;

  /// No description provided for @shadowingReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for shadowing practice'**
  String get shadowingReady;

  /// No description provided for @shadowingSelectSegment.
  ///
  /// In en, this message translates to:
  /// **'Select an A-B Loop segment to start'**
  String get shadowingSelectSegment;

  /// No description provided for @shadowingStartPractice.
  ///
  /// In en, this message translates to:
  /// **'Start Practice'**
  String get shadowingStartPractice;

  /// No description provided for @shadowingSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Listen to sample\n2. Press record\n3. Repeat after sample'**
  String get shadowingSteps;

  /// No description provided for @shadowingListeningSample.
  ///
  /// In en, this message translates to:
  /// **'Listening to sample...'**
  String get shadowingListeningSample;

  /// No description provided for @shadowingListenCarefully.
  ///
  /// In en, this message translates to:
  /// **'Listen carefully...'**
  String get shadowingListenCarefully;

  /// No description provided for @shadowingReadyEx.
  ///
  /// In en, this message translates to:
  /// **'Ready!'**
  String get shadowingReadyEx;

  /// No description provided for @shadowingRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get shadowingRecording;

  /// No description provided for @shadowingMax.
  ///
  /// In en, this message translates to:
  /// **'Max: {seconds}s'**
  String shadowingMax(Object seconds);

  /// No description provided for @shadowingAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get shadowingAnalyzing;

  /// No description provided for @shadowingRhythm.
  ///
  /// In en, this message translates to:
  /// **'Rhythm'**
  String get shadowingRhythm;

  /// No description provided for @shadowingPitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get shadowingPitch;

  /// No description provided for @shadowingEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get shadowingEnergy;

  /// No description provided for @shadowingPlaySample.
  ///
  /// In en, this message translates to:
  /// **'Play sample'**
  String get shadowingPlaySample;

  /// No description provided for @shadowingStopSample.
  ///
  /// In en, this message translates to:
  /// **'Stop sample'**
  String get shadowingStopSample;

  /// No description provided for @shadowingCancelCountdown.
  ///
  /// In en, this message translates to:
  /// **'Cancel countdown'**
  String get shadowingCancelCountdown;

  /// No description provided for @shadowingStopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get shadowingStopRecording;

  /// No description provided for @shadowingRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get shadowingRetry;

  /// No description provided for @shadowingFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get shadowingFinish;

  /// No description provided for @shadowingSelectToPractice.
  ///
  /// In en, this message translates to:
  /// **'Select segment to practice'**
  String get shadowingSelectToPractice;

  /// No description provided for @grammarPos.
  ///
  /// In en, this message translates to:
  /// **'Part of speech'**
  String get grammarPos;

  /// No description provided for @grammarCefr.
  ///
  /// In en, this message translates to:
  /// **'CEFR level'**
  String get grammarCefr;

  /// No description provided for @grammarDifficultyUser.
  ///
  /// In en, this message translates to:
  /// **'Difficulty (your tags)'**
  String get grammarDifficultyUser;

  /// No description provided for @grammarPresetSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggested presets'**
  String get grammarPresetSuggestions;

  /// No description provided for @grammarYourPresets.
  ///
  /// In en, this message translates to:
  /// **'Your presets'**
  String get grammarYourPresets;

  /// No description provided for @grammarShowMiniLegend.
  ///
  /// In en, this message translates to:
  /// **'Show mini legend in reading area'**
  String get grammarShowMiniLegend;

  /// No description provided for @grammarComparePalette.
  ///
  /// In en, this message translates to:
  /// **'Compare palettes visually'**
  String get grammarComparePalette;

  /// No description provided for @grammarColorStyle.
  ///
  /// In en, this message translates to:
  /// **'Color style'**
  String get grammarColorStyle;

  /// No description provided for @grammarPosGroups.
  ///
  /// In en, this message translates to:
  /// **'POS groups'**
  String get grammarPosGroups;

  /// No description provided for @grammarUsingPreset.
  ///
  /// In en, this message translates to:
  /// **'Using preset: {name}'**
  String grammarUsingPreset(Object name);

  /// No description provided for @grammarCustomizingFrom.
  ///
  /// In en, this message translates to:
  /// **'Customizing from nearest preset: {name}'**
  String grammarCustomizingFrom(Object name);

  /// No description provided for @grammarHiddenGroups.
  ///
  /// In en, this message translates to:
  /// **'{count} groups hidden'**
  String grammarHiddenGroups(Object count);

  /// No description provided for @grammarSavePreset.
  ///
  /// In en, this message translates to:
  /// **'Save custom preset'**
  String get grammarSavePreset;

  /// No description provided for @grammarRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore {name}'**
  String grammarRestore(Object name);

  /// No description provided for @grammarHiddenDesc.
  ///
  /// In en, this message translates to:
  /// **'{count} POS groups hidden. You can re-enable them.'**
  String grammarHiddenDesc(Object count);

  /// No description provided for @grammarEnableAll.
  ///
  /// In en, this message translates to:
  /// **'Enable all'**
  String get grammarEnableAll;

  /// No description provided for @grammarExperienceMode.
  ///
  /// In en, this message translates to:
  /// **'Experience mode'**
  String get grammarExperienceMode;

  /// No description provided for @grammarTextAlign.
  ///
  /// In en, this message translates to:
  /// **'Text alignment'**
  String get grammarTextAlign;

  /// No description provided for @grammarFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get grammarFontSize;

  /// No description provided for @grammarTranslationBilingual.
  ///
  /// In en, this message translates to:
  /// **'Translation & bilingual'**
  String get grammarTranslationBilingual;

  /// No description provided for @grammarColorMode.
  ///
  /// In en, this message translates to:
  /// **'Color mode'**
  String get grammarColorMode;

  /// No description provided for @grammarDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get grammarDisplay;

  /// No description provided for @grammarShowTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get grammarShowTranslation;

  /// No description provided for @grammarShowLineNumbers.
  ///
  /// In en, this message translates to:
  /// **'Show line numbers'**
  String get grammarShowLineNumbers;

  /// No description provided for @grammarSmartSplit.
  ///
  /// In en, this message translates to:
  /// **'Smart line split'**
  String get grammarSmartSplit;

  /// No description provided for @grammarReadingMode.
  ///
  /// In en, this message translates to:
  /// **'Reading Mode'**
  String get grammarReadingMode;

  /// No description provided for @grammarListeningMode.
  ///
  /// In en, this message translates to:
  /// **'Listening Mode (TTS)'**
  String get grammarListeningMode;

  /// No description provided for @grammarTranslationMode.
  ///
  /// In en, this message translates to:
  /// **'Translation Mode'**
  String get grammarTranslationMode;

  /// No description provided for @grammarDrivingMode.
  ///
  /// In en, this message translates to:
  /// **'Driving Mode'**
  String get grammarDrivingMode;

  /// No description provided for @ytAudioCaptionsHistory.
  ///
  /// In en, this message translates to:
  /// **'Audio · Captions · History'**
  String get ytAudioCaptionsHistory;

  /// No description provided for @ytPasteUrl.
  ///
  /// In en, this message translates to:
  /// **'Paste YouTube URL...'**
  String get ytPasteUrl;

  /// No description provided for @ytHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get ytHistory;

  /// No description provided for @ytNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get ytNoHistory;

  /// No description provided for @ytAddChannel.
  ///
  /// In en, this message translates to:
  /// **'Add channel'**
  String get ytAddChannel;

  /// No description provided for @ytChannelIdHint.
  ///
  /// In en, this message translates to:
  /// **'Channel ID or URL...'**
  String get ytChannelIdHint;

  /// No description provided for @ytVocabLevel.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary level'**
  String get ytVocabLevel;

  /// No description provided for @ytSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get ytSortBy;

  /// No description provided for @ytDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get ytDate;

  /// No description provided for @ytViews.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get ytViews;

  /// No description provided for @ytChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get ytChannel;

  /// No description provided for @ytAllChannels.
  ///
  /// In en, this message translates to:
  /// **'All channels'**
  String get ytAllChannels;

  /// No description provided for @ytNoVideos.
  ///
  /// In en, this message translates to:
  /// **'No videos'**
  String get ytNoVideos;

  /// No description provided for @ytSampleData.
  ///
  /// In en, this message translates to:
  /// **'Using sample data.\nSet YouTube Data API v3 key for real videos.'**
  String get ytSampleData;

  /// No description provided for @ytGetInfo.
  ///
  /// In en, this message translates to:
  /// **'Get info'**
  String get ytGetInfo;

  /// No description provided for @ytDownloadAudio.
  ///
  /// In en, this message translates to:
  /// **'Download Audio'**
  String get ytDownloadAudio;

  /// No description provided for @ytDownloadLyrics.
  ///
  /// In en, this message translates to:
  /// **'Download Lyrics'**
  String get ytDownloadLyrics;

  /// No description provided for @ytSubtitleLang.
  ///
  /// In en, this message translates to:
  /// **'Subtitle language'**
  String get ytSubtitleLang;

  /// No description provided for @ytDownloadingAudio.
  ///
  /// In en, this message translates to:
  /// **'Downloading audio...'**
  String get ytDownloadingAudio;

  /// No description provided for @ytProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get ytProcessing;

  /// No description provided for @ytDownloadingSubs.
  ///
  /// In en, this message translates to:
  /// **'Downloading subtitles...'**
  String get ytDownloadingSubs;

  /// No description provided for @ytNoSubs.
  ///
  /// In en, this message translates to:
  /// **'No subtitles'**
  String get ytNoSubs;

  /// No description provided for @ytIknow.
  ///
  /// In en, this message translates to:
  /// **'✓ Known'**
  String get ytIknow;

  /// No description provided for @ytLearning.
  ///
  /// In en, this message translates to:
  /// **'📖 Learning'**
  String get ytLearning;

  /// No description provided for @ytSkip.
  ///
  /// In en, this message translates to:
  /// **'⊘ Skip'**
  String get ytSkip;

  /// No description provided for @ytKnownAll.
  ///
  /// In en, this message translates to:
  /// **'Know all'**
  String get ytKnownAll;

  /// No description provided for @ytLearnSentence.
  ///
  /// In en, this message translates to:
  /// **'Learn whole sentence'**
  String get ytLearnSentence;

  /// No description provided for @ytNoDict.
  ///
  /// In en, this message translates to:
  /// **'(not in dictionary)'**
  String get ytNoDict;

  /// No description provided for @ytQualityHighest.
  ///
  /// In en, this message translates to:
  /// **'Highest'**
  String get ytQualityHighest;

  /// No description provided for @ytQualityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium (128kbps)'**
  String get ytQualityMedium;

  /// No description provided for @ytQualityLow.
  ///
  /// In en, this message translates to:
  /// **'Low / Small (64kbps)'**
  String get ytQualityLow;

  /// No description provided for @ytPreparingQuality.
  ///
  /// In en, this message translates to:
  /// **'Preparing · {kbps}kbps · {size}'**
  String ytPreparingQuality(Object kbps, Object size);

  /// No description provided for @ytVideoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video unavailable'**
  String get ytVideoUnavailable;

  /// No description provided for @ytNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error — check connection'**
  String get ytNetworkError;

  /// No description provided for @ytQualityList.
  ///
  /// In en, this message translates to:
  /// **'Fetching quality list...'**
  String get ytQualityList;

  /// No description provided for @ytDownloadedPlaying.
  ///
  /// In en, this message translates to:
  /// **'Downloaded! Playing...'**
  String get ytDownloadedPlaying;

  /// No description provided for @ytQualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quality: {quality}'**
  String ytQualityLabel(Object quality);

  /// No description provided for @ytDownloadAnother.
  ///
  /// In en, this message translates to:
  /// **'Download another video'**
  String get ytDownloadAnother;

  /// No description provided for @ytFetchingInfo.
  ///
  /// In en, this message translates to:
  /// **'Fetching info...'**
  String get ytFetchingInfo;

  /// No description provided for @ytPasteToStart.
  ///
  /// In en, this message translates to:
  /// **'Paste YouTube URL above to start'**
  String get ytPasteToStart;

  /// No description provided for @ytSelectQuality.
  ///
  /// In en, this message translates to:
  /// **'Select audio quality'**
  String get ytSelectQuality;

  /// No description provided for @ytHigherBigger.
  ///
  /// In en, this message translates to:
  /// **'Higher quality = bigger file'**
  String get ytHigherBigger;

  /// No description provided for @ytHighDesc.
  ///
  /// In en, this message translates to:
  /// **'Highest bitrate, prefer mp4/aac'**
  String get ytHighDesc;

  /// No description provided for @ytMediumDesc.
  ///
  /// In en, this message translates to:
  /// **'~128kbps – balanced quality/size'**
  String get ytMediumDesc;

  /// No description provided for @ytLowDesc.
  ///
  /// In en, this message translates to:
  /// **'~64kbps – smallest, for slow network'**
  String get ytLowDesc;

  /// No description provided for @ytChooseSpecific.
  ///
  /// In en, this message translates to:
  /// **'Choose specific'**
  String get ytChooseSpecific;

  /// No description provided for @ytNoCaptionsLang.
  ///
  /// In en, this message translates to:
  /// **'No captions for \"{lang}\".\nTry another language.'**
  String ytNoCaptionsLang(Object lang);

  /// No description provided for @ytLang.
  ///
  /// In en, this message translates to:
  /// **'Language:'**
  String get ytLang;

  /// No description provided for @ytGetCaptions.
  ///
  /// In en, this message translates to:
  /// **'Get captions ({lang})'**
  String ytGetCaptions(Object lang);

  /// No description provided for @ytLines.
  ///
  /// In en, this message translates to:
  /// **'{count} lines'**
  String ytLines(Object count);

  /// No description provided for @ytMoreLines.
  ///
  /// In en, this message translates to:
  /// **'... and {count} more lines'**
  String ytMoreLines(Object count);

  /// No description provided for @ytLoadedToStudio.
  ///
  /// In en, this message translates to:
  /// **'✅ Loaded into Text Studio'**
  String get ytLoadedToStudio;

  /// No description provided for @ytLinkPlay.
  ///
  /// In en, this message translates to:
  /// **'Link + Play'**
  String get ytLinkPlay;

  /// No description provided for @ytLinkPlayDone.
  ///
  /// In en, this message translates to:
  /// **'Link + Play ✅'**
  String get ytLinkPlayDone;

  /// No description provided for @ytNeedAudioFirst.
  ///
  /// In en, this message translates to:
  /// **'Please download audio in \"Audio\" tab first'**
  String get ytNeedAudioFirst;

  /// No description provided for @ytAudioLyricsLinked.
  ///
  /// In en, this message translates to:
  /// **'🎵 Audio + Lyrics linked!'**
  String get ytAudioLyricsLinked;

  /// No description provided for @msgCopied.
  ///
  /// In en, this message translates to:
  /// **'📋 Copied!'**
  String get msgCopied;

  /// No description provided for @msgSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get msgSaved;

  /// No description provided for @msgDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get msgDeleted;

  /// No description provided for @msgError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String msgError(Object error);

  /// No description provided for @msgNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error, please check connection'**
  String get msgNetworkError;

  /// No description provided for @msgLoginNeeded.
  ///
  /// In en, this message translates to:
  /// **'Please login'**
  String get msgLoginNeeded;

  /// No description provided for @msgNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get msgNotLoggedIn;

  /// No description provided for @msgPleaseEnter.
  ///
  /// In en, this message translates to:
  /// **'Please enter {field}'**
  String msgPleaseEnter(Object field);

  /// No description provided for @msgInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid input'**
  String get msgInvalidInput;

  /// No description provided for @toolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get toolsTitle;

  /// No description provided for @toolsFeaturesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} features'**
  String toolsFeaturesCount(Object count);

  /// No description provided for @toolsMoreComing.
  ///
  /// In en, this message translates to:
  /// **'More features coming'**
  String get toolsMoreComing;

  /// No description provided for @toolsProgress.
  ///
  /// In en, this message translates to:
  /// **'Learning Progress'**
  String get toolsProgress;

  /// No description provided for @toolsWordMap.
  ///
  /// In en, this message translates to:
  /// **'Word Map'**
  String get toolsWordMap;

  /// No description provided for @toolsTriangle.
  ///
  /// In en, this message translates to:
  /// **'Triangle'**
  String get toolsTriangle;

  /// No description provided for @toolsVenn.
  ///
  /// In en, this message translates to:
  /// **'Venn Diagram'**
  String get toolsVenn;

  /// No description provided for @demoWordHello.
  ///
  /// In en, this message translates to:
  /// **'hello'**
  String get demoWordHello;

  /// No description provided for @demoWordWorld.
  ///
  /// In en, this message translates to:
  /// **'world'**
  String get demoWordWorld;

  /// No description provided for @shellUiSettings.
  ///
  /// In en, this message translates to:
  /// **'Shell interface'**
  String get shellUiSettings;

  /// No description provided for @shellUiSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compact mode, auto-hide, long-press to change mode'**
  String get shellUiSettingsSubtitle;

  /// No description provided for @learnByHeart.
  ///
  /// In en, this message translates to:
  /// **'Learn by Heart'**
  String get learnByHeart;

  /// No description provided for @learnByHeartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dhammapada, recitations and meaningful passages'**
  String get learnByHeartSubtitle;

  /// No description provided for @soundList.
  ///
  /// In en, this message translates to:
  /// **'Soundlist'**
  String get soundList;

  /// No description provided for @soundListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scores, chapters and audio table of contents'**
  String get soundListSubtitle;

  /// No description provided for @lhb_0.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get lhb_0;

  /// No description provided for @lhb_1.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get lhb_1;

  /// No description provided for @lhb_2.
  ///
  /// In en, this message translates to:
  /// **'Deep assessment'**
  String get lhb_2;

  /// No description provided for @lhb_3.
  ///
  /// In en, this message translates to:
  /// **'Fill in the blanks'**
  String get lhb_3;

  /// No description provided for @lhb_4.
  ///
  /// In en, this message translates to:
  /// **'Meaning → Verse'**
  String get lhb_4;

  /// No description provided for @lhb_5.
  ///
  /// In en, this message translates to:
  /// **'Listen and continue reading'**
  String get lhb_5;

  /// No description provided for @lhb_6.
  ///
  /// In en, this message translates to:
  /// **'Show answer to compare'**
  String get lhb_6;

  /// No description provided for @lhb_7.
  ///
  /// In en, this message translates to:
  /// **'Play the first half'**
  String get lhb_7;

  /// No description provided for @lhb_8.
  ///
  /// In en, this message translates to:
  /// **'Show the rest to check'**
  String get lhb_8;

  /// No description provided for @lhb_9.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get lhb_9;

  /// No description provided for @lhb_10.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get lhb_10;

  /// No description provided for @lhb_11.
  ///
  /// In en, this message translates to:
  /// **'Add a new recitation'**
  String get lhb_11;

  /// No description provided for @lhb_12.
  ///
  /// In en, this message translates to:
  /// **'Restore built-in samples'**
  String get lhb_12;

  /// No description provided for @lhb_13.
  ///
  /// In en, this message translates to:
  /// **'Add new item'**
  String get lhb_13;

  /// No description provided for @lhb_14.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get lhb_14;

  /// No description provided for @lhb_15.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get lhb_15;

  /// No description provided for @lhb_16.
  ///
  /// In en, this message translates to:
  /// **'Review Active Recall'**
  String get lhb_16;

  /// No description provided for @lhb_17.
  ///
  /// In en, this message translates to:
  /// **'Progressive learning'**
  String get lhb_17;

  /// No description provided for @lhb_18.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get lhb_18;

  /// No description provided for @lhb_19.
  ///
  /// In en, this message translates to:
  /// **'Delete item'**
  String get lhb_19;

  /// No description provided for @lhb_20.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get lhb_20;

  /// No description provided for @lhb_21.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this lesson? Review progress will be lost.'**
  String get lhb_21;

  /// No description provided for @lhb_22.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get lhb_22;

  /// No description provided for @lhb_23.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get lhb_23;

  /// No description provided for @lhb_24.
  ///
  /// In en, this message translates to:
  /// **'Restore sample data'**
  String get lhb_24;

  /// No description provided for @lhb_25.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get lhb_25;

  /// No description provided for @audit_0.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get audit_0;

  /// No description provided for @audit_1.
  ///
  /// In en, this message translates to:
  /// **'Most recent'**
  String get audit_1;

  /// No description provided for @audit_2.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get audit_2;

  /// No description provided for @audit_3.
  ///
  /// In en, this message translates to:
  /// **'Audio library'**
  String get audit_3;

  /// No description provided for @audit_4.
  ///
  /// In en, this message translates to:
  /// **'Listening library'**
  String get audit_4;

  /// No description provided for @audit_5.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get audit_5;

  /// No description provided for @audit_6.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get audit_6;

  /// No description provided for @audit_7.
  ///
  /// In en, this message translates to:
  /// **'Listened notes'**
  String get audit_7;

  /// No description provided for @audit_8.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get audit_8;

  /// No description provided for @audit_9.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get audit_9;

  /// No description provided for @audit_10.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get audit_10;

  /// No description provided for @audit_11.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get audit_11;

  /// No description provided for @audit_12.
  ///
  /// In en, this message translates to:
  /// **'Reading Library'**
  String get audit_12;

  /// No description provided for @audit_13.
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get audit_13;

  /// No description provided for @audit_14.
  ///
  /// In en, this message translates to:
  /// **'Speaking'**
  String get audit_14;

  /// No description provided for @audit_15.
  ///
  /// In en, this message translates to:
  /// **'Understanding'**
  String get audit_15;

  /// No description provided for @audit_16.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get audit_16;

  /// No description provided for @audit_17.
  ///
  /// In en, this message translates to:
  /// **'Shell interface'**
  String get audit_17;

  /// No description provided for @sound_0.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get sound_0;

  /// No description provided for @sound_1.
  ///
  /// In en, this message translates to:
  /// **'Segment'**
  String get sound_1;

  /// No description provided for @sound_2.
  ///
  /// In en, this message translates to:
  /// **'Table of contents'**
  String get sound_2;

  /// No description provided for @sound_3.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get sound_3;

  /// No description provided for @sound_4.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get sound_4;

  /// No description provided for @sound_5.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get sound_5;

  /// No description provided for @sound_6.
  ///
  /// In en, this message translates to:
  /// **'Chapter note'**
  String get sound_6;

  /// No description provided for @sound_7.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get sound_7;

  /// No description provided for @sound_8.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get sound_8;

  /// No description provided for @sound_9.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get sound_9;

  /// No description provided for @sound_10.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get sound_10;

  /// No description provided for @sound_11.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get sound_11;

  /// No description provided for @sound_12.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get sound_12;

  /// No description provided for @sound_13.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get sound_13;

  /// No description provided for @sound_14.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sound_14;

  /// No description provided for @sound_15.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sound_15;

  /// No description provided for @sound_16.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sound_16;

  /// No description provided for @sound_17.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get sound_17;

  /// No description provided for @sound_18.
  ///
  /// In en, this message translates to:
  /// **'Soundlist'**
  String get sound_18;

  /// No description provided for @sound_19.
  ///
  /// In en, this message translates to:
  /// **'Soundlist is empty'**
  String get sound_19;

  /// No description provided for @sound_20.
  ///
  /// In en, this message translates to:
  /// **'Soundlist — Audio library'**
  String get sound_20;

  /// No description provided for @sound_21.
  ///
  /// In en, this message translates to:
  /// **'No table of contents yet.'**
  String get sound_21;

  /// No description provided for @sound_22.
  ///
  /// In en, this message translates to:
  /// **'No scores yet.'**
  String get sound_22;

  /// No description provided for @sound_23.
  ///
  /// In en, this message translates to:
  /// **'No segments yet.'**
  String get sound_23;

  /// No description provided for @sound_24.
  ///
  /// In en, this message translates to:
  /// **'This file has no data — open it in Listen Mode and add bookmarks.'**
  String get sound_24;

  /// No description provided for @sound_25.
  ///
  /// In en, this message translates to:
  /// **'No results found for this keyword.'**
  String get sound_25;

  /// No description provided for @sound_26.
  ///
  /// In en, this message translates to:
  /// **'None in the observation list'**
  String get sound_26;

  /// No description provided for @soundRelated.
  ///
  /// In en, this message translates to:
  /// **'Related'**
  String get soundRelated;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'bn',
        'bo',
        'de',
        'en',
        'es',
        'fr',
        'hi',
        'id',
        'it',
        'ja',
        'km',
        'ko',
        'lo',
        'mn',
        'mr',
        'my',
        'pt',
        'ru',
        'si',
        'ta',
        'te',
        'th',
        'vi',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'bo':
      return AppLocalizationsBo();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'km':
      return AppLocalizationsKm();
    case 'ko':
      return AppLocalizationsKo();
    case 'lo':
      return AppLocalizationsLo();
    case 'mn':
      return AppLocalizationsMn();
    case 'mr':
      return AppLocalizationsMr();
    case 'my':
      return AppLocalizationsMy();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'si':
      return AppLocalizationsSi();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
    case 'th':
      return AppLocalizationsTh();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
