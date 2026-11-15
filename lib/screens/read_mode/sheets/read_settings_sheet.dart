// lib/screens/read_mode/sheets/read_settings_sheet.dart
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:in4up_core/vocab_level_difficulty.dart';

import '../../../features/grammar/grammar.dart';
import '../../../features/translation/translation_language_picker.dart';
import '../../../models/color_mode.dart';
import '../../../models/ipa_display_mode.dart';
import '../../../models/word_analysis.dart';
import '../../../models/word_color_style.dart';
import '../../../providers/text_provider.dart';
import '../../../services/ipa_styling.dart';
import '../../../services/storage_service.dart';
import '../controllers/read_mode_controller.dart';
import '../services/playback_controller.dart';
import '../widgets/read_settings_group.dart';
import 'read_voice_settings_page.dart';

class ReadSettingsSheet {
  ReadSettingsSheet._();

  static void show(BuildContext context) {
    context.read<TextProvider>().refreshGrammarPresetLibrary();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _SettingsContent(),
    ).then((_) {
      // AUDIT-2026-10-20 (mục 1): sheet đóng ⇒ cấu hình vừa đổi (ví dụ vị
      // trí phần TIÊU ĐỀ khi ở chế độ Focus) phải có hiệu lực NGAY, không
      // phải đợi mở lại app. Báo cho ReadModeController refresh ⇒ màn Đọc
      // rebuild ⇒ đọc lại setting từ storage.
      if (!context.mounted) return;
      try {
        context.read<ReadModeController>().requestRefresh();
      } catch (_) {
        // Màn Đọc đã bị đóng trong lúc mở sheet — không cần refresh.
      }
    });
  }
}

/// PSRC-236 / ADR-0030 D1 — các nhóm gập của «Cài đặt Text Studio».
enum _SettingsGroupId { text, translation, color }

/// PSRC-236 / ADR-0030: bảng cài đặt KHÔNG còn là một trang cuộn dài.
///
///   * D1 — 3 nhóm gập, mỗi nhóm có DÒNG TÓM TẮT giá trị đang chọn ⇒ mở bảng
///     là thấy hết trạng thái hiện tại mà không cần cuộn (nhận ra, không
///     phải nhớ). Mỗi lần chỉ mở MỘT nhóm ⇒ trang luôn ngắn.
///   * D2 — cấu hình engine giọng đọc (thứ tự engine, model, giọng theo ngôn
///     ngữ, cache, giấy phép) là thứ chỉnh MỘT LẦN ⇒ trang riêng
///     `ReadVoiceSettingsPage`, vào bằng một dòng ở cuối bảng.
///   * D3 — «Tách dòng tự động» là THAO TÁC trên văn bản ⇒ đã chuyển sang
///     panel «Công cụ đọc» (`showAutoSplitSheet`), không còn ở đây.
class _SettingsContent extends StatefulWidget {
  const _SettingsContent();

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  /// Nhớ nhóm đang mở TRONG PHIÊN chạy app: đóng bảng rồi mở lại vẫn ở đúng
  /// nhóm vừa chỉnh. `null` (mặc định) = gập hết ⇒ lần đầu thấy toàn cảnh.
  static _SettingsGroupId? _lastOpen;

  final Map<_SettingsGroupId, GlobalKey> _groupKeys = {
    for (final id in _SettingsGroupId.values) id: GlobalKey(),
  };

  _SettingsGroupId? _open = _lastOpen;

