// PSRC-211 — NGHIỆM THU: bong bóng dịch KHÔNG bỏ sót khối và nằm ĐÚNG CHỖ.
//
// Audit v1.28.0 (owner): "bong bóng dịch bỏ sót nhiều khối nội dung, bản dịch
// hiển thị sai vị trí; khung bản dịch đang thừa khoảng trống bên dưới — cần
// thu gọn, ôm sát nội dung để đủ chỗ hiển thị các khối dịch liền kề".
//
// File này chạy NGUYÊN pipeline phía Dart (OCR giả → controller → dịch giả →
// layout) trên một màn hình cỡ THẬT (1080×2400 @2.75, ảnh chụp 540×1200 như
// native downscale) và đo đúng ba tiêu chí của phiếu L4:
//   1. Màn hình ≥ 8 khối chữ ⇒ đủ ngần ấy bong bóng.
//   2. Mỗi bong bóng lệch khỏi khối gốc của nó ≤ 4dp (11px @2.75) — kể cả khi
//      nội dung đã cuộn (khối nằm ở toạ độ bất kỳ, sát mép màn hình).
//   3. Hai khối sát nhau ⇒ không bong bóng nào đè lên nhau.
//
// CỐ Ý chỉ dùng API đã có từ trước PSRC-211 (controller, `ScreenBlock`,
// `countOverlappingPairs`): chính file này chạy trên code CŨ là bản TÁI HIỆN
// lỗi (đỏ), chạy trên code mới là bằng chứng đã sửa (xanh). Test cho các hàm
// mới nằm ở `screen_translate_text_flow_test.dart`.
//
// Các test controller cũ không bắt được lỗi này vì chúng dùng frame vài pixel
// (màn < 200px ⇒ layout bị bỏ qua) và khối OCR một dòng.
//
// THUẦN host VM — không cần thiết bị / MediaProjection.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/ocr/ocr_block.dart';
import 'package:in4up/features/ocr/ocr_service.dart';
import 'package:in4up/features/screen_translate/screen_translate_controller.dart';
import 'package:in4up/features/screen_translate/screen_translate_geometry.dart';
import 'package:in4up/features/screen_translate/screen_translate_models.dart';
import 'package:in4up/features/screen_translate/screen_translate_overlay_layout.dart';
import 'package:in4up/features/translation/engines/translation_engine.dart';

const double _dpr = 2.75; // Pixel 7 kiểu
const int _screenW = 1080;
const int _screenH = 2400;

/// Native downscale ảnh chụp (`MAX_CAPTURE_EDGE`): OCR chạy trên 540×1200, toạ
/// độ phải được nhân lại ×2 để ra pixel màn hình.
const int _captureScale = 2;

/// Sai lệch vị trí cho phép: ~4dp (phiếu L4) = 11px ở mật độ 2.75.
const int _maxDeltaPx = 11;

/// Một khối chữ GỐC, toạ độ PIXEL MÀN HÌNH (số chẵn để chia 2 không lẻ).
class _Src {
  const _Src(this.left, this.top, this.right, this.bottom, this.text);

  final int left;
  final int top;
  final int right;
  final int bottom;

  /// Chữ như ML Kit trả: các dòng của khối nối bằng `\n`.
  final String text;

  int get lineCount => text.split('\n').length;

  /// Chiều cao trung bình một dòng chữ gốc (px màn hình).
  double get lineHeightPx => (bottom - top) / lineCount;

  _Src shifted(int dy) => _Src(left, top + dy, right, bottom + dy, text);

  OcrBlock toOcr() => OcrBlock(
        text: text,
        rect: OcrBlockRect(
          left: left ~/ _captureScale,
          top: top ~/ _captureScale,
          right: right ~/ _captureScale,
          bottom: bottom ~/ _captureScale,
        ),
      );

  @override
  String toString() => '"${text.split('\n').first}…" @($left,$top)';
}

