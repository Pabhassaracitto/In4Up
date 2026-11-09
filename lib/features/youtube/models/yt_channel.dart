// YT-MY-CHANNELS-001 (#1 owner 2026-10-28) — "Kênh của tôi" không cần OAuth.
//
// Owner đồng ý phương án: người dùng **dán** `@handle` hoặc URL kênh, app lưu
// danh sách đó ở máy, rồi liệt kê video mới của từng kênh bằng đường **không
// cần API key** (`YtSearchService.fetchChannelVideos`).
//
// Vì sao không "đăng nhập YouTube": không có API nào cho app bên thứ ba đọc
// subscription/video của kênh bằng tài khoản người dùng mà không qua OAuth +
// phê duyệt của Google, còn nhúng WebView đăng nhập thì Google chặn
// ("insecure browser") và vi phạm ToS. Đổi lại, cách dán tay chỉ tốn 10 giây
// cho mỗi kênh và **không bao giờ hỏng vì Google đổi chính sách**.
//
// Toàn bộ phần ĐỌC CHUỖI ở đây là hàm thuần ⇒ test được trong CI, không cần
// mạng, không cần plugin.

/// Một kênh người dùng tự thêm.
class YtChannel {
  const YtChannel({
    required this.id,
    required this.title,
    this.handle,
    this.addedAt,
  });

  /// `UC...` (24 ký tự). Đây là khoá duy nhất — mọi thứ khác chỉ để hiển thị.
  final String id;

  /// Tên hiển thị. Rỗng lúc mới thêm (chưa phân giải) ⇒ hiện `heandle`/id.
  final String title;

  /// `@handle` nếu người dùng dán handle thay vì ID (để hiện lại cho dễ nhận).
  final String? handle;

  final DateTime? addedAt;

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final h = handle?.trim();
    if (h != null && h.isNotEmpty) return h;
    return id;
  }

  YtChannel copyWith({String? title, String? handle, DateTime? addedAt}) =>
      YtChannel(
        id: id,
        title: title ?? this.title,
        handle: handle ?? this.handle,
        addedAt: addedAt ?? this.addedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (handle != null) 'handle': handle,
        if (addedAt != null) 'addedAt': addedAt!.toIso8601String(),
      };

  static YtChannel? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return null;
    return YtChannel(
      id: id,
      title: (j['title'] as String?) ?? '',
      handle: (j['handle'] as String?)?.trim(),
      addedAt: DateTime.tryParse((j['addedAt'] as String?) ?? ''),
    );
  }
}

/// Một dòng trong file OPML (`subscription_manager` của Google Takeout).
class YtOpmlChannel {
  const YtOpmlChannel({required this.title, required this.channelId});
  final String title;
  final String channelId;
}

/// Kết quả đọc ô "thêm kênh" — hoặc có ID luôn, hoặc cần phân giải handle.
class YtChannelRef {
  const YtChannelRef({this.channelId, this.handle, this.raw});

  final String? channelId;
  final String? handle;
  final String? raw;

  bool get isResolved => channelId != null;

  /// Khoá để so trùng khi người dùng thêm cùng kênh hai lần bằng hai kiểu
  /// nhập khác nhau (`@bbc` và URL `youtube.com/@bbc`).
  String get dedupeKey {
    final id = channelId;
    if (id != null) return id;
    final h = handle;
    if (h != null) return h.toLowerCase();
    return (raw ?? '').trim().toLowerCase();
  }
}

/// 24 ký tự: `UC` + 22 ký tự URL-safe của YouTube.
final RegExp _kChannelId = RegExp(r'^UC[A-Za-z0-9_-]{22}$');
final RegExp _kChannelIdInText = RegExp(r'channel[/=](UC[A-Za-z0-9_-]{22})');
final RegExp _kChannelIdJson = RegExp(r'"channelId":"(UC[A-Za-z0-9_-]{22})"');

