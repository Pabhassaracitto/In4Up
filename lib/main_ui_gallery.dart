// lib/main_ui_gallery.dart
//
// ⚠️ ENTRYPOINT CHỈ DÀNH CHO PREVIEW — KHÔNG nằm trong app phát hành.
//
// Vì sao cần file này:
//   `lib/main_web.dart` (bản web chính thức) là một màn hình "web lite" riêng
//   (In4Up · Web) chỉ gồm 4 card tải/đọc/phát của web_core — nó KHÔNG dựng
//   các màn của app native (Thư Viện Chung, Phiên Cabin, PDF Reader, Tab Đọc,
//   Shadowing…). Vì vậy nó không cho thấy thay đổi giao diện của 2 bản beta
//   1.30.0 / 1.30.1 (sàn chữ ≥11sp, vùng chạm ≥40pt, SafeArea cho sheet,
//   i18n 8 locale).
//
//   File này dựng một **gallery** bằng CHÍNH các widget thật của sprint 3/4 —
//   không mock, không vẽ lại — để owner nhìn thấy đúng thứ đã thay đổi:
//
//   • Theme thật       : AppTheme.dark() (AppTypography ≥11sp, AppColors,
//                        AppRadius, materialTapTargetSize.padded)
//   • Typography       : thang chữ thật + bảng đo "sàn 11sp"
//   • Touch target     : các widget thật có nút/nút chọn ≥40pt
//   • SafeArea sheet   : các sheet thật mở bằng showModalBottomSheet
//                        (useSafeArea: true, isScrollControlled: true)
//   • 8 locale         : đổi Locale thật để xem chuỗi đã dịch
//
// Mọi widget được chọn đều đã được kiểm tra **đồ thị import sạch** (không kéo
// `dart:io`, `dart:ffi`, `dart:isolate` — những thư viện không có trên web).
// Widget nào chạm vào các thư viện đó (ReadSettingsSheet, PdfToolbar,
// DictEntryDetailSheet, LiveCaptionBubble…) KHÔNG đưa vào đây được; chúng chỉ
// xem được trên app native.

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:in4up/core/language/localized_material.dart';

import 'core/language/app_ui_translations.dart';
import 'core/theme/app_theme.dart';
import 'screens/read_mode/widgets/read_settings_group.dart';

import 'features/grammar/models/grammar_category.dart';
import 'features/grammar/models/grammar_highlight_preset.dart';
import 'features/grammar/models/grammar_highlight_settings.dart';
import 'features/grammar/models/grammar_palette.dart';
import 'features/grammar/widgets/grammar_legend_bar.dart';
import 'features/grammar/widgets/grammar_quick_settings_sheet.dart';
import 'features/learn_by_heart/models/fsrs_models.dart';
import 'features/learn_by_heart/models/learn_by_heart_item.dart';
import 'features/learn_by_heart/widgets/assessment_rating_bar.dart';
import 'features/learn_by_heart/widgets/elaborative_card.dart';
import 'features/learn_by_heart/widgets/fsrs_rating_bar.dart';
import 'features/pdf_reader/services/pdf_reader_theme.dart';
import 'features/pdf_reader/widgets/pdf_reader_theme_sheet.dart';
import 'features/shadowing/models/phoneme_models.dart';
import 'features/shadowing/services/lrc_ab_suggestions.dart';
import 'features/shadowing/widgets/phoneme_display.dart';
import 'features/shadowing/widgets/shadowing_sentence_picker.dart';
import 'features/tipitaka/widgets/opentipitaka_credit.dart';

void main() {
  runApp(const UiGalleryApp());
}

const List<Locale> kGalleryLocales = <Locale>[
  Locale('vi'),
  Locale('en'),
  Locale('hi'),
  Locale('zh'),
  Locale('zh', 'TW'),
  Locale('si'),
  Locale('my'),
  Locale('th'),
  Locale('ja'),
];

class UiGalleryApp extends StatefulWidget {
  const UiGalleryApp({super.key});

  @override
  State<UiGalleryApp> createState() => _UiGalleryAppState();
}

class _UiGalleryAppState extends State<UiGalleryApp> {
  Locale _locale = const Locale('vi');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'In4Up · UI Gallery (preview)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: _locale,
      supportedLocales: kGalleryLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: GalleryHome(
        locale: _locale,
        onLocaleChanged: (l) => setState(() => _locale = l),
      ),
    );
  }
}

