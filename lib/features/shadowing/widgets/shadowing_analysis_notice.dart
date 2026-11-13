import 'package:in4up/core/language/localized_material.dart';

/// Honest failure state for shadowing analysis: no transcript/reference means
/// no score, never a fabricated perfect result.
class ShadowingAnalysisNotice extends StatelessWidget {
  const ShadowingAnalysisNotice({super.key, required this.code});

  final String code;

  String get _message {
    switch (code) {
      case 'no_reference':
        return 'Chưa có câu mẫu để chấm điểm. Hãy chọn một câu có lời.';
      case 'analysis_failed':
        return 'Chưa phân tích được bản ghi. Hãy thử ghi âm lại.';
      case 'no_speech':
      default:
        return 'Không nghe rõ bài đọc. Hãy kiểm tra micro rồi ghi âm lại.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.uiText(_message),
              style: const TextStyle(color: Colors.orange, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