/// Màn hình "bài viết hướng dẫn": tiêu đề, đoạn văn nhiều dòng, đề mục, hai
/// nút cạnh nhau — 10 khối. Chữ thân bài ~14sp (dòng cách dòng ~54px), đoạn
/// cách đoạn ~1 dòng, đúng như một trang đọc thông thường.
const List<_Src> _article = <_Src>[
  _Src(44, 240, 900, 302, 'Getting started with offline reading'),
  _Src(
    44,
    360,
    1036,
    562,
    'Download a language pack once and the app keeps\n'
        'working without a connection. Translations, the\n'
        'dictionary and text to speech all run on your\n'
        'phone, so nothing you read ever leaves the device.',
  ),
  _Src(
    44,
    616,
    1036,
    764,
    'Packs are large, so we recommend downloading\n'
        'them over Wi-Fi. You can pause a download at\n'
        'any time and resume it later.',
  ),
  _Src(44, 840, 640, 890, 'Choose a language pack'),
  _Src(
    44,
    940,
    1036,
    1196,
    'Each pack contains the translation model for one\n'
        'language pair. If you read in English and want\n'
        'translations in Vietnamese, a single pack is enough.\n'
        'Add more packs whenever you start reading in\n'
        'another language.',
  ),
  _Src(
    44,
    1250,
    1036,
    1344,
    'Downloaded packs are listed in Settings, where\n'
        'you can also remove the ones you no longer need.',
  ),
  _Src(44, 1420, 520, 1470, 'Before you travel'),
  _Src(
    44,
    1520,
    1036,
    1668,
    'Open the app once while you are still online so\n'
        'it can check that every pack is complete, then\n'
        'switch on airplane mode to test it.',
  ),
  _Src(120, 1780, 440, 1826, 'Download now'),
  _Src(640, 1780, 930, 1826, 'Maybe later'),
];

/// Danh sách cài đặt DÀY: 8 hàng một dòng, hàng cách hàng chỉ 16px.
const List<String> _settingsLabels = <String>[
  'Language packs',
  'Reading history',
  'Notifications and sounds',
  'Privacy and security',
  'Help and feedback',
  'About this application',
  'Storage and downloaded data',
  'Display and text size',
];

List<_Src> _tightList() => <_Src>[
      for (var i = 0; i < _settingsLabels.length; i++)
        _Src(
          60,
          300 + i * 60,
          60 + _settingsLabels[i].length * 22,
          344 + i * 60,
          _settingsLabels[i],
        ),
    ];

/// Bản dịch tiếng Việt THẬT của từng khối (dài hơn bản gốc ~1.1–1.3×).
const Map<String, String> _vi = <String, String>{
  'Getting started with offline reading': 'Bắt đầu với chế độ đọc ngoại tuyến',
  'Download a language pack once and the app keeps working without a '
          'connection. Translations, the dictionary and text to speech all '
          'run on your phone, so nothing you read ever leaves the device.':
      'Tải gói ngôn ngữ một lần và ứng dụng vẫn hoạt động khi không có kết '
          'nối. Bản dịch, từ điển và chuyển văn bản thành giọng nói đều chạy '
          'trên điện thoại của bạn, nên những gì bạn đọc không bao giờ rời '
          'khỏi thiết bị.',
  'Packs are large, so we recommend downloading them over Wi-Fi. You can '
          'pause a download at any time and resume it later.':
      'Các gói có dung lượng lớn, vì vậy chúng tôi khuyên bạn nên tải chúng '
          'qua Wi-Fi. Bạn có thể tạm dừng tải xuống bất cứ lúc nào và tiếp '
          'tục sau.',
  'Choose a language pack': 'Chọn một gói ngôn ngữ',
  'Each pack contains the translation model for one language pair. If you '
          'read in English and want translations in Vietnamese, a single '
          'pack is enough. Add more packs whenever you start reading in '
          'another language.':
      'Mỗi gói chứa mô hình dịch cho một cặp ngôn ngữ. Nếu bạn đọc bằng '
          'tiếng Anh và muốn có bản dịch tiếng Việt thì một gói là đủ. Hãy '
          'thêm gói khác mỗi khi bạn bắt đầu đọc bằng một ngôn ngữ khác.',
  'Downloaded packs are listed in Settings, where you can also remove the '
          'ones you no longer need.':
      'Các gói đã tải được liệt kê trong Cài đặt, nơi bạn cũng có thể xoá '
          'những gói không còn cần nữa.',
  'Before you travel': 'Trước khi bạn đi xa',
  'Open the app once while you are still online so it can check that every '
          'pack is complete, then switch on airplane mode to test it.':
      'Mở ứng dụng một lần khi bạn vẫn còn trực tuyến để nó kiểm tra rằng '
          'mọi gói đã đầy đủ, sau đó bật chế độ máy bay để thử.',
  'Download now': 'Tải xuống ngay',
  'Maybe later': 'Để sau',
  'Language packs': 'Gói ngôn ngữ',
  'Reading history': 'Lịch sử đọc',
  'Notifications and sounds': 'Thông báo và âm thanh',
  'Privacy and security': 'Quyền riêng tư và bảo mật',
  'Help and feedback': 'Trợ giúp và phản hồi',
  'About this application': 'Giới thiệu về ứng dụng này',
  'Storage and downloaded data': 'Bộ nhớ và dữ liệu đã tải',
  'Display and text size': 'Hiển thị và cỡ chữ',
};

