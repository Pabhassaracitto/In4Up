// Test cho đợt 7 (2026-10-28) — hai tính năng owner chốt:
//
//   #1 YT-MY-CHANNELS-001  — "Kênh của tôi" bằng @handle/link + import OPML
//                            (KHÔNG đăng nhập YouTube — không khả thi + ToS)
//   #4 YT-PREPARE-001      — tab Tải thành kế hoạch "Tải & chuẩn bị" có lựa
//                            chọn: tải gì / đồng bộ tab Đọc / lưu đám mây
//
// Toàn bộ là logic THUẦN (không plugin, không mạng) nên chạy được trong CI —
// đúng lý do các hàm đọc chuỗi được tách ra khỏi UI.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/models/yt_channel.dart';
import 'package:in4up/features/youtube/services/yt_prepare_plan.dart';

void main() {
  group('#1 parseYtChannelInput — người dùng dán gì cũng hiểu', () {
    test('ID trần UC… 24 ký tự', () {
      const id = 'UCVd9ExaFGD8VEmWDKDCMa2Q';
      final r = parseYtChannelInput(id)!;
      expect(r.channelId, id);
      expect(r.isResolved, isTrue);
    });

    test('link /channel/UC… (kèm /videos và tham số) ⇒ ra ID', () {
      const id = 'UCVd9ExaFGD8VEmWDKDCMa2Q';
      expect(
        parseYtChannelInput('https://www.youtube.com/channel/$id/videos')!
            .channelId,
        id,
      );
      expect(
        parseYtChannelInput('https://www.youtube.com/channel/$id?si=abc123')!
            .channelId,
        id,
      );
    });

    test('@handle và link @handle ⇒ cùng một handle', () {
      expect(parseYtChannelInput('@bbclearningenglish')!.handle,
          '@bbclearningenglish');
      expect(
        parseYtChannelInput('https://www.youtube.com/@bbclearningenglish')!
            .handle,
        '@bbclearningenglish',
      );
      // Cùng một handle nhập hai kiểu ⇒ cùng dedupeKey (để không thêm trùng).
      expect(
        parseYtChannelInput('@bbclearningenglish')!.dedupeKey,
        parseYtChannelInput(
                'https://www.youtube.com/@bbclearningenglish')!
            .dedupeKey,
      );
    });

    test('dạng cũ /c/ và /user/', () {
      expect(parseYtChannelInput('https://www.youtube.com/c/PewDiePie')!.handle,
          'PewDiePie');
      expect(
        parseYtChannelInput('https://www.youtube.com/user/SomeUser')!.handle,
        'SomeUser',
      );
    });

    test('tên trơn ⇒ coi là handle (người dùng hay gõ tên kênh)', () {
      expect(parseYtChannelInput('BBC Learning English')!.handle,
          'BBC Learning English');
    });

    test('link VIDEO ⇒ null (không được thêm kênh rác)', () {
      expect(parseYtChannelInput('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
          isNull);
      expect(parseYtChannelInput('https://youtu.be/dQw4w9WgXcQ'), isNull);
      expect(
        parseYtChannelInput('https://youtube.com/shorts/dQw4w9WgXcQ'),
        isNull,
      );
    });

    test('domain lạ / rỗng ⇒ null', () {
      expect(parseYtChannelInput('https://vimeo.com/foo'), isNull);
      expect(parseYtChannelInput('   '), isNull);
    });
  });

  group('#1 đọc HTML trang kênh', () {
    test('lấy channelId từ ytInitialData', () {
      const html = '<script>var ytInitialData={"a":1,"channelId":'
          '"UCVd9ExaFGD8VEmWDKDCMa2Q","b":2}</script>';
      expect(ytChannelIdFromHtml(html), 'UCVd9ExaFGD8VEmWDKDCMa2Q');
    });

    test('dự phòng: link canonical /channel/UC…', () {
      const html = '<link rel="canonical" '
          'href="https://www.youtube.com/channel/UCVd9ExaFGD8VEmWDKDCMa2Q">';
      expect(ytChannelIdFromHtml(html), 'UCVd9ExaFGD8VEmWDKDCMa2Q');
    });

    test('HTML rỗng/không có ⇒ null (không đoán bừa)', () {
      expect(ytChannelIdFromHtml(''), isNull);
      expect(ytChannelIdFromHtml('<html>Nothing here</html>'), isNull);
    });

    test('tiêu đề og:title bỏ đuôi " - YouTube"', () {
      const html = '<meta property="og:title" content="BBC Learning English '
          '- YouTube">';
      expect(ytChannelTitleFromHtml(html), 'BBC Learning English');
    });
  });

  group('#1 đọc OPML (Google Takeout)', () {
    const opml = '''
<?xml version="1.0" encoding="UTF-8"?>
<opml version="1.1">
  <body>
    <outline text="YouTube" title="YouTube">
      <outline text="BBC Learning English"
               xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCHaHD477h-FeBbVh9Sh7syA" />
      <outline text="Rachel &amp; English"
               xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCVd9ExaFGD8VEmWDKDCMa2Q" />
      <outline text="Some Blog" xmlUrl="https://example.com/feed.xml" />
    </outline>
  </body>
</opml>''';

    test('chỉ lấy kênh YouTube, bỏ feed khác', () {
      final list = parseYtOpml(opml);
      expect(list.length, 2);
      expect(list.map((c) => c.channelId),
          containsAll(['UCHaHD477h-FeBbVh9Sh7syA', 'UCVd9ExaFGD8VEmWDKDCMa2Q']));
    });

    test('giải mã ký tự XML trong tên kênh', () {
      final list = parseYtOpml(opml);
      final rachel =
          list.firstWhere((c) => c.channelId == 'UCVd9ExaFGD8VEmWDKDCMa2Q');
      expect(rachel.title, 'Rachel & English');
    });

    test('kênh trùng ID chỉ lấy một lần', () {
      const dup = '''
<opml><body>
<outline text="A" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCVd9ExaFGD8VEmWDKDCMa2Q" />
<outline text="A lần nữa" xmlUrl="https://www.youtube.com/feeds/videos.xml?channel_id=UCVd9ExaFGD8VEmWDKDCMa2Q" />
</body></opml>''';
      expect(parseYtOpml(dup).length, 1);
    });

    test('file rỗng / không có thẻ outline ⇒ danh sách rỗng, không crash', () {
      expect(parseYtOpml(''), isEmpty);
      expect(parseYtOpml('<opml><body></body></opml>'), isEmpty);
    });
  });

  group('#1 YtChannel — JSON khứ hồi', () {
    test('giữ id/title/handle/addedAt', () {
      final c = YtChannel(
        id: 'UCVd9ExaFGD8VEmWDKDCMa2Q',
        title: 'Rachel',
        handle: '@rachel',
        addedAt: DateTime.utc(2026, 10, 28),
      );
      final back = YtChannel.fromJson(c.toJson())!;
      expect(back.id, c.id);
      expect(back.title, c.title);
      expect(back.handle, c.handle);
      expect(back.addedAt, c.addedAt);
    });

    test('thiếu id ⇒ null (không tạo kênh rác)', () {
      expect(YtChannel.fromJson(const {}), isNull);
      expect(YtChannel.fromJson(const {'id': '  '}), isNull);
    });

    test('tên trống ⇒ hiện handle rồi mới tới id', () {
      const a = YtChannel(id: 'UCx', title: '', handle: '@abc');
      expect(a.displayTitle, '@abc');
      const b = YtChannel(id: 'UCx', title: '');
      expect(b.displayTitle, 'UCx');
    });
  });

  group('#4 buildYtPreparePlan — bỏ qua việc đã xong, nói rõ việc bị bỏ', () {
    test('máy trắng + chọn cả hai ⇒ tải phụ đề TRƯỚC âm thanh', () {
      final p = buildYtPreparePlan(
        hasCaptions: false,
        hasAudio: false,
        wantCaptions: true,
        wantAudio: true,
        wantSyncRead: false,
        wantCloudCopy: false,
      );
      expect(p.steps, [
        YtPrepareStep.downloadCaptions,
        YtPrepareStep.downloadAudio,
      ]);
      expect(p.nothingToDo, isFalse);
      expect(p.alreadyComplete, isFalse);
    });

    test('đã có phụ đề ⇒ KHÔNG tải lại, và nói rõ lý do', () {
      final p = buildYtPreparePlan(
        hasCaptions: true,
        hasAudio: false,
        wantCaptions: true,
        wantAudio: true,
        wantSyncRead: false,
        wantCloudCopy: false,
      );
      expect(p.steps, [YtPrepareStep.downloadAudio]);
      expect(p.notes, contains('captions_already_saved'));
    });

    test('đã có đủ cả hai + không chọn gì thêm ⇒ không có việc nào', () {
      final p = buildYtPreparePlan(
        hasCaptions: true,
        hasAudio: true,
        wantCaptions: true,
        wantAudio: true,
        wantSyncRead: false,
        wantCloudCopy: false,
      );
      expect(p.nothingToDo, isTrue);
      expect(p.alreadyComplete, isTrue);
    });

    test('đồng bộ tab Đọc mà CHƯA có phụ đề ⇒ báo thiếu, không nạp rỗng', () {
      final p = buildYtPreparePlan(
        hasCaptions: false,
        hasAudio: false,
        wantCaptions: false,
        wantAudio: false,
        wantSyncRead: true,
        wantCloudCopy: false,
      );
      expect(p.steps, isEmpty);
      expect(p.notes, contains('sync_needs_captions'));
    });

    test('đồng bộ tab Đọc khi SẼ tải phụ đề ⇒ xếp sau bước tải', () {
      final p = buildYtPreparePlan(
        hasCaptions: false,
        hasAudio: false,
        wantCaptions: true,
        wantAudio: false,
        wantSyncRead: true,
        wantCloudCopy: false,
      );
      expect(p.steps, [YtPrepareStep.downloadCaptions, YtPrepareStep.syncRead]);
    });

    test('lưu đám mây khi đã lưu đúng bản ⇒ không đẩy bản trùng', () {
      final p = buildYtPreparePlan(
        hasCaptions: true,
        hasAudio: false,
        wantCaptions: true,
        wantAudio: false,
        wantSyncRead: false,
        wantCloudCopy: true,
        cloudUpToDate: true,
      );
      expect(p.steps, isEmpty);
      expect(p.notes, contains('cloud_up_to_date'));
    });

    test('lưu đám mây nhưng chưa đăng nhập/không có phụ đề ⇒ báo thiếu', () {
      final p = buildYtPreparePlan(
        hasCaptions: false,
        hasAudio: true,
        wantCaptions: false,
        wantAudio: false,
        wantSyncRead: false,
        wantCloudCopy: true,
      );
      expect(p.steps, isEmpty);
      expect(p.notes, contains('cloud_needs_captions'));
    });

    test('đủ cả 4 lựa chọn ⇒ thứ tự tải → đồng bộ → đám mây', () {
      final p = buildYtPreparePlan(
        hasCaptions: true,
        hasAudio: false,
        wantCaptions: true,
        wantAudio: true,
        wantSyncRead: true,
        wantCloudCopy: true,
      );
      expect(p.steps, [
        YtPrepareStep.downloadAudio,
        YtPrepareStep.syncRead,
        YtPrepareStep.cloudCopy,
      ]);
    });
  });

  group('#4 ytPlainTextFromLrc — lưu đám mây không kèm mốc thời gian', () {
    test('bỏ [mm:ss.cc] và metadata, giữ nội dung từng dòng', () {
      const lrc = '[ti:My video]\n'
          '[ar:Channel]\n'
          '[00:01.00]Hello there\n'
          '[00:03.45]How are you?\n';
      expect(ytPlainTextFromLrc(lrc), 'Hello there\nHow are you?');
    });

    test('nhiều mốc trên một dòng (karaoke) ⇒ bỏ hết mốc', () {
      const lrc = '[00:01.00][00:02.00]Same line\n';
      expect(ytPlainTextFromLrc(lrc), 'Same line');
    });

    test('dòng trống và khoảng trắng thừa bị bỏ', () {
      const lrc = '[00:01.00]A\n\n   \n[00:02.00]  B  \n';
      expect(ytPlainTextFromLrc(lrc), 'A\nB');
    });

    test('chuỗi rỗng ⇒ rỗng', () {
      expect(ytPlainTextFromLrc(''), '');
    });
  });
}
