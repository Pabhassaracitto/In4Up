// Đợt B (2026-11-09) — YT1-05/06/08/09/10 + phần kéo theo.
//
// Test HÀNH VI cho phần logic thuần (cache, TTL, continuation, model cài đặt)
// và test DÂY NỐI cho phần UI (màn hình cần Flutter runtime). Cố tình không
// viết thêm test `source.contains(...)` cho những gì đã có test hành vi —
// xem YT1-15 trong `docs/Bangiao/khao_sat_youtube_tang1_2026_11_09.md`.
//
// Bối cảnh: 8/11 lỗi tầng 1 của Đợt A đã xong. Đợt B sửa nhóm "người dùng
// không biết chuyện gì đang xảy ra": mất mạng = màn trống, không cache, thẻ
// video không nói đã tải hay chưa, bộ lọc mất khi thoát.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/models/yt_learning_settings.dart';
import 'package:in4up/features/youtube/services/yt_explorer_cache.dart';
import 'package:in4up/features/youtube/services/yt_initial_data_parser.dart';
import 'package:in4up/features/youtube/services/yt_search_service.dart';

/// Trang kế của một kênh, rút gọn còn đúng cấu trúc YouTube trả về.
const _continuationJson = '''
{
  "onResponseReceivedActions": [
    {
      "appendContinuationItemsAction": {
        "continuationItems": [
          {
            "richItemRenderer": {
              "content": {
                "videoRenderer": {
                  "videoId": "abcdefghijk",
                  "title": {"runs": [{"text": "Video trang 2"}]},
                  "ownerText": {
                    "runs": [
                      {
                        "text": "Kênh thử",
                        "navigationEndpoint": {
                          "browseEndpoint": {"browseId": "UCabcdefghijklmnopqrstuv"}
                        }
                      }
                    ]
                  },
                  "lengthText": {"simpleText": "12:34"},
                  "viewCountText": {"simpleText": "1,234 views"},
                  "publishedTimeText": {"simpleText": "2 days ago"}
                }
              }
            }
          },
          {
            "continuationItemRenderer": {
              "continuationEndpoint": {
                "continuationCommand": {"token": "TOKEN-TRANG-3"}
              }
            }
          }
        ]
      }
    }
  ]
}
''';

