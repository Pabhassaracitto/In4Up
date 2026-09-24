// lib/screens/read_mode/widgets/ipa_legend_strip.dart
//
// READ-IPA-006 (P1) — Bảng thông tin màu IPA tương tác cho Read Mode.
//
// Mỗi loại màu (nguyên âm · phụ âm · đôi nguyên âm · trọng âm · nối âm ·
// âm tiết nhấn) là 1 chip bật/tắt — mặc định BẬT HẾT (yêu cầu mục 2).
// Tap chip → ẩn/hiện loại đó NGAY LẬP TỨC trên các dòng IPA đang hiển thị.
// Toàn bộ panel ẩn được (yêu cầu mục 2) qua nút X hoặc toggle master.
//
// Bỏ widget animation (AnimatedSize/AnimatedOpacity…) theo READ-TOOLBAR-001:
// GPU Mali/Adreno tạo khối đen. Alpha nền cố định.

import 'package:in4up/core/language/localized_material.dart';

import '../../../providers/text_provider.dart';
import '../../../services/ipa_styling.dart';

class IpaLegendStrip extends StatelessWidget {
  final TextProvider tp;
  const IpaLegendStrip({super.key, required this.tp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  context,
                  color: IpaStyling.vowelColor,
                  label: context.uiText('Nguyên âm'),
                  on: tp.ipaColorVisibility.vowels,
                  onToggle: () =>
                      tp.setIpaColorVisible(vowels: !tp.ipaColorVisibility.vowels),
                ),
                _chip(
                  context,
                  color: IpaStyling.consonantColor,
                  label: context.uiText('Phụ âm'),
                  on: tp.ipaColorVisibility.consonants,
                  onToggle: () => tp.setIpaColorVisible(
                      consonants: !tp.ipaColorVisibility.consonants),
                ),
                _chip(
                  context,
                  color: IpaStyling.diphthongColor,
                  label: context.uiText('Đôi nguyên âm'),
                  on: tp.ipaColorVisibility.diphthongs,
                  onToggle: () => tp.setIpaColorVisible(
                      diphthongs: !tp.ipaColorVisibility.diphthongs),
                ),
                _chip(
                  context,
                  color: IpaStyling.stressColor,
                  label: context.uiText('Trọng âm'),
                  on: tp.ipaColorVisibility.stress,
                  onToggle: () => tp.setIpaColorVisible(
                      stress: !tp.ipaColorVisibility.stress),
                ),
                _chip(
                  context,
                  color: IpaStyling.linkingColor,
                  label: context.uiText('Nối âm'),
                  on: tp.ipaColorVisibility.linking,
                  onToggle: () => tp.setIpaColorVisible(
                      linking: !tp.ipaColorVisibility.linking),
                ),
                _chip(
                  context,
                  color: IpaStyling.stressColor,
                  label: context.uiText('Từ nhấn'),
                  on: tp.ipaColorVisibility.stressWords,
                  onToggle: () => tp.setIpaColorVisible(
                      stressWords: !tp.ipaColorVisibility.stressWords),
                  decorationHint: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final hiddenCount = _hiddenCount();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          const Icon(Icons.abc, size: 14, color: Color(0xFF4DD0E1)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.uiText('Màu phiên âm IPA'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hiddenCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    context.uiText(
                        'Đang ẩn $hiddenCount loại màu — chạm chip để bật lại.'),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hiddenCount > 0)
            TextButton(
              onPressed: tp.resetIpaColorVisibility,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: const Color(0xFF9FA8DA),
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('Bật lại tất cả'),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => tp.setIpaLegendVisible(false),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  int _hiddenCount() {
    final v = tp.ipaColorVisibility;
    var n = 0;
    if (!v.vowels) n++;
    if (!v.consonants) n++;
    if (!v.diphthongs) n++;
    if (!v.stress) n++;
    if (!v.linking) n++;
    if (!v.stressWords) n++;
    return n;
  }

  Widget _chip(
    BuildContext context, {
    required Color color,
    required String label,
    required bool on,
    required VoidCallback onToggle,
    bool decorationHint = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onToggle,
      child: Opacity(
        opacity: on ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
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
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: on ? Colors.white : Colors.grey[500],
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (decorationHint) ...[
                const SizedBox(width: 4),
                Text(
                  '¯',
                  style: TextStyle(
                    color: IpaStyling.stressColor,
                    fontSize: 14,
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

/// Nút mở/đóng panel trên TopBar (không nằm trong chính strip — strip tự
/// render, nút này đặt ở cạnh dòng văn bản hoặc top bar).
class IpaLegendToggleButton extends StatelessWidget {
  final TextProvider tp;
  const IpaLegendToggleButton({super.key, required this.tp});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => tp.setIpaLegendVisible(!tp.ipaLegendVisible),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: tp.ipaLegendVisible
              ? IpaStyling.baseIpaColor.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: tp.ipaLegendVisible
                ? IpaStyling.baseIpaColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.palette_outlined,
              size: 14,
              color: tp.ipaLegendVisible
                  ? IpaStyling.baseIpaColor
                  : Colors.grey[400],
            ),
            const SizedBox(width: 4),
            Text(
              context.uiText('Màu IPA'),
              style: TextStyle(
                fontSize: 11,
                color: tp.ipaLegendVisible
                    ? IpaStyling.baseIpaColor
                    : Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
