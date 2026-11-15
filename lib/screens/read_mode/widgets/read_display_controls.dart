// lib/screens/read_mode/widgets/read_display_controls.dart
//
// READ-UI-121 — khôi phục các nút «Không màu / Bôi nhiều chữ / Đồng bộ tự
// động / ? / Focus» đã bị kẹt trong `ReadTopBar` khi READ-UI-120 tắt top bar
// trong luồng shell (`showTopBar: false`).
//
// MỘT cụm điều khiển duy nhất, dùng chung cho:
//   * panel «Hiển thị» của `ReadBottomDock` (có `ReadModeController`);
//   * sheet `showReadDisplaySheet` (app bar overflow ⚡, `ReadTopBar` legacy,
//     caller standalone — controller có thể null);
//   * «Vị trí công cụ: Trên» khôi phục luôn `ReadTopBar` cũ.
//
// Không tạo nguồn sự thật thứ hai: mọi nút gọi thẳng API hiện có của
// `TextProvider` / `ReadModeController`. Progressive disclosure vẫn giữ
// nguyên — cụm này nằm TRONG panel/sheet, dock đáy vẫn đúng 1 hàng luôn hiện.
// Mọi nhãn đi qua `context.uiText` (quy tắc vàng #5).
//
// PSRC-239 / ADR-0032 — MỘT quy ước điều khiển cho cả cụm. Trước đây 6 chip
// trông giống hệt nhau nhưng làm ba loại việc khác nhau; nhìn vào không đoán
// được bấm sẽ xảy ra gì. Nay hình dạng nói lên loại việc:
//
//   | Loại việc         | Điều khiển                                    |
//   |-------------------|-----------------------------------------------|
//   | Chọn 1 trong N    | nhóm nút chung một viền (`ChoiceChip`)        |
//   | Bật / tắt         | công tắc (`Switch`)                           |
//   | Mở bảng khác      | chip rời có mũi tên (`ActionChip`)            |
//
// Chỉ đổi HÌNH DẠNG: hàm được gọi và nơi lưu giữ nguyên. Phần vẽ tách thành
// `ReadDisplayControlsView` (chỉ nhận giá trị + callback) để test dựng được
// mà không cần `TextProvider` / Hive.

import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/core/platform/safe_haptics.dart';
import 'package:provider/provider.dart';

import '../../../models/color_mode.dart';
import '../../../models/ipa_display_mode.dart';
import '../../../providers/text_provider.dart';
import '../controllers/read_mode_controller.dart';
import 'read_line_hint.dart';

class ReadDisplayControls extends StatelessWidget {
  const ReadDisplayControls({super.key, this.controller});

  /// `null` khi gọi từ app bar shell (ngoài provider của màn Đọc): 2 nút phụ
  /// thuộc controller (Đồng bộ tự động / Focus) tự ẩn, còn lại vẫn dùng được.
  final ReadModeController? controller;

  @override
  Widget build(BuildContext context) {
    final tp = context.read<TextProvider>();
    final ctrl = controller;
    // `ReadModeController` không phải lúc nào cũng có provider ⇒ tự quản
    // listenable thay vì `context.watch` để sheet vẫn dựng được.
    return AnimatedBuilder(
      animation: ctrl == null ? tp : Listenable.merge([tp, ctrl]),
      builder: (context, _) => _body(context, tp, ctrl),
    );
  }

  Widget _body(
    BuildContext context,
    TextProvider tp,
    ReadModeController? ctrl,
  ) {
    // Theo ngữ cảnh: công tắc «Màu IPA» chỉ hiện khi lớp IPA đang bật.
    final bool showIpaColors = tp.ipaDisplayMode != IpaDisplayMode.hidden;
    return ReadDisplayControlsView(
      // 1) Không màu / Loại từ / CEFR / Độ khó — chọn thẳng, không xoay vòng.
      colorMode: tp.colorMode,
      onColorModeSelected: (mode) {
        if (mode == tp.colorMode) return;
        SafeHaptics.selectionClick();
        tp.setColorMode(mode);
      },
      // 2) Bôi nhiều chữ ⇄ Box từng từ — hai trạng thái đều có tên.
      wordTapBoxes: tp.wordTapBoxes,
      onWordTapBoxesSelected: (boxes) {
        if (boxes == tp.wordTapBoxes) return;
        SafeHaptics.selectionClick();
        tp.setWordTapBoxes(!tp.wordTapBoxes);
      },
      // 3) Nhãn A1 / N/V / độ khó dưới từng từ.
      showColorDetails: tp.showColorModeDetails,
      onShowColorDetailsChanged: (value) => tp.setShowColorModeDetails(value),
      // 4) Chú giải màu IPA.
      ipaLegendVisible: showIpaColors ? tp.ipaLegendVisible : null,
      onIpaLegendVisibleChanged: (value) => tp.setIpaLegendVisible(value),
      // 5) Focus + 6) Đồng bộ tự động — chỉ khi có controller.
      focusMode: ctrl?.isFocusMode,
      onFocusModeChanged: ctrl == null ? null : (_) => ctrl.toggleFocusMode(),
      autoSync: ctrl?.autoSyncEnabled,
      onAutoSyncChanged: ctrl == null ? null : (_) => ctrl.toggleAutoSync(),
      // 7) Dấu «?» — hướng dẫn đọc theo dòng.
      onOpenLineGuide: () => ReadLineHint.showSheet(context),
    );
  }
}