/// Nhận diện người dùng vừa dán gì vào ô "thêm kênh".
///
/// Nhận:
///  • `UC...` (ID trần, 24 ký tự)
///  • `https://www.youtube.com/channel/UC...` (+ `/videos`, `?si=...`)
///  • `https://www.youtube.com/@handle`, `@handle`, `youtube.com/@handle`
///  • `https://www.youtube.com/c/Name`, `/user/Name` (dạng cũ)
///  • tên trơn ⇒ coi là handle (người dùng hay gõ "BBC Learning English")
///
/// Không nhận: link video (`watch?v=`) — trả `null` để UI báo "đây là link
/// video, không phải kênh" thay vì âm thầm thêm một kênh rác.
YtChannelRef? parseYtChannelInput(String input) {
  final t = input.trim();
  if (t.isEmpty) return null;

  // Link video / playlist ⇒ KHÔNG phải kênh.
  if (t.contains('watch?v=') || t.contains('youtu.be/') || t.contains('/shorts/')) {
    return null;
  }

  if (_kChannelId.hasMatch(t)) {
    return YtChannelRef(channelId: t, raw: t);
  }

  final inText = _kChannelIdInText.firstMatch(t)?.group(1);
  if (inText != null) return YtChannelRef(channelId: inText, raw: t);

  // @handle (có hoặc không có domain)
  final at = RegExp(r'@([A-Za-z0-9._-]{2,60})').firstMatch(t);
  if (at != null && (t.startsWith('@') || t.contains('youtube.com') || t.contains('youtu.be'))) {
    return YtChannelRef(handle: '@${at.group(1)}', raw: t);
  }

  // Dạng cũ /c/Name, /user/Name
  final legacy =
      RegExp(r'/(?:c|user)/([A-Za-z0-9._-]{2,60})').firstMatch(t);
  if (legacy != null) {
    return YtChannelRef(handle: legacy.group(1), raw: t);
  }

  // Chỉ một domain lạ ⇒ không đoán bừa.
  if (t.startsWith('http') || t.contains('://')) return null;

  // Tên trơn: bỏ khoảng trắng thừa, coi là handle để đi phân giải.
  final name = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return YtChannelRef(handle: name, raw: t);
}

/// Lấy ID kênh từ HTML trang kênh (đường dự phòng khi handle không đoán được).
///
/// YouTube đặt `"channelId":"UC..."` trong `ytInitialData` rất sớm; nếu layout
/// đổi, thử tiếp link canonical `youtube.com/channel/UC...`.
String? ytChannelIdFromHtml(String html) {
  if (html.isEmpty) return null;
  final json = _kChannelIdJson.firstMatch(html)?.group(1);
  if (json != null) return json;
  return _kChannelIdInText.firstMatch(html)?.group(1);
}

/// Tiêu đề kênh từ HTML (`og:title`) — để lưu danh sách mà không cần gọi thêm.
String? ytChannelTitleFromHtml(String html) {
  final m = RegExp(
    r'<meta[^>]+property="og:title"[^>]+content="([^"]+)"',
    caseSensitive: false,
  ).firstMatch(html);
  final t = m?.group(1)?.trim();
  if (t == null || t.isEmpty) return null;
  // YouTube hay thêm đuôi " - YouTube".
  return t.endsWith(' - YouTube') ? t.substring(0, t.length - 10).trim() : t;
}

/// Đọc file OPML xuất từ Google Takeout (`subscription_manager.opml`).
///
/// Chỉ lấy entry YouTube. ID kênh lấy từ `xmlUrl=...channel_id=UC...` (định
/// dạng chuẩn của Takeout); entry không có ID thì bỏ — KHÔNG đoán.
List<YtOpmlChannel> parseYtOpml(String xml) {
  if (xml.trim().isEmpty) return const [];
  final out = <YtOpmlChannel>[];
  final seen = <String>{};

  // Không dùng XML parser: file Takeout có thể rất lớn (hàng nghìn kênh) và
  // ta chỉ cần hai thuộc tính trên thẻ `<outline>`. Regex ở đây an toàn vì
  // thuộc tính luôn nằm trong một thẻ, không lồng nhau.
  final outline = RegExp(r'<outline\b[^>]*>', caseSensitive: false);
  for (final m in outline.allMatches(xml)) {
    final tag = m.group(0)!;
    final id = RegExp(r'channel_id=(UC[A-Za-z0-9_-]{22})')
        .firstMatch(tag)
        ?.group(1);
    if (id == null) continue;
    if (!seen.add(id)) continue;

    final title = RegExp(r'(?:text|title)="([^"]*)"', caseSensitive: false)
            .firstMatch(tag)
            ?.group(1) ??
        '';
    out.add(YtOpmlChannel(
      title: _unescapeXml(title).trim(),
      channelId: id,
    ));
  }
  return out;
}

String _unescapeXml(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'");
