// lib/features/iconize/widgets/iconize_toggle_button.dart
//
// ICONIZE-001d — nút "Icon hóa" cho header các panel dịch Tab Đọc.
//
//  - Tap: bật/tắt toggle (persist qua IconizeSettings). Lần bật đầu sẽ
//    nạp engine lười + làm mới map ảnh user từ VocabularyProvider.
//  - Nhấn giữ: mở sheet mật độ + cài đặt (blueprint Khối B).
//  - Asset hỏng (status=disabled): nút chuyển badge lỗi — tooltip giải
//    thích, không crash, không retry (blueprint 3.8).

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/vocabulary_provider.dart';
import '../iconize_service.dart';
import '../iconize_settings.dart';
import 'iconize_density_sheet.dart';

class IconizeToggleButton extends StatefulWidget {
  const IconizeToggleButton({super.key});

  @override
  State<IconizeToggleButton> createState() => _IconizeToggleButtonState();
}

class _IconizeToggleButtonState extends State<IconizeToggleButton> {
  final IconizeSettings _settings = IconizeSettings();
  final IconizeService _service = IconizeService();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onChanged);
    _service.addListener(_onChanged);
    _settings.init().then((_) {
      // Toggle đã bật từ session trước → nạp lại engine sớm. Dời ra sau
      // frame đầu: ensureLoaded notify ĐỒNG BỘ — không được chạm vào
      // listeners khác giữa build phase.
      if (mounted && _settings.enabled) _activate();
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_onChanged);
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _activate() {
    _service.ensureLoaded();
    _service.refreshVocabIcons(
      Provider.of<VocabularyProvider>(context, listen: false).allWords,
    );
  }

  void _onTap() {
    HapticFeedback.selectionClick();
    if (_service.isDisabled) return; // badge lỗi — không bật được
    final next = !_settings.enabled;
    _settings.setEnabled(next);
    if (next) _activate();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _service.isDisabled;
    final active = _settings.enabled && !disabled;
    final tooltip = disabled
        ? context.uiText('Icon hóa tạm tắt do lỗi dữ liệu')
        : context.uiText('Icon hóa — nhấn giữ để chỉnh mật độ');
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: _onTap,
        onLongPress: () {
          if (disabled) return;
          HapticFeedback.mediumImpact();
          IconizeDensitySheet.show(context);
        },
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          child: Icon(
            disabled
                ? Icons.image_not_supported_outlined
                : Icons.emoji_symbols_rounded,
            size: 17,
            color: disabled
                ? Colors.grey[700]
                : active
                    ? const Color(0xFF66BB6A)
                    : Colors.white70,
          ),
        ),
      ),
    );
  }
}
