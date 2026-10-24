// lib/features/iconize/widgets/iconize_density_sheet.dart
//
// ICONIZE-001d — bottom sheet cài đặt Iconize (mở bằng NHẤN GIỮ nút
// "Icon hóa" trong panel dịch — blueprint Khối B):
//  - 3 nấc mật độ (≈18/32/48% từ đủ điều kiện — ADR-0013 quyết định #4);
//  - sub-toggle "Icon hóa cả bản dịch" (mặc định TẮT);
//  - chú thích nguyên tắc giữ chữ khi không chắc.
//
// Không dùng RadioListTile: API group đang chuyển đổi giữa các bản
// Flutter — ListTile + check trailing ổn định hơn với CI pin version.

import 'package:in4up/core/language/localized_material.dart';

import '../iconize_settings.dart';
import '../models/iconize_span.dart';

class IconizeDensitySheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const _IconizeDensitySheetBody(),
    );
  }
}

class _IconizeDensitySheetBody extends StatefulWidget {
  const _IconizeDensitySheetBody();

  @override
  State<_IconizeDensitySheetBody> createState() =>
      _IconizeDensitySheetBodyState();
}

class _IconizeDensitySheetBodyState extends State<_IconizeDensitySheetBody> {
  final IconizeSettings _settings = IconizeSettings();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 10),
                const Icon(Icons.emoji_symbols_rounded,
                    size: 18, color: Color(0xFF66BB6A)),
                const SizedBox(width: 8),
                Text(
                  context.uiText('Mật độ icon'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _densityTile(IconizeDensity.low, 'Thấp — khoảng 18% từ'),
            _densityTile(IconizeDensity.medium, 'Vừa — khoảng 32% từ'),
            _densityTile(IconizeDensity.high, 'Cao — khoảng 48% từ'),
            const Divider(height: 14, color: Color(0x11FFFFFF)),
            SwitchListTile(
              dense: true,
              value: _settings.iconizeTranslation,
              onChanged: (v) {
                setState(() => _settings.setIconizeTranslation(v));
              },
              title: Text(
                context.uiText('Icon hóa cả bản dịch'),
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
              subtitle: Text(
                context.uiText('Mặc định tắt — bản dịch là chỗ dựa nghĩa.'),
                style: TextStyle(color: Colors.grey[500], fontSize: 10.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Text(
                context.uiText(
                  'Chỉ từ cụ thể, dễ hình dung mới được thay bằng icon — không chắc thì giữ chữ. Chạm icon để xem lại từ gốc.',
                ),
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 10.5, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _densityTile(IconizeDensity value, String label) {
    final selected = _settings.density == value;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      onTap: () => setState(() => _settings.setDensity(value)),
      title: Text(
        context.uiText(label),
        style: TextStyle(
          color: selected ? Colors.white : Colors.grey[400],
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Color(0xFF66BB6A))
          : null,
    );
  }
}
