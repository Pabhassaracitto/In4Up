import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/material.dart' as material;

import '../services/dictionary_service.dart';

/// Never expose file paths or native database errors in the UI.
class DictLookupNotice extends StatelessWidget {
  final DictLookupReport report;
  final VoidCallback? onOpenDictionary;
  const DictLookupNotice({super.key, required this.report, this.onOpenDictionary});

  @override
  Widget build(BuildContext context) {
    if (report.failedSources.isEmpty && report.truncatedSources.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (report.failedSources.isNotEmpty) ...[
          Text(context.uiText('Không thể đọc một số bộ từ điển. Hãy kiểm tra hoặc nhập lại bộ bị lỗi.'),
            style: const TextStyle(color: Color(0xFFFFB74D))),
          material.Text(report.failedSources.join(', '), style: const TextStyle(color: Color(0xFFFFB74D))),
        ],
        if (report.truncatedSources.isNotEmpty) ...[
          Text(context.uiText('Một số bộ còn kết quả chưa hiển thị; nội dung bên dưới chưa đầy đủ.'),
            style: const TextStyle(color: Color(0xFFFFB74D))),
          material.Text(report.truncatedSources.join(', '), style: const TextStyle(color: Color(0xFFFFB74D))),
          if (onOpenDictionary != null)
            TextButton(onPressed: onOpenDictionary,
              child: Text(context.uiText('Xem từ điển đầy đủ'))),
        ],
      ]),
    );
  }
}
