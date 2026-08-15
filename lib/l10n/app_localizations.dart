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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
  /// In vi, this message translates to:
  /// **'COMMAND CENTER'**
  String get commandCenter;

  /// No description provided for @knowledgeOS.
  ///
  /// In vi, this message translates to:
  /// **'Hệ điều hành Tri thức'**
  String get knowledgeOS;

  /// No description provided for @manageAIModels.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý Model AI'**
  String get manageAIModels;

  /// No description provided for @loginFailed.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập thất bại: {error}'**
  String loginFailed(String error);

  /// No description provided for @studioRoom.
  ///
  /// In vi, this message translates to:
  /// **'PHÒNG STUDIO'**
  String get studioRoom;

  /// No description provided for @listen.
  ///
  /// In vi, this message translates to:
  /// **'NGHE'**
  String get listen;

  /// No description provided for @read.
  ///
  /// In vi, this message translates to:
  /// **'ĐỌC'**
  String get read;

  /// No description provided for @understand.
  ///
  /// In vi, this message translates to:
  /// **'HIỂU'**
  String get understand;

  /// No description provided for @remember.
  ///
  /// In vi, this message translates to:
  /// **'NHỚ'**
  String get remember;

  /// No description provided for @quickNote.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú nhanh'**
  String get quickNote;

  /// No description provided for @listening.
  ///
  /// In vi, this message translates to:
  /// **'Đang lắng nghe...'**
  String get listening;

  /// No description provided for @done.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tất'**
  String get done;

  /// No description provided for @wordList.
  ///
  /// In vi, this message translates to:
  /// **'Word List'**
  String get wordList;

  /// No description provided for @wordListSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách từ vựng'**
  String get wordListSubtitle;

  /// No description provided for @timeline.
  ///
  /// In vi, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @timelineSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Hành trình học từ theo thời gian'**
  String get timelineSubtitle;

  /// No description provided for @wordListStats.
  ///
  /// In vi, this message translates to:
  /// **'Wordlist Stats'**
  String get wordListStats;

  /// No description provided for @wordListStatsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Thống kê từ vựng chi tiết'**
  String get wordListStatsSubtitle;

  /// No description provided for @webReader.
  ///
  /// In vi, this message translates to:
  /// **'Web Reader'**
  String get webReader;

  /// No description provided for @webReaderSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Đọc web + highlight CEFR'**
  String get webReaderSubtitle;

  /// No description provided for @youtube.
  ///
  /// In vi, this message translates to:
  /// **'YouTube'**
  String get youtube;

  /// No description provided for @youtubeSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá kênh học tiếng Anh'**
  String get youtubeSubtitle;

  /// No description provided for @pdfReader.
  ///
  /// In vi, this message translates to:
  /// **'PDF Reader'**
  String get pdfReader;

  /// No description provided for @pdfReaderSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Mở và đọc file PDF'**
  String get pdfReaderSubtitle;

  /// No description provided for @youglish.
  ///
  /// In vi, this message translates to:
  /// **'YouGlish'**
  String get youglish;

  /// No description provided for @youglishSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nghe phát âm chuẩn'**
  String get youglishSubtitle;

  /// No description provided for @overview.
  ///
  /// In vi, this message translates to:
  /// **'Tổng Quan'**
  String get overview;

  /// No description provided for @overviewSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tiến trình học tập'**
  String get overviewSubtitle;

  /// No description provided for @wordMap.
  ///
  /// In vi, this message translates to:
  /// **'Bản Đồ Từ'**
  String get wordMap;

  /// No description provided for @wordMapSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Biết → nhỏ · Chưa biết → to'**
  String get wordMapSubtitle;

  /// No description provided for @triangle.
  ///
  /// In vi, this message translates to:
  /// **'Tam Giác'**
  String get triangle;

  /// No description provided for @triangleSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Bản đồ + Đánh giá nhanh'**
  String get triangleSubtitle;

  /// No description provided for @vennDiagram.
  ///
  /// In vi, this message translates to:
  /// **'Biểu Đồ Venn'**
  String get vennDiagram;

  /// No description provided for @vennDiagramSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Phân vùng kỹ năng'**
  String get vennDiagramSubtitle;

  /// No description provided for @review.
  ///
  /// In vi, this message translates to:
  /// **'Ôn Tập'**
  String get review;

  /// No description provided for @reviewSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'SM-2 Spaced Repetition'**
  String get reviewSubtitle;

  /// No description provided for @shadowing.
  ///
  /// In vi, this message translates to:
  /// **'Shadowing'**
  String get shadowing;

  /// No description provided for @shadowingSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Luyện nói theo bóng'**
  String get shadowingSubtitle;

  /// No description provided for @dictation.
  ///
  /// In vi, this message translates to:
  /// **'Chính Tả'**
  String get dictation;

  /// No description provided for @dictationSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nghe và gõ lại'**
  String get dictationSubtitle;

  /// No description provided for @audioLibrary.
  ///
  /// In vi, this message translates to:
  /// **'Thư viện âm thanh'**
  String get audioLibrary;

  /// No description provided for @home.
  ///
  /// In vi, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @tools.
  ///
  /// In vi, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @nowPlaying.
  ///
  /// In vi, this message translates to:
  /// **'Đang phát'**
  String get nowPlaying;

  /// No description provided for @typeVocabulary.
  ///
  /// In vi, this message translates to:
  /// **'Từ vựng'**
  String get typeVocabulary;

  /// No description provided for @typePhrase.
  ///
  /// In vi, this message translates to:
  /// **'Cụm từ'**
  String get typePhrase;

  /// No description provided for @typeSentence.
  ///
  /// In vi, this message translates to:
  /// **'Câu'**
  String get typeSentence;

  /// No description provided for @typeParagraph.
  ///
  /// In vi, this message translates to:
  /// **'Đoạn'**
  String get typeParagraph;

  /// No description provided for @typeDharma.
  ///
  /// In vi, this message translates to:
  /// **'Phật Pháp'**
  String get typeDharma;

  /// No description provided for @typeGrammar.
  ///
  /// In vi, this message translates to:
  /// **'Ngữ pháp'**
  String get typeGrammar;

  /// No description provided for @diffEasy.
  ///
  /// In vi, this message translates to:
  /// **'Dễ'**
  String get diffEasy;

  /// No description provided for @diffMedium.
  ///
  /// In vi, this message translates to:
  /// **'Vừa'**
  String get diffMedium;

  /// No description provided for @diffHard.
  ///
  /// In vi, this message translates to:
  /// **'Khó'**
  String get diffHard;

  /// No description provided for @vocabWord.
  ///
  /// In vi, this message translates to:
  /// **'Từ'**
  String get vocabWord;

  /// No description provided for @vocabPhrase.
  ///
  /// In vi, this message translates to:
  /// **'Cụm từ'**
  String get vocabPhrase;

  /// No description provided for @vocabSentence.
  ///
  /// In vi, this message translates to:
  /// **'Câu'**
  String get vocabSentence;

  /// No description provided for @vocabParagraph.
  ///
  /// In vi, this message translates to:
  /// **'Đoạn'**
  String get vocabParagraph;
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
