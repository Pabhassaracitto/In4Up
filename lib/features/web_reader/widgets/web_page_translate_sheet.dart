import 'dart:async';

import 'package:in4up/core/language/app_language.dart';
import 'package:in4up/core/language/localized_material.dart';

import '../../translation/translation_service.dart';
import '../services/web_page_translation.dart';

/// Partial, bilingual translation of the Web Reader page's main content.
/// Text is translated in small sequential batches so a long page never becomes
/// one oversized translation request.
class WebPageTranslateSheet extends StatefulWidget {
  const WebPageTranslateSheet({
    super.key,
    required this.text,
    required this.targetCode,
    this.sourceCode,
    this.sourceTitle = '',
    this.service,
  });

  final String text;
  final String targetCode;
  final String? sourceCode;
  final String sourceTitle;

  /// Optional seam for widget tests; production uses the app's shared service.
  final TranslationService? service;

  static Future<void> show(
    BuildContext context, {
    required String text,
    required String targetCode,
    String? sourceCode,
    String sourceTitle = '',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WebPageTranslateSheet(
        text: text,
        targetCode: targetCode,
        sourceCode: sourceCode,
        sourceTitle: sourceTitle,
      ),
    );
  }

  @override
  State<WebPageTranslateSheet> createState() =>
      _WebPageTranslateSheetState();
}

class _WebPageTranslateSheetState extends State<WebPageTranslateSheet> {
  List<WebTranslationUnit> _units = const [];
  int _completed = 0;
  int _total = 0;
  bool _isTranslating = true;
  bool _stopRequested = false;
  String? _error;
  int _runId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_translate());
    });
  }

  @override
  void dispose() {
    // The active TranslationService request cannot be force-cancelled, but the
    // batch stops immediately after that request completes.
    _runId++;
    super.dispose();
  }

  Future<void> _translate() async {
    final runId = ++_runId;
    final sourceUnits = splitWebTextIntoUnits(widget.text);
    if (sourceUnits.isEmpty) {
      setState(() {
        _units = const [];
        _total = 0;
        _completed = 0;
        _isTranslating = false;
        _stopRequested = false;
        _error = 'Không tìm thấy văn bản trong trang.';
      });
      return;
    }

    setState(() {
      _units = sourceUnits
          .map((text) => WebTranslationUnit(original: text))
          .toList(growable: true);
      _total = sourceUnits.length;
      _completed = 0;
      _isTranslating = true;
      _stopRequested = false;
      _error = null;
    });

    final service = widget.service ?? TranslationService();
    try {
      final report = await translateWebPageUnits(
        units: sourceUnits,
        shouldStop: () => !mounted || runId != _runId || _stopRequested,
        onUnit: (index, unit) {
          if (!mounted || runId != _runId || index >= _units.length) return;
          setState(() {
            _units[index] = unit;
            _completed = index + 1;
          });
        },
        translate: (text) async {
          final result = await service.translateText(
            text,
            sourceLang: widget.sourceCode,
            targetLang: widget.targetCode,
          );
          if (!result.isSuccess || result.translatedText.trim().isEmpty) {
            return null;
          }
          return result.translatedText;
        },
      );
      if (!mounted || runId != _runId) return;
      final stoppedByUser = _stopRequested && report.stoppedEarly;
      setState(() {
        _isTranslating = false;
        _stopRequested = stoppedByUser;
        _completed = report.translations.length;
        if (stoppedByUser) {
          _error = 'Đã dừng dịch';
        } else if (report.translatedCount == 0) {
          _error =
              'Chưa dịch được đoạn này. Kiểm tra engine dịch hoặc kết nối mạng.';
        } else if (report.failedCount > 0) {
          _error = 'Một số đoạn chưa dịch được.';
        }
      });
    } catch (_) {
      if (!mounted || runId != _runId) return;
      setState(() {
        _isTranslating = false;
        _error =
            'Chưa dịch được đoạn này. Kiểm tra engine dịch hoặc kết nối mạng.';
      });
    }
  }

  void _requestStop() {
    if (!_isTranslating || _stopRequested) return;
    setState(() => _stopRequested = true);
  }

  @override
  Widget build(BuildContext context) {
    final target = AppLanguageCatalog.fromCode(widget.targetCode);
    final title = '${context.uiText('Dịch trang')} · ${target.flag} '
        '${target.nativeName}';
    final screenHeight = MediaQuery.sizeOf(context).height;

    return SafeArea(
      top: false,
      child: Container(
        height: screenHeight * 0.82,
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 10, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.translate_rounded,
                    color: Color(0xFF66BB6A),
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (widget.sourceTitle.trim().isNotEmpty)
                          Text(
                            widget.sourceTitle.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_isTranslating)
                    IconButton(
                      tooltip: context.uiText(
                        _stopRequested ? 'Đang dừng dịch…' : 'Dừng dịch',
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: _stopRequested ? null : _requestStop,
                      icon: Icon(
                        Icons.stop_circle_outlined,
                        color: _stopRequested ? Colors.white30 : Colors.white70,
                        size: 19,
                      ),
                    )
                  else
                    IconButton(
                      tooltip: context.uiText('Dịch lại'),
                      visualDensity: VisualDensity.compact,
                      onPressed: _translate,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                        size: 19,
                      ),
                    ),
                  IconButton(
                    tooltip: context.uiText('Đóng'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
            if (_isTranslating)
              LinearProgressIndicator(
                value: _total > 0 ? _completed / _total : null,
                minHeight: 2,
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF66BB6A)),
              )
            else
              const Divider(height: 1, color: Color(0x1AFFFFFF)),
            if (_isTranslating)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.uiText(
                          _stopRequested
                              ? 'Đang dừng dịch…'
                              : 'Đang dịch trang…',
                        ),
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ),
                    Text(
                      '$_completed/$_total',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              )
            else if (_stopRequested || (_completed > 0 && _error == null))
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
                  child: Text(
                    context.uiText(_stopRequested ? 'Đã dừng dịch' : 'Đã dịch xong'),
                    style: TextStyle(color: Colors.grey[500], fontSize: 10.5),
                  ),
                ),
              ),
            if (_error != null && _error != 'Đã dừng dịch' && !_isTranslating)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFFB74D).withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  context.uiText(_error!),
                  style: const TextStyle(
                    color: Color(0xFFFFCC80),
                    fontSize: 11.5,
                  ),
                ),
              ),
            Expanded(
              child: _units.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          context.uiText(
                              'Không tìm thấy văn bản trong trang.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                      itemCount: _units.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _TranslationUnitCard(
                        unit: _units[index],
                        isPending: _isTranslating && index == _completed,
                        showFailure: !_isTranslating &&
                            index < _completed &&
                            _units[index].translation == null,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranslationUnitCard extends StatelessWidget {
  const _TranslationUnitCard({
    required this.unit,
    required this.isPending,
    required this.showFailure,
  });

  final WebTranslationUnit unit;
  final bool isPending;
  final bool showFailure;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            unit.original,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          if (unit.hasTranslation) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: Color(0x14FFFFFF)),
            ),
            SelectableText(
              unit.translation!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ] else if (isPending)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF66BB6A)),
                ),
              ),
            )
          else if (showFailure)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                context.uiText(
                  'Chưa dịch được đoạn này. Kiểm tra engine dịch hoặc kết nối mạng.',
                ),
                style: const TextStyle(
                  color: Color(0xFFEF9A9A),
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