/// Phần vẽ của cụm «Tùy biến chữ» — không biết gì về provider.
///
/// Giá trị `null` ở [ipaLegendVisible] / [focusMode] / [autoSync] nghĩa là
/// điều khiển đó không áp dụng ở ngữ cảnh hiện tại ⇒ không vẽ.
class ReadDisplayControlsView extends StatelessWidget {
  const ReadDisplayControlsView({
    super.key,
    required this.colorMode,
    required this.onColorModeSelected,
    required this.wordTapBoxes,
    required this.onWordTapBoxesSelected,
    required this.showColorDetails,
    required this.onShowColorDetailsChanged,
    required this.onOpenLineGuide,
    this.ipaLegendVisible,
    this.onIpaLegendVisibleChanged,
    this.focusMode,
    this.onFocusModeChanged,
    this.autoSync,
    this.onAutoSyncChanged,
  });

  final ColorMode colorMode;
  final ValueChanged<ColorMode> onColorModeSelected;

  /// `true` = «Box từng từ», `false` = «Bôi nhiều chữ».
  final bool wordTapBoxes;
  final ValueChanged<bool> onWordTapBoxesSelected;

  final bool showColorDetails;
  final ValueChanged<bool> onShowColorDetailsChanged;

  final bool? ipaLegendVisible;
  final ValueChanged<bool>? onIpaLegendVisibleChanged;

  final bool? focusMode;
  final ValueChanged<bool>? onFocusModeChanged;

  final bool? autoSync;
  final ValueChanged<bool>? onAutoSyncChanged;

  final VoidCallback onOpenLineGuide;

  @override
  Widget build(BuildContext context) {
    final ipaLegend = ipaLegendVisible;
    final onIpaLegend = onIpaLegendVisibleChanged;
    final focus = focusMode;
    final onFocus = onFocusModeChanged;
    final sync = autoSync;
    final onSync = onAutoSyncChanged;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.uiText('Tùy biến chữ'),
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 4),

