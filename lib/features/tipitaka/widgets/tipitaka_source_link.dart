import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/screens/reader_screen.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_source_resolver.dart';
import 'package:in4up/models/tipitaka_source_anchor.dart';

/// Small reusable action used by Worklist/Learn by Heart to reopen a saved
/// Tipiṭaka location after resolving it against the current database.
class TipitakaSourceLink extends StatelessWidget {
  final TipitakaSourceAnchor anchor;
  final bool compact;

  const TipitakaSourceLink({
    super.key,
    required this.anchor,
    this.compact = false,
  });

  Future<void> _open(BuildContext context) async {
    try {
      final location = await const TipitakaSourceResolver().resolve(anchor);
      if (!context.mounted) return;
      if (location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.uiText('Không tìm thấy lại nguồn Tipiṭaka.'))),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TipitakaReaderScreen(
            bookId: location.bookId,
            bookCode: location.bookCode,
            bookName: location.bookName,
            initialSegmentId: location.segment.id,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.uiText('Không thể mở nguồn Tipiṭaka: $error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _open(context),
      icon: const Icon(Icons.menu_book_outlined, size: 16),
      label: Text(
        context.uiText('Mở nguồn Tipiṭaka'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: TextButton.styleFrom(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
            : null,
        minimumSize: compact ? Size.zero : null,
        tapTargetSize:
            compact ? MaterialTapTargetSize.shrinkWrap : null,
      ),
    );
  }
}