/// Bỏ xuống dòng của OCR để tra bảng (engine thật cũng đọc cả câu).
String _flat(String text) => text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

/// Engine giả trả MỘT đoạn liền (không giữ `\n`). Câu không có trong bảng
/// (vd. code cũ gửi từng dòng cụt) ⇒ kéo dài ~1.3× như EN→VI.
String _translate(String text) {
  final key = _flat(text);
  final known = _vi[key];
  if (known != null) return known;
  final words = key.split(' ');
  final extra = words.take((words.length * 0.3).ceil()).join(' ');
  return '$key $extra';
}

/// Engine giả GIỮ số dòng của đầu vào (nhiều engine trả lại đúng các `\n` nó
/// nhận): chia bản dịch thành ngần ấy dòng.
String _translateKeepingLines(String text) {
  final whole = _translate(text);
  final lineCount = text.split('\n').length;
  if (lineCount <= 1) return whole;
  final words = whole.split(' ');
  final perLine = (words.length / lineCount).ceil();
  final lines = <String>[];
  for (var i = 0; i < words.length; i += perLine) {
    final end = i + perLine > words.length ? words.length : i + perLine;
    lines.add(words.sublist(i, end).join(' '));
  }
  return lines.join('\n');
}

/// Chạy một lượt dịch màn hình đầy đủ qua controller.
Future<ScreenTranslateResult> _run(
  List<_Src> screen, {
  String Function(String text) translate = _translate,
  double fontScale = 1.0,
  List<String>? seen,
}) {
  final controller = ScreenTranslateController(
    localeCode: 'en',
    ocrRunner: ({
      required Uint8List pixels,
      required int width,
      required int height,
    }) async =>
        OcrBlocksResult(
      blocks: <OcrBlock>[for (final src in screen) src.toOcr()],
    ),
    translator: (text, target) async {
      seen?.add(text);
      return TranslationResult.success(
        original: text,
        translated: translate(text),
        engine: 'fake-engine',
      );
    },
  );
  const captureW = _screenW ~/ _captureScale;
  const captureH = _screenH ~/ _captureScale;
  return controller.handleFrame(<Object?, Object?>{
    'pixels': Uint8List(captureW * captureH * 4),
    'width': captureW,
    'height': captureH,
    'rowStride': captureW * 4,
    'screenWidth': _screenW,
    'screenHeight': _screenH,
    'devicePixelRatio': _dpr,
    'fontScale': fontScale,
    'targetLanguage': 'VI',
    'locale': 'en',
  });
}

String _describe(Iterable<ScreenBlock> blocks) => blocks
    .map((b) => '(${b.rect.left},${b.rect.top})-(${b.rect.right},'
        '${b.rect.bottom}) ${b.textSizeSp.toStringAsFixed(1)}sp')
    .join('; ');