class GalleryHome extends StatefulWidget {
  const GalleryHome({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<GalleryHome> createState() => _GalleryHomeState();
}

class _GalleryHomeState extends State<GalleryHome> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('In4Up · UI Gallery'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Locale>(
                value: widget.locale,
                dropdownColor: AppColors.surfaceModal,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.language),
                items: [
                  for (final l in kGalleryLocales)
                    DropdownMenuItem<Locale>(
                      value: l,
                      child: Text(
                        l.toLanguageTag(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
                onChanged: (l) {
                  if (l != null) widget.onLocaleChanged(l);
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SectionTabs(
              value: _section,
              onChanged: (i) => setState(() => _section = i),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
                child: switch (_section) {
                  0 => const _TypographySection(),
                  1 => const _TouchTargetSection(),
                  2 => const _SheetsSection(),
                  3 => const _LocalesSection(),
                  4 => const _GreatLibrarySection(),
                  _ => const _AboutSection(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const List<String> _labels = <String>[
    'Chữ (11sp)',
    'Chạm (40pt)',
    'Sheet',
    '8 locale',
    'Thư viện',
    'Ghi chú',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == value;
          return IntrinsicWidth(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: ChoiceChip(
              label: Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => onChanged(i),
              backgroundColor: AppColors.surfaceElevated,
              selectedColor: AppColors.accentPrimary.withValues(alpha: 0.22),
              side: BorderSide(
                color: selected
                    ? AppColors.accentPrimary.withValues(alpha: 0.6)
                    : AppColors.borderSubtle,
              ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// 0 · TYPOGRAPHY — sàn chữ ≥ 11sp (sprint 3/4)
// ===========================================================================

class _TypographySection extends StatelessWidget {
  const _TypographySection();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final List<(String, TextStyle?, String)> rows = <(String, TextStyle?, String)>[
      ('headlineMedium', t.headlineMedium, 'largeTitle 24'),
      ('titleLarge', t.titleLarge, 'title 20'),
      ('titleMedium', t.titleMedium, 'headline 17'),
      ('bodyLarge', t.bodyLarge, 'body 15'),
      ('bodyMedium', t.bodyMedium, 'subhead 13.5'),
      ('bodySmall', t.bodySmall, 'footnote 12'),
      ('labelLarge', t.labelLarge, 'label 13.5'),
      ('labelMedium', t.labelMedium, 'caption 11'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.text_fields,
          title: 'Sàn chữ ≥ 11sp',
          note:
              'Thang chữ thật trong AppTypography.darkTextTheme(). Sprint 3/4 '
              'nâng mọi chỗ dưới 11sp lên 11sp — dòng "caption" bên dưới là sàn.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in rows) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          'Aa · Tiếng Việt đủ dấu — Ẩm thực, nghiêng ngả',
                          style: row.$2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(row.$2?.fontSize ?? 0).toStringAsFixed(1)}sp',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    row.$1,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted.withValues(alpha: 0.75),
                    ),
                  ),
                  const Divider(height: 18),
                ],
                Row(
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      size: 16,
                      color: Color(0xFF81C784),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Sàn tối thiểu: '
                        '${AppTypography.minReadableSize.toStringAsFixed(1)}sp '
                        '· không còn chữ 9–10sp',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF81C784),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionHeader(
          icon: Icons.abc,
          title: 'Chữ trong widget thật',
          note: 'Tipitaka credit + chú thích phoneme dùng style của widget.',
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OpenTipitakaCredit(),
                SizedBox(height: 10),
                Text(
                  'Mọi nhãn phụ trong app đều đọc được ở 11sp trên màn nhỏ.',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const ElaborativeCard(
          shortMeaning: 'Không phóng dật là con đường bất tử.',
          keywords: <String>['appamāda', 'phóng dật', 'bất tử'],
          lifeConnection:
              'Mỗi sáng, chọn một việc nhỏ rồi làm cho trọn — đó là phóng dật '
              'được chuyển hoá thành tinh tấn.',
          initiallyExpanded: true,
        ),
      ],
    );
  }
}

// ===========================================================================
// 1 · TOUCH TARGET — vùng chạm ≥ 40pt
// ===========================================================================

class _TouchTargetSection extends StatefulWidget {
  const _TouchTargetSection();

  @override
  State<_TouchTargetSection> createState() => _TouchTargetSectionState();
}

class _TouchTargetSectionState extends State<_TouchTargetSection> {
  FSRSRating _rating = FSRSRating.good;
  AssessmentRating _assessment = AssessmentRating.nearCorrect;
  int _picker = 1;

  static final LearnByHeartItem _demoItem = LearnByHeartItem(
    id: 'gallery-demo',
    title: 'Appamādo amaṭapadaṁ',
    paliText: 'Appamādo amaṭapadaṁ, pamādo maccuno padaṁ.',
    vietnameseText: 'Không phóng dật là con đường bất tử.',
    createdAt: DateTime(2024, 1, 1),
    consecutiveSuccesses: 5,
    totalReviews: 12,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.touch_app_outlined,
          title: 'Vùng chạm ≥ 40pt',
          note:
              'AppTheme bật materialTapTargetSize.padded và sprint 3/4 nâng '
              'từng nút chọn lên tối thiểu 40pt. Bấm thử — nút nào cũng dễ '
              'trúng ở ngón tay trên mobile.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FSRSRatingBar — đánh giá ôn tập',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                FSRSRatingBar(
                  item: _demoItem,
                  onRated: (r) => setState(() => _rating = r),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đã chọn: ${_rating.label}',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AssessmentRatingBar — kiểm tra thực chất',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                AssessmentRatingBar(
                  onRated: (r) => setState(() => _assessment = r),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đã chọn: ${_assessment.label}',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ShadowingSentencePicker — 3 hàng timestamp 11sp',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                ShadowingSentencePicker(
                  suggestions: _abSuggestions,
                  selectedIndex: _picker,
                  onSelected: (s) => setState(() => _picker = s.index),
                  onUseCurrent: () => setState(() => _picker = -1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                PhonemeDisplay(
                  word: 'appamāda',
                  phonemeScores: _phonemes,
                  showDetails: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static final List<AbSuggestion> _abSuggestions = <AbSuggestion>[
    const AbSuggestion(
      index: 0,
      start: Duration(seconds: 12),
      end: Duration(seconds: 18),
      text: 'Appamādo amaṭapadaṁ',
    ),
    const AbSuggestion(
      index: 1,
      start: Duration(seconds: 19),
      end: Duration(seconds: 27),
      text: 'pamādo maccuno padaṁ',
    ),
    const AbSuggestion(
      index: 2,
      start: Duration(seconds: 28, milliseconds: 400),
      end: Duration(seconds: 36),
      text: 'appamattā na mīyanti',
    ),
    const AbSuggestion(
      index: 3,
      start: Duration(minutes: 1, seconds: 2),
      end: Duration(minutes: 1, seconds: 11),
      text: 'ye pamattā yathā matā',
    ),
  ];

  static const List<PhonemeScore> _phonemes = <PhonemeScore>[
    PhonemeScore(
      phoneme: 'æ',
      type: PhonemeType.vowel,
      score: 0.91,
      status: PhonemeStatus.correct,
    ),
    PhonemeScore(
      phoneme: 'p',
      type: PhonemeType.consonant,
      score: 0.86,
      status: PhonemeStatus.correct,
    ),
    PhonemeScore(
      phoneme: 'ə',
      type: PhonemeType.vowel,
      score: 0.74,
      status: PhonemeStatus.acceptable,
    ),
    PhonemeScore(
      phoneme: 'm',
      type: PhonemeType.consonant,
      score: 0.62,
      status: PhonemeStatus.needsWork,
    ),
    PhonemeScore(
      phoneme: 'd',
      type: PhonemeType.consonant,
      score: 0.38,
      status: PhonemeStatus.missed,
    ),
  ];
}

// ===========================================================================
// 2 · SHEETS — SafeArea trong bottom sheet
// ===========================================================================

class _SheetsSection extends StatelessWidget {
  const _SheetsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.vertical_align_bottom,
          title: 'SafeArea trong sheet',
          note:
              'Mở từng sheet THẬT bên dưới. Tất cả dùng showModalBottomSheet với '
              'useSafeArea: true + isScrollControlled: true ⇒ không bị tai thỏ / '
              'thanh home che, và kéo được khi nội dung dài.',
        ),
        const SizedBox(height: 12),
        _SheetLauncher(
          icon: Icons.text_format,
          title: 'Bảng chú giải ngữ pháp',
          subtitle: 'GrammarQuickSettingsSheet · useSafeArea: true',
          onTap: () => GrammarQuickSettingsSheet.show(
            context,
            title: 'Chú giải ngữ pháp',
            settings: GrammarHighlightSettings.defaults(),
            palette: GrammarPalettes.defaults().first,
            activePreset: GrammarHighlightPresets.defaults().first,
            presets: GrammarHighlightPresets.defaults(),
            onToggleEnabled: (_) async {},
            onSelectPreset: (_) async {},
            onSaveCurrentAsPreset: (name, description) async =>
                GrammarHighlightPresets.defaults().first,
            onRestorePreviousPreset: () async {},
            onToggleAdvancedMode: (_) async {},
            onSelectPalette: (_) async {},
            onSelectStyle: (_) async {},
            onToggleCategory: (_) async {},
            onToggleLegend: (_) async {},
            onShowAllCategories: () async {},
          ),
        ),
        const SizedBox(height: 10),
        _SheetLauncher(
          icon: Icons.palette_outlined,
          title: 'Giao diện trình đọc PDF',
          subtitle: 'PdfReaderThemeSheet · sheet thật của PDF Reader',
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => PdfReaderThemeSheet(
              state: PdfReaderThemeState.defaults,
              onChanged: (_) {},
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _SectionHeader(
          icon: Icons.view_agenda_outlined,
          title: 'Nhóm cài đặt dạng thẻ',
          note:
              'ReadSettingsGroup / ReadSettingsLinkRow — hai kiểu hàng cài đặt '
              'đã đổi ở sprint 3/4 (mũi tên đúng nghĩa: mở tại chỗ vs mở trang).',
        ),
        const SizedBox(height: 12),
        const _ReadSettingsGroupDemo(),
      ],
    );
  }
}

class _SheetLauncher extends StatelessWidget {
  const _SheetLauncher({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.open_in_new, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadSettingsGroupDemo extends StatefulWidget {
  const _ReadSettingsGroupDemo();

  @override
  State<_ReadSettingsGroupDemo> createState() => _ReadSettingsGroupDemoState();
}

class _ReadSettingsGroupDemoState extends State<_ReadSettingsGroupDemo> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReadSettingsGroup(
          tapKey: const ValueKey('gallery-read-group'),
          icon: Icons.tune,
          title: 'Hiển thị khi đọc',
          summary: 'Cỡ chữ 15sp · IPA bật · 3 màu từ loại',
          open: _open,
          onToggle: () => setState(() => _open = !_open),
          children: const [
            ReadSettingsLinkRow(
              tapKey: ValueKey('gallery-row-voice'),
              icon: Icons.record_voice_over_outlined,
              title: 'Giọng đọc',
              summary: 'Chọn giọng, tốc độ, khoảng nghỉ',
              onTap: _noop,
            ),
            ReadSettingsLinkRow(
              tapKey: ValueKey('gallery-row-color'),
              icon: Icons.color_lens_outlined,
              title: 'Kiểu tô màu từ',
              summary: 'Theo từ loại / theo cấp độ từ vựng',
              onTap: _noop,
            ),
            ReadSettingsLinkRow(
              tapKey: ValueKey('gallery-row-ipa'),
              icon: Icons.spellcheck,
              title: 'Phiên âm IPA',
              summary: 'Hiện trên đầu từ · kiểu mảnh',
              onTap: _noop,
            ),
          ],
        ),
        ReadSettingsLinkRow(
          tapKey: const ValueKey('gallery-row-translate'),
          icon: Icons.translate,
          title: 'Dịch toàn văn',
          summary: 'Mở trang chọn ngôn ngữ đích',
          onTap: _noop,
        ),
      ],
    );
  }
}

void _noop() {}

// ===========================================================================
// 3 · LOCALES — 8 locale ưu tiên
// ===========================================================================

class _LocalesSection extends StatelessWidget {
  const _LocalesSection();

  @override
  Widget build(BuildContext context) {
    final current = Localizations.localeOf(context).toLanguageTag();
    const samples = <String>[
      'Thư viện chung',
      'Chạm để đọc tiếp',
      'Chọn ngôn ngữ đích',
      'Đã lưu từ vựng',
      'Không phóng dật là con đường bất tử.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.translate,
          title: 'Dịch UI · 8 locale ưu tiên',
          note:
              'Đổi ngôn ngữ ở góc phải AppBar. Chuỗi bên dưới đi qua đúng bộ '
              'dịch của app (AppUITranslations + priority pack) chứ không phải '
              'bản dịch làm sẵn trong gallery.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Locale hiện tại: $current',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                for (final s in samples) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.uiText(s),
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'gốc: $s',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted.withValues(alpha: 0.8),
                    ),
                  ),
                  const Divider(height: 18),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cùng một chuỗi ở 8 locale ưu tiên',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                for (final code in const [
                  'vi',
                  'en',
                  'hi',
                  'zh',
                  'zh_TW',
                  'si',
                  'my',
                  'th',
                  'ja',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            code,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            AppUITranslations.translate(
                              'Chạm để đọc tiếp',
                              code,
                            ),
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: GrammarLegendBarDemo(),
          ),
        ),
      ],
    );
  }
}

/// Legend thật (chips từ loại) — cũng là nơi dễ thấy nhất việc nâng 11sp.
class GrammarLegendBarDemo extends StatefulWidget {
  const GrammarLegendBarDemo({super.key});

  @override
  State<GrammarLegendBarDemo> createState() => _GrammarLegendBarDemoState();
}

class _GrammarLegendBarDemoState extends State<GrammarLegendBarDemo> {
  late GrammarHighlightSettings _settings = GrammarHighlightSettings.defaults();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GrammarLegendBar — chip từ loại',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GrammarLegendBar(
          settings: _settings,
          palette: GrammarPalettes.byId(_settings.paletteId),
          horizontalScroll: true,
          onToggleCategory: (c) => setState(() {
            final next = Set<GrammarCategory>.of(_settings.visibleCategories);
            if (!next.remove(c)) next.add(c);
            _settings = GrammarHighlightSettings(
              enabled: _settings.enabled,
              activePresetId: _settings.activePresetId,
              lastNonCustomPresetId: _settings.lastNonCustomPresetId,
              paletteId: _settings.paletteId,
              highlightStyle: _settings.highlightStyle,
              visibleCategories: next,
              showLegend: _settings.showLegend,
              legendCollapsed: _settings.legendCollapsed,
              emphasizeContentWords: _settings.emphasizeContentWords,
              dimHiddenCategories: _settings.dimHiddenCategories,
              showAdvancedControls: _settings.showAdvancedControls,
            );
          }),
        ),
      ],
    );
  }
}

// ===========================================================================
// 4 · GREAT LIBRARY — trạng thái "có trên app native, không lên web"
// ===========================================================================

class _GreatLibrarySection extends StatelessWidget {
  const _GreatLibrarySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.library_books_outlined,
          title: 'Thư Viện Chung (GLIB)',
          note:
              'GLIB có 5 màn thật (thư viện, chi tiết gói, đóng góp, kiểm duyệt, '
              'đóng góp của tôi) nhưng phụ thuộc tầng file/FFI nên KHÔNG build '
              'được cho web. Phần này chỉ mô tả — muốn xem thì cài APK/IPA của '
              'beta, hoặc xem trên app native.',
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GlItem('GreatLibraryScreen', 'Duyệt & tìm gói nội dung'),
                _GlItem('PackDetailScreen', 'Chi tiết gói + tải/cài đặt'),
                _GlItem('ContributeWizardScreen', 'Wizard đóng góp nhiều bước'),
                _GlItem('MyContributionsScreen', 'Theo dõi đóng góp đã gửi'),
                _GlItem('AdminModerationScreen', 'Hàng chờ kiểm duyệt (admin)'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionHeader(
          icon: Icons.info_outline,
          title: 'Vì sao gallery không có màn nào khác?',
          note:
              'ReadSettingsSheet, PdfToolbar, DictEntryDetailSheet, '
              'LiveCaptionBubble… kéo dart:io / dart:ffi / dart:isolate qua '
              'tầng service ⇒ không tồn tại trên web. Đây là giới hạn của '
              'nền tảng, không phải lỗi của beta.',
        ),
      ],
    );
  }
}

class _GlItem extends StatelessWidget {
  const _GlItem(this.name, this.description);

  final String name;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_outline, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'native',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 5 · ABOUT
// ===========================================================================

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.fact_check_outlined,
          title: 'Preview này là gì?',
          note:
              'Một app Flutter thật, build từ chính commit của 1.30.1-Beta, chỉ '
              'dựng các widget thật vào một gallery để xem giao diện trên '
              'trình duyệt mà không cần cài APK/IPA.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _AboutRow('Nội dung', '1.30.0-Beta + 1.30.1-Beta'),
                _AboutRow('Commit', 'cbaf7d51 · arena/395208ef-in4up'),
                _AboutRow('Phiên bản', '1.30.1+33'),
                _AboutRow('Widget', 'theme + widget thật, không mock'),
                _AboutRow('Locale', '9 nút chọn · 8 locale ưu tiên'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không có trong preview',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Âm thanh/ghi âm, tải gói, dịch bằng engine FFI, PDF OCR, '
                  'đồng bộ Firebase — cần quyền + native. Các màn dùng những '
                  'thành phần này chỉ xem được trên app cài thật (APK/IPA của '
                  'beta).',
                  style: TextStyle(fontSize: 11.5, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared
// ===========================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.note,
  });

  final IconData icon;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: AppColors.accentPrimary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                note,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