void main() {
  group('YT1-06 — cache có TTL, có dung lượng, đọc/ghi được', () {
    test('TTL đúng chốt của owner: tìm kiếm 24 giờ, kênh 3 ngày', () {
      expect(YtExplorerCache.ttl[YtCacheKind.search], const Duration(hours: 24));
      expect(YtExplorerCache.ttl[YtCacheKind.channel], const Duration(days: 3));
    });

    test('entry sống lại đúng sau JSON (không mất videoId/tiêu đề)', () {
      final hits = [
        const YtSearchHit(
          id: 'vid00000001',
          title: 'Bài học 1',
          channel: 'Kênh A',
          channelId: 'UCaaaaaaaaaaaaaaaaaaaaaa',
          duration: Duration(minutes: 12, seconds: 34),
          viewCount: 1234,
        ),
      ];
      final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final json = YtCacheEntry(hits: hits, savedAt: at).toJson();
      // Đi qua `jsonEncode/decode` như thật, không chỉ Map→Map.
      final back = YtCacheEntry.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(back, isNotNull);
      expect(back!.savedAt, at);
      expect(back.hits.single.id, 'vid00000001');
      expect(back.hits.single.title, 'Bài học 1');
      expect(back.hits.single.duration, const Duration(minutes: 12, seconds: 34));
      expect(back.hits.single.viewCount, 1234);
    });

    test('entry hỏng (thiếu mốc thời gian) ⇒ null, KHÔNG ném', () {
      expect(YtCacheEntry.fromJson({'items': []}), isNull);
      expect(YtCacheEntry.fromJson({'t': 'hỏng'}), isNull);
    });

    test('bản quá TTL bị coi là hết hạn nhưng VẪN đọc được (hiện tạm)', () {
      final old = YtCacheEntry(
        hits: [
          const YtSearchHit(
              id: 'x', title: 't', channel: 'c', channelId: ''),
        ],
        savedAt: DateTime.now().subtract(const Duration(days: 4)),
      );
      expect(YtExplorerCache.expired(YtCacheKind.channel, old), isTrue);
      expect(YtExplorerCache.expired(YtCacheKind.search, old), isTrue);
      expect(old.hits, isNotEmpty,
          reason: 'hết hạn chỉ là "nên làm mới", không phải "xoá"');
    });
  });

  group('YT1-05 — phân biệt lỗi với rỗng', () {
    test('YtFetchResult: ok khi có video, failed chỉ khi lỗi thật', () {
      const hit = YtSearchHit(
          id: 'a', title: 't', channel: 'c', channelId: 'd');
      const ok = YtFetchResult.ok([hit]);
      expect(ok.ok, isTrue);
      expect(ok.failed, isFalse);
      expect(ok.failure, YtFetchFailure.none);

      const empty = YtFetchResult(<YtSearchHit>[], YtFetchFailure.empty);
      // "Rỗng" KHÔNG phải lỗi: không được hiện nút Thử lại như thể mạng hỏng.
      expect(empty.ok, isFalse);
      expect(empty.failed, isFalse);

      for (final f in [
        YtFetchFailure.network,
        YtFetchFailure.blocked,
        YtFetchFailure.parseFailed,
      ]) {
        expect(YtFetchResult(const <YtSearchHit>[], f).failed, isTrue);
      }
    });
  });

  group('YT1-07 — phân trang bằng continuation token', () {
    test('đọc được video + token trang kế', () {
      final parsed = parseContinuationResponse(
        jsonDecode(_continuationJson),
        now: DateTime(2026, 11, 9),
      );
      expect(parsed.hits, hasLength(1));
      expect(parsed.hits.single.id, 'abcdefghijk');
      expect(parsed.hits.single.channel, 'Kênh thử');
      expect(parsed.next, 'TOKEN-TRANG-3');
    });

    test('trang cuối (không có token) ⇒ next = null', () {
      final parsed = parseContinuationResponse({
        'onResponseReceivedActions': [
          {
            'appendContinuationItemsAction': {
              'continuationItems': [
                {
                  'videoRenderer': {
                    'videoId': 'lastvideo01',
                    'title': {'runs': [{'text': 'Cuối'}]},
                  }
                }
              ]
            }
          }
        ]
      });
      expect(parsed.hits, hasLength(1));
      expect(parsed.next, isNull);
    });

    test('phản hồi rác không làm ném', () {
      expect(parseContinuationResponse(null).hits, isEmpty);
      expect(parseContinuationResponse('chuỗi').hits, isEmpty);
      expect(parseContinuationResponse(<String, dynamic>{}).next, isNull);
    });

    test('lấy token + INNERTUBE_API_KEY từ HTML trang kênh', () {
      const html = '<script>var ytInitialData = '
          '{"contents":{"x":{"continuationCommand":{"token":"FROM-HTML"}}}};'
          '</script>'
          '<script>"INNERTUBE_API_KEY":"AIza-test-key"</script>';
      expect(extractContinuationTokenFromHtml(html), 'FROM-HTML');
      expect(extractInnertubeApiKey(html), 'AIza-test-key');
      // Trang không có gì ⇒ null, không ném.
      expect(extractContinuationTokenFromHtml('<html></html>'), isNull);
      expect(extractInnertubeApiKey('<html></html>'), isNull);
    });
  });

  group('YT1-09 / YT1-10 — cài đặt dung lượng mới', () {
    test('mặc định: HIỆN dung lượng file và HIỆN dung lượng cache', () {
      const s = YtLearningSettings();
      expect(s.hideMediaSize, isFalse,
          reason: 'owner: người dùng phải biết file chiếm bao nhiêu');
      expect(s.showCacheSize, isTrue,
          reason: 'owner: cache mặc định hiện, có thể ẩn');
    });

    test('dữ liệu cũ (chưa có 2 khoá) ⇒ đúng mặc định, không crash', () {
      final s = YtLearningSettings.fromJson({'subtitleLang': 'en'});
      expect(s.hideMediaSize, isFalse);
      expect(s.showCacheSize, isTrue);
    });

    test('toJson → fromJson giữ nguyên 2 cờ', () {
      const s = YtLearningSettings(hideMediaSize: true, showCacheSize: false);
      final back = YtLearningSettings.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(back.hideMediaSize, isTrue);
      expect(back.showCacheSize, isFalse);
    });

    test('copyWith đổi 2 cờ mà KHÔNG reset cài đặt đọc thành tiếng', () {
      const s = YtLearningSettings(
        readAloudSyncVideo: true,
        readAloudPasses: 0,
        saveLocation: YtSaveLocation.externalDownloads,
      );
      final n = s.copyWith(hideMediaSize: true);
      expect(n.hideMediaSize, isTrue);
      expect(n.readAloudSyncVideo, isTrue);
      expect(n.readAloudPasses, 0);
      expect(n.saveLocation, YtSaveLocation.externalDownloads);
      expect(n.showCacheSize, isTrue);
    });
  });

  group('Dây nối UI — không được tái phát lỗi cũ', () {
    late String explorer;
    late String sheet;
    late String media;
    late String settingsModel;

    setUpAll(() {
      explorer = File('lib/features/youtube/youtube_explorer_screen.dart')
          .readAsStringSync();
      sheet = File(
              'lib/features/youtube/widgets/yt_subtitle_settings_sheet.dart')
          .readAsStringSync();
      media = File('lib/features/youtube/widgets/yt_media_library_sheet.dart')
          .readAsStringSync();
      settingsModel =
          File('lib/features/youtube/models/yt_learning_settings.dart')
              .readAsStringSync();
    });

    test('danh sách kênh gợi ý đang TRỐNG (owner chưa duyệt danh sách)', () {
      // Không kênh `UC…` nào được hard-code trở lại.
      expect(RegExp(r'UC[A-Za-z0-9_-]{20,}').hasMatch(explorer), isFalse,
          reason: 'kênh gợi ý cũ là kênh cá nhân — owner sẽ đưa danh sách sau');
      expect(
        explorer.contains(
            'const List<(String, String)> kYtRecommendedChannels = <(String, String)>[];'),
        isTrue,
      );
    });

    test('Explorer dùng bản có KIỂU và nói ra lý do trống', () {
      expect(explorer.contains('searchVideosResult('), isTrue);
      expect(explorer.contains('fetchChannelVideosResult('), isTrue);
      expect(explorer.contains('YtFetchFailure.blocked'), isTrue);
      expect(explorer.contains('YtFetchFailure.parseFailed'), isTrue);
      expect(explorer.contains('_loadVideos(forceRefresh: true)'), isTrue);
    });

    test('Explorer ghi/đọc cache + nhớ lựa chọn + phân trang', () {
      expect(explorer.contains('YtExplorerCache.instance'), isTrue);
      expect(explorer.contains('YtExplorerPrefs.instance'), isTrue);
      expect(explorer.contains('fetchMoreResult('), isTrue);
      expect(explorer.contains("'Tải thêm'"), isTrue);
    });

    test('mọi ảnh thumbnail khai báo cacheWidth (không decode full-size)',
        () {
      final calls = RegExp(r'Image\.network\(').allMatches(explorer).length;
      final widths = RegExp(r'cacheWidth:').allMatches(explorer).length;
      expect(calls, greaterThan(0));
      expect(widths, calls,
          reason: 'mỗi Image.network phải có cacheWidth tương ứng');
    });

    test('sheet Cài đặt dựng lại bằng copyWith, không tạo mới', () {
      expect(sheet.contains('widget.initial.copyWith('), isTrue);
      expect(
        RegExp(r'Navigator\.pop\(\s*context,\s*YtLearningSettings\(')
            .hasMatch(sheet),
        isFalse,
        reason: 'dựng mới ⇒ reset readAloud*/saveLocation mỗi lần bấm Xong',
      );
      expect(sheet.contains('hideMediaSize'), isTrue);
      expect(sheet.contains('showCacheSize'), isTrue);
    });

    test('thư viện media tôn trọng cờ ẩn dung lượng', () {
      expect(media.contains('hideMediaSize'), isTrue);
      expect(media.contains('_hideSize'), isTrue);
    });

    test('model có 2 field mới ở cả toJson và fromJson', () {
      expect(settingsModel.contains("'hideMediaSize': hideMediaSize"), isTrue);
      expect(settingsModel.contains("'showCacheSize': showCacheSize"), isTrue);
      expect(settingsModel.contains("json['hideMediaSize'] as bool? ?? false"),
          isTrue);
      expect(settingsModel.contains("json['showCacheSize'] as bool? ?? true"),
          isTrue);
    });

    test('i18n: khoá mới có đủ 5 ngôn ngữ ưu tiên', () {
      final catalog =
          File('lib/core/language/priority_ui_overrides.dart').readAsStringSync();
      for (final key in [
        'Thử lại',
        'Làm mới',
        'Tải thêm',
        'Bộ nhớ & dữ liệu',
        'Hiện dung lượng bộ nhớ đệm',
        'Xoá bộ nhớ đệm',
        'Chưa có kênh nào. Thêm @handle, dán link kênh hoặc import OPML.',
      ]) {
        expect(catalog.contains("'$key':"), isTrue, reason: 'thiếu khoá $key');
      }
    });
  });
}