/// Ba tiêu chí nghiệm thu của phiếu L4 trên một màn hình.
void _expectEveryBlockInPlace(
  List<_Src> screen,
  ScreenTranslateResult result, {
  String label = '',
}) {
  expect(result.status, ScreenTranslateStatus.ok, reason: label);
  final drawn = result.blocks.where((b) => b.hasTranslation).toList();

  // (1) Không bỏ sót: mỗi khối gốc một bong bóng.
  expect(
    drawn,
    hasLength(screen.length),
    reason: '$label — ${screen.length} khối chữ nhưng chỉ vẽ được '
        '${drawn.length} bong bóng: ${_describe(drawn)}',
  );

  // (2) Đúng chỗ: góc trên-trái của bong bóng trùng khối gốc (± 4dp).
  // Chip thu gọn (mục 3) chỉ là ~26×20dp ở góc trên-phải khung gốc nên KHÔNG
  // thể trùng `left`; nó được kiểm riêng bên dưới: đỉnh trùng (chip neo vào
  // cạnh trên khối) và mép phải trùng.
  for (final src in screen) {
    final inPlace = drawn.where(
      (b) =>
          (b.rect.top - src.top).abs() <= _maxDeltaPx &&
          (b.rect.left - src.left).abs() <= _maxDeltaPx,
    );
    if (inPlace.isEmpty) {
      final chip = drawn.where(
        (b) =>
            b.collapsed &&
            (b.rect.top - src.top).abs() <= _maxDeltaPx + 24 &&
            (b.rect.right - src.right).abs() <= _maxDeltaPx,
      );
      if (chip.isNotEmpty) continue; // khối này được đại diện bằng chip
    }
    expect(
      inPlace,
      isNotEmpty,
      reason: '$label — khối $src không có bong bóng nào trong ±4dp '
          '($_maxDeltaPx px). Các bong bóng: ${_describe(drawn)}',
    );
  }

  // (3) Không đè nhau. Chip thu gọn nằm TRONG khung gốc của chính nó nên chỉ
  // so các bong bóng ĐẦY ĐỦ; chồng lấn chip↔chip ở màn hình cực dày đã được
  // chấp nhận và có bài kiểm riêng (overlay_layout_audit_test).
  expect(
    countOverlappingPairs(result.blocks.where((b) => b.isExpanded).toList()),
    0,
    reason: '$label — có bong bóng đè lên nhau: ${_describe(drawn)}',
  );
}

/// Chữ dịch không được TO HƠN chữ gốc: cỡ chữ (px thật native sẽ vẽ = sp ×
/// density × fontScale) không vượt chiều cao một dòng của khối gốc.
void _expectTextNoBiggerThanSource(
  List<_Src> screen,
  ScreenTranslateResult result, {
  double fontScale = 1.0,
}) {
  expect(result.blocks, hasLength(screen.length));
  for (var i = 0; i < screen.length; i++) {
    final src = screen[i];
    final drawnPx = result.blocks[i].textSizeSp * _dpr * fontScale;
    expect(
      drawnPx,
      lessThanOrEqualTo(src.lineHeightPx + 0.5),
      reason: 'Khối $src: dòng gốc cao ${src.lineHeightPx.toStringAsFixed(1)}'
          'px nhưng bản dịch vẽ ở ${drawnPx.toStringAsFixed(1)}px '
          '(${result.blocks[i].textSizeSp.toStringAsFixed(1)}sp × $_dpr × '
          '$fontScale) ⇒ cần nhiều chỗ hơn chữ gốc ⇒ đẩy/bỏ khối bên dưới.',
    );
  }
}

