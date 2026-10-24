// lib/features/iconize/widgets/iconize_sentence_text.dart
//
// ICONIZE-001d — widget "một câu, có thể icon hóa" cho các panel Tab Đọc.
//
// Gói trọn vòng: nghe IconizeSettings + IconizeService → gọi engine khi
// (và chỉ khi) toggle bật + engine sẵn sàng → render IconizedRichText;
// mọi trường hợp khác rơi về Text thường. Panel chủ chỉ cần thay
// `Text(câu)` bằng `IconizeSentenceText(text: câu, ...)` — diff tối thiểu.
//
// [isTranslation]: true = dòng BẢN DỊCH — chỉ icon hóa khi sub-toggle
// "Icon hóa cả bản dịch" bật (blueprint Khối B, mặc định tắt).

import 'package:flutter/material.dart';

import '../iconize_service.dart';
import '../iconize_settings.dart';
import '../models/iconize_span.dart';
import 'iconized_rich_text.dart';

class IconizeSentenceText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Mã ngôn ngữ user khai báo cho dòng này ('AUTO'/null → service đoán).
  final String? declaredLang;

  final bool isTranslation;

  const IconizeSentenceText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.declaredLang,
    this.isTranslation = false,
  });

  @override
  State<IconizeSentenceText> createState() => _IconizeSentenceTextState();
}

class _IconizeSentenceTextState extends State<IconizeSentenceText> {
  final IconizeSettings _settings = IconizeSettings();
  final IconizeService _service = IconizeService();

  IconizeResult? _result;
  // Khóa của kết quả đang giữ — tránh gọi lại engine mỗi build.
  String? _resultKey;
  int _generation = 0;

  bool get _active =>
      _settings.enabled &&
      _service.isReady &&
      (!widget.isTranslation || _settings.iconizeTranslation);

  String get _key =>
      '${widget.text}|${widget.declaredLang}|${_settings.density.name}';

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onDepsChanged);
    _service.addListener(_onDepsChanged);
    _maybeIconize();
  }

  @override
  void didUpdateWidget(IconizeSentenceText old) {
    super.didUpdateWidget(old);
    _maybeIconize();
  }

  @override
  void dispose() {
    _settings.removeListener(_onDepsChanged);
    _service.removeListener(_onDepsChanged);
    super.dispose();
  }

  void _onDepsChanged() {
    if (!mounted) return;
    setState(_maybeIconize);
  }

  void _maybeIconize() {
    if (!_active) return; // giữ _result cũ — bật lại không tính lại
    final key = _key;
    if (_resultKey == key) return;
    final gen = ++_generation;
    _service
        .iconizeSentence(
      widget.text,
      declaredLang: widget.declaredLang,
      density: _settings.density,
    )
        .then((r) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _result = r;
        _resultKey = key;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (!_active || result == null || _resultKey != _key) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }
    return IconizedRichText(
      result: result,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      iconsBundle: _service.iconsBundle,
    );
  }
}
