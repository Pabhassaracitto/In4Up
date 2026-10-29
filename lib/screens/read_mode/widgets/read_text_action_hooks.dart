// lib/screens/read_mode/widgets/read_text_action_hooks.dart
import 'package:in4up/core/language/localized_material.dart';

import '../../../widgets/workspace_navigation/workspace_navigation.dart';

/// Hành động theo ngữ cảnh áp dụng cho đoạn text đang được chọn.
///
/// Đây là lớp Tool trong mô hình Mode → Source → Tool → Settings — KHÔNG
/// gộp chung với Source (`ReadContentSource` ở
/// `lib/models/read_content_source.dart`) và KHÔNG gộp chung với Mode
/// (Đọc/Viết).
enum ReadTextAction {
  translate,
  grammar,
  pronounce,
  dictionary;

  /// Nhãn UI (vi) — dịch qua `context.uiText(label)` tại nơi hiển thị.
  String get label {
    switch (this) {
      case ReadTextAction.translate:
        return 'Dịch';
      case ReadTextAction.grammar:
        return 'Ngữ pháp';
      case ReadTextAction.pronounce:
        return 'Phát âm';
      case ReadTextAction.dictionary:
        return 'Từ điển';
    }
  }

  IconData get icon {
    switch (this) {
      case ReadTextAction.translate:
        return Icons.translate;
      case ReadTextAction.grammar:
        return Icons.auto_awesome_motion;
      case ReadTextAction.pronounce:
        return Icons.record_voice_over;
      case ReadTextAction.dictionary:
        return Icons.menu_book;
    }
  }
}

/// Hợp đồng callback cho 4 hành động theo ngữ cảnh trên văn bản đã chọn.
///
/// Mỗi callback nhận chuỗi text đã chọn. Đây CHỈ là điểm móc (hook) —
/// workspace Đọc không tự triển khai dịch / ngữ pháp / phát âm / từ điển ở
/// đây; agent tích hợp sẽ nối các callback này vào service thật
/// (translation, grammar, pronunciation, dictionary) ở bước sau. Không cần
/// cung cấp StorageService hay persistence tại lớp này.
@immutable
class ReadTextActionCallbacks {
  const ReadTextActionCallbacks({
    this.onTranslate,
    this.onGrammar,
    this.onPronounce,
    this.onDictionary,
  });

  final ValueChanged<String>? onTranslate;
  final ValueChanged<String>? onGrammar;
  final ValueChanged<String>? onPronounce;
  final ValueChanged<String>? onDictionary;

  /// `true` nếu có ít nhất một hành động đã được nối dây.
  bool get hasAnyHook =>
      onTranslate != null ||
      onGrammar != null ||
      onPronounce != null ||
      onDictionary != null;

  /// Trả về callback tương ứng với [action], nếu có.
  ValueChanged<String>? forAction(ReadTextAction action) {
    switch (action) {
      case ReadTextAction.translate:
        return onTranslate;
      case ReadTextAction.grammar:
        return onGrammar;
      case ReadTextAction.pronounce:
        return onPronounce;
      case ReadTextAction.dictionary:
        return onDictionary;
    }
  }
}

/// Thanh hành động hiện khi có text được chọn trong tab Đọc.
///
/// Chỉ hiển thị nút cho hành động nào đã có callback tương ứng trong
/// [callbacks] — nếu chưa agent nào nối dây, widget không vẽ gì
/// ([SizedBox.shrink]) để không tạo ra UI "chết" khó hiểu cho người dùng.
class ReadTextActionBar extends StatelessWidget {
  const ReadTextActionBar({
    super.key,
    required this.selectedText,
    required this.callbacks,
  });

  final String selectedText;
  final ReadTextActionCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final actions = [
      for (final action in ReadTextAction.values)
        if (callbacks.forAction(action) != null) action,
    ];
    if (actions.isEmpty || selectedText.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      key: const Key('read-text-action-bar'),
      color: const Color(0xFF151C2E),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Builder(
                  builder: (context) {
                    // Rule #5 (AGENTS.md) — dịch nhãn ngay tại nơi hiển thị.
                    final label = context.uiText(actions[i].label);
                    return WorkspaceActionButton(
                      key: ValueKey<Object?>(
                        'read-text-action-${actions[i].name}',
                      ),
                      label: label,
                      icon: actions[i].icon,
                      compact: true,
                      tooltip: label,
                      onPressed: () =>
                          callbacks.forAction(actions[i])!(selectedText),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
