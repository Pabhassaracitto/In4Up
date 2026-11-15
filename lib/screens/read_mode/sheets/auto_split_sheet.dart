// lib/screens/read_mode/sheets/auto_split_sheet.dart
//
// PSRC-236 / ADR-0030 D3 — «Tách dòng tự động» là một THAO TÁC trên văn bản
// (chọn chế độ → xem trước → Áp dụng), không phải một giá trị cấu hình. Trước
// đây nó nằm ở cuối bảng «Cài đặt Text Studio», sau toàn bộ cấu hình engine.
//
// Nay mở thành sheet riêng từ:
//   * panel «Công cụ đọc» của `ReadBottomDock` (bố cục mặc định);
//   * `ReadTopBar` (bố cục «Vị trí công cụ: Trên»).
// Hai bố cục loại trừ nhau ⇒ vẫn đúng READ-ACT-001 «mỗi hành động một chỗ».
// Không đổi logic: vẫn `AutoSplitSection` + `TextProvider.loadFromLines`.
//
// PSRC-237 / ADR-0031: tách dòng làm mất liên kết dòng ⇄ bản dịch. Nếu đang
// «Đổi vai» thì văn bản GỐC đang nằm ở dòng dịch ⇒ đổi lại TRƯỚC khi mở, để
// thứ được tách (và giữ lại) luôn là văn bản gốc.

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../../features/translation/role_swap_controls.dart';
import '../../../features/tts/widgets/auto_split_section.dart';
import '../../../providers/text_provider.dart';

void showAutoSplitSheet(BuildContext context) {
  final tp = context.read<TextProvider>();
  if (tp.rolesSwapped) toggleReadRoleSwap(context);
  // Lấy messenger TRƯỚC khi mở sheet: SnackBar phải hiện trên màn Đọc sau
  // khi sheet đã đóng.
  final messenger = ScaffoldMessenger.maybeOf(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: SingleChildScrollView(
            key: const Key('read-auto-split-sheet'),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: AutoSplitSection(
              currentText: tp.fullText,
              primaryColor: const Color(0xFF6C63FF),
              onApply: (lines) {
                final message = sheetContext
                    .uiText('Đã tách thành ${lines.length} dòng');
                tp.loadFromLines(lines);
                Navigator.pop(sheetContext);
                messenger?.showSnackBar(SnackBar(content: Text(message)));
              },
            ),
          ),
        ),
      );
    },
  );
}
