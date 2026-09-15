import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

/// Trả kết quả CHỈ sau khi dialog route đã reverse-animation xong và overlay
/// entries đã rời navigator. Caller vì thế có thể đổi layout / nhảy trang ngay
/// sau await mà không đụng race dispose của chính dialog.
Future<int?> showPdfJumpToPageDialog({
  required BuildContext context,
  required int currentPage,
  required int totalPages,
}) async {
  if (totalPages <= 0) return null;
  final route = DialogRoute<int>(
    context: context,
    builder: (_) => PdfJumpToPageDialog(
      currentPage: currentPage,
      totalPages: totalPages,
    ),
  );
  final navigator = Navigator.of(context, rootNavigator: true);
  final result = await navigator.push(route);
  await route.completed;
  return result;
}

class PdfJumpToPageDialog extends StatefulWidget {
  const PdfJumpToPageDialog({
    super.key,
    required this.currentPage,
    required this.totalPages,
  });

  /// 0-based, như `PdfReaderController.currentPage`.
  final int currentPage;
  final int totalPages;

  @override
  State<PdfJumpToPageDialog> createState() => _PdfJumpToPageDialogState();
}

class _PdfJumpToPageDialogState extends State<PdfJumpToPageDialog> {
  late final TextEditingController _field;
  late double _pageValue;

  @override
  void initState() {
    super.initState();
    final initialPage = _clampPageNumber(widget.currentPage + 1);
    _pageValue = initialPage.toDouble();
    _field = TextEditingController(text: '$initialPage');
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  int _clampPageNumber(int page) => page.clamp(1, widget.totalPages).toInt();

  int? _parseFieldPage([String? raw]) {
    final page = int.tryParse((raw ?? _field.text).trim());
    if (page == null) return null;
    return _clampPageNumber(page);
  }

  void _close([int? page]) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(page);
  }

  void _syncSliderFromField(String value) {
    final page = _parseFieldPage(value);
    if (page == null || page.toDouble() == _pageValue) return;
    setState(() => _pageValue = page.toDouble());
  }

  void _syncFieldFromSlider(double value) {
    final page = _clampPageNumber(value.round());
    final text = '$page';
    setState(() => _pageValue = page.toDouble());
    _field.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: Text(
        context.uiText('Tới trang'),
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('pdf_jump_page_field'),
              controller: _field,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onChanged: _syncSliderFromField,
              onSubmitted: (value) => _close(_parseFieldPage(value)),
            ),
            Slider(
              key: const Key('pdf_jump_page_slider'),
              value: _pageValue,
              min: 1,
              max: widget.totalPages.toDouble(),
              onChanged: _syncFieldFromSlider,
            ),
            Text(
              '1 – ${widget.totalPages}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('pdf_jump_cancel_button'),
          onPressed: () => _close(),
          child: Text(context.uiText('Huỷ')),
        ),
        TextButton(
          key: const Key('pdf_jump_go_button'),
          onPressed: () => _close(_parseFieldPage()),
          child: Text(context.uiText('Đi tới')),
        ),
      ],
    );
  }
}