  void _toggle(_SettingsGroupId id) {
    final opening = _open != id;
    setState(() {
      _open = opening ? id : null;
      _lastOpen = _open;
    });
    if (!opening) return;
    // Nhóm phía trên vừa gập lại ⇒ tiêu đề nhóm vừa chạm có thể trượt ra
    // ngoài màn hình. Chỉ cuộn khi tiêu đề KHÔNG còn nhìn thấy.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _groupKeys[id]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 180),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Consumer<TextProvider>(
          builder: (context, tp, _) {
            final source = tp.detectedSourceLanguage;
            final target = tp.translationTargetLanguage;
            final alignLabel = context.uiText(
              tp.textAlign == TextAlign.center ? 'Giữa' : 'Trái',
            );
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Color(0xFF2196F3)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Cài đặt Text Studio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // PSRC-235: thứ tự theo TẦN SUẤT dùng. Đã bỏ khỏi bảng này
                  // «Chế độ trải nghiệm» (`subMode` không ai đọc — TẠM bỏ,
                  // xem ADR-0030 D5) và cụm «Text-to-Speech» (lối phát + đường
                  // tốc độ thứ hai, lệch ADR-0021 D1). Cài đặt chỉ chứa GIÁ
                  // TRỊ cấu hình, không chứa nút hành động.

                  // ===== NHÓM 1: CHỮ & BỐ CỤC =====
                  ReadSettingsGroup(
                    key: _groupKeys[_SettingsGroupId.text],
                    tapKey: const Key('read-settings-group-text'),
                    icon: Icons.text_fields,
                    title: 'Chữ & bố cục',
                    summary: '${context.uiText('Cỡ chữ')} '
                        '${tp.fontSize.round()} · $alignLabel',
                    open: _open == _SettingsGroupId.text,
                    onToggle: () => _toggle(_SettingsGroupId.text),
                    children: [
                      const _SectionTitle(
                          title: 'Cỡ chữ', icon: Icons.text_fields),
                      const SizedBox(height: 12),
                      _FontSizeControl(tp: tp),
                      const SizedBox(height: 20),
                      const _SectionTitle(
                          title: 'Căn lề văn bản',
                          icon: Icons.format_align_center),
                      const SizedBox(height: 12),
                      _AlignmentSelector(tp: tp),
                      const SizedBox(height: 20),
                      // PSRC-235: tên cũ «Hiển thị» trùng với popup / tab
                      // dock / sheet. Chỉ còn 2 công tắc về DÒNG.
                      const _SectionTitle(
                          title: 'Dòng văn bản',
                          icon: Icons.format_list_numbered),
                      const SizedBox(height: 12),
                      _LineOptions(tp: tp),
                      const SizedBox(height: 20),
                      // IN4-30 — giữ phần tiêu đề khi ở chế độ Focus.
                      const _SectionTitle(
                          title: 'Chế độ Focus: giữ tiêu đề',
                          icon: Icons.fullscreen),
                      const SizedBox(height: 12),
                      const _FocusTitlePositionSelector(),
                    ],
                  ),

                  // ===== NHÓM 2: DỊCH & ĐỌC SONG NGỮ =====
                  ReadSettingsGroup(
                    key: _groupKeys[_SettingsGroupId.translation],
                    tapKey: const Key('read-settings-group-translation'),
                    icon: Icons.compare_arrows_rounded,
                    title: 'Dịch & đọc song ngữ',
                    summary: '${source.nativeName} → ${target.nativeName}',
                    // Cặp trùng (ví dụ «Tiếng Việt → Tiếng Việt») phải lộ ra
                    // ngay ở dòng tóm tắt, không đợi người dùng mở nhóm.
                    summaryColor: tp.translationPairUsesSameLanguage
                        ? Colors.amber
                        : null,
                    open: _open == _SettingsGroupId.translation,
                    onToggle: () => _toggle(_SettingsGroupId.translation),
                    children: [
                      _TranslationLanguageSection(tp: tp),
                    ],
                  ),

                  // ===== NHÓM 3: MÀU & PHIÊN ÂM =====
                  ReadSettingsGroup(
                    key: _groupKeys[_SettingsGroupId.color],
                    tapKey: const Key('read-settings-group-color'),
                    icon: Icons.palette,
                    title: 'Màu & phiên âm',
                    summary: '${context.uiText(tp.colorMode.label)} · IPA: '
                        '${context.uiText(tp.ipaDisplayMode.label)}',
                    open: _open == _SettingsGroupId.color,
                    onToggle: () => _toggle(_SettingsGroupId.color),
                    children: [
                      const _SectionTitle(
                          title: 'Chế độ màu', icon: Icons.palette),
                      const SizedBox(height: 12),
                      _ColorModeSelector(tp: tp),

                      // READ-WORDSTYLE-001: kiểu hiển thị từ (nền màu / chỉ
                      // màu chữ / gạch chân) — tách khỏi "chọn màu gì" để
                      // người đọc lâu chọn kiểu nhẹ mắt mà vẫn giữ tô màu.
                      if (tp.colorMode != ColorMode.none) ...[
                        const SizedBox(height: 16),
                        _WordColorStyleSelector(tp: tp),
                        const SizedBox(height: 16),
                        _LegendPanel(colorMode: tp.colorMode),
                      ],

                      if (tp.colorMode == ColorMode.wordType) ...[
                        const SizedBox(height: 16),
                        _GrammarHighlightSection(tp: tp),
                      ],

                      const SizedBox(height: 20),

                      // READ-IPA-001
                      const _SectionTitle(
                          title: 'Phiên âm / IPA', icon: Icons.abc),
                      const SizedBox(height: 12),
                      _IpaModeSelector(tp: tp),
                      const SizedBox(height: 16),
                      const _IpaSaveSourceSection(),
                      const SizedBox(height: 12),
                      _IpaColorOptions(tp: tp),
                    ],
                  ),

                  // ===== GIỌNG ĐỌC & ENGINE — trang riêng (ADR-0030 D2) =====
                  ReadSettingsLinkRow(
                    tapKey: const Key('read-settings-open-voice'),
                    icon: Icons.record_voice_over,
                    title: 'Giọng đọc & engine',
                    summary: 'Thứ tự engine, giọng theo ngôn ngữ, model, cache',
                    onTap: () => ReadVoiceSettingsPage.open(context),
                  ),

                  // Chỉ đường cho người quen bảng cũ: thứ đã rời bảng này
                  // nằm ở đâu (tránh cảm giác «nút biến mất» — ADR-0024).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                    child: Text(
                      'Nút đọc, tốc độ và Tách dòng tự động nằm ở thanh công cụ đọc.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AlignmentSelector extends StatelessWidget {
  final TextProvider tp;
  const _AlignmentSelector({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildAlignBtn(Icons.format_align_left, 'Trái', TextAlign.left),
          const SizedBox(width: 8),
          _buildAlignBtn(Icons.format_align_center, 'Giữa', TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildAlignBtn(IconData icon, String label, TextAlign align) {
    final isSelected = tp.textAlign == align;
    return Expanded(
      child: GestureDetector(
        onTap: () => tp.setTextAlign(align),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2196F3) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2196F3)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _FontSizeControl extends StatelessWidget {
  final TextProvider tp;
  const _FontSizeControl({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => tp.setFontSize(tp.fontSize - 2),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.remove, color: Colors.white, size: 20),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  context.uiText('${tp.fontSize.toInt()}'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: tp.fontSize,
                  min: 12,
                  max: 36,
                  divisions: 12,
                  activeColor: const Color(0xFF2196F3),
                  onChanged: (v) => tp.setFontSize(v),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => tp.setFontSize(tp.fontSize + 2),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslationLanguageSection extends StatelessWidget {
  final TextProvider tp;

  const _TranslationLanguageSection({required this.tp});

  @override
  Widget build(BuildContext context) {
    final source = tp.detectedSourceLanguage;
    final target = tp.translationTargetLanguage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslationLanguagePickerButton(
            sourceLanguage: source,
            targetLanguage: target,
            compact: false,
            accentColor: const Color(0xFF53D6BD),
            onSelected: (language) async {
              final playback = context.read<PlaybackController>();
              if (playback.isRunning) {
                playback.stop(fileId: tp.currentDocument?.id ?? 'unknown');
              }
              await tp.stopSpeaking();
              await tp.setTranslationTargetLanguage(
                language.translationCode,
                retranslateExisting: true,
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            context.uiText('Nguồn được nhận diện tự động. Khi đọc song ngữ, In4Up sẽ chuyển giọng ${source.ttsLocale} ↔ ${target.ttsLocale} trước từng lượt đọc.'),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              height: 1.4,
            ),
          ),
          if (tp.translationPairUsesSameLanguage) ...[
            const SizedBox(height: 8),
            const Text(
              'Hãy chọn ngôn ngữ đích khác ngôn ngữ nguồn.',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorModeSelector extends StatelessWidget {
  final TextProvider tp;
  const _ColorModeSelector({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ColorMode.values.map((mode) {
        final isSelected = tp.colorMode == mode;
        return GestureDetector(
          onTap: () => tp.setColorMode(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2196F3)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2196F3)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mode.icon,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  context.uiText(mode.label),
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// READ-WORDSTYLE-001 — chọn kiểu hiển thị từ khi tô màu.
///
/// Owner 2026-10-25: "có người chỉ muốn đổi màu chữ thôi thay vì có màu nền…
/// khi đọc hay xem không bị phân tâm bởi màu sắc quá". Ba lựa chọn áp cho cả
/// chế độ ô chữ (`ColoredTextWidget`) lẫn chế độ bôi chữ (`SelectableText.rich`).
class _WordColorStyleSelector extends StatelessWidget {
  final TextProvider tp;
  const _WordColorStyleSelector({required this.tp});

  @override
  Widget build(BuildContext context) {
    final current = tp.wordColorStyle;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_paint, size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.uiText('Kiểu hiển thị từ'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final style in WordColorStyle.values) ...[
                Expanded(
                  child: _WordColorStyleChip(
                    style: style,
                    selected: current == style,
                    onTap: () => tp.setWordColorStyle(style),
                  ),
                ),
                if (style != WordColorStyle.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.uiText(current.description),
            style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _WordColorStyleChip extends StatelessWidget {
  final WordColorStyle style;
  final bool selected;
  final VoidCallback onTap;

  const _WordColorStyleChip({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF2196F3);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Xem trước ngay trong chip: nền / chữ màu / gạch chân.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: style == WordColorStyle.fill
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.22)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Aa',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF81C784),
                  decoration: style == WordColorStyle.underline
                      ? TextDecoration.underline
                      : null,
                  decorationColor: const Color(0xFF81C784),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.uiText(style.label),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: selected ? Colors.white : Colors.grey[500],
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip chọn chế độ IPA — READ-IPA-001.
/// Cyan (0xFF4DD0E1) — cùng tông với dòng IPA xếp chồng trong text.
class _IpaModeSelector extends StatelessWidget {
  final TextProvider tp;
  const _IpaModeSelector({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: IpaDisplayMode.values.map((mode) {
        final isSelected = tp.ipaDisplayMode == mode;
        return GestureDetector(
          onTap: () => tp.setIpaDisplayMode(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4DD0E1)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4DD0E1)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mode.icon,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  context.uiText(mode.label),
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Selector "Nguồn IPA khi lưu" — READ-IPA-002 (ADR-0005).
/// Setting toàn cục `ipa_save_source`: auto / dict / g2p / off —
/// quyết định waterfall khi resolver điền IPA còn trống lúc lưu từ.
class _IpaSaveSourceSection extends StatefulWidget {
  const _IpaSaveSourceSection();

  @override
  State<_IpaSaveSourceSection> createState() => _IpaSaveSourceSectionState();
}

class _IpaSaveSourceSectionState extends State<_IpaSaveSourceSection> {
  static const Color _accent = Color(0xFF6C63FF);

  late String _source;

  @override
  void initState() {
    super.initState();
    _source = StorageService().getIpaSaveSource();
  }

  void _select(String value) {
    setState(() => _source = value);
    StorageService().saveIpaSaveSource(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nguồn IPA khi lưu',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tự điền IPA cho từ lưu mới — không hỏi lại từng lần.',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _sourceChip('auto', 'Tự động', Icons.auto_awesome, _accent),
            _sourceChip('dict', 'Từ điển', Icons.menu_book, _accent),
            _sourceChip('g2p', 'G2P', Icons.biotech, _accent),
            _sourceChip('off', 'Tắt', Icons.block, _accent),
          ],
        ),
      ],
    );
  }

  Widget _sourceChip(String value, String label, IconData icon, Color accent) {
    final isSelected = _source == value;
    return GestureDetector(
      onTap: () => _select(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? accent : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggle tô màu phoneme + mờ IPA từ đã thuộc — READ-IPA-004 (ADR-0005 §4).
/// Cả hai default OFF; legend hiện ra khi bật tô màu (không nhập
/// [_LegendPanel] — keying khác: ipaColorByType ≠ colorMode).
///
/// READ-IPA-006: chip màu THÀNH toggle (ẩn/bật riêng từng loại) + nút mở
/// bảng màu ngay trên văn bản.
class _IpaColorOptions extends StatelessWidget {
  final TextProvider tp;
  const _IpaColorOptions({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Tô màu phoneme',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            value: tp.ipaColorByType,
            activeThumbColor: const Color(0xFFF0E442),
            onChanged: tp.setIpaColorByType,
          ),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
          SwitchListTile(
            title: const Text('Mờ IPA từ đã thuộc',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            value: tp.ipaFadeKnown,
            activeThumbColor: const Color(0xFF4DD0E1),
            onChanged: tp.setIpaFadeKnown,
          ),
          SwitchListTile(
            title: const Text('Bảng màu IPA trên văn bản',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text(
              'Dải thông tin màu ngay đầu màn hình đọc — ẩn/mở bằng nút “Màu IPA”.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            value: tp.ipaLegendVisible,
            activeThumbColor: const Color(0xFF4DD0E1),
            onChanged: tp.setIpaLegendVisible,
          ),
          if (tp.ipaColorByType) ...[
            Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Loại màu (chạm để ẩn/bật):',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[400]),
                    ),
                  ),
                  if (tp.ipaColorVisibility.hasHidden)
                    TextButton(
                      onPressed: tp.resetIpaColorVisibility,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF9FA8DA),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      child: const Text('Bật lại tất cả'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _IpaToggleChip(
                    color: IpaStyling.stressColor,
                    label: 'Trọng âm',
                    on: tp.ipaColorVisibility.stress,
                    onTap: () => tp.setIpaColorVisible(stress: !tp.ipaColorVisibility.stress),
                  ),
                  _IpaToggleChip(
                      color: IpaStyling.vowelColor,
                      label: 'Nguyên âm',
                      on: tp.ipaColorVisibility.vowels,
                      onTap: () => tp.setIpaColorVisible(vowels: !tp.ipaColorVisibility.vowels)),
                  _IpaToggleChip(
                      color: IpaStyling.consonantColor,
                      label: 'Phụ âm',
                      on: tp.ipaColorVisibility.consonants,
                      onTap: () => tp.setIpaColorVisible(consonants: !tp.ipaColorVisibility.consonants)),
                  _IpaToggleChip(
                      color: IpaStyling.diphthongColor,
                      label: 'Đôi nguyên âm',
                      on: tp.ipaColorVisibility.diphthongs,
                      onTap: () => tp.setIpaColorVisible(diphthongs: !tp.ipaColorVisibility.diphthongs)),
                  _IpaToggleChip(
                      color: IpaStyling.linkingColor,
                      label: 'Nối âm',
                      on: tp.ipaColorVisibility.linking,
                      onTap: () => tp.setIpaColorVisible(linking: !tp.ipaColorVisibility.linking)),
                  _IpaToggleChip(
                      color: IpaStyling.stressColor,
                      label: 'Từ nhấn',
                      on: tp.ipaColorVisibility.stressWords,
                      onTap: () => tp.setIpaColorVisible(stressWords: !tp.ipaColorVisibility.stressWords),
                      markHint: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IpaToggleChip extends StatelessWidget {
  final Color color;
  final String label;
  final bool on;
  final VoidCallback onTap;
  final bool markHint;

  const _IpaToggleChip({
    required this.color,
    required this.label,
    required this.on,
    required this.onTap,
    this.markHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: on ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color.withValues(alpha: on ? 0.55 : 0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: on ? color : Colors.grey[500],
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (markHint) ...[
                const SizedBox(width: 3),
                Text(
                  '¯',
                  style: TextStyle(
                    color: IpaStyling.stressColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendPanel extends StatelessWidget {
  final ColorMode colorMode;
  const _LegendPanel({required this.colorMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: _items),
        ],
      ),
    );
  }

  String get _title {
    switch (colorMode) {
      case ColorMode.none:
        return '';
      case ColorMode.wordType:
        return 'Loại từ (Syntax Highlighting):';
      case ColorMode.cefrLevel:
        return 'Cấp độ CEFR:';
      case ColorMode.difficulty:
        return 'Độ khó (bạn đánh dấu):';
    }
  }

  List<Widget> get _items {
    switch (colorMode) {
      case ColorMode.none:
        return [];
      case ColorMode.wordType:
        return WordType.values
            .where((t) => t != WordType.unknown)
            .map((type) => _Chip(color: type.color, label: type.labelVi))
            .toList();
      case ColorMode.cefrLevel:
        return CEFRLevel.values
            .where((l) => l != CEFRLevel.unknown)
            .map((level) => _Chip(color: level.color, label: level.shortLabel))
            .toList();
      case ColorMode.difficulty:
        return DifficultyLevel.values
            .map((level) => _Chip(color: level.color, label: level.label))
            .toList();
    }
  }
}

class _Chip extends StatelessWidget {
  final Color color;
  final String label;
  const _Chip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GrammarHighlightSection extends StatelessWidget {
  final TextProvider tp;

  const _GrammarHighlightSection({required this.tp});

  @override
  Widget build(BuildContext context) {
    final settings = tp.grammarSettings;
    final palette = tp.activeGrammarPalette;
    final presets = tp.availableGrammarPresets;
    final builtInPresets = presets.where((preset) => preset.isBuiltIn).toList();
    final customPresets = presets.where((preset) => !preset.isBuiltIn).toList();
    final palettes = GrammarPalettes.defaults();
    final previousPreset = presets.firstWhere(
      (preset) => preset.id == settings.lastNonCustomPresetId,
      orElse: () => GrammarHighlightPresets.byId(settings.lastNonCustomPresetId),
    );
    final activePresetName = tp.activeGrammarPreset.isBuiltIn
        ? context.uiText(tp.activeGrammarPreset.name)
        : tp.activeGrammarPreset.name;
    final previousPresetName = previousPreset.isBuiltIn
        ? context.uiText(previousPreset.name)
        : previousPreset.name;
    final hiddenCategories = GrammarCategory.values
        .where((category) => !settings.visibleCategories.contains(category))
        .toList()
      ..sort((a, b) => a.referenceStyleIndex.compareTo(b.referenceStyleIndex));
    final groupOrder = const [
      GrammarCategoryGroup.contentWord,
      GrammarCategoryGroup.functionWord,
      GrammarCategoryGroup.symbols,
      GrammarCategoryGroup.structural,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  title: 'Phase A · Từ loại chuyên sâu',
                  icon: Icons.auto_awesome_motion,
                ),
              ),
              Switch(
                value: settings.enabled,
                activeColor: const Color(0xFF6C63FF),
                onChanged: (value) => tp.setGrammarHighlightEnabled(value),
              ),
            ],
          ),
          Text(
            'Panel này đã được làm lại theo hướng control panel: preset đẹp hơn, so sánh palette trực quan hơn, có mini/advanced và cho phép lưu preset cá nhân.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _GrammarControlSummary(
            settings: settings,
            activePresetName: activePresetName,
            previousPresetName: previousPresetName,
            visibleCount: settings.visibleCategories.length,
            hiddenCount: hiddenCategories.length,
            onRestorePreviousPreset: tp.restorePreviousGrammarPreset,
            onToggleAdvancedMode: tp.setGrammarAdvancedControls,
            onSaveCurrentPreset: () async {
              final draft = await _showReadSavePresetDialog(
                context,
                activePresetName,
              );
              if (draft == null) return;
              await tp.saveCurrentGrammarPreset(
                name: draft.name,
                description: draft.description,
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            'Preset gợi ý',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: builtInPresets.map((preset) {
              final selected = settings.activePresetId == preset.id;
              return _PresetChoiceCard(
                preset: preset,
                selected: selected,
                onTap: () => tp.applyGrammarPreset(preset.id),
              );
            }).toList(),
          ),
          if (customPresets.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Preset của bạn',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: customPresets.map((preset) {
                final selected = settings.activePresetId == preset.id;
                return _PresetChoiceCard(
                  preset: preset,
                  selected: selected,
                  onTap: () => tp.applyGrammarPreset(preset.id),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            settings.showAdvancedControls ? 'Preview & legend' : 'Preview nhanh',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          GrammarStylePreview(
            settings: settings,
            palette: palette,
          ),
          const SizedBox(height: 12),
          GrammarLegendBar(
            settings: settings,
            palette: palette,
            onToggleCategory: (category) => tp.toggleGrammarCategory(category),
          ),
          if (hiddenCategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ReadSettingsHiddenGrammarCard(
              hiddenCategories: hiddenCategories,
              palette: palette,
              previousPresetName: previousPresetName,
              onShowAllCategories: tp.showAllGrammarCategories,
              onToggleCategory: tp.toggleGrammarCategory,
            ),
          ],
          const SizedBox(height: 10),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Hiện legend mini trong vùng đọc',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: Text(
              settings.showLegend
                  ? 'Đang bật để bạn lọc category trực tiếp trên màn đọc.'
                  : 'Tắt để vùng đọc sạch hơn; phần điều khiển vẫn nằm ở đây.',
              style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
            ),
            value: settings.showLegend,
            activeThumbColor: const Color(0xFF6C63FF),
            onChanged: (value) => tp.setGrammarLegendVisible(value),
          ),
          if (settings.showAdvancedControls) ...[
            const SizedBox(height: 14),
            Text(
              'So sánh palette trực quan',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: palettes.map((item) {
                final selected = settings.paletteId == item.id;
                return _PaletteChoiceCard(
                  palette: item,
                  selected: selected,
                  onTap: () => tp.setGrammarPalette(item.id),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              'Kiểu tô màu',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GrammarHighlightStyle.values.map((style) {
                final selected = settings.highlightStyle == style;
                return _ChoiceChipButton(
                  label: style.labelVi,
                  selected: selected,
                  compact: true,
                  onTap: () => tp.setGrammarHighlightStyle(style),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              'Nhóm từ loại',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...groupOrder.map((group) {
              final categories = grammarCategoriesForGroup(group);
              if (categories.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReadSettingsGrammarGroupCard(
                  group: group,
                  categories: categories,
                  settings: settings,
                  palette: palette,
                  onToggleCategory: tp.toggleGrammarCategory,
                ),
              );
            }),
          ] else ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.22),
                ),
              ),
              child: const Text(
                'Mini mode đang ưu tiên thao tác cốt lõi: chọn preset, xem preview, bật tắt legend, lưu preset riêng và khôi phục nhanh. Bật advanced để chia category theo content / function / symbols và so màu trực quan hơn.',
                style: TextStyle(
                  color: Color(0xFFB8B5FF),
                  height: 1.45,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GrammarControlSummary extends StatelessWidget {
  final GrammarHighlightSettings settings;
  final String activePresetName;
  final String previousPresetName;
  final int visibleCount;
  final int hiddenCount;
  final Future<void> Function() onRestorePreviousPreset;
  final Future<void> Function(bool value) onToggleAdvancedMode;
  final Future<void> Function() onSaveCurrentPreset;

  const _GrammarControlSummary({
    required this.settings,
    required this.activePresetName,
    required this.previousPresetName,
    required this.visibleCount,
    required this.hiddenCount,
    required this.onRestorePreviousPreset,
    required this.onToggleAdvancedMode,
    required this.onSaveCurrentPreset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.uiText(settings.isCustomPreset
                ? 'Đang dùng preset: Tùy chỉnh'
                : 'Đang dùng preset: $activePresetName'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.uiText(settings.isCustomPreset
                ? 'Bạn đang chỉnh tay từ preset gần nhất: $previousPresetName'
                : 'Có thể chuyển sang tùy chỉnh nếu cần ẩn/hiện thủ công từng nhóm từ loại.'),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyStatChip(label: '$visibleCount bật'),
              _TinyStatChip(label: '$hiddenCount ẩn'),
              _TinyStatChip(
                label: settings.showLegend ? 'Legend nổi' : 'Legend tắt',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Mini'),
                selected: !settings.showAdvancedControls,
                onSelected: (_) => onToggleAdvancedMode(false),
                selectedColor:
                    const Color(0xFF6C63FF).withValues(alpha: 0.20),
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                labelStyle: TextStyle(
                  color: !settings.showAdvancedControls
                      ? const Color(0xFFB8B5FF)
                      : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: !settings.showAdvancedControls
                      ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              ChoiceChip(
                label: const Text('Advanced'),
                selected: settings.showAdvancedControls,
                onSelected: (_) => onToggleAdvancedMode(true),
                selectedColor:
                    const Color(0xFF6C63FF).withValues(alpha: 0.20),
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                labelStyle: TextStyle(
                  color: settings.showAdvancedControls
                      ? const Color(0xFFB8B5FF)
                      : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: settings.showAdvancedControls
                      ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onSaveCurrentPreset,
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: const Text('Lưu preset riêng'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB8B5FF),
                  side: BorderSide(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                  ),
                ),
              ),
              if (settings.isCustomPreset)
                OutlinedButton.icon(
                  onPressed: onRestorePreviousPreset,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: Text(context.uiText('Khôi phục $previousPresetName')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB8B5FF),
                    side: BorderSide(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadSettingsHiddenGrammarCard extends StatelessWidget {
  final List<GrammarCategory> hiddenCategories;
  final GrammarPalette palette;
  final String previousPresetName;
  final Future<void> Function() onShowAllCategories;
  final Future<void> Function(GrammarCategory category) onToggleCategory;

  const _ReadSettingsHiddenGrammarCard({
    required this.hiddenCategories,
    required this.palette,
    required this.previousPresetName,
    required this.onShowAllCategories,
    required this.onToggleCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.uiText('Đang ẩn ${hiddenCategories.length} nhóm từ loại. Chúng chưa bị xoá — bạn có thể bật lại từng nhóm, bật hết, hoặc quay về preset $previousPresetName.'),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onShowAllCategories,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Bật lại tất cả'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB8B5FF),
                  side: BorderSide(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                  ),
                ),
              ),
              for (final category in hiddenCategories.take(6))
                ActionChip(
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                  side: BorderSide(
                    color: palette.styleFor(category).color.withValues(alpha: 0.28),
                  ),
                  label: Text(
                    '+ ${context.uiText(category.labelVi)}',
                    style: TextStyle(
                      color: palette.styleFor(category).color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => onToggleCategory(category),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadSettingsGrammarGroupCard extends StatelessWidget {
  final GrammarCategoryGroup group;
  final List<GrammarCategory> categories;
  final GrammarHighlightSettings settings;
  final GrammarPalette palette;
  final Future<void> Function(GrammarCategory category) onToggleCategory;

  const _ReadSettingsGrammarGroupCard({
    required this.group,
    required this.categories,
    required this.settings,
    required this.palette,
    required this.onToggleCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, size: 16, color: const Color(0xFFB8B5FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.labelVi,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            group.helperVi,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((category) {
              final selected = settings.visibleCategories.contains(category);
              final style = palette.styleFor(category);
              return FilterChip(
                selected: selected,
                selectedColor: style.color.withValues(alpha: 0.18),
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                side: BorderSide(
                  color: selected
                      ? style.color.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
                ),
                avatar: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: selected ? style.color : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(
                  category.labelVi,
                  style: TextStyle(
                    color: selected ? style.color : Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onSelected: (_) => onToggleCategory(category),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PresetChoiceCard extends StatelessWidget {
  final GrammarHighlightPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChoiceCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    preset.audienceLabel,
                    style: TextStyle(
                      color: selected ? const Color(0xFFD4D2FF) : Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  preset.isBuiltIn ? Icons.auto_awesome : Icons.person_outline,
                  size: 15,
                  color: selected ? const Color(0xFFD4D2FF) : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              preset.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              preset.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              preset.focusSummary,
              style: TextStyle(
                color: selected ? const Color(0xFFB8B5FF) : Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteChoiceCard extends StatelessWidget {
  final GrammarPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteChoiceCard({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sampleCategories = [
      GrammarCategory.verb,
      GrammarCategory.adjective,
      GrammarCategory.noun,
      GrammarCategory.preposition,
      GrammarCategory.pronoun,
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    palette.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    palette.isDark ? 'Dark' : 'Light',
                    style: TextStyle(
                      color: selected ? const Color(0xFFD4D2FF) : Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: sampleCategories.map((category) {
                final color = palette.styleFor(category).color;
                return Expanded(
                  child: Container(
                    height: 12,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Text(
              _paletteHint(palette.id),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _paletteHint(String id) {
    switch (id) {
      case 'classic-dark':
        return 'Màu sâu, nổi rõ trên nền tối.';
      case 'classic-light':
        return 'Sáng, dễ so màu khi đọc nền trắng.';
      case 'noun-verb-focus':
        return 'Rất rõ noun/verb để luyện cấu trúc cốt lõi.';
      default:
        return 'So sánh trực quan các nhóm màu chính.';
    }
  }
}

class _TinyStatChip extends StatelessWidget {
  final String label;

  const _TinyStatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.uiText(label),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _ChoiceChipButton({
    required this.label,
    this.subtitle,
    required this.selected,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 10,
          vertical: compact ? 9 : 10,
        ),
        constraints: BoxConstraints(minWidth: compact ? 0 : 120),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFFB8B5FF) : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (!compact && subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadPresetDraft {
  final String name;
  final String description;

  const _ReadPresetDraft({required this.name, required this.description});
}

Future<_ReadPresetDraft?> _showReadSavePresetDialog(
  BuildContext context,
  String suggestedName,
) async {
  final nameCtrl = TextEditingController(
    text: suggestedName == context.uiText('Tùy chỉnh')
        ? context.uiText('Preset của tôi 1')
        : context.uiText('$suggestedName riêng'),
  );
  final descCtrl = TextEditingController();

  final shouldSave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF151B26),
        title: const Text('Lưu preset cá nhân'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _readDialogInputDecoration(
                  context: context,
                  label: 'Tên preset',
                  hint: 'Ví dụ: Verb focus riêng',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: _readDialogInputDecoration(
                  context: context,
                  label: 'Mô tả ngắn',
                  hint: 'Ghi chú cách dùng của preset này',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Lưu preset'),
          ),
        ],
      );
    },
  );

  if (shouldSave != true) return null;
  return _ReadPresetDraft(
    name: nameCtrl.text.trim(),
    description: descCtrl.text.trim(),
  );
}

InputDecoration _readDialogInputDecoration({
  required BuildContext context,
  required String label,
  required String hint,
}) {
  return InputDecoration(
    labelText: context.uiText(label),
    hintText: context.uiText(hint),
    labelStyle: const TextStyle(color: Colors.white70),
    hintStyle: const TextStyle(color: Colors.grey),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF6C63FF)),
    ),
  );
}

// PSRC-235: trước đây là `_DisplayOptions` với 4 công tắc. Hai công tắc
// «Hiện bản dịch» và «Box từng từ» là BẢN SAO của nút Dịch ở dock / chip
// «Bản dịch: Ẩn · Dưới · Cột» trong sheet Bố cục đọc và chip «Box từng từ ⇄
// Bôi nhiều chữ» trong cụm Tùy biến chữ ⇒ bỏ (READ-ACT-001: mỗi thứ một chỗ).
class _LineOptions extends StatelessWidget {
  final TextProvider tp;
  const _LineOptions({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Hiện số dòng',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text('Hiện số thứ tự và timestamp',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            value: tp.showLineNumbers,
            activeThumbColor: const Color(0xFF2196F3),
            onChanged: (_) => tp.toggleLineNumbers(),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
          SwitchListTile(
            title: const Text('Tách dòng thông minh',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text('Tự động tối ưu độ dài câu để dễ đọc',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            value: tp.useAutoSplit,
            activeThumbColor: const Color(0xFF9C27B0),
            onChanged: (v) => tp.toggleAutoSplit(v),
          ),
        ],
      ),
    );
  }
}

// ── Chọn vị trí phần TIÊU ĐỀ khi ở chế độ Focus (IN4-30) ────────────────
// Ẩn hẳn (mặc định, hành vi cũ) | Trên | Dưới.
class _FocusTitlePositionSelector extends StatefulWidget {
  const _FocusTitlePositionSelector();

  @override
  State<_FocusTitlePositionSelector> createState() =>
      _FocusTitlePositionSelectorState();
}

class _FocusTitlePositionSelectorState
    extends State<_FocusTitlePositionSelector> {
  String _value = StorageService.readFocusTitleHidden;

  @override
  void initState() {
    super.initState();
    _value = StorageService().getReadFocusTitlePosition();
  }

  Future<void> _set(String value) async {
    setState(() => _value = value);
    await StorageService().saveReadFocusTitlePosition(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _btn(context, Icons.visibility_off, 'Ẩn', StorageService.readFocusTitleHidden),
          const SizedBox(width: 8),
          _btn(context, Icons.vertical_align_top, 'Trên', StorageService.readFocusTitleTop),
          const SizedBox(width: 8),
          _btn(context, Icons.vertical_align_bottom, 'Dưới', StorageService.readFocusTitleBottom),
        ],
      ),
    );
  }

  Widget _btn(BuildContext context, IconData icon, String label, String value) {
    final selected = _value == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _set(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6C63FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
