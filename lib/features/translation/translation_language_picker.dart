import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

import '../../core/language/app_language.dart';
import 'translation_source_choice.dart';

class TranslationLanguagePickerButton extends StatelessWidget {
  final AppLanguage sourceLanguage;
  final AppLanguage targetLanguage;

  /// Chọn xong ngôn ngữ ĐÍCH (bảng chỉ-chọn-đích). Bỏ qua khi có [onPressed].
  final Future<void> Function(AppLanguage language)? onSelected;

  /// PSRC-238: nơi gọi tự mở bảng chọn (vd bảng chọn cả nguồn lẫn đích của
  /// tab Đọc). Có giá trị ⇒ nút KHÔNG tự mở bảng chỉ-chọn-đích nữa.
  final Future<void> Function()? onPressed;

  /// False khi người dùng đã tự chọn nguồn ⇒ chú thích không còn ghi
  /// «Tự nhận diện».
  final bool sourceIsAuto;
  final Color accentColor;
  final bool compact;

  const TranslationLanguagePickerButton({
    super.key,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.onSelected,
    this.onPressed,
    this.sourceIsAuto = true,
    this.accentColor = const Color(0xFF6C63FF),
    this.compact = true,
  }) : assert(onSelected != null || onPressed != null);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      // Tên ngôn ngữ là tên bản ngữ ⇒ dạng đã chọn nguồn không cần dịch.
      message: sourceIsAuto
          ? context.uiText(
              'Tự nhận diện ${sourceLanguage.nativeName} → ${targetLanguage.nativeName}',
            )
          : '${sourceLanguage.nativeName} → ${targetLanguage.nativeName}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(compact ? 18 : 14),
          onTap: () async {
            final open = onPressed;
            if (open != null) {
              await open();
              return;
            }
            final selected = await showTranslationLanguagePicker(
              context,
              sourceLanguage: sourceLanguage,
              currentTarget: targetLanguage,
              accentColor: accentColor,
            );
            if (selected != null) await onSelected?.call(selected);
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 6 : 12,
            ),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(compact ? 18 : 14),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.32),
              ),
            ),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Text(sourceLanguage.flag,
                    style: TextStyle(fontSize: compact ? 15 : 20)),
                const SizedBox(width: 5),
                if (!compact)
                  Flexible(
                    child: Text(
                      sourceLanguage.nativeName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: compact ? 13 : 17,
                    color: Colors.grey[500],
                  ),
                ),
                Text(targetLanguage.flag,
                    style: TextStyle(fontSize: compact ? 15 : 20)),
                const SizedBox(width: 5),
                if (compact)
                  Text(
                    targetLanguage.translationCode,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else
                  Flexible(
                    child: Text(
                      targetLanguage.nativeName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more_rounded,
                  size: compact ? 14 : 18,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PSRC-238: kết quả của bảng chọn CẶP ngôn ngữ ở tab Đọc.
class TranslationPairChoice {
  const TranslationPairChoice({this.sourceCode, this.target});

  /// `null` = không đổi nguồn; [kTranslationSourceAuto] = «Tự nhận diện»;
  /// còn lại = mã dịch (vd `EN`).
  final String? sourceCode;

  /// `null` = không đổi đích.
  final AppLanguage? target;
}

/// Bảng CHỈ chọn ngôn ngữ đích (dùng ở thẻ «Dịch màn hình»: nguồn được chọn
/// ở chỗ khác).
Future<AppLanguage?> showTranslationLanguagePicker(
  BuildContext context, {
  required AppLanguage sourceLanguage,
  required AppLanguage currentTarget,
  Color accentColor = const Color(0xFF6C63FF),
}) async {
  final choice = await showModalBottomSheet<TranslationPairChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LanguagePickerSheet(
      detectedSource: sourceLanguage,
      pinnedSourceCode: null,
      currentTarget: currentTarget,
      accentColor: accentColor,
      sourceSelectable: false,
    ),
  );
  return choice?.target;
}

/// PSRC-238 / ADR-0031 (3b): bảng chọn cả ngôn ngữ NGUỒN («Tự nhận diện» +
/// danh sách) lẫn ngôn ngữ ĐÍCH cho tài liệu ở tab Đọc.
///
/// [detectedSource] = kết quả nhận diện tự động; [pinnedSourceCode] = nguồn
/// người dùng đã chọn (`null` = đang «Tự nhận diện»).
///
/// Khi nguồn trùng đích, bảng KHÔNG đóng với một dòng lỗi: nó chuyển sang
/// phía đích và đề nghị sẵn một ngôn ngữ đích khác.
Future<TranslationPairChoice?> showTranslationPairPicker(
  BuildContext context, {
  required AppLanguage detectedSource,
  required String? pinnedSourceCode,
  required AppLanguage currentTarget,
  Color accentColor = const Color(0xFF6C63FF),
}) =>
    showModalBottomSheet<TranslationPairChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguagePickerSheet(
        detectedSource: detectedSource,
        pinnedSourceCode: pinnedSourceCode,
        currentTarget: currentTarget,
        accentColor: accentColor,
        sourceSelectable: true,
      ),
    );

enum _PickerSide { source, target }

class _LanguagePickerSheet extends StatefulWidget {
  final AppLanguage detectedSource;
  final String? pinnedSourceCode;
  final AppLanguage currentTarget;
  final Color accentColor;
  final bool sourceSelectable;

  const _LanguagePickerSheet({
    required this.detectedSource,
    required this.pinnedSourceCode,
    required this.currentTarget,
    required this.accentColor,
    required this.sourceSelectable,
  });

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _PickerSide _side = _PickerSide.target;

  /// Nguồn vừa chọn trong bảng này nhưng CHƯA áp (đang chờ chọn đích vì
  /// trùng). `null` = chưa đụng tới nguồn.
  String? _pendingSourceCode;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Mã nguồn đang chọn: [kTranslationSourceAuto] hoặc mã dịch.
  String get _sourceChoice =>
      _pendingSourceCode ?? widget.pinnedSourceCode ?? kTranslationSourceAuto;

  bool get _sourceIsAuto => _sourceChoice == kTranslationSourceAuto;

  AppLanguage get _effectiveSource => _sourceIsAuto
      ? widget.detectedSource
      : AppLanguageCatalog.fromCode(
          _sourceChoice,
          fallback: widget.detectedSource,
        );

  /// Nguồn hiệu dụng lúc mở bảng (trước mọi thay đổi trong bảng).
  AppLanguage get _initialSource => widget.pinnedSourceCode == null
      ? widget.detectedSource
      : AppLanguageCatalog.fromCode(
          widget.pinnedSourceCode,
          fallback: widget.detectedSource,
        );

  bool get _samePair =>
      _effectiveSource.translationCode == widget.currentTarget.translationCode;

  void _clearSearch() {
    _searchController.clear();
    _query = '';
  }

  void _pickSource(String code) {
    HapticFeedback.selectionClick();
    final language = code == kTranslationSourceAuto
        ? widget.detectedSource
        : AppLanguageCatalog.fromCode(code, fallback: widget.detectedSource);
    if (language.translationCode == widget.currentTarget.translationCode) {
      // Trùng đích ⇒ ở lại, chuyển sang phía đích và đề nghị đích khác.
      setState(() {
        _pendingSourceCode = code;
        _side = _PickerSide.target;
        _clearSearch();
      });
      return;
    }
    Navigator.pop(context, TranslationPairChoice(sourceCode: code));
  }

  void _pickTarget(AppLanguage language) {
    HapticFeedback.selectionClick();
    Navigator.pop(
      context,
      TranslationPairChoice(sourceCode: _pendingSourceCode, target: language),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final languages = AppLanguageCatalog.languages.where((language) {
      if (query.isEmpty) return true;
      return language.nativeName.toLowerCase().contains(query) ||
          language.englishName.toLowerCase().contains(query) ||
          language.vietnameseName.toLowerCase().contains(query) ||
          language.translationCode.toLowerCase().contains(query);
    }).toList(growable: false);
    final source = _effectiveSource;
    final pickingSource =
        widget.sourceSelectable && _side == _PickerSide.source;
    // Các dòng đứng trước danh sách ngôn ngữ. Chúng CUỘN cùng danh sách để
    // phần đầu bảng (tiêu đề, cặp ngôn ngữ, ô tìm) luôn đủ chỗ trên màn thấp.
    final leading = <Widget>[
      if (widget.sourceSelectable && _samePair)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: _SamePairBanner(
            suggestion: suggestTargetAvoidingSource(
              source: source,
              uiLanguageCode: Localizations.localeOf(context).toLanguageTag(),
              previousSource: _initialSource,
            ),
            onAccept: _pickTarget,
            // Chỉ khi cặp trùng là do vừa đổi nguồn ngay trong bảng này: cho
            // phép giữ cặp trùng (vd chỉ cần đúng giọng đọc, không cần dịch).
            onKeepSourceOnly: _pendingSourceCode == null
                ? null
                : () => Navigator.pop(
                      context,
                      TranslationPairChoice(sourceCode: _pendingSourceCode),
                    ),
          ),
        ),
      // «Tự nhận diện» đứng đầu danh sách nguồn; ẩn khi đang gõ tìm.
      if (pickingSource && query.isEmpty) _autoDetectTile(context),
    ];
    final leadingRows = leading.length;

    return DraggableScrollableSheet(
      // Bảng chọn cặp có thêm hàng «nguồn → đích» ở đầu ⇒ cần cao hơn một
      // chút để phần đầu không tràn trên màn thấp (điện thoại nằm ngang).
      initialChildSize: widget.sourceSelectable ? 0.82 : 0.76,
      minChildSize: widget.sourceSelectable ? 0.64 : 0.48,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 28,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ngôn ngữ bản dịch',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (!widget.sourceSelectable) ...[
                              const SizedBox(height: 4),
                              Text(
                                context.uiText('Đã nhận diện ${source.flag} ${source.nativeName} • ${AppLanguageCatalog.languages.length} ngôn ngữ đích'),
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ],
                  ),
                  if (widget.sourceSelectable) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _PairSideCard(
                            key: const Key('translation-pair-source-side'),
                            label: context.uiText('Ngôn ngữ nguồn'),
                            language: source,
                            caption: _sourceIsAuto
                                ? context.uiText('Tự nhận diện')
                                : null,
                            selected: _side == _PickerSide.source,
                            accentColor: widget.accentColor,
                            onTap: () => setState(() {
                              _side = _PickerSide.source;
                              _clearSearch();
                            }),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                        Expanded(
                          child: _PairSideCard(
                            key: const Key('translation-pair-target-side'),
                            label: context.uiText('Ngôn ngữ đích'),
                            language: widget.currentTarget,
                            selected: _side == _PickerSide.target,
                            accentColor: widget.accentColor,
                            onTap: () => setState(() {
                              _side = _PickerSide.target;
                              _clearSearch();
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.uiText('Tìm ngôn ngữ…'),
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white38),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(_clearSearch),
                              icon: const Icon(Icons.clear,
                                  color: Colors.white38),
                            ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              // Material riêng cho danh sách: nền dòng đang chọn và hiệu
              // ứng chạm của ListTile vẽ lên Material gần nhất — nếu không
              // có thì bị nền đặc của bảng che mất.
              child: Material(
                type: MaterialType.transparency,
                child: ListView.builder(
                // Đổi phía ⇒ danh sách mới, cuộn về đầu.
                key: ValueKey<_PickerSide>(
                  pickingSource ? _PickerSide.source : _PickerSide.target,
                ),
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                itemCount: languages.length + leadingRows,
                itemBuilder: (context, index) {
                  if (index < leadingRows) return leading[index];
                  final language = languages[index - leadingRows];
                  return pickingSource
                      ? _sourceTile(context, language)
                      : _targetTile(context, language, source);
                },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _autoDetectTile(BuildContext context) {
    final detected = widget.detectedSource;
    final isSelected = _sourceIsAuto;
    return ListTile(
      key: const Key('translation-source-auto'),
      onTap: () => _pickSource(kTranslationSourceAuto),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: isSelected
          ? widget.accentColor.withValues(alpha: 0.13)
          : Colors.transparent,
      leading: Icon(Icons.auto_awesome, color: widget.accentColor, size: 24),
      title: Text(
        context.uiText('Tự nhận diện'),
        style: TextStyle(
          color: Colors.white,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      // Cho thấy app đang nhận ra ngôn ngữ nào, để người dùng biết có cần
      // chọn tay hay không.
      subtitle: Text(
        '${detected.flag} ${detected.nativeName}',
        style: TextStyle(color: Colors.grey[500], fontSize: 11),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: widget.accentColor, size: 20)
          : null,
    );
  }

  Widget _sourceTile(BuildContext context, AppLanguage language) {
    final isSelected = !_sourceIsAuto &&
        language.translationCode == _effectiveSource.translationCode;
    return ListTile(
      onTap: () => _pickSource(language.translationCode),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: isSelected
          ? widget.accentColor.withValues(alpha: 0.13)
          : Colors.transparent,
      leading: Text(language.flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        language.nativeName,
        style: TextStyle(
          color: Colors.white,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${language.englishName} • ${language.translationCode}',
        style: TextStyle(color: Colors.grey[500], fontSize: 11),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: widget.accentColor, size: 20)
          : null,
    );
  }

  Widget _targetTile(
    BuildContext context,
    AppLanguage language,
    AppLanguage source,
  ) {
    final isSource = language.translationCode == source.translationCode;
    final isSelected =
        language.translationCode == widget.currentTarget.translationCode;
    return ListTile(
      enabled: !isSource,
      onTap: isSource ? null : () => _pickTarget(language),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: isSelected
          ? widget.accentColor.withValues(alpha: 0.13)
          : Colors.transparent,
      leading: Text(language.flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        language.nativeName,
        style: TextStyle(
          color: isSource ? Colors.white30 : Colors.white,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        isSource
            ? context.uiText('${language.nativeName} • ngôn ngữ nguồn')
            : '${language.nativeName} • ${language.translationCode}',
        style: TextStyle(
          color: isSource ? Colors.white24 : Colors.grey[500],
          fontSize: 11,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: widget.accentColor, size: 20)
          : isSource
              ? const Icon(Icons.auto_awesome, color: Colors.white24, size: 18)
              : null,
    );
  }
}

/// Một nửa của cặp «nguồn → đích» ở đầu bảng; chạm để chọn phía cần đổi.
class _PairSideCard extends StatelessWidget {
  final String label;
  final AppLanguage language;
  final String? caption;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _PairSideCard({
    super.key,
    required this.label,
    required this.language,
    required this.selected,
    required this.accentColor,
    required this.onTap,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            // Vùng chạm ≥ 48 dp.
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? accentColor : Colors.white12,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  caption == null ? label : '$label · $caption',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  '${language.flag} ${language.nativeName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nguồn trùng đích ⇒ nói rõ và đề nghị sẵn MỘT đích khác (một chạm).
class _SamePairBanner extends StatelessWidget {
  final AppLanguage suggestion;
  final ValueChanged<AppLanguage> onAccept;
  final VoidCallback? onKeepSourceOnly;

  const _SamePairBanner({
    required this.suggestion,
    required this.onAccept,
    this.onKeepSourceOnly,
  });

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFC107);
    return Container(
      key: const Key('translation-same-pair-banner'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.info_outline, color: amber, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.uiText(
                    'Ngôn ngữ nguồn và ngôn ngữ đích đang giống nhau.',
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                key: const Key('translation-same-pair-accept'),
                onPressed: () => onAccept(suggestion),
                icon: Text(
                  suggestion.flag,
                  style: const TextStyle(fontSize: 16),
                ),
                label: Text(
                  context.uiText('Dịch sang ${suggestion.nativeName}'),
                ),
              ),
              if (onKeepSourceOnly != null)
                TextButton(
                  key: const Key('translation-same-pair-keep'),
                  onPressed: onKeepSourceOnly,
                  child: Text(context.uiText('Chỉ đổi nguồn')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
