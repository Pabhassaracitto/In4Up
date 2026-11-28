// lib/screens/ai_chat/ai_model_options_sheet.dart
//
// PSRC-253 — bảng lựa chọn model local theo khả năng thiết bị.
//
// Luật hiển thị (tránh hiểu nhầm số đo với số ước tính):
//  * TỔNG RAM: ghi rõ "đo được" hoặc "không có số liệu" — không đoán.
//  * Kích thước file .gguf: đo được từ file trên máy.
//  * RAM đỉnh: ƯỚC TÍNH từ kích thước file, không phải cam kết an toàn.
//
// App KHÔNG tự tải model theo profile (không bịa URL model). Các tên model
// chỉ là ví dụ phổ thông để người dùng biết cần tìm file ~bao nhiêu MB.

import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up_ai/in4up_ai.dart';

/// Mở bảng tuỳ chọn AI local. Gọi từ nút trên AppBar của AI chat.
Future<void> showAiModelOptionsSheet(
  BuildContext context,
  AiServiceFacade facade,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AiModelOptionsSheet(facade: facade),
  );
}

class _AiModelOptionsSheet extends StatefulWidget {
  final AiServiceFacade facade;

  const _AiModelOptionsSheet({required this.facade});

  @override
  State<_AiModelOptionsSheet> createState() => _AiModelOptionsSheetState();
}

class _AiModelOptionsSheetState extends State<_AiModelOptionsSheet> {
  AiServiceFacade get facade => widget.facade;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.68,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, controller) => ListView(
        key: const Key('ai-model-options-sheet'),
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            context.uiText('Chọn model AI phù hợp thiết bị'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            context.uiText(
              'Gợi ý theo RAM, không phải cam kết model chạy an toàn. '
              'App không tự tải model — bạn tự import file .gguf.',
            ),
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          _MeasuredFacts(facade: facade),
          const SizedBox(height: 12),
          ...AiLocalProfile.values.map(
            (profile) => _ProfileTile(
              profile: profile,
              facade: facade,
              selected: facade.selectedLocalProfile == profile,
              recommended: facade.effectiveLocalProfile == profile &&
                  facade.selectedLocalProfile == null,
              onSelected: () => setState(
                () => facade.selectLocalProfile(
                  facade.selectedLocalProfile == profile ? null : profile,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ExpansionNote(
            title: 'Giới hạn đo lường & nóng máy',
            lines: const [
              'TỔNG RAM thiết bị: đo qua native Android. RAM ĐANG TRỐNG '
              'không có số liệu trên hầu hết nền tảng.',
              'RAM đỉnh bên trên là ước tính từ kích thước file, không đo thực tế.',
              'iOS/desktop/web/kênh native cũ không trả số RAM ⇒ app chỉ '
              'gợi ý profile nhẹ, model lớn cần xác nhận.',
              'App chưa đo nhiệt độ máy. Khi có ≥2 tác vụ nặng chạy cùng lúc '
              '(chat local + dịch/STT offline) sẽ hiện cảnh báo; hãy đợi bớt '
              'một tác vụ để máy nguội.',
            ],
          ),
        ],
      ),
    );
  }
}

class _MeasuredFacts extends StatelessWidget {
  final AiServiceFacade facade;
  const _MeasuredFacts({required this.facade});

  @override
  Widget build(BuildContext context) {
    final ram = facade.measuredTotalRamBytes;
    final fileBytes = facade.modelSizeBytes;
    final verdict = facade.lastModelFitVerdict;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FactRow(
              label: 'Tổng RAM (ĐO ĐƯỢC)',
              value: ram == null
                  ? context.uiText('Không có số liệu từ nền tảng')
                  : formatAiMemoryMb(ram),
            ),
            _FactRow(
              label: 'Ưu tiên hiện tại',
              value: facade.selectedLocalProfile == null
                  ? context.uiText('Tự theo RAM')
                  : facade.selectedLocalProfile!.id,
            ),
            _FactRow(
              label: 'File model hiện tại (ĐO ĐƯỢC)',
              value: fileBytes == null
                  ? context.uiText('Chưa có model local')
                  : formatAiMemoryMb(fileBytes),
            ),
            if (verdict?.estimatedPeakBytes != null)
              _FactRow(
                label: 'RAM đỉnh (ƯỚC TÍNH)',
                value: formatAiMemoryMb(verdict!.estimatedPeakBytes!),
              ),
            if (verdict != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  context.uiText(
                    switch (verdict.status) {
                      AiModelFitStatus.fit => 'Nằm trong ngưỡng gợi ý',
                      AiModelFitStatus.needsConfirmation =>
                        'Cần xác nhận trước khi nạp',
                      AiModelFitStatus.tooLarge =>
                        'Vượt ngưỡng RAM đo được — đã chặn',
                    },
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: verdict.isBlocked ? Colors.red : Colors.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;
  const _FactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.uiText(label),
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final AiLocalProfile profile;
  final AiServiceFacade facade;
  final bool selected;
  final bool recommended;
  final VoidCallback onSelected;

  const _ProfileTile({
    required this.profile,
    required this.facade,
    required this.selected,
    required this.recommended,
    required this.onSelected,
  });

  static const _examples = {
    AiLocalProfile.lite: '~1,5–2 GB · ví dụ Gemma 2B / Qwen 2.5 3B (Q4)',
    AiLocalProfile.balanced: '~3–3,5 GB · ví dụ Gemma 3 4B (Q4)',
    AiLocalProfile.full: '~4–7 GB · ví dụ Qwen 2.5 7B / Llama 3 8B (Q4)',
  };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      key: Key('ai-profile-${profile.id}'),
      selected: selected,
      onTap: onSelected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 18,
        color: selected ? const Color(0xFF4CAF50) : null,
      ),
      title: Text(
        context.uiText(
          switch (profile) {
            AiLocalProfile.lite => 'Nhẹ — máy ít RAM / dùng hàng ngày',
            AiLocalProfile.balanced => 'Cân bằng — máy tầm trung',
            AiLocalProfile.full => 'Đầy đủ — máy nhiều RAM, cần tốc độ',
          },
        ),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.uiText(_examples[profile]!),
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          if (recommended)
            Text(
              context.uiText('Khuyến nghị theo RAM'),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF81C784),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
      trailing: selected
          ? Icon(Icons.check, size: 16, color: Theme.of(context).primaryColor)
          : null,
    );
  }
}

class _ExpansionNote extends StatelessWidget {
  final String title;
  final List<String> lines;
  const _ExpansionNote({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(context.uiText(title), style: const TextStyle(fontSize: 13)),
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              context.uiText(line),
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
      ],
    );
  }
}
