import 'package:in4up/core/language/localized_material.dart';

/// The annotation belongs inside the source word's layout box. It can wrap
/// within that box when even one transcription exceeds the source column.
class ReadWordIpa extends StatelessWidget {
  const ReadWordIpa({super.key, required this.span, this.inline = false});

  final InlineSpan span;

  /// WidgetSpan already applies the paragraph's scale to its whole child.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: RichText(
        text: span,
        textAlign: TextAlign.center,
        textScaler:
            inline ? TextScaler.noScaling : MediaQuery.textScalerOf(context),
      ),
    );
  }
}
