import 'package:flutter/material.dart' as material;

import 'app_ui_translations.dart';

export 'package:flutter/material.dart' hide Text;

extension LocalizedUiBuildContext on material.BuildContext {
  /// Translates a known hard-coded presentation message for this locale.
  String uiText(String sourceText) {
    final locale = material.Localizations.localeOf(this).toLanguageTag();
    return AppUITranslations.translate(sourceText, locale);
  }
}

/// Drop-in presentation shim for legacy hard-coded UI labels.
///
/// It intentionally has the same constructor surface currently used by this
/// application. The original value stays const-safe and is translated only at
/// build time, when the effective Flutter locale is available.
class Text extends material.StatelessWidget {
  final String data;
  final material.TextStyle? style;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final int? maxLines;

  const Text(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.maxLines,
  });

  @override
  material.Widget build(material.BuildContext context) {
    final locale = material.Localizations.localeOf(context).toLanguageTag();
    return material.Text(
      AppUITranslations.translateExact(data, locale),
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}
