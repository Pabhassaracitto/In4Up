/// ═══════════════════════════════════════════════════════════════
/// EVIDENCE — nơi/lúc gặp một KnowledgeUnit
///
/// Handoff MATRIX KNOWLEDGE MVA v2.0 — schema mục 2.2.
///
/// Quy tắc cứng:
///  * Khi reopen: nếu `locator` resolve được nhưng nội dung tại đó không
///    khớp `snapshotHash` ⇒ UI phải báo "NGUỒN ĐÃ THAY ĐỔI" (`verifyAgainst`
///    trả false), KHÔNG được âm thầm coi evidence còn hợp lệ.
///  * `producerVersion` bắt buộc — để biết dữ liệu sinh bởi rule/version nào.
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Nguồn nơi gặp unit.
enum EvidenceSourceType { pdf, web, audio, youtube, text, clipboard }

/// Hình chữ nhật tọa độ chuẩn hóa [0..1] trên trang PDF
/// (để reopen highlight đúng vị trí độc lập kích thước render).
class LocatorRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const LocatorRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  factory LocatorRect.fromJson(Map<String, dynamic> json) => LocatorRect(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) {
    return other is LocatorRect &&
        other.x == x &&
        other.y == y &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(x, y, width, height);
}

/// Vị trí gặp unit trong nguồn — cấu trúc theo loại nguồn (mục 2.2):
///  * PDF: `page`, `rect`, `offset`
///  * Web: `url`, `scrollPercent`
///  * Audio: `timestampStart`, `timestampEnd` (giây)
class EvidenceLocator {
  /// PDF — số trang hiển thị cho người dùng (1-based).
  final int? page;

  /// PDF — vùng chữ trên trang.
  final LocatorRect? rect;

  /// PDF/text — offset ký tự trong nội dung đã trích xuất.
  final int? offset;

  /// Web/YouTube — URL gốc lúc ghi nhận.
  final String? url;

  /// Web — vị trí cuộn 0..100 khi gặp.
  final double? scrollPercent;

  /// Audio — bắt đầu khoảng gặp (giây).
  final double? timestampStart;

  /// Audio — kết thúc khoảng gặp (giây).
  final double? timestampEnd;

  const EvidenceLocator({
    this.page,
    this.rect,
    this.offset,
    this.url,
    this.scrollPercent,
    this.timestampStart,
    this.timestampEnd,
  });

  /// Chỉ xuất các key khác null — JSON gọn, dễ diff giữa các loại nguồn.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (page != null) map['page'] = page;
    if (rect != null) map['rect'] = rect!.toJson();
    if (offset != null) map['offset'] = offset;
    if (url != null) map['url'] = url;
    if (scrollPercent != null) map['scrollPercent'] = scrollPercent;
    if (timestampStart != null) map['timestampStart'] = timestampStart;
    if (timestampEnd != null) map['timestampEnd'] = timestampEnd;
    return map;
  }

  factory EvidenceLocator.fromJson(Map<String, dynamic> json) {
    final rectJson = json['rect'];
    return EvidenceLocator(
      page: json['page'] as int?,
      rect: rectJson == null
          ? null
          : LocatorRect.fromJson(rectJson as Map<String, dynamic>),
      offset: json['offset'] as int?,
      url: json['url'] as String?,
      scrollPercent: (json['scrollPercent'] as num?)?.toDouble(),
      timestampStart: (json['timestampStart'] as num?)?.toDouble(),
      timestampEnd: (json['timestampEnd'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EvidenceLocator &&
        other.page == page &&
        other.rect == rect &&
        other.offset == offset &&
        other.url == url &&
        other.scrollPercent == scrollPercent &&
        other.timestampStart == timestampStart &&
        other.timestampEnd == timestampEnd;
  }

  @override
  int get hashCode => Object.hash(
        page,
        rect,
        offset,
        url,
        scrollPercent,
        timestampStart,
        timestampEnd,
      );
}

/// Phiên bản của bộ máy sinh ra evidence (bắt buộc — mục 2.2):
/// dữ liệu sinh bởi rule nào, splitter/extractor version nào.
class ProducerVersion {
  final String splitterVersion;
  final String extractorVersion;

  const ProducerVersion({
    required this.splitterVersion,
    required this.extractorVersion,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'splitterVersion': splitterVersion,
        'extractorVersion': extractorVersion,
      };

  factory ProducerVersion.fromJson(Map<String, dynamic> json) =>
      ProducerVersion(
        splitterVersion: json['splitterVersion'] as String,
        extractorVersion: json['extractorVersion'] as String,
      );

  @override
  bool operator ==(Object other) {
    return other is ProducerVersion &&
        other.splitterVersion == splitterVersion &&
        other.extractorVersion == extractorVersion;
  }

  @override
  int get hashCode => Object.hash(splitterVersion, extractorVersion);

  @override
  String toString() =>
      'ProducerVersion(splitter: $splitterVersion, extractor: $extractorVersion)';
}

/// Hash SHA-256 của excerpt tại thời điểm ghi nhận —
/// cổng phát hiện "nguồn đã thay đổi" khi reopen (mục 2.2).
class SnapshotHash {
  SnapshotHash._();

  static String compute(String excerpt) =>
      sha256.convert(utf8.encode(excerpt)).toString();
}

class Evidence {
  final String evidenceId;

  /// FK → KnowledgeUnit.unitId. Được repoint khi merge qua `MergeSplitService`.
  final String unitId;

  final EvidenceSourceType sourceType;

  /// ID của tài liệu/track gốc (file id, document id, video id…).
  final String sourceId;

  final EvidenceLocator locator;

  /// Đoạn văn bản gốc quanh vị trí gặp — dùng cho citation + snapshotHash.
  final String excerpt;

  /// SHA-256 của excerpt lúc ghi nhận (xem `SnapshotHash.compute`).
  final String snapshotHash;

  final DateTime createdAt;

  /// Bắt buộc — truy vết nguồn gốc dữ liệu (mục 2.2).
  final ProducerVersion producerVersion;

  Evidence({
    required this.evidenceId,
    required this.unitId,
    required this.sourceType,
    required this.sourceId,
    required this.locator,
    required this.excerpt,
    required this.snapshotHash,
    required this.createdAt,
    required this.producerVersion,
  });

  /// Ghi nhận evidence mới — tự sinh id (UUID v4) và snapshotHash từ excerpt.
  factory Evidence.record({
    required String unitId,
    required EvidenceSourceType sourceType,
    required String sourceId,
    required EvidenceLocator locator,
    required String excerpt,
    required ProducerVersion producerVersion,
    String? evidenceId,
    DateTime? createdAt,
  }) {
    return Evidence(
      evidenceId: evidenceId ?? const Uuid().v4(),
      unitId: unitId,
      sourceType: sourceType,
      sourceId: sourceId,
      locator: locator,
      excerpt: excerpt,
      snapshotHash: SnapshotHash.compute(excerpt),
      createdAt: createdAt ?? DateTime.now(),
      producerVersion: producerVersion,
    );
  }

  /// Mục 2.2 — đối chiếu nội dung HIỆN TẠI của nguồn với snapshot lúc ghi nhận.
  /// Trả về false ⇒ UI phải báo "Nguồn đã thay đổi", không âm thầm dùng tiếp.
  bool verifyAgainst(String currentExcerpt) =>
      SnapshotHash.compute(currentExcerpt) == snapshotHash;

  /// Copy với unitId mới — phục vụ repoint khi merge/split.
  Evidence copyWith({String? unitId}) => Evidence(
        evidenceId: evidenceId,
        unitId: unitId ?? this.unitId,
        sourceType: sourceType,
        sourceId: sourceId,
        locator: locator,
        excerpt: excerpt,
        snapshotHash: snapshotHash,
        createdAt: createdAt,
        producerVersion: producerVersion,
      );

  @override
  bool operator ==(Object other) {
    return other is Evidence &&
        other.evidenceId == evidenceId &&
        other.unitId == unitId &&
        other.sourceType == sourceType &&
        other.sourceId == sourceId &&
        other.locator == locator &&
        other.excerpt == excerpt &&
        other.snapshotHash == snapshotHash &&
        other.createdAt == createdAt &&
        other.producerVersion == producerVersion;
  }

  @override
  int get hashCode => Object.hash(
        evidenceId,
        unitId,
        sourceType,
        sourceId,
        locator,
        excerpt,
        snapshotHash,
        createdAt,
        producerVersion,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'evidenceId': evidenceId,
        'unitId': unitId,
        'sourceType': sourceType.name,
        'sourceId': sourceId,
        'locator': locator.toJson(),
        'excerpt': excerpt,
        'snapshotHash': snapshotHash,
        'createdAt': createdAt.toIso8601String(),
        'producerVersion': producerVersion.toJson(),
      };

  factory Evidence.fromJson(Map<String, dynamic> json) {
    final sourceTypeName = json['sourceType'] as String;
    return Evidence(
      evidenceId: json['evidenceId'] as String,
      unitId: json['unitId'] as String,
      sourceType: EvidenceSourceType.values.firstWhere(
        (s) => s.name == sourceTypeName,
        orElse: () => throw FormatException(
            'EvidenceSourceType không hợp lệ: $sourceTypeName'),
      ),
      sourceId: json['sourceId'] as String,
      locator: EvidenceLocator.fromJson(
          json['locator'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      excerpt: json['excerpt'] as String,
      snapshotHash: json['snapshotHash'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      producerVersion: ProducerVersion.fromJson(
          json['producerVersion'] as Map<String, dynamic>),
    );
  }

  @override
  String toString() =>
      'Evidence($evidenceId, ${sourceType.name}, unit:$unitId)';
}
