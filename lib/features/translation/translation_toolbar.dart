// lib/features/translation/translation_toolbar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language/app_language.dart';
import '../../providers/text_provider.dart';
import '../../screens/read_mode/services/playback_controller.dart';
import 'translation_display_mode.dart';
import 'translation_language_picker.dart';
import 'translation_service.dart';

class TranslationToolbar extends StatelessWidget {
  final Color primaryColor;

  const TranslationToolbar({
    super.key,
    this.primaryColor = const Color(0xFF6C63FF),
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TextProvider>(
      builder: (context, textProvider, _) {
        final isTranslating = textProvider.isTranslating;
        final hasTranslations = textProvider.translatedLineCount > 0;
        final displayMode = textProvider.translationDisplayMode;
        final progress = textProvider.translationProgress;
        final sourceLanguage = textProvider.detectedSourceLanguage;
        final targetLanguage = textProvider.translationTargetLanguage;
        final sameLanguage = textProvider.translationPairUsesSameLanguage;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            border: Border(
              bottom: BorderSide(
                color: primaryColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final translateButton = _TranslateButton(
                    isTranslating: isTranslating,
                    hasTranslations: hasTranslations,
                    primaryColor: primaryColor,
                    progress: progress,
                    totalLines: textProvider.lines.length,
                    translatedLines: textProvider.translatedLineCount,
                    requiresLanguageChoice: sameLanguage,
                    onTap: () async {
                      if (isTranslating) {
                        textProvider.cancelTranslation();
                      } else if (sameLanguage) {
                        await _selectTargetLanguage(context, textProvider);
                      } else {
                        await textProvider.translateAll();
                      }
                    },
                    onLongPress: () =>
                        _showTranslationOptions(context, textProvider),
                  );
                  final languageButton = TranslationLanguagePickerButton(
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    accentColor: primaryColor,
                    onSelected: (language) =>
                        _applyTargetLanguage(context, textProvider, language),
                  );
                  final settingsButton = IconButton(
                    onPressed: () => _showServerSettings(context),
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    color: Colors.grey[500],
                    tooltip: 'Cài đặt engine dịch',
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  );
                  final layoutSelector = _LayoutSelector(
                    displayMode: displayMode,
                    primaryColor: primaryColor,
                    onChanged: textProvider.setTranslationDisplayMode,
                  );

                  if (constraints.maxWidth < 560) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            translateButton,
                            const SizedBox(width: 8),
                            languageButton,
                            const Spacer(),
                            settingsButton,
                          ],
                        ),
                        if (hasTranslations) ...[
                          const SizedBox(height: 7),
                          Align(
                            alignment: Alignment.centerRight,
                            child: layoutSelector,
                          ),
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      translateButton,
                      const SizedBox(width: 8),
                      languageButton,
                      if (hasTranslations) ...[
                        const Spacer(),
                        layoutSelector,
                      ] else
                        const Spacer(),
                      const SizedBox(width: 4),
                      settingsButton,
                    ],
                  );
                },
              ),
              if (isTranslating) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      minHeight: 2),
                ),
              ],
              if (textProvider.translationError != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Lỗi: ${textProvider.translationError}',
                  style: const TextStyle(fontSize: 10, color: Colors.redAccent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectTargetLanguage(
    BuildContext context,
    TextProvider textProvider,
  ) async {
    final selected = await showTranslationLanguagePicker(
      context,
      sourceLanguage: textProvider.detectedSourceLanguage,
      currentTarget: textProvider.translationTargetLanguage,
      accentColor: primaryColor,
    );
    if (selected != null && context.mounted) {
      await _applyTargetLanguage(context, textProvider, selected);
    }
  }

  Future<void> _applyTargetLanguage(
    BuildContext context,
    TextProvider textProvider,
    AppLanguage language,
  ) async {
    final playback = context.read<PlaybackController>();
    if (playback.isRunning) {
      playback.stop(fileId: textProvider.currentDocument?.id ?? 'unknown');
    }
    await textProvider.stopSpeaking();
    final changed = await textProvider.setTranslationTargetLanguage(
      language.translationCode,
      retranslateExisting: true,
    );
    if (changed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${language.flag} Đã đổi bản dịch và giọng đọc sang '
            '${language.nativeName}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showTranslationOptions(
      BuildContext context, TextProvider textProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.translate, color: primaryColor),
              title: const Text('Dịch tất cả (bỏ qua đã có)',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                textProvider.translateAll();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text('Dịch lại tất cả',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                textProvider.translateAll(forceRetranslate: true);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Xóa tất cả bản dịch',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                textProvider.clearAllTranslations();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showServerSettings(BuildContext context) {
    // ★ SỬA 1: Tạo instance, không dùng static
    final service = TranslationService();

    final urlController = TextEditingController(
      text: service.deeplxUrl ?? '',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⚙️ Engine dịch thuật',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'DeepLX Server URL (tùy chọn)',
                labelStyle: const TextStyle(color: Colors.grey),
                hintText: 'Để trống → dùng Google Free',
                hintStyle: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ngôn ngữ đích được chọn bằng nút lá cờ trên thanh Dịch.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                service.configure(
                  deeplxUrl: urlController.text.trim(),
                );
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranslateButton extends StatelessWidget {
  final bool isTranslating;
  final bool hasTranslations;
  final Color primaryColor;
  final double progress;
  final int totalLines;
  final int translatedLines;
  final bool requiresLanguageChoice;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TranslateButton({
    required this.isTranslating,
    required this.hasTranslations,
    required this.primaryColor,
    required this.progress,
    required this.totalLines,
    required this.translatedLines,
    required this.requiresLanguageChoice,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = hasTranslations && translatedLines >= totalLines;
    final String label;
    final IconData icon;
    final Color color;
    if (isTranslating) {
      label = 'Dừng';
      icon = Icons.stop_circle_outlined;
      color = Colors.orange;
    } else if (requiresLanguageChoice) {
      label = 'Chọn đích';
      icon = Icons.language_rounded;
      color = Colors.amber;
    } else if (isComplete) {
      label = 'Đã dịch';
      icon = Icons.check_circle_outline;
      color = Colors.green;
    } else {
      label = 'Dịch';
      icon = Icons.translate;
      color = primaryColor;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            if (isTranslating)
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 2,
                      color: color))
            else
              Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _LayoutSelector extends StatelessWidget {
  final TranslationDisplayMode displayMode;
  final Color primaryColor;
  final ValueChanged<TranslationDisplayMode> onChanged;

  const _LayoutSelector(
      {required this.displayMode,
      required this.primaryColor,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeChip(
            icon: Icons.visibility_off_outlined,
            label: 'Ẩn',
            isSelected: displayMode == TranslationDisplayMode.hidden,
            color: primaryColor,
            onTap: () => onChanged(TranslationDisplayMode.hidden)),
        const SizedBox(width: 4),
        _ModeChip(
            icon: Icons.view_agenda_outlined,
            label: 'Dưới',
            isSelected: displayMode == TranslationDisplayMode.stackedBelow,
            color: primaryColor,
            onTap: () => onChanged(TranslationDisplayMode.stackedBelow)),
        const SizedBox(width: 4),
        _ModeChip(
            icon: Icons.view_column_outlined,
            label: 'Cột',
            isSelected: displayMode == TranslationDisplayMode.sideBySide,
            color: primaryColor,
            onTap: () => onChanged(TranslationDisplayMode.sideBySide)),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ModeChip(
      {required this.icon,
      required this.label,
      required this.isSelected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade700),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? color : Colors.grey,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class TranslationLineDisplay extends StatelessWidget {
  final String originalText;
  final String? translatedText;
  final TranslationDisplayMode displayMode;
  final Widget originalWidget;
  final TextStyle? translationStyle;
  final TextAlign? textAlign;

  const TranslationLineDisplay({
    super.key,
    required this.originalText,
    this.translatedText,
    required this.displayMode,
    required this.originalWidget,
    this.translationStyle,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final hasTranslation = translatedText != null && translatedText!.isNotEmpty;
    final targetLanguage = TranslationService().targetLanguage;

    if (displayMode == TranslationDisplayMode.hidden) return originalWidget;

    if (displayMode == TranslationDisplayMode.stackedBelow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          originalWidget,
          if (hasTranslation) ...[
            const SizedBox(height: 6),
            _TranslationText(
              text: translatedText!,
              language: targetLanguage,
              style: translationStyle,
              textAlign: textAlign,
            ),
          ],
        ],
      );
    }

    // Side by side
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: originalWidget),
          Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: Colors.white10),
          Expanded(
            child: hasTranslation
                ? _TranslationText(
                    text: translatedText!,
                    language: targetLanguage,
                    style: translationStyle,
                    textAlign: textAlign,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TranslationText extends StatelessWidget {
  final String text;
  final AppLanguage language;
  final TextStyle? style;
  final TextAlign? textAlign;

  const _TranslationText({
    required this.text,
    required this.language,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = language.translationCode == 'AR';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.035)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(language.flag, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              textDirection: isRtl ? TextDirection.rtl : null,
              textAlign: isRtl ? TextAlign.right : textAlign,
              style: style ??
                  TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
