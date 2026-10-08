import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/core/responsive/app_responsive.dart';

@immutable
class I4uCommand {
  const I4uCommand({
    required this.id,
    required this.label,
    required this.icon,
    this.keywords = const <String>[],
    this.enabled = true,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<String> keywords;
  final bool enabled;

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return enabled;
    return enabled && ('$label ${keywords.join(' ')}').toLowerCase().contains(needle);
  }
}

Future<String?> showI4uCommandPalette(
  BuildContext context, {
  required List<I4uCommand> commands,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _CommandPaletteDialog(commands: commands),
  );
}

class _CommandPaletteDialog extends StatefulWidget {
  const _CommandPaletteDialog({required this.commands});
  final List<I4uCommand> commands;

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.commands.where((command) => command.matches(_query.text)).toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppResponsive.overlayDialogMaxWidth,
          maxHeight: AppResponsive.overlayDialogMaxHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _query,
                focusNode: _focus,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  // Chrome ⇒ đi qua uiText (rule #5): locale ≠ vi hiện English.
                  hintText: context.uiText('Tìm lệnh hoặc workspace'),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => filtered.isNotEmpty ? Navigator.pop(context, filtered.first.id) : null,
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(context.uiText('Không tìm thấy lệnh phù hợp.')),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final command = filtered[index];
                      return Semantics(
                        button: true,
                        label: command.label,
                        child: ListTile(
                          leading: Icon(command.icon),
                          title: Text(command.label),
                          onTap: () => Navigator.pop(context, command.id),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