void main() {
  group('PSRC-211 — màn hình bài viết 10 khối', () {
    test('đủ 10 bong bóng, lệch ≤ 4dp, không đè nhau', () async {
      final seen = <String>[];
      final result = await _run(_article, seen: seen);
      _expectEveryBlockInPlace(_article, result);
      _expectTextNoBiggerThanSource(_article, result);

      // Đoạn văn phải được dịch NGUYÊN CÂU, không phải từng dòng bị màn hình
      // ngắt giữa chừng.
      expect(
        seen,
        contains(_flat(_article[1].text)),
        reason: 'Engine phải nhận cả câu, không phải chuỗi còn `\\n` của OCR.',
      );
    });

    test('engine giữ nguyên xuống dòng ⇒ vẫn đủ 10 bong bóng, đúng chỗ',
        () async {
      final result = await _run(_article, translate: _translateKeepingLines);
      _expectEveryBlockInPlace(_article, result);
    });

    test('máy bật cỡ chữ hệ thống 1.3× ⇒ chữ dịch không to hơn chữ gốc',
        () async {
      final result = await _run(_article, fontScale: 1.3);
      _expectEveryBlockInPlace(_article, result, label: 'fontScale 1.3');
      _expectTextNoBiggerThanSource(_article, result, fontScale: 1.3);
    });

    test('nội dung đã CUỘN (khối ở toạ độ bất kỳ, sát đáy) vẫn đúng chỗ',
        () async {
      // Ảnh chụp là màn hình ĐANG hiển thị ⇒ "cuộn" = mọi khối dời cùng một
      // quãng. −138: tiêu đề sát mép trên; +560: hai nút nằm sát lề đáy.
      for (final dy in <int>[-138, 300, 560]) {
        final screen = <_Src>[for (final src in _article) src.shifted(dy)];
        final result = await _run(screen);
        _expectEveryBlockInPlace(screen, result, label: 'cuộn $dy px');
        for (final block in result.blocks.where((b) => b.hasTranslation)) {
          expect(block.rect.top, greaterThanOrEqualTo(0));
          expect(block.rect.bottom, lessThanOrEqualTo(_screenH));
        }
      }
    });
  });

  group('PSRC-211 — khối sát nhau', () {
    test('danh sách 8 hàng dày: đủ 8 bong bóng, hàng nào ở đúng hàng đó',
        () async {
      // Bản cũ: mỗi ô cần cao hơn hàng của nó vài pixel ⇒ đẩy hàng dưới ⇒
      // độ lệch CỘNG DỒN, tới hàng thứ 4 đã vượt 4dp.
      final screen = _tightList();
      final result = await _run(screen);
      _expectEveryBlockInPlace(screen, result);
      _expectTextNoBiggerThanSource(screen, result);
    });

    test('hai khối cách nhau 6px: không đè, khối dưới không bị đẩy xa',
        () {
      // Thuần layout (không qua controller): hai nhãn một dòng sát nhau.
      const upper = OverlayRect(left: 60, top: 300, right: 520, bottom: 344);
      const lower = OverlayRect(left: 60, top: 350, right: 520, bottom: 394);
      final out = layoutTranslatedBlocks(
        const <ScreenBlock>[
          ScreenBlock(
            rect: upper,
            original: 'Privacy and security',
            translation: 'Quyền riêng tư và bảo mật',
          ),
          ScreenBlock(
            rect: lower,
            original: 'Help and feedback',
            translation: 'Trợ giúp và phản hồi',
          ),
        ],
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
      );
      expect(out, hasLength(2));
      expect(out.every((b) => b.hasTranslation), isTrue,
          reason: 'không được bỏ khối nào');
      expect(countOverlappingPairs(out), 0);
      expect(out[0].rect.top, upper.top);
      expect((out[1].rect.top - lower.top).abs(),
          lessThanOrEqualTo(_maxDeltaPx),
          reason: 'khối dưới bị đẩy ${out[1].rect.top - lower.top}px '
              '(cho phép $_maxDeltaPx px = 4dp)');
      expect(out[0].rect.bottom, lessThanOrEqualTo(out[1].rect.top));
    });
  });

  group('PSRC-211 — đoạn văn bị OCR tách thành từng dòng', () {
    // ML Kit tách một đoạn 4 dòng thành 4 khối riêng (giãn dòng rộng).
    const lines = <String>[
      'Download a language pack once and the app keeps',
      'working without a connection. Translations, the',
      'dictionary and text to speech all run on your',
      'phone, so nothing you read ever leaves the device.',
    ];
    final screen = <_Src>[
      for (var i = 0; i < lines.length; i++)
        _Src(44, 360 + i * 54, i == 3 ? 1000 : 1036, 400 + i * 54, lines[i]),
    ];

    test('dịch NGUYÊN CÂU một lần, bong bóng phủ đúng cả đoạn', () async {
      final seen = <String>[];
      final result = await _run(screen, seen: seen);
      expect(result.status, ScreenTranslateStatus.ok);

      expect(
        seen,
        <String>[lines.join(' ')],
        reason: 'Bốn dòng của MỘT câu phải đi thành một request — dịch từng '
            'dòng cụt vừa sai nghĩa vừa sinh 4 bong bóng đẩy nhau.',
      );

      final drawn = result.blocks.where((b) => b.hasTranslation).toList();
      expect(drawn, isNotEmpty);
      // Mọi dòng gốc đều nằm dưới một bong bóng…
      for (final src in screen) {
        final covering = drawn.where(
          (b) =>
              b.rect.top <= src.top + _maxDeltaPx &&
              b.rect.bottom >= src.bottom - _maxDeltaPx &&
              b.rect.left <= src.left + _maxDeltaPx,
        );
        expect(covering, isNotEmpty,
            reason: 'dòng $src không được bong bóng nào phủ: '
                '${_describe(drawn)}');
      }
      // …và bong bóng bắt đầu đúng đỉnh đoạn văn.
      expect((drawn.first.rect.top - screen.first.top).abs(),
          lessThanOrEqualTo(_maxDeltaPx));
      expect(countOverlappingPairs(result.blocks), 0);
    });
  });
}
