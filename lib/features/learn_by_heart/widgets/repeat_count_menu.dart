import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';

/// Compact popup to pick how many times to play a verse or a line.
///
/// `0` is infinite and only offered when [allowInfinite] is true (item/chunk).
Future<void> showRepeatCountMenu(
  BuildContext context, {
  required int current,
  required ValueChanged<int> onChanged,
  bool allowInfinite = false,
  String title = 'Số lần phát',
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) return;

  final rect = RelativeRect.fromRect(
    Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    ),
    Offset.zero & overlay.size,
  );

  final selected = await showMenu<int>(
    context: context,
    position: rect,
    color: const Color(0xFF141D2E),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    items: [
      if (allowInfinite)
        PopupMenuItem<int>(
          value: 0,
          child: _RepeatMenuItem(
            label: '∞',
            subtitle: 'Lặp mãi',
            selected: current == 0,
          ),
        ),
      for (final value in [1, 2, 3, 4, 5, 7, 10])
        PopupMenuItem<int>(
          value: value,
          child: _RepeatMenuItem(
            label: '$value×',
            subtitle: value == 1 ? 'Một lần' : '$value lần',
            selected: current == value,
          ),
        ),
      const PopupMenuDivider(height: 1),
      const PopupMenuItem<int>(
        value: -1,
        child: _RepeatMenuItem(
          label: 'Tùy chỉnh...',
          subtitle: 'Nhập số khác',
        ),
      ),
    ],
  );

  if (selected == null) return;
  if (selected == -1) {
    if (!context.mounted) return;
    final ctrl = TextEditingController(
      text: current > 0 ? '$current' : '',
    );
    final custom = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: context.uiText('VD: 12'),
            hintStyle: TextStyle(color: Colors.grey[600]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, value);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (custom == null) return;
    if (!allowInfinite && custom < 1) return;
    HapticFeedback.selectionClick();
    onChanged(custom);
    return;
  }

  HapticFeedback.selectionClick();
  onChanged(selected);
}

class _RepeatMenuItem extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;

  const _RepeatMenuItem({
    required this.label,
    required this.subtitle,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (selected)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.check, size: 14, color: Color(0xFFFFB300)),
          )
        else
          const SizedBox(width: 22),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.uiText(label),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                context.uiText(subtitle),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
