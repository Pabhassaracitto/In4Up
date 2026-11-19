// lib/features/tipitaka/widgets/opentipitaka_credit.dart
//
// PSRC-256 — ghi công nguồn nội dung OpenTipitaka một cách tinh tế.
//
// Đã XÁC MINH tên + liên kết trên trang chính thức của dự án
// (https://www.opentipitaka.org/, truy cập 2026-11-19): "OpenTipitaka" là
// dự án Tipiṭaka đa ngữ; trang giới thiệu nêu sự hỗ trợ của Pyin Oo Lwin
// Pa-Auk Tawya Meditation Centre. Đây LÀ THÔNG TIN VỀ DỰ ÁN, không phải tuyên
// bố đối tác, chứng thực hay khuyến nghị của dự án đối với I4U. Vì vậy UI
// chỉ ghi "nguồn nội dung" + liên kết chính thức, không dùng từ "đối tác".

import 'package:in4up/core/language/localized_material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Địa chỉ chính thức đã xác minh — không dùng opentipitaka.com (trang độc
/// lập, không phải website chính thức của dự án).
const String kOpenTipitakaUrl = 'https://www.opentipitaka.org/';

/// Ghi công nhỏ ở cuối danh sách thư viện / màn quản lý dữ liệu.
class OpenTipitakaCredit extends StatelessWidget {
  /// true: chỉ một dòng mảnh, phù hợp cuối danh sách dài.
  final bool compact;

  const OpenTipitakaCredit({super.key, this.compact = true});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(kOpenTipitakaUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.uiText('Không mở được trang OpenTipitaka.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 12,
        vertical: compact ? 10 : 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('opentipitaka-credit-link'),
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    size: 12,
                    color: theme.hintColor,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      context.uiText(
                        'Nguồn nội dung: OpenTipitaka · opentipitaka.org',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(left: 17, top: 2),
              child: Text(
                context.uiText(
                  'Dự án Tipiṭaka đa ngữ được cộng đồng Pa-Auk hỗ trợ.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
