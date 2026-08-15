import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/language/app_language.dart';
import 'package:in4up/core/language/tr_extension.dart';

class TranslationLanguagePickerButton extends StatelessWidget {
  final AppLanguage sourceLanguage;
  final AppLanguage targetLanguage;
  final Future<void> Function(AppLanguage language) onSelected;
  final Color accentColor;
  final bool compact;

  const TranslationLanguagePickerButton({
    super.key,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.onSelected,
    this.accentColor = const Color(0xFF6C63FF),
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'Content',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(compact ? 18 : 14),
          onTap: () async {
            final selected = await showTranslationLanguagePicker(
              context,
              sourceLanguage: sourceLanguage,
              currentTarget: targetLanguage,
              accentColor: accentColor,
            );
            if (selected != null) await onSelected(selected);
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

Future<AppLanguage?> showTranslationLanguagePicker(
  BuildContext context, {
  required AppLanguage sourceLanguage,
  required AppLanguage currentTarget,
  Color accentColor = const Color(0xFF6C63FF),
}) =>
    showModalBottomSheet<AppLanguage>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguagePickerSheet(
        sourceLanguage: sourceLanguage,
        currentTarget: currentTarget,
        accentColor: accentColor,
      ),
    );

class _LanguagePickerSheet extends StatefulWidget {
  final AppLanguage sourceLanguage;
  final AppLanguage currentTarget;
  final Color accentColor;

  const _LanguagePickerSheet({
    required this.sourceLanguage,
    required this.currentTarget,
    required this.accentColor,
  });

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    return DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.48,
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
                            const Text(context.l10n.translationLanguage, style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Đã nhận diện ${widget.sourceLanguage.flag} '
                              '${widget.sourceLanguage.nativeName} • '
                              'Content',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.l10n.translationSearchLang,
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white38),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
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
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final language = languages[index];
                  final isSource = language.translationCode ==
                      widget.sourceLanguage.translationCode;
                  final isSelected = language.translationCode ==
                      widget.currentTarget.translationCode;
                  return ListTile(
                    enabled: !isSource,
                    onTap: isSource
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context, language);
                          },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tileColor: isSelected
                        ? widget.accentColor.withValues(alpha: 0.13)
                        : Colors.transparent,
                    leading: Text(language.flag,
                        style: const TextStyle(fontSize: 24)),
                    title: Text(
                      language.nativeName,
                      style: TextStyle(
                        color: isSource ? Colors.white30 : Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      isSource
                          ? 'Content'
                          : '${language.vietnameseName} • ${language.translationCode}',
                      style: TextStyle(
                        color: isSource ? Colors.white24 : Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle,
                            color: widget.accentColor, size: 20)
                        : isSource
                            ? const Icon(Icons.auto_awesome,
                                color: Colors.white24, size: 18)
                            : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}