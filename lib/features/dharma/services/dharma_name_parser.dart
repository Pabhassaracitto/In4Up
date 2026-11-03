// lib/features/dharma/services/dharma_name_parser.dart
//
// PLAN-042 §5 — bộ phân tích tên THẬT của kho pháp thoại thành metadata.
//
// Hàm THUẦN (0 I/O, 0 plugin) để test được trên CI và để kết quả không phụ
// thuộc màn hình/ngôn ngữ máy.
//
// Thứ tự luật là một phần của hợp đồng — đã có 2 lỗi thật khi đảo thứ tự
// (PLAN-042 F9/F10 ở phụ lục kế hoạch):
//   file:  range('05-06')  →  ordinal('B1'/'01.')  →  date('ddMMyy')  →
//          part('Phần 3'/'P9')  →  durationHint('(54 phút)')  →  housekeeping
//   series: order('34.')  →  year('2024')  →  language(song ngữ TRƯỚC vi)  →
//          speaker('Sayadaw U …' | 'SU …' | 'Ngài U …')  →  topic  →  venue
//
// Nguyên tắc "đoán an toàn": KHÔNG BAO GIỜ mất `rawName`; trường đoán được có
// cờ tin cậy; người dùng sửa tay được (xem DharmaAliasStore).

import '../models/dharma_talk.dart';
import 'dharma_text.dart';

/// Extension audio được nhận — trùng bộ đã dùng ở `google_drive_service.dart`
/// để một file không "có" ở luồng Drive mà "không có" ở luồng này.
const Set<String> dharmaAudioExtensions = {
  'mp3',
  'm4a',
  'm4b',
  'mp4',
  'aac',
  'wav',
  'flac',
  'ogg',
  'opus',
  'webm',
};

/// File rác của hệ điều hành/nhà sản xuất — lọc trước khi phân tích.
bool isDharmaAudioFile(String fileName) {
  final lower = fileName.toLowerCase().trim();
  if (lower == 'desktop.ini' || lower.startsWith('.')) return false;
  final dot = lower.lastIndexOf('.');
  if (dot < 0) return false;
  return dharmaAudioExtensions.contains(lower.substring(dot + 1));
}

/// Kết quả phân tích một tên (thư mục hoặc file).
class DharmaNameInfo {
  final String title;
  final String rawName;
  final int? orderIndex;
  final int? episodeStart;
  final int? episodeEnd;
  final DateTime? date;
  final bool dateConfident;
  final int? part;
  final int? durationHintMin;
  final bool housekeeping;
  final int? year;
  final String? speakerKey;
  final String? speakerDisplay;
  final DharmaLanguage language;
  final String? venue;
  final String? topic;

  const DharmaNameInfo({
    required this.title,
    required this.rawName,
    this.orderIndex,
    this.episodeStart,
    this.episodeEnd,
    this.date,
    this.dateConfident = true,
    this.part,
    this.durationHintMin,
    this.housekeeping = false,
    this.year,
    this.speakerKey,
    this.speakerDisplay,
    this.language = DharmaLanguage.unknown,
    this.venue,
    this.topic,
  });
}

/// Bảng alias vị Thầy — cùng một người nhiều cách viết (PLAN-042 F5).
///
/// Khoá là `searchKey` (bỏ dấu, lowercase) của cụm nhận được; giá trị là tên
/// hiển thị chuẩn. Người dùng sửa tay sẽ được lưu ở `DharmaAliasStore` và
/// **thắng** bảng này.
const Map<String, String> dharmaSpeakerAliases = {
  'pa_auk_sayadawgyi': 'Pa Auk Sayadawgyi',
  'pa_auk_tawya_sayadaw': 'Pa Auk Sayadawgyi',
  'pa_auk_sayadaw': 'Pa Auk Sayadawgyi',
  'sayadaw_u_revata': 'Sayadaw U Revata',
  'sayadaw_u_reveta': 'Sayadaw U Revata',
  'sayadaw_u_janakabhivamsa': 'Sayadaw U Janakābhivaṃsa',
  'sayadaw_u_kovida': 'Sayadaw U Kovida',
  'su_kovida': 'Sayadaw U Kovida',
  'ngai_u_kovida': 'Sayadaw U Kovida',
  'sayadaw_u_kumarabhivamsa': 'Sayadaw U Kumārābhivaṃsa',
  'sayadaw_u_kumurabhivamsa': 'Sayadaw U Kumārābhivaṃsa',
  'sayadaw_u_kundadhana': 'Sayadaw U Kuṇḍadhāna',
  'sayadaw_u_janeyyacara': 'Sayadaw U Jāneyyācāra',
  'sayadaw_u_agganha': 'Sayadaw U Aggañña',
  'sayadaw_u_kume': 'Sayadaw U Kume',
  'sayalay_dipankara': 'Sayalay Dipankara',
  'ngai_u_kovida_': 'Sayadaw U Kovida',
};

const Map<String, String> _venues = {
  'da lat': 'Đà Lạt',
  'đà lạt': 'Đà Lạt',
  'ba vi': 'Ba Vì',
  'ba vì': 'Ba Vì',
  'long hai': 'Long Hải',
  'long hải': 'Long Hải',
  'phuoc son': 'Phước Sơn',
  'phước sơn': 'Phước Sơn',
  'nepal': 'Nepal',
  'han quoc': 'Hàn Quốc',
  'hàn quốc': 'Hàn Quốc',
  'tukpok': 'Tukpok',
  'us retreat': 'US Retreat',
  'korea': 'Hàn Quốc',
};

/// Cụm chủ đề Pāḷi thường gặp — nhận bằng `searchKey` để không lệ thuộc dấu.
const Map<String, String> _topicPatterns = {
  'bojjhanga sutta': 'Bojjhaṅga Sutta',
  'metta sutta': 'Metta Sutta',
  'mangala sutta': 'Mangala Sutta',
  'ratana sutta': 'Ratana Sutta',
  'karaniyametta sutta': 'Karaṇīyamettā Sutta',
  'anattalakkhana sutta': 'Anattalakkhaṇa Sutta',
  'satipatthana': 'Satipaṭṭhāna',
  'thanh tinh dao': 'Thanh Tịnh Đạo',
  'vi dieu phap': 'Vi Diệu Pháp',
  'vinaya': 'Vinaya',
  'parami': 'Pāramī',
  'ba la mat': 'Pāramī',
};

class DharmaNameParser {
  const DharmaNameParser();

  /// Phân tích tên một SERIES (tên thư mục cấp 2).
  DharmaNameInfo parseSeries(String rawFolderName) {
    final raw = rawFolderName.trim();
    var work = raw;

    // 1. Số thứ tự đầu: '34. …' — bỏ khỏi tiêu đề, giữ để sắp xếp.
    int? orderIndex;
    final orderMatch = RegExp(r'^\s*(\d{1,3})\s*[.)]\s*').firstMatch(work);
    if (orderMatch != null) {
      orderIndex = int.tryParse(orderMatch.group(1)!);
      work = work.substring(orderMatch.end);
    }

    // 2. Năm ở cuối: '… 2024' / '… 2022-2023' (lấy năm đầu).
    int? year;
    final years = RegExp(r'(?<!\d)(19|20)\d{2}(?!\d)').allMatches(work);
    if (years.isNotEmpty) {
      year = int.tryParse(years.first.group(0)!.substring(0, 4));
    }

    // 3. Ngôn ngữ — song ngữ phải xét TRƯỚC 'vi' (PLAN-042 F8).
    final langKey = searchKey(work);
    DharmaLanguage language = DharmaLanguage.unknown;
    // searchKey() đã hạ chữ + gộp thành '_' nên mọi so khớp dưới đây là
    // lowercase; viết hoa nhầm sẽ làm rơi cả một nhánh (đã mắc khi viết).
    final langTokens = langKey.split('_').toSet();
    if (langKey.contains('song_ngu') ||
        langKey.contains('en_vi') ||
        langKey.contains('vi_en')) {
      language = DharmaLanguage.bilingual;
    } else if (langKey.contains('tieng_viet') || langTokens.contains('viet')) {
      language = DharmaLanguage.vi;
    } else if (langTokens.contains('vi') && langTokens.contains('en')) {
      language = DharmaLanguage.bilingual;
    } else if (langTokens.contains('vi')) {
      language = DharmaLanguage.vi;
    } else if (langKey.contains('pali') || langTokens.contains('pali')) {
      language = DharmaLanguage.pali;
    } else if (langTokens.contains('english') || langTokens.contains('en')) {
      language = DharmaLanguage.en;
    } else if (langTokens.contains('myanmar')) {
      language = DharmaLanguage.my;
    } else if (langKey.contains('kinh_tung')) {
      // Thư mục kinh tụng mặc định là Pāḷi (collection A).
      language = DharmaLanguage.pali;
    }

    // 4. Vị Thầy — nhận trên chuỗi CHƯA bỏ dấu để giữ tên hiển thị đẹp.
    final speaker = _extractSpeaker(raw);

    // 5. Chủ đề (sutta/pháp học). `searchKey()` trả '_' nên phải so trên dạng
    //    có dấu cách — so trực tiếp sẽ không bao giờ khớp (lỗi đã mắc).
    String? topic;
    final topicHaystack = ' ${langKey.replaceAll('_', ' ')} ';
    for (final entry in _topicPatterns.entries) {
      if (topicHaystack.contains(' ${entry.key} ')) {
        topic = entry.value;
        break;
      }
    }

    // 6. Địa điểm/khoá thiền.
    String? venue;
    final venueKey = ' ${searchKey(work).replaceAll('_', ' ')} ';
    for (final entry in _venues.entries) {
      if (venueKey.contains(' ${entry.key} ')) {
        venue = entry.value;
        break;
      }
    }

    return DharmaNameInfo(
      title: _cleanTitle(removeSpeaker: true, removeYear: true, text: work),
      rawName: raw,
      orderIndex: orderIndex,
      year: year,
      speakerKey: speaker?.key,
      speakerDisplay: speaker?.display,
      language: language,
      venue: venue,
      topic: topic,
    );
  }

  /// Phân tích tên một FILE audio trong series.
  DharmaNameInfo parseEpisode(String rawFileName) {
    final raw = rawFileName.trim();
    var stem = _stripExtension(raw);

    // 1. Range buổi TRƯỚC ordinal (PLAN-042 F9: '05-06.' không được lấy '05').
    int? episodeStart;
    int? episodeEnd;
    final rangeMatch =
        RegExp(r'^\s*(\d{1,3})\s*-\s*(\d{1,3})\s*[.)]\s*').firstMatch(stem);
    if (rangeMatch != null) {
      episodeStart = int.tryParse(rangeMatch.group(1)!);
      episodeEnd = int.tryParse(rangeMatch.group(2)!);
      stem = stem.substring(rangeMatch.end);
    } else {
      // 2. Tiền tố: 'B12 …' (Drive hiện tại) hoặc '01. …' (kiểu cũ).
      final bMatch = RegExp(r'^\s*[Bb](\d{1,2})\b\s*').firstMatch(stem);
      final numMatch = RegExp(r'^\s*(\d{1,3})\s*[.)\-]\s*').firstMatch(stem);
      final aMatch = RegExp(r'^\s*[A-Za-z]-(\d{1,3})\s*[.)]\s*').firstMatch(stem);
      if (bMatch != null) {
        episodeStart = int.tryParse(bMatch.group(1)!);
        stem = stem.substring(bMatch.end);
      } else if (numMatch != null) {
        episodeStart = int.tryParse(numMatch.group(1)!);
        stem = stem.substring(numMatch.end);
      } else if (aMatch != null) {
        // 'A-01. …' → mã nội bộ của kho; dùng làm số buổi nếu chưa có.
        episodeStart = int.tryParse(aMatch.group(1)!);
        stem = stem.substring(aMatch.end);
      }
      // 2b. Mã thứ hai: '01. A-01. …' — bỏ tiếp để tiêu đề sạch, KHÔNG đổi số
      //     buổi đã lấy ở bước 2 (số buổi là mốc ngoài cùng).
      final secondCode =
          RegExp(r'^\s*[A-Za-z]-(\d{1,3})\s*[.)]\s*').firstMatch(stem);
      if (secondCode != null) {
        episodeStart ??= int.tryParse(secondCode.group(1)!);
        stem = stem.substring(secondCode.end);
      }
    }

    // 3. Ngày: yyyyMMdd (8 số) hoặc ddMMyy (6 số, phải validate).
    DateTime? date;
    var dateConfident = true;
    final dateResult = _extractDate(stem);
    if (dateResult != null) {
      date = dateResult.date;
      dateConfident = dateResult.confident;
      stem = dateResult.cleaned;
    }

    // 4. 'Phần N' / 'P9' — lấy mốc CUỐI cùng (B12/B13 có 'P1/P2' là nội dung).
    int? part;
    final partMatches =
        RegExp(r'\b(?:Ph[aầ]n|Phan|P)\s*(\d{1,2})\b', caseSensitive: false)
            .allMatches(stem);
    if (partMatches.isNotEmpty) {
      part = int.tryParse(partMatches.last.group(1)!);
    }

    // 5. Hậu tố nhà sản xuất — chỉ đánh cờ, giữ tên gốc.
    //    Phải xét TRƯỚC thời lượng vì '(54 phút) - end sound' đặt ngoặc ở
    //    giữa chuỗi; nếu xét sau thì regex neo cuối chuỗi không khớp.
    var housekeeping = false;
    final hk = RegExp(r'\b(end sound|end_sound|intro|outro)\b', caseSensitive: false)
        .firstMatch(stem);
    if (hk != null) {
      housekeeping = true;
      stem = stem.replaceRange(hk.start, hk.end, ' ');
      // Sau khi bỏ 'end sound' thường còn dấu nối ở cuối ('… - ') — phải dọn
      // trước khi so khớp thời lượng neo cuối chuỗi, nếu không sẽ trượt.
      stem = stem.replaceAll(RegExp(r'[\s\-–—_]+$'), '');
    }

    // 6. Gợi ý thời lượng '(54 phút)' / '(52)' ở CUỐI chuỗi (sau khi đã bỏ
    //    hậu tố rác). Chỉ nhận giá trị hợp lý, không bao giờ coi là số thật.
    int? durationHintMin;
    final durMatch =
        RegExp(r'\((\d{1,3})\s*(?:phút|phut)?\s*\)[\s\-–—_]*$',
            caseSensitive: false)
            .firstMatch(stem);
    if (durMatch != null) {
      final value = int.tryParse(durMatch.group(1)!);
      if (value != null && value > 0 && value <= 300) {
        durationHintMin = value;
        stem = stem.substring(0, durMatch.start);
      }
    }

    return DharmaNameInfo(
      title: _cleanTitle(removeSpeaker: false, removeYear: false, text: stem),
      rawName: raw,
      episodeStart: episodeStart,
      episodeEnd: episodeEnd,
      date: date,
      dateConfident: dateConfident,
      part: part,
      durationHintMin: durationHintMin,
      housekeeping: housekeeping,
    );
  }

  /// Dựng `DharmaSeries` + danh sách `DharmaEpisode` từ một thư mục.
  ///
  /// [folderName] — tên thư mục series; [relativeFolder] — đường dẫn tương đối
  /// so với thư mục gốc người dùng chọn; [files] — (tên file, source, size,
  /// modifiedAt) của các file audio TRỰC TIẾP trong thư mục đó.
  DharmaSeries buildSeries({
    required String folderName,
    required String relativeFolder,
    required String seriesKey,
    required Iterable<DharmaFileRef> files,
    DharmaCollection? collectionOverride,
    String? speakerOverride,
  }) {
    final info = parseSeries(folderName);
    final collection = collectionOverride ?? collectionBelow(relativeFolder);
    final speakerDisplay = speakerOverride ?? info.speakerDisplay;

    final episodes = <DharmaEpisode>[];
    for (final file in files) {
      if (!isDharmaAudioFile(file.name)) continue;
      final ep = parseEpisode(file.name);
      episodes.add(
        DharmaEpisode(
          episodeKey: file.episodeKey,
          source: file.source,
          sourceKind: file.sourceKind,
          title: ep.title.isEmpty ? _stripExtension(file.name) : ep.title,
          rawName: file.name,
          episodeStart: ep.episodeStart,
          episodeEnd: ep.episodeEnd,
          talkDate: ep.date,
          dateConfident: ep.dateConfident,
          durationHintMin: ep.durationHintMin,
          part: ep.part,
          housekeeping: ep.housekeeping,
          libraryId: file.libraryId,
          driveFileId: file.driveFileId,
          sizeBytes: file.sizeBytes,
          driveModifiedTime: file.modifiedAt,
        ),
      );
    }
    sortEpisodes(episodes);

    return DharmaSeries(
      seriesKey: seriesKey,
      title: info.title.isEmpty ? folderName : info.title,
      rawName: folderName,
      orderIndex: info.orderIndex,
      speakerKey: (speakerDisplay == null || speakerDisplay.trim().isEmpty)
          ? null
          : searchKey(speakerDisplay),
      speakerDisplay: speakerDisplay,
      collection: collection,
      language: info.language,
      year: info.year,
      venue: info.venue,
      topic: info.topic,
      relativeFolder: relativeFolder,
      episodes: List.unmodifiable(episodes),
      lastScannedAt: DateTime.now(),
    );
  }

  /// Sắp xếp buổi theo số buổi (natural), rồi tới tên.
  ///
  /// `episodeStart` BẰNG NHAU (thường gặp: hai buổi cùng 'P…' khác `Phần`,
  /// hoặc file ghép `05-06`) phải rơi xuống `naturalCompare`, nếu chỉ so
  /// `!=` rồi trả 0 thì thứ tự phụ thuộc thứ tự quét ⇒ mở app lại thấy đổi.
  static void sortEpisodes(List<DharmaEpisode> episodes) {
    episodes.sort((a, b) {
      final startA = a.episodeStart;
      final startB = b.episodeStart;
      if (startA != null && startB != null) {
        final byNumber = startA.compareTo(startB);
        if (byNumber != 0) return byNumber;
      } else if (startA != null) {
        return -1;
      } else if (startB != null) {
        return 1;
      }
      return naturalCompare(a.rawName, b.rawName);
    });
  }

  // ── helpers ──────────────────────────────────────────────────

  static String _stripExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return name;
    final ext = name.substring(dot + 1).toLowerCase();
    if (!dharmaAudioExtensions.contains(ext)) return name;
    return name.substring(0, dot);
  }

  static String _cleanTitle({
    required bool removeSpeaker,
    required bool removeYear,
    required String text,
  }) {
    var out = text;
    if (removeYear) {
      out = out.replaceAll(RegExp(r'(?<!\d)(19|20)\d{2}\s*$'), ' ');
    }
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    out = out.replaceAll(RegExp(r'^[\s\-–—_]+'), '');
    out = out.replaceAll(RegExp(r'[\s\-–—_]+$'), '');
    return out;
  }

  /// Nhận vị Thầy; trả (key chuẩn hoá, tên hiển thị).
  _Speaker? _extractSpeaker(String text) {
    final patterns = <RegExp>[
      RegExp(r'Pa[\s-]Auk\s+(?:Tawya\s+)?Sayadaw(?:gyi)?', caseSensitive: false),
      RegExp(
        r'Sayadaw\s+U\s+[A-Za-zÀ-ɏ\u0100-\u024F\u1E00-\u1EFF]+',
        caseSensitive: false,
      ),
      RegExp(r'Sayalay\s+[A-Za-zÀ-ɏĀ-ſ]+', caseSensitive: false),
      RegExp(r'\bSU\s+[A-Z][A-Za-z]+', caseSensitive: false),
      RegExp(r'Ngài\s+U\s+[A-Za-zÀ-ɏĀ-ſ]+', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final display = match.group(0)!.trim();
      final key = searchKey(display);
      final canonical = dharmaSpeakerAliases[key];
      if (canonical != null) {
        return _Speaker(searchKey(canonical), canonical);
      }
      // Không có trong bảng alias: viết hoa lại cho đẹp nhưng GIỮ NGUYÊN dấu.
      return _Speaker(key, _titleCaseSpeaker(display));
    }
    return null;
  }

  static String _titleCaseSpeaker(String display) {
    final cleaned = display.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.toLowerCase().startsWith('su ')) {
      return 'Sayadaw U ${cleaned.substring(3)}';
    }
    return cleaned;
  }

  /// Loại collection dựa trên đường dẫn tương đối (tên thư mục gốc A..G).
  static DharmaCollection collectionBelow(String relativeFolder) {
    final key = searchKey(relativeFolder);
    if (key.startsWith('a_') || key.contains('kinh_tung')) {
      return DharmaCollection.chanting;
    }
    if (key.startsWith('b_') || key.contains('sach_noi')) {
      return DharmaCollection.audiobook;
    }
    if (key.contains('dang_giang')) return DharmaCollection.talkOngoing;
    if (key.startsWith('c_') || key.contains('phap_thoai')) {
      return DharmaCollection.talkArchive;
    }
    return DharmaCollection.other;
  }

  static _DateHit? _extractDate(String text) {
    // yyyyMMdd — 8 số liền, năm hợp lý.
    final long = RegExp(r'(?<!\d)((?:19|20)\d{2})(\d{2})(\d{2})(?!\d)').firstMatch(text);
    if (long != null) {
      final y = int.parse(long.group(1)!);
      final m = int.parse(long.group(2)!);
      final d = int.parse(long.group(3)!);
      if (_validDate(y, m, d)) {
        return _DateHit(
          date: DateTime(y, m, d),
          confident: true,
          cleaned: text.replaceRange(long.start, long.end, ' '),
        );
      }
    }
    // ddMMyy — 6 số liền, phải validate để không ăn 'B10 5 Quyền'.
    for (final match in RegExp(r'(?<!\d)(\d{2})(\d{2})(\d{2})(?!\d)').allMatches(text)) {
      final d = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      final y = 2000 + int.parse(match.group(3)!);
      if (_validDate(y, m, d)) {
        return _DateHit(
          date: DateTime(y, m, d),
          confident: true,
          cleaned: text.replaceRange(match.start, match.end, ' '),
        );
      }
    }
    return null;
  }

  static bool _validDate(int year, int month, int day) {
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;
    if (year < 1990 || year > 2100) return false;
    // DateTime(y, m+1, 0) = ngày cuối của tháng m ⇒ kiểm tra 31/02, 31/04…
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return day <= daysInMonth;
  }
}

class _Speaker {
  final String key;
  final String display;
  const _Speaker(this.key, this.display);
}

class _DateHit {
  final DateTime date;
  final bool confident;
  final String cleaned;
  const _DateHit({
    required this.date,
    required this.confident,
    required this.cleaned,
  });
}

/// Một file audio đầu vào cho bộ dựng series (đã có sẵn nguồn + danh tính).
class DharmaFileRef {
  final String name;
  final String source;
  final String episodeKey;
  final DharmaSourceKind sourceKind;
  final int sizeBytes;
  final DateTime? modifiedAt;
  final String? libraryId;
  final String? driveFileId;

  const DharmaFileRef({
    required this.name,
    required this.source,
    required this.episodeKey,
    this.sourceKind = DharmaSourceKind.local,
    this.sizeBytes = 0,
    this.modifiedAt,
    this.libraryId,
    this.driveFileId,
  });
}
