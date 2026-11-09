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

import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/core/platform/safe_haptics.dart';
import 'package:provider/provider.dart';

import '../../../models/ipa_display_mode.dart';
import '../../../providers/text_provider.dart';
import '../../../services/ipa_styling.dart';
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
    final bool showIpaColors = tp.ipaDisplayMode != IpaDisplayMode.hidden;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.uiText('Tùy biến chữ'),
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            // 1) «Không màu» ⇄ Loại từ / CEFR / Độ khó.
            ActionChip(
              avatar: Icon(tp.colorMode.icon, size: 14, color: Colors.white70),
              label: Text(context.uiText(tp.colorMode.label)),
              onPressed: () {
                SafeHaptics.selectionClick();
                tp.cycleColorMode();
              },
            ),
            // 2) Nhãn A1 / N/V / độ khó dưới từng từ.
            ActionChip(
              avatar: Icon(
                tp.showColorModeDetails
                    ? Icons.label_rounded
                    : Icons.label_off_rounded,
                size: 14,
                color: tp.showColorModeDetails ? Colors.lightBlue : Colors.white70,
              ),
              label: Text(context.uiText('Thông tin màu')),
              onPressed: () =>
                  tp.setShowColorModeDetails(!tp.showColorModeDetails),
            ),
            // 3) Box từng từ ⇄ Bôi nhiều chữ.
            ActionChip(
              avatar: Icon(
                tp.wordTapBoxes
                    ? Icons.grid_view_rounded
                    : Icons.grid_view_outlined,
                size: 14,
                color: tp.wordTapBoxes ? Colors.orangeAccent : Colors.white70,
              ),
              label: Text(context.uiText(
                tp.wordTapBoxes ? 'Box từng từ' : 'Bôi nhiều chữ',
              )),
              onPressed: () {
                SafeHaptics.selectionClick();
                tp.setWordTapBoxes(!tp.wordTapBoxes);
              },
            ),
            // 4) Theo ngữ cảnh: chỉ hiện khi lớp IPA đang bật.
            if (showIpaColors)
              ActionChip(
                avatar: Icon(
                  Icons.palette_outlined,
                  size: 14,
                  color: tp.ipaLegendVisible
                      ? IpaStyling.baseIpaColor
                      : Colors.white70,
                ),
                label: Text(context.uiText('Màu IPA')),
                onPressed: () =>
                    tp.setIpaLegendVisible(!tp.ipaLegendVisible),
              ),
            // 5) Dấu «?» — hướng dẫn đọc theo dòng.
            ActionChip(
              avatar: const Icon(Icons.help_outline,
                  size: 14, color: Colors.white70),
              label: Text(context.uiText('Hướng dẫn đọc theo dòng')),
              onPressed: () => ReadLineHint.showSheet(context),
            ),
            // 6) Focus — chỉ khi có controller (dock / ReadTopBar).
            if (ctrl != null)
              ActionChip(
                avatar: Icon(
                  ctrl.isFocusMode
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  size: 14,
                  color: ctrl.isFocusMode ? Colors.lightBlue : Colors.white70,
                ),
                label: Text(context.uiText('Chế độ Focus')),
                onPressed: () => ctrl.toggleFocusMode(),
              ),
          ],
        ),
        // 7) «Đồng bộ tự động» — có giải thích ngay dưới công tắc để owner
        //    không phải đoán công dụng (xem câu trả lời trong ADR-0024).
        if (ctrl != null)
          SwitchListTile(
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
            value: ctrl.autoSyncEnabled,
            onChanged: (_) => ctrl.toggleAutoSync(),
          ),
      ],
    );
  }
}
