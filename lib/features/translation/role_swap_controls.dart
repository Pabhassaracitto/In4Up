// lib/features/translation/role_swap_controls.dart
//
// PSRC-237 / ADR-0031 — phần GIAO DIỆN của «Đổi vai văn bản ⇄ bản dịch».
//
// Vì sao có tính năng này: IPA, tô màu loại từ, CEFR và chạm tra từ chỉ chạy
// trên dòng văn bản chính, và chỉ hiểu tiếng Anh. Người học mở văn bản tiếng
// mẹ đẻ rồi dịch sang tiếng Anh thì phần tiếng Anh nằm ở dòng dịch — không
// công cụ nào với tới. «Đổi vai» đưa bản dịch lên làm văn bản chính; văn bản
// gốc xuống dòng dịch và đổi lại được nguyên vẹn.
//
// Ba mảnh, dùng chung MỘT hàm hành động ([toggleReadRoleSwap]):
//   * [RoleSwapButton]      — nút trong `TranslationToolbar`;
//   * [RoleSwapStatusStrip] — dải phía trên vùng đọc: khi đang đổi vai thì
//     ghi rõ «Đang đọc bản dịch máy · <ngôn ngữ>» + «Đổi lại»; khi chưa đổi
//     vai mà người dùng bật IPA / tô màu trên văn bản không phải tiếng Anh
//     đã có bản dịch tiếng Anh thì gợi ý «Đổi vai» (đóng được);
//   * [roleSwapGuardSnackBar] — lời giải thích khi một thao tác bị chặn.
//
// Không dùng widget animation (READ-TOOLBAR-001: GPU Mali/Adreno vẽ khối đen).

import 'dart:async';

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../models/color_mode.dart';
import '../../models/ipa_display_mode.dart';
import '../../providers/text_provider.dart';
import '../../screens/read_mode/services/playback_controller.dart';

/// Đổi vai / đổi lại cho tài liệu đang mở. Dừng phát và TTS trước: hàng đợi
/// phát đang giữ nội dung dòng CŨ. Trả true nếu đã đổi.
bool toggleReadRoleSwap(BuildContext context, {bool announce = true}) {
  final tp = context.read<TextProvider>();
  if (!tp.canSwapRoles) return false;
  final playback = context.read<PlaybackController>();
  if (playback.isRunning) {
    playback.stop(fileId: tp.currentDocument?.id ?? 'unknown');
  }
  unawaited(tp.stopSpeaking());
  final messenger = ScaffoldMessenger.maybeOf(context);
  final swappedMessage =
      context.uiText('Đã đổi vai: bản dịch thành văn bản chính');
  final restoredMessage = context.uiText('Đã đổi lại văn bản gốc');

  final result = tp.swapTextAndTranslationRoles();
  if (result == null) return false;
  if (announce) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(tp.rolesSwapped ? swappedMessage : restoredMessage),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  return true;
}

/// Lời giải thích khi đổi ngôn ngữ / dịch lại bị chặn vì đang đổi vai.
SnackBar roleSwapGuardSnackBar(BuildContext context) {
  return SnackBar(
    content: Text(
      context.uiText(
        'Đang đổi vai — hãy đổi lại trước khi đổi ngôn ngữ hoặc dịch lại.',
      ),
    ),
    duration: const Duration(seconds: 3),
  );
}

/// Nút «Đổi vai» trong thanh công cụ dịch. Sáng màu khi đang đổi vai.
class RoleSwapButton extends StatelessWidget {
  final Color primaryColor;

  const RoleSwapButton({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TextProvider>();
    final swapped = tp.rolesSwapped;
    return IconButton(
      key: const Key('translation-role-swap-button'),
      tooltip: context.uiText(
        swapped ? 'Đổi lại' : 'Đổi vai văn bản ⇄ bản dịch',
      ),
      isSelected: swapped,
      onPressed: tp.canSwapRoles ? () => toggleReadRoleSwap(context) : null,
      icon: const Icon(Icons.swap_vert),
      color: swapped ? primaryColor : Colors.grey,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Dải trạng thái / gợi ý phía trên vùng đọc. Không có gì để nói ⇒ không
/// chiếm chỗ.
class RoleSwapStatusStrip extends StatefulWidget {
  final Color accentColor;

  const RoleSwapStatusStrip({
    super.key,
    this.accentColor = const Color(0xFF6C63FF),
  });

  /// Có nên gợi ý «Đổi vai» hay không: người dùng đã bật một công cụ chỉ
  /// hiểu tiếng Anh, văn bản không phải tiếng Anh, và bản dịch tiếng Anh đã
  /// có sẵn.
  static bool shouldOfferSwap(TextProvider tp) {
    if (tp.rolesSwapped) return false;
    // Kiểm tra rẻ trước: dải này dựng lại mỗi lần provider báo thay đổi.
    final toolOn = tp.ipaDisplayMode != IpaDisplayMode.hidden ||
        tp.colorMode != ColorMode.none;
    if (!toolOn) return false;
    if (tp.translationTargetLanguage.translationCode != 'EN') return false;
    // `canSwapRoles` đã bao gồm «nguồn khác đích» ⇒ văn bản không phải
    // tiếng Anh.
    return tp.canSwapRoles;
  }

  @override
  State<RoleSwapStatusStrip> createState() => _RoleSwapStatusStripState();
}

class _RoleSwapStatusStripState extends State<RoleSwapStatusStrip> {
  /// Tài liệu (theo `translationDocumentRevision`) mà người dùng đã đóng
  /// gợi ý — không hỏi lại trên cùng tài liệu đó.
  int? _dismissedRevision;

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TextProvider>();
    if (tp.rolesSwapped) return _swappedStrip(context, tp);
    if (_dismissedRevision != tp.translationDocumentRevision &&
        RoleSwapStatusStrip.shouldOfferSwap(tp)) {
      return _hintStrip(context, tp);
    }
    return const SizedBox.shrink();
  }

  Widget _frame({required Key key, required List<Widget> children}) {
    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      decoration: BoxDecoration(
        color: widget.accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.accentColor.withValues(alpha: 0.35)),
      ),
      child: Row(children: children),
    );
  }

  Widget _swappedStrip(BuildContext context, TextProvider tp) {
    final language = tp.roleSwapPromotedLanguage;
    final label = context.uiText('Đang đọc bản dịch máy');
    return _frame(
      key: const Key('read-role-swap-strip'),
      children: [
        Icon(Icons.smart_toy_outlined, size: 16, color: widget.accentColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            language == null ? label : '$label · ${language.nativeName}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          key: const Key('read-role-swap-back'),
          onPressed:
              tp.canSwapRoles ? () => toggleReadRoleSwap(context) : null,
          child: Text(context.uiText('Đổi lại')),
        ),
      ],
    );
  }

  Widget _hintStrip(BuildContext context, TextProvider tp) {
    final revision = tp.translationDocumentRevision;
    return _frame(
      key: const Key('read-role-swap-hint'),
      children: [
        Icon(Icons.lightbulb_outline, size: 16, color: widget.accentColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.uiText(
              'IPA và tô màu chỉ chạy trên tiếng Anh. Đổi vai để dùng trên bản dịch?',
            ),
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          key: const Key('read-role-swap-hint-accept'),
          onPressed: () => toggleReadRoleSwap(context),
          child: Text(context.uiText('Đổi vai')),
        ),
        IconButton(
          key: const Key('read-role-swap-hint-dismiss'),
          tooltip: context.uiText('Đóng'),
          onPressed: () => setState(() => _dismissedRevision = revision),
          icon: const Icon(Icons.close, size: 16),
          color: Colors.white54,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
