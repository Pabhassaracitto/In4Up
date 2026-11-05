// lib/features/translation/engines/deeplx_endpoint.dart
//
// AUDIT-1.21.0 #6 — "kẹt «Thử kết nối DeepLX»" / dán nhầm link bài hướng dẫn.
//
// Owner chạy DeepLX bằng server trong Termux rồi "lấy link dán vô". Link lấy
// được thường là **trang hướng dẫn** (vd https://linux.do/t/topic/111737 — bài
// chia sẻ endpoint DeepLX), KHÔNG phải endpoint. `DeepLXEngine.normalizeUrl`
// hiện GIỮ NGUYÊN mọi path lạ ⇒ app POST câu mẫu lên trang forum, chờ HTML/
// redirect/timeout ⇒ nút "Thử kết nối" quay mãi, chuỗi dịch còn tốn 12s cho
// engine DeepLX trước khi rớt xuống engine kế (dù máy ĐÃ CÓ model offline).
//
// Bộ lọc này là hàm THUẦN (test host VM) và là nguồn sự thật DUY NHẤT cho
// "URL này có phải endpoint DeepLX không?": UI sheet, probe và
// TranslationService._initEngines đều hỏi nó.

/// Lý do URL không dùng được làm endpoint.
enum DeepLXEndpointIssue {
  /// Ô để trống — KHÔNG phải lỗi: app dùng engine online khác.
  notConfigured,

  /// Không parse được / thiếu scheme / thiếu host.
  malformed,

  /// Scheme không phải http/https.
  unsupportedScheme,

  /// Link bài viết/forum/hướng dẫn (dán nhầm).
  articleLink,

  /// Có vẻ là host của trang tin/blog, không phải server DeepLX.
  contentHost,
}

class DeepLXEndpointVerdict {
  const DeepLXEndpointVerdict({
    required this.issue,
    required this.normalizedUrl,
    required this.message,
  });

  final DeepLXEndpointIssue? issue;
  final String? normalizedUrl;

  /// Thông báo English (canonical fallback rule #5) — UI có thể bọc
  /// `context.uiText(...)` khi cần bản địa hoá.
  final String message;

  bool get isConfigured => issue != DeepLXEndpointIssue.notConfigured;
  bool get isValid => issue == null;
  bool get isArticleLink => issue == DeepLXEndpointIssue.articleLink;
}

/// Path của các trang bài viết / diễn đàn / tài liệu — dán nhầm thay vì endpoint.
final RegExp _articlePath = RegExp(
  r'(?:^|/)(?:t|topic|topics|thread|threads|post|posts|p|discussion|'
  r'discussions|article|articles|blog|news|docs|wiki|readme|blob)(?:/|$)',
  caseSensitive: false,
);

/// Host của các trang nội dung (không phải API server).
const List<String> _contentHostSuffixes = <String>[
  'linux.do',
  'github.com',
  'gitee.com',
  'medium.com',
  'stackoverflow.com',
  'csdn.net',
  'zhihu.com',
  'reddit.com',
  'bilibili.com',
];

const List<String> _knownEndpointPaths = <String>[
  '/translate',
  '/v1/translate',
  '/v2/translate',
  '/api/translate',
];

/// Đánh giá [raw] (chuỗi user dán) TRƯỚC khi gọi mạng.
///
///  • host trần (`http://192.168.1.5:1188`) → tự nối `/translate`;
///  • path `/translate` (hoặc reverse-proxy tự đặt) → giữ nguyên;
///  • link bài/forum → từ chối NGAY (không tốn 20s probe, không làm chậm dịch).
DeepLXEndpointVerdict assessDeepLXEndpoint(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const DeepLXEndpointVerdict(
      issue: DeepLXEndpointIssue.notConfigured,
      normalizedUrl: null,
      message: 'DeepLX is not configured — using other engines.',
    );
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return const DeepLXEndpointVerdict(
      issue: DeepLXEndpointIssue.malformed,
      normalizedUrl: null,
      // Giữ nguyên cụm "invalid URL" (test XLAT-DEEPLX-001 pin chuỗi này).
      message: 'invalid URL — expected http(s)://host[:port]/translate.',
    );
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return const DeepLXEndpointVerdict(
      issue: DeepLXEndpointIssue.unsupportedScheme,
      normalizedUrl: null,
      message: 'DeepLX URL must use http or https.',
    );
  }

  var path = uri.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final host = uri.host.toLowerCase();

  if (_articlePath.hasMatch(path)) {
    return const DeepLXEndpointVerdict(
      issue: DeepLXEndpointIssue.articleLink,
      normalizedUrl: null,
      message: 'This is an article/forum link, not a DeepLX endpoint. '
          'Paste the server URL instead (e.g. http://127.0.0.1:1188/translate).',
    );
  }
  if (_contentHostSuffixes.any(
    (suffix) => host == suffix || host.endsWith('.$suffix'),
  )) {
    return const DeepLXEndpointVerdict(
      issue: DeepLXEndpointIssue.contentHost,
      normalizedUrl: null,
      message: 'This host is a content site, not a DeepLX server. '
          'Use the /translate endpoint running in Termux or on your LAN.',
    );
  }

  // Host trần ⇒ tự nối /translate (hành vi cũ, giữ nguyên).
  if (path.isEmpty || path == '/') {
    path = '/translate';
  }

  final normalized = uri.replace(path: path).toString();
  return DeepLXEndpointVerdict(
    issue: null,
    normalizedUrl: normalized,
    message: _knownEndpointPaths.contains(path.toLowerCase())
        ? 'DeepLX endpoint looks valid.'
        : 'Custom DeepLX path — will probe before sending translations.',
  );
}
