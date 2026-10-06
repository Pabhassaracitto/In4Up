// lib/screens/read_mode/sheets/read_selection_sheets.dart
//
// READ-ACT-001 — Bảng kết quả cho 2 hành động văn bản của tab Đọc đang là
// "nút chết": **Dịch** và **Ngữ pháp**.
//
// Trước bản 0.10.3 hai nút này chỉ hiện snackbar "Bản dịch sẽ dùng đoạn đang
// chọn trong tab Đọc." — tức là không làm gì cả (audit 1.b). Hai sheet dưới
// đây nối thẳng vào service đã có của repo:
//   • Dịch     → TranslationService.translateText (cùng engine/pipeline mà
//                toolbar dịch của tab Đọc đang dùng — KHÔNG thêm engine mới).
//   • Ngữ pháp → GrammarAnalysisService (từ loại) + StructureSection (cấu
//                trúc câu) — đúng hai thứ WordActionsSheet đang dùng.
//
// i18n (quy tắc vàng #5 — AGENTS.md): mọi nhãn đi qua `context.uiText(...)`
// và đã đăng ký đủ en/hi/zh/zh_TW/si trong
// `lib/core/language/priority_ui_overrides.dart`.

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

import '../../../core/language/app_language.dart';
import '../../../features/grammar/models/grammar_category.dart';
import '../../../features/grammar/services/grammar_analysis_service.dart';
import '../../../features/grammar/widgets/structure_section.dart';
import '../../../features/translation/engines/translation_engine.dart';
import '../../../features/translation/translation_service.dart';

const Color _kSheetBackground = Color(0xFF1A1A2E);

Widget _sheetFrame({required BuildContext context, required Widget child}) {
  return SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: child,
    ),
  );
}

Widget _grabber() => Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.grey[600],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

Widget _sourceBlock(BuildContext context, String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: SelectableText(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
    ),
  );
}

/// Bảng kết quả **Dịch đoạn đang chọn**.
class ReadSelectionTranslateSheet extends StatefulWidget {
  const ReadSelectionTranslateSheet({
    super.key,
    required this.text,
    required this.targetCode,
    this.sourceCode,
    this.service,
  });

  final String text;

  /// Mã ngôn ngữ đích (`VI`, `EN`…) — lấy từ TextProvider để đúng lựa chọn
  /// của người dùng trong toolbar dịch.
  final String targetCode;

  /// Mã nguồn đã ghim; null = để service tự nhận diện.
  final String? sourceCode;

  /// Tiêm service giả khi test widget.
  final TranslationService? service;

  static Future<void> show(
    BuildContext context, {
    required String text,
    required String targetCode,
    String? sourceCode,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSheetBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReadSelectionTranslateSheet(
        text: text,
        targetCode: targetCode,
        sourceCode: sourceCode,
      ),
    );
  }

  @override
  State<ReadSelectionTranslateSheet> createState() =>
      _ReadSelectionTranslateSheetState();
}

class _ReadSelectionTranslateSheetState
    extends State<ReadSelectionTranslateSheet> {
  TranslationResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _translate());
  }

  Future<void> _translate() async {
    final service = widget.service ?? TranslationService();
    setState(() => _loading = true);
    TranslationResult result;
    try {
      result = await service.translateText(
        widget.text,
        sourceLang: widget.sourceCode,
        targetLang: widget.targetCode,
      );
    } catch (error) {
      result = TranslationResult.failure(
        original: widget.text,
        error: error.toString(),
        engine: 'read-selection',
      );
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final target = AppLanguageCatalog.fromCode(widget.targetCode);
    final translated = result?.translatedText.trim() ?? '';
    final sameLanguage = result != null && result.isSuccess && translated == widget.text.trim();

    return _sheetFrame(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _grabber(),
          Row(
            children: [
              const Icon(Icons.translate, color: Color(0xFF4CAF50), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${context.uiText('Dịch đoạn đang chọn')} · ${target.flag} ${target.nativeName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sourceBlock(context, widget.text),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (result != null && result.isSuccess && translated.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
                ),
              ),
              child: SelectableText(
                translated,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            )
          else
            Text(
              context.uiText('Chưa dịch được đoạn này. Kiểm tra engine dịch hoặc kết nối mạng.'),
              style: const TextStyle(color: Color(0xFFEF9A9A), fontSize: 12.5),
            ),
          if (sameLanguage) ...[
            const SizedBox(height: 8),
            Text(
              context.uiText('Đoạn này đã ở ngôn ngữ đích nên giữ nguyên.'),
              style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (result != null && result.isSuccess && translated.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: translated));
                      Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(context.uiText('Sao chép')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ),
              if (result != null && result.isSuccess && translated.isNotEmpty)
                const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _translate,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(context.uiText('Dịch lại')),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          if (result != null && result.engineName.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              result.engineName,
              style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bảng kết quả **Ngữ pháp của đoạn đang chọn**.
class ReadSelectionGrammarSheet extends StatelessWidget {
  const ReadSelectionGrammarSheet({
    super.key,
    required this.text,
    required this.lineText,
    required this.anchorStart,
    required this.anchorEnd,
  });

  final String text;

  /// Dòng chứa đoạn đã chọn (để phân tích cấu trúc câu quanh đoạn đó).
  final String lineText;
  final int anchorStart;
  final int anchorEnd;

  static Future<void> show(
    BuildContext context, {
    required String text,
    required String lineText,
    required int anchorStart,
    required int anchorEnd,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSheetBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReadSelectionGrammarSheet(
        text: text,
        lineText: lineText,
        anchorStart: anchorStart,
        anchorEnd: anchorEnd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GrammarAnalysisService.instance.analyzeLine(text).tokens;
    final counted = <GrammarCategory, int>{};
    for (final token in tokens) {
      counted[token.category] = (counted[token.category] ?? 0) + 1;
    }

    return _sheetFrame(
      context: context,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grabber(),
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_motion,
                  color: Color(0xFFB39DDB),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  context.uiText('Ngữ pháp đoạn đang chọn'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sourceBlock(context, text),
            const SizedBox(height: 12),
            if (tokens.isEmpty)
              Text(
                context.uiText('Chưa phân tích được từ loại cho đoạn này.'),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              )
            else ...[
              Text(
                context.uiText('Từ loại'),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in counted.entries)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E57C2).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              const Color(0xFF7E57C2).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        '${context.uiText(entry.key.labelVi)} · ${entry.value}',
                        style: const TextStyle(
                          color: Color(0xFFD1C4E9),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            StructureSection(
              lineText: lineText,
              anchorStart: anchorStart,
              anchorEnd: anchorEnd,
            ),
          ],
        ),
      ),
    );
  }
}
