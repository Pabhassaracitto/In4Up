import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'app_ui_translations.dart';

extension TrBuildContext on BuildContext {
  /// Translate a Vietnamese hardcoded string to current locale
  /// If locale is Vietnamese, returns original.
  /// If translation not found, falls back to original but will be logged.
  String tr(String vietnameseText) {
    final locale = Localizations.localeOf(this);
    return AppUITranslations.translate(vietnameseText, locale.toLanguageTag());
  }

  AppLocalizations get l10n => AppLocalizations.of(this)!;

  /// Shorthand for l10n with fallback to tr for legacy strings
  String trOrL10n(String vietnameseText, {String Function(AppLocalizations)? l10nGetter}) {
    if (l10nGetter != null) {
      try {
        return l10nGetter(l10n);
      } catch (_) {}
    }
    return tr(vietnameseText);
  }
}

/// A Text widget that automatically translates Vietnamese text based on current locale
class TrText extends StatelessWidget {
  final String vietnameseText;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;

  const TrText(
    this.vietnameseText, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      context.tr(vietnameseText),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}

/// Rich version for cases with variables: you pass builder that receives translated base strings
class TrBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, String Function(String) tr) builder;

  const TrBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return builder(context, (String vi) => context.tr(vi));
  }
}
