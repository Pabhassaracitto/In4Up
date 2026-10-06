// lib/screens/read_mode/services/read_text_action_runner.dart
//
// READ-ACT-001 — một chỗ duy nhất quyết định 4 hành động văn bản của tab Đọc
// (Dịch · Ngữ pháp · Phát âm · Từ điển) chạy trên đoạn nào và làm gì.
//
// Vì sao phải có file này (audit 0.10.3 mục 1.b):
//   • `main_shell._handleReadTextAction` cũ bắt buộc phải có `selectedText`,
//     còn các chế độ hiển thị "ô chạm từ"/interlinear của tab Đọc KHÔNG tạo
//     được selection (không có SelectableText) ⇒ người dùng bôi chọn kiểu gì
//     cũng nhận snackbar "Bạn cần bôi chọn một đoạn trước".
//   • Dịch/Ngữ pháp trước đây chỉ hiện snackbar mô tả, không gọi service nào.
//
// Luật phân giải đoạn ([resolveTarget]) — thuần logic, test được:
//   1. đoạn đang bôi chọn (TextProvider.selectedText)
//   2. dòng đang đọc (currentLineIndex)
//   3. dòng đầu tiên có chữ
//   → chỉ khi tài liệu rỗng mới báo "chưa có gì để xử lý".

import 'dart:async';

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../../features/dictionary/models/dict_entry.dart';
import '../../../features/dictionary/services/dictionary_service.dart';
import '../../../features/dictionary/widgets/dict_result_sheet.dart';
import '../../../providers/text_provider.dart';
import '../sheets/read_selection_sheets.dart';
import '../widgets/read_text_action_hooks.dart';

/// Đoạn văn bản mà một hành động sẽ chạy lên.
class ReadActionTarget {
  const ReadActionTarget({
    required this.text,
    required this.lineIndex,
    required this.fromSelection,
  });

  /// Nội dung đã trim (luôn khác rỗng).
  final String text;

  /// Dòng chứa đoạn này; -1 nếu không xác định được.
  final int lineIndex;

  /// true = người dùng thực sự bôi chọn; false = app tự lấy dòng hiện tại.
  final bool fromSelection;
}

/// Phân giải đoạn làm việc từ trạng thái provider — tách riêng để unit-test
/// không cần dựng widget tree.
ReadActionTarget? resolveReadActionTarget({
  required String? selectedText,
  required String? providerSelection,
  required List<String> lines,
  required int currentLineIndex,
}) {
  final explicit = (selectedText ?? '').trim();
  if (explicit.isNotEmpty) {
    return ReadActionTarget(
      text: explicit,
      lineIndex: _lineIndexContaining(lines, explicit, currentLineIndex),
      fromSelection: true,
    );
  }

  final selection = (providerSelection ?? '').trim();
  if (selection.isNotEmpty) {
    return ReadActionTarget(
      text: selection,
      lineIndex: _lineIndexContaining(lines, selection, currentLineIndex),
      fromSelection: true,
    );
  }

  if (currentLineIndex >= 0 && currentLineIndex < lines.length) {
    final current = lines[currentLineIndex].trim();
    if (current.isNotEmpty) {
      return ReadActionTarget(
        text: current,
        lineIndex: currentLineIndex,
        fromSelection: false,
      );
    }
  }

  for (var index = 0; index < lines.length; index++) {
    final content = lines[index].trim();
    if (content.isNotEmpty) {
      return ReadActionTarget(
        text: content,
        lineIndex: index,
        fromSelection: false,
      );
    }
  }
  return null;
}

int _lineIndexContaining(List<String> lines, String text, int preferred) {
  if (preferred >= 0 && preferred < lines.length &&
      lines[preferred].contains(text)) {
    return preferred;
  }
  for (var index = 0; index < lines.length; index++) {
    if (lines[index].contains(text)) return index;
  }
  return preferred >= 0 && preferred < lines.length ? preferred : -1;
}

/// Bộ chạy hành động — gọi từ `main_shell` và từ bất kỳ thanh hành động nào
/// của tab Đọc (một hợp đồng duy nhất, không nhân bản logic).
class ReadTextActionRunner {
  ReadTextActionRunner._();

  static ReadActionTarget? targetFor(
    TextProvider tp, {
    String? selectedText,
  }) {
    return resolveReadActionTarget(
      selectedText: selectedText,
      providerSelection: tp.selectedText,
      lines: tp.lines.map((line) => line.content).toList(growable: false),
      currentLineIndex: tp.currentLineIndex,
    );
  }

  static Future<void> run(
    BuildContext context,
    ReadTextAction action, {
    String? selectedText,
    VoidCallback? onOpenDictionaryManager,
  }) async {
    final tp = context.read<TextProvider>();
    final target = targetFor(tp, selectedText: selectedText);

    if (target == null) {
      if (action == ReadTextAction.dictionary) {
        onOpenDictionaryManager?.call();
        return;
      }
      _snack(context, 'Chưa có nội dung để xử lý — hãy mở một tài liệu trước.');
      return;
    }

    switch (action) {
      case ReadTextAction.pronounce:
        unawaited(tp.speak(target.text));
        return;

      case ReadTextAction.translate:
        await ReadSelectionTranslateSheet.show(
          context,
          text: target.text,
          targetCode: tp.translationTargetLanguage.translationCode,
          sourceCode: tp.translationSourceIsPinned
              ? tp.translationSourceLanguage.translationCode
              : null,
        );
        return;

      case ReadTextAction.grammar:
        final lineText = target.lineIndex >= 0 &&
                target.lineIndex < tp.lines.length
            ? tp.lines[target.lineIndex].content
            : target.text;
        var anchorStart = lineText.indexOf(target.text);
        if (anchorStart < 0) anchorStart = 0;
        await ReadSelectionGrammarSheet.show(
          context,
          text: target.text,
          lineText: lineText,
          anchorStart: anchorStart,
          anchorEnd: anchorStart + target.text.length,
        );
        return;

      case ReadTextAction.dictionary:
        await _lookupDictionary(
          context,
          target.text,
          onOpenDictionaryManager: onOpenDictionaryManager,
        );
        return;
    }
  }

  /// Tra từ điển MDX đã import; không có kết quả → mời mở trình quản lý từ
  /// điển thay vì im lặng.
  static Future<void> _lookupDictionary(
    BuildContext context,
    String text, {
    VoidCallback? onOpenDictionaryManager,
  }) async {
    final query = _dictionaryQuery(text);
    List<DictEntry> entries = const [];
    try {
      entries = await DictionaryService.instance.lookup(query);
    } catch (_) {
      entries = const [];
    }
    if (!context.mounted) return;
    if (entries.isNotEmpty) {
      DictResultSheet.show(context, query, entries);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          context.uiText('Chưa có từ điển nào tra được từ này.'),
        ),
        action: onOpenDictionaryManager == null
            ? null
            : SnackBarAction(
                label: context.uiText('Quản lý từ điển'),
                onPressed: onOpenDictionaryManager,
              ),
      ),
    );
  }

  /// Từ khoá tra cứu: từ đầu tiên của đoạn (MDX đánh index theo từ/cụm, tra
  /// nguyên câu luôn trượt).
  static String _dictionaryQuery(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length <= 3) return trimmed;
    return words.first.replaceAll(RegExp(r'''^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$''',
        unicode: true), '');
  }

  static void _snack(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(context.uiText(message)),
      ),
    );
  }
}
