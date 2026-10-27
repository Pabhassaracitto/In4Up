import 'package:in4up/core/language/localized_material.dart';

import '../../../providers/player_provider.dart';

/// The old cache used only a display name, so its path-keyed data needs a
/// deliberate user decision before it can be attached to a particular URI.
class LegacyAudioDataButton extends StatelessWidget {
  final PlayerProvider player;
  const LegacyAudioDataButton({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final offer = player.legacyDataOffer;
    if (offer == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: context.uiText('Dữ liệu cũ chưa xác minh'),
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(dialogContext.uiText('Dữ liệu cũ chưa xác minh')),
            content: Text(dialogContext.uiText(offer.canLink
                ? 'Dữ liệu cũ cùng tên được giữ nguyên. Chỉ liên kết nếu bạn chắc đây là đúng file âm thanh.'
                : 'Dữ liệu cũ được giữ nguyên, nhưng không thể liên kết an toàn vì cache cũ khác nội dung hoặc đã thuộc nguồn khác.')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(dialogContext.uiText('Để sau')),
              ),
              if (offer.canLink)
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(dialogContext.uiText('Liên kết dữ liệu cũ')),
                ),
            ],
          ),
        );
        if (confirmed != true) return;
        final linked = await player.claimLegacyAudioData();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.uiText(linked
              ? 'Đã liên kết dữ liệu cũ'
              : 'Không thể liên kết dữ liệu cũ')),
        ));
      },
    );
  }
}
