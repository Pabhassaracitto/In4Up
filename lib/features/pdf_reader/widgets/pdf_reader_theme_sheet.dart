// Bảng chọn chủ đề đọc (Wave 1.5) + thanh trượt độ sáng trang.
//
// Cố ý CHỈ đổi nền quanh trang và màu trang, không đổi màu AppBar/các panel:
// đổi luôn chrome là quyết định thị giác lớn, cần thấy trên thiết bị thật rồi
// hãy làm, còn hai thứ này thì không.
import 'package:in4up/core/language/localized_material.dart';

import '../services/pdf_reader_theme.dart';

class PdfReaderThemeSheet extends StatelessWidget {
  const PdfReaderThemeSheet({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final PdfReaderThemeState state;
  final ValueChanged<PdfReaderThemeState> onChanged;

  @override
  Widget build(BuildContext context) {
    final note = pdfReaderThemeNoteKey(state.theme);
    final percent = (clampPdfPageBrightness(state.brightness) * 100).round();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  context.uiText('Chủ đề đọc'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!state.isDefault)
                  TextButton(
                    onPressed: () =>
                        onChanged(PdfReaderThemeState.defaults),
                    child: Text(
                      context.uiText('Đặt lại'),
                      style: const TextStyle(
                        color: Color(0xFF64B5F6),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final theme in PdfReaderTheme.values)
                  Expanded(
                    child: _ThemeCard(
                      theme: theme,
                      selected: theme == state.theme,
                      onTap: () => onChanged(state.copyWith(theme: theme)),
                    ),
                  ),
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(
                context.uiText(note),
                style: TextStyle(
                  color: const Color(0xFFFFB74D),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  context.uiText('Độ sáng trang'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                Text(
                  percent == 0
                      ? '0%'
                      : (percent > 0 ? '+$percent%' : '$percent%'),
                  style: const TextStyle(
                    color: Color(0xFF9CCC65),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            Slider(
              min: kPdfPageBrightnessMin,
              max: kPdfPageBrightnessMax,
              divisions: 20,
              activeColor: const Color(0xFF2196F3),
              inactiveColor: Colors.white.withValues(alpha: 0.18),
              label: '$percent%',
              value: clampPdfPageBrightness(state.brightness),
              onChanged: (value) =>
                  onChanged(state.copyWith(brightness: value)),
            ),
            // Hai đầu thanh trượt theo đúng chiều của Slider: min = tối, max = sáng.
            Row(
              children: [
                Text(
                  context.uiText('Tối'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10.5,
                  ),
                ),
                const Spacer(),
                Text(
                  context.uiText('Sáng'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final PdfReaderTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2196F3)
                  : Colors.white.withValues(alpha: 0.12),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 54,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: ColoredBox(
                    // Màu nền QUANH trang — thứ mà theme đổi nhiều nhất.
                    color: Color(pdfReaderSurroundColorArgb(theme)),
                    child: Center(
                      child: Container(
                        width: 30,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(pdfReaderPreviewPageColorArgb(theme)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int i = 0; i < 4; i++)
                                Padding(
                                  padding: EdgeInsets.only(bottom: i == 3 ? 0 : 3),
                                  child: Container(
                                    height: 2,
                                    color: Color(
                                      pdfReaderPreviewInkColorArgb(theme),
                                    ).withValues(
                                      alpha: i == 0 ? 0.95 : 0.55,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  context.uiText(pdfReaderThemeLabelKey(theme)),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                    fontSize: 10.5,
                    height: 1.25,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