        // ── Chọn 1 trong N: nhóm nút chung một viền ────────────────────
        _ChoiceGroup(
          key: const Key('read-display-color-mode'),
          children: [
            for (final mode in ColorMode.values)
              _Choice(
                key: Key('read-display-color-${mode.name}'),
                label: mode.label,
                selected: colorMode == mode,
                onSelected: () => onColorModeSelected(mode),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _ChoiceGroup(
          key: const Key('read-display-word-tap'),
          children: [
            _Choice(
              key: const Key('read-display-word-tap-multi'),
              label: 'Bôi nhiều chữ',
              selected: !wordTapBoxes,
              onSelected: () => onWordTapBoxesSelected(false),
            ),
            _Choice(
              key: const Key('read-display-word-tap-boxes'),
              label: 'Box từng từ',
              selected: wordTapBoxes,
              // PSRC-235: công tắc trùng trong Cài đặt Text Studio đã bỏ ⇒
              // lời giải thích của nó ở đây (nhấn giữ để xem). «Tắt» = lựa
              // chọn «Bôi nhiều chữ», «Bật» = lựa chọn này.
              tooltip: context.uiText(
                'Tắt = bôi nhiều chữ (mặc định). Bật = mỗi từ một hộp, '
                'long-press lưu từ — nền lưu hàng loạt.',
              ),
              onSelected: () => onWordTapBoxesSelected(true),
            ),
          ],
        ),
        const SizedBox(height: 2),

        // ── Bật / tắt: công tắc ────────────────────────────────────────
        _SwitchGrid(
          children: [
            _SwitchTile(
              key: const Key('read-display-switch-color-details'),
              label: 'Thông tin màu',
              value: showColorDetails,
              onChanged: onShowColorDetailsChanged,
            ),
            if (ipaLegend != null && onIpaLegend != null)
              _SwitchTile(
                key: const Key('read-display-switch-ipa-colors'),
                label: 'Màu IPA',
                value: ipaLegend,
                onChanged: onIpaLegend,
              ),
            if (focus != null && onFocus != null)
              _SwitchTile(
                key: const Key('read-display-switch-focus'),
                label: 'Chế độ Focus',
                value: focus,
                onChanged: onFocus,
              ),
          ],
        ),
        // «Đồng bộ tự động» — có giải thích ngay dưới công tắc để owner
        // không phải đoán công dụng (xem câu trả lời trong ADR-0024).
        if (sync != null && onSync != null)
          SwitchListTile(
            key: const Key('read-display-switch-auto-sync'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.uiText('Đồng bộ tự động'),
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            subtitle: Text(
              context.uiText('Tự cuộn theo dòng đang đọc; tắt để cuộn tay.'),
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
            value: sync,
            onChanged: onSync,
          ),

        // ── Mở bảng khác: chip rời có mũi tên ──────────────────────────
        ActionChip(
          key: const Key('read-display-line-guide'),
          avatar: const Icon(
            Icons.help_outline,
            size: 14,
            color: Colors.white70,
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  context.uiText('Hướng dẫn đọc theo dòng'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: Colors.white54,
              ),
            ],
          ),
          onPressed: onOpenLineGuide,
        ),
      ],
    );
  }
}

/// Khung chung của một nhóm «chọn 1 trong N»: các lựa chọn nằm trong CÙNG
/// một viền ⇒ nhìn là biết chúng loại trừ nhau. Dùng `Wrap` (không phải
/// `SegmentedButton`) để nhãn dài ở th / my / si xuống hàng thay vì tràn.
class _ChoiceGroup extends StatelessWidget {
  const _ChoiceGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Wrap(spacing: 4, runSpacing: 4, children: children),
    );
  }
}

/// Một lựa chọn trong [_ChoiceGroup]. Cùng màu «đang chọn» với bộ chọn
/// «Chế độ màu» trong Cài đặt Text Studio (một lựa chọn = một cách hiện).
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.tooltip,
  });

  static const Color _accent = Color(0xFF2196F3);

  /// Chuỗi nguồn (tiếng Việt) — dịch ở đây.
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  /// Đã dịch sẵn ở nơi gọi.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(context.uiText(label)),
      labelStyle: TextStyle(
        fontSize: 11.5,
        color: selected ? Colors.white : Colors.white70,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      // Không dùng dấu tích: nó làm chip đổi bề rộng khi chọn ⇒ cả hàng
      // nhảy. Trạng thái thể hiện bằng nền + chữ đậm.
      showCheckmark: false,
      selected: selected,
      selectedColor: _accent,
      backgroundColor: Colors.transparent,
      side: BorderSide(color: selected ? _accent : Colors.transparent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      tooltip: tooltip,
      onSelected: (_) => onSelected(),
    );
  }
}

/// Xếp các công tắc thành 2 cột khi đủ chỗ để cụm không cao thêm nhiều so
/// với hàng chip cũ; màn rất hẹp hoặc cỡ chữ hệ thống lớn thì về 1 cột.
class _SwitchGrid extends StatelessWidget {
  const _SwitchGrid({required this.children});

  static const double _minWidthForTwoColumns = 280;
  static const double _maxTextScaleForTwoColumns = 1.3;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool twoColumns = children.length > 1 &&
            constraints.maxWidth.isFinite &&
            constraints.maxWidth >= _minWidthForTwoColumns &&
            textScale <= _maxTextScaleForTwoColumns;
        if (!twoColumns) {
          return Column(mainAxisSize: MainAxisSize.min, children: children);
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i += 2)
              Row(
                children: [
                  Expanded(child: children[i]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < children.length
                        ? children[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Công tắc gọn: nhãn bên trái, `Switch` bên phải; chạm cả hàng để đổi.
class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// Chuỗi nguồn (tiếng Việt) — dịch ở đây.
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.uiText(label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              const SizedBox(width: 4),
              // `Switch` M3 rộng 52 px; thu còn ~42 px để 2 cột vừa màn
              // 320 px mà nhãn vẫn còn chỗ.
              SizedBox(
                height: 26,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
