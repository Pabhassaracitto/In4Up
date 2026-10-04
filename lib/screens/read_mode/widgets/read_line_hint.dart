// lib/screens/read_mode/widgets/read_line_hint.dart
//
// I4U18-READ-IPA-001 (F1.2 + F1.3) — snackbar + sheet hướng dẫn chế độ dòng.
//
// F1.2: mở file Word/DOCX (hoặc nguồn chữ theo dòng khác) → hiện một snackbar
//       dưới đáy nhắc "chạm dòng để hiện IPA, chạm từ để tra nghĩa", kèm nút
//       mở bảng hướng dẫn đầy đủ.
// F1.3: bảng hướng dẫn mở lại được bất cứ lúc nào qua nút Trợ giúp trên
//       ReadTopBar → người dùng bấm "Hiểu rồi" không bị mất tính năng.
//
// i18n: mọi nhãn đi qua `context.uiText(...)`/shim `Text`; bản dịch
// en/hi/zh/zh_TW/si nằm trong `lib/core/language/priority_ui_overrides.dart`
// (quy tắc vàng #5 + ADR-0002 — T2 phải có ngay trong cùng PR).

import 'package:in4up/core/language/localized_material.dart';

import '../services/read_line_hint_service.dart';

class ReadLineHint {
  ReadLineHint._();

  /// Snackbar đáy màn hình (F1.2). Không tự mở sheet — người đọc đang muốn
  /// đọc, không muốn bị chặn bởi modal.
  static void showSnackBar(BuildContext context, {required bool wordSource}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 7),
        backgroundColor: const Color(0xFF1A1A2E),
        content: Text(
          wordSource
              ? context.uiText(
                  'Đã mở theo dòng: chạm một dòng để hiện IPA, chạm một từ để tra nghĩa.')
              : context.uiText(
                  'Chạm một dòng để hiện IPA, chạm một từ để tra nghĩa.'),
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        action: SnackBarAction(
          label: context.uiText('Xem hướng dẫn'),
          textColor: const Color(0xFF64B5F6),
          onPressed: () => showSheet(context),
        ),
      ),
    );
  }

  /// Bảng hướng dẫn đầy đủ (F1.3 — mở lại từ nút Trợ giúp).
  static Future<void> showSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                sheetContext.uiText('Hướng dẫn đọc theo dòng'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const _HintRow(
                icon: Icons.touch_app_outlined,
                label: 'Chạm một dòng: chọn dòng đó và hiện IPA ngay dưới chữ.',
              ),
              const _HintRow(
                icon: Icons.record_voice_over_outlined,
                label: 'Chạm một từ: nghe phát âm và mở bảng tra từ.',
              ),
              const _HintRow(
                icon: Icons.touch_app,
                label: 'Chạm hai lần vào dòng: mở bảng hành động của dòng.',
              ),
              const _HintRow(
                icon: Icons.edit_note,
                label: 'Giữ một dòng: sửa nội dung dòng đó.',
              ),
              const _HintRow(
                icon: Icons.spellcheck,
                label:
                    'Chưa thấy phiên âm? Bật IPA ở thanh công cụ phía trên.',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ReadLineHintService.instance.dismissForever();
                        Navigator.of(sheetContext).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(sheetContext.uiText('Đừng nhắc lại')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                      ),
                      child: Text(sheetContext.uiText('Hiểu rồi')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HintRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64B5F6)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.uiText(label),
              style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
