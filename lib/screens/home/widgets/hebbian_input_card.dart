import 'package:in4up/core/language/localized_material.dart';

/// Card "NẠP TRI THỨC NHANH" ở tab Home (HOME-QUICK-001).
///
/// Hai hành động THẬT (không còn stub rỗng):
///  * [onStartVoiceCapture] — mở sheet STT dùng chung với FAB microphone
///    (`QuickCaptureSheet`): transcript realtime → lưu WordList / ghi chú.
///  * [onShowSuggestion] — hiện MỘT entry thật từ WordList (ưu tiên thẻ
///    đến kỳ ôn) kèm IPA/nghĩa + TTS.
///
/// Card giữ vai trò trình bày: caller (HomeScreen) quyết định mở sheet nào
/// để FAB và card đi chung MỘT flow, không tạo STT session rời rạc.
class HebbianInputCard extends StatelessWidget {
  const HebbianInputCard({
    super.key,
    this.onStartVoiceCapture,
    this.onShowSuggestion,
  });

  final VoidCallback? onStartVoiceCapture;
  final VoidCallback? onShowSuggestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.uiText('NẠP TRI THỨC NHANH'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickInputButton(
                  icon: Icons.mic,
                  label: context.uiText('Ghi chú nói'),
                  color: const Color(0xFFFF4848),
                  onTap: onStartVoiceCapture,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickInputButton(
                  icon: Icons.auto_awesome,
                  label: context.uiText('Gợi ý'),
                  color: const Color(0xFF00D1FF),
                  onTap: onShowSuggestion,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickInputButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickInputButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
