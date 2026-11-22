// lib/features/great_library/models/pack_manifest.dart
//
// GLIB-001 — Thư Viện Chung I4U (PLAN-049, ADR-0031 D1).
// Model lõi của gói chia sẻ cộng đồng `.i4upack` và manifest JSON của nó.
//
// Thuần Dart (không Flutter, không dart:io) để test chạy mọi nơi và tái dùng
// được trong tool soạn pack seed (tool/great_library_seed — GLIB-008).
//
// Quy ước checksum (ADR-0031 D1):
//  - `payloadSha256` TRONG manifest: hash nội dung data/ + media/ do
//    pack_file.dart tính lúc build và verify lúc mở — bất biến theo cách nén
//    ZIP, không đổi khi chỉ re-zip cùng nội dung.
//  - `fileSha256` của NGUYÊN file .i4upack nằm ở catalog Firestore
//    (gl_pack_versions) — PackDownloadManager verify sau khi tải (GLIB-002).
//
// Lưu ý append-only: KHÔNG chèn giá trị mới vào giữa các enum dưới đây
// (tiền lệ SPEC_VOCAB_MASTERY) — chỉ thêm vào cuối.

import 'dart:convert';

/// Schema version của manifest — tăng khi đổi format không tương thích ngược.
const int kPackSchemaVersion = 1;

/// Trần cứng dung lượng payload 1 pack (AudioPack dài được moderator nâng tới
/// mức này — ideation v1.2 §6.2). Quota mặc định 50 MB nằm ở pack_file.dart.
const int kPackHardCeilingBytes = 200 * 1024 * 1024;

const int kMaxPackTitleLength = 120;
const int kMaxPackDescriptionLength = 4000;
const int kMaxPackTags = 20;
const int kMaxPackTagLength = 32;
const int kMaxPackAuthorNameLength = 60;
const int kMaxPackIdLength = 64;

/// Loại pack — append-only.
enum PackType {
  vocab('vocab'),
  audio('audio'),
  image('image');

  const PackType(this.wire);
  final String wire;

  static PackType? tryParse(Object? raw) {
    for (final value in PackType.values) {
      if (value.wire == raw) return value;
    }
    return null;
  }
}

/// Giấy phép nội dung — bắt buộc khi upload (ideation §5.2). Append-only.
enum PackLicense {
  cc0('cc0'),
  ccBy('cc-by'),
  ccByNc('cc-by-nc'),
  selfMade('self-made'),
  permissionGranted('permission-granted');

  const PackLicense(this.wire);
  final String wire;

  static PackLicense? tryParse(Object? raw) {
    for (final value in PackLicense.values) {
      if (value.wire == raw) return value;
    }
    return null;
  }
}

/// Vòng đời kiểm duyệt (ADR-0031 D4: pending-first). Append-only.
enum PackStatus {
  pending('pending'),
  published('published'),
  rejected('rejected'),
  hidden('hidden');

  const PackStatus(this.wire);
  final String wire;

  static PackStatus? tryParse(Object? raw) {
    for (final value in PackStatus.values) {
      if (value.wire == raw) return value;
    }
    return null;
  }
}

/// Trình độ CEFR của nội dung pack.
const Set<String> kPackLevels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'mixed'};

/// Tác giả pack (uid rỗng cho pack seed nội bộ).
class PackAuthor {
  const PackAuthor({
    required this.uid,
    required this.displayName,
    this.verified = false,
  });

  final String uid;
  final String displayName;
  final bool verified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uid': uid,
        'displayName': displayName,
        'verified': verified,
      };

  factory PackAuthor.fromJson(Map<String, dynamic> json) => PackAuthor(
        uid: (json['uid'] as String?) ?? '',
        displayName: (json['displayName'] as String?) ?? '',
        verified: json['verified'] == true,
      );
}

/// Thống kê cộng đồng (catalog ghi, manifest chỉ đọc).
class PackStats {
  const PackStats({this.downloads = 0, this.rating = 0, this.ratings = 0});

  final int downloads;
  final double rating;
  final int ratings;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'downloads': downloads,
        'rating': rating,
        'ratings': ratings,
      };

  factory PackStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PackStats();
    return PackStats(
      downloads: (json['downloads'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      ratings: (json['ratings'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Tham chiếu storage pluggable (ADR-0031 D3): backend nào + path trong backend.
class PackStorageRef {
  const PackStorageRef({required this.backend, required this.path});

  /// 'firebase' | 'supabase' | … (chuỗi tự do, resolver map ở tầng service).
  final String backend;

  /// ví dụ: packs/pack_01JAB…/3.i4upack
  final String path;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'backend': backend, 'path': path};

  factory PackStorageRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PackStorageRef(backend: '', path: '');
    return PackStorageRef(
      backend: (json['backend'] as String?) ?? '',
      path: (json['path'] as String?) ?? '',
    );
  }
}

/// Manifest đầy đủ của một `.i4upack` (manifest.json bên trong gói; catalog
/// Firestore lưu bản sao metadata để browse không cần tải pack).
class PackManifest {
  PackManifest({
    required this.id,
    required this.type,
    required this.title,
    this.description = '',
    this.srcLang = '',
    this.dstLang = '',
    this.tags = const <String>[],
    this.level = 'mixed',
    PackAuthor? author,
    this.license,
    this.version = 1,
    this.payloadSha256,
    this.sizeBytes = 0,
    this.entryCount = 0,
    PackStats? stats,
    this.status = PackStatus.pending,
    this.storage,
    this.createdAt,
    this.updatedAt,
    this.schemaVersion = kPackSchemaVersion,
  })  : author = author ?? const PackAuthor(uid: '', displayName: ''),
        stats = stats ?? const PackStats();

  final int schemaVersion;
  final String id;

  /// null khi parse gặp giá trị lạ — validate() sẽ báo lỗi.
  final PackType? type;
  final String title;
  final String description;

  /// Mã ngôn ngữ nguồn/đích dạng ngắn ('en', 'vi', 'pi'…).
  final String srcLang;
  final String dstLang;
  final List<String> tags;
  final String level;
  final PackAuthor author;
  final PackLicense? license;

  /// Tăng dần mỗi lần tác giả phát hành bản mới (≥ 1).
  final int version;

  /// sha256 của payload (data/ + media/) — do pack_file.dart inject lúc build.
  final String? payloadSha256;

  /// Tổng byte payload (data + media, KHÔNG gồm overhead ZIP) — để UI hiển thị
  /// dung lượng ước lượng; dung lượng file zip chính xác nằm ở catalog.
  final int sizeBytes;

  /// Số mục nội dung (số từ / số track / số ảnh) — cho UI.
  final int entryCount;
  final PackStats stats;
  final PackStatus status;
  final PackStorageRef? storage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  /// Trả về danh sách mã lỗi ổn định (rỗng = hợp lệ). Mã lỗi là contract cho
  /// test + UI, không đổi tuỳ tiện.
  List<String> validate() {
    final errors = <String>[];
    if (schemaVersion < 1) {
      errors.add('schema-invalid');
    } else if (schemaVersion > kPackSchemaVersion) {
      // App cũ không hiểu pack từ tương lai — từ chối thay vì đọc sai.
      errors.add('schema-unsupported');
    }
    if (id.isEmpty) {
      errors.add('id-empty');
    } else if (id.length > kMaxPackIdLength) {
      errors.add('id-too-long');
    } else if (!_idPattern.hasMatch(id)) {
      errors.add('id-invalid-chars');
    }
    if (title.trim().isEmpty) {
      errors.add('title-empty');
    } else if (title.length > kMaxPackTitleLength) {
      errors.add('title-too-long');
    }
    if (description.length > kMaxPackDescriptionLength) {
      errors.add('description-too-long');
    }
    if (type == null) errors.add('type-missing-or-unknown');
    if (license == null) errors.add('license-missing-or-unknown');
    if (srcLang.trim().isEmpty) errors.add('srcLang-empty');
    if (dstLang.trim().isEmpty) errors.add('dstLang-empty');
    if (!kPackLevels.contains(level)) errors.add('level-invalid');
    if (version < 1) errors.add('version-invalid');
    if (sizeBytes < 0) {
      errors.add('size-negative');
    } else if (sizeBytes > kPackHardCeilingBytes) {
      errors.add('size-over-ceiling');
    }
    if (entryCount < 0) errors.add('entry-count-negative');
    final sha = payloadSha256;
    if (sha != null && !_sha256Pattern.hasMatch(sha)) {
      errors.add('payload-sha256-invalid');
    }
    if (tags.length > kMaxPackTags) errors.add('tags-too-many');
    for (final tag in tags) {
      if (tag.isEmpty || tag.length > kMaxPackTagLength) {
        errors.add('tag-invalid');
        break;
      }
    }
    if (author.displayName.trim().isEmpty) errors.add('author-name-empty');
    if (author.displayName.length > kMaxPackAuthorNameLength) {
      errors.add('author-name-too-long');
    }
    final ref = storage;
    if (ref != null && (ref.backend.isEmpty || ref.path.isEmpty)) {
      errors.add('storage-invalid');
    }
    return errors;
  }

  bool get isValid => validate().isEmpty;

  PackManifest copyWith({
    PackType? type,
    String? title,
    String? description,
    String? srcLang,
    String? dstLang,
    List<String>? tags,
    String? level,
    PackAuthor? author,
    PackLicense? license,
    int? version,
    String? payloadSha256,
    int? sizeBytes,
    int? entryCount,
    PackStats? stats,
    PackStatus? status,
    PackStorageRef? storage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PackManifest(
      schemaVersion: schemaVersion,
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      srcLang: srcLang ?? this.srcLang,
      dstLang: dstLang ?? this.dstLang,
      tags: tags ?? this.tags,
      level: level ?? this.level,
      author: author ?? this.author,
      license: license ?? this.license,
      version: version ?? this.version,
      payloadSha256: payloadSha256 ?? this.payloadSha256,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      entryCount: entryCount ?? this.entryCount,
      stats: stats ?? this.stats,
      status: status ?? this.status,
      storage: storage ?? this.storage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'id': id,
      'type': type?.wire,
      'title': title,
      'description': description,
      'srcLang': srcLang,
      'dstLang': dstLang,
      'tags': tags,
      'level': level,
      'author': author.toJson(),
      'license': license?.wire,
      'version': version,
      'sizeBytes': sizeBytes,
      'entryCount': entryCount,
      'stats': stats.toJson(),
      'status': status.wire,
    };
    final sha = payloadSha256;
    if (sha != null) json['payloadSha256'] = sha;
    final ref = storage;
    if (ref != null) json['storage'] = ref.toJson();
    final created = createdAt;
    if (created != null) json['createdAt'] = created.toIso8601String();
    final updated = updatedAt;
    if (updated != null) json['updatedAt'] = updated.toIso8601String();
    return json;
  }

  factory PackManifest.fromJson(Map<String, dynamic> json) {
    return PackManifest(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      id: (json['id'] as String?) ?? '',
      type: PackType.tryParse(json['type']),
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      srcLang: (json['srcLang'] as String?) ?? '',
      dstLang: (json['dstLang'] as String?) ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
      level: (json['level'] as String?) ?? 'mixed',
      author: PackAuthor.fromJson(
        (json['author'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      license: PackLicense.tryParse(json['license']),
      version: (json['version'] as num?)?.toInt() ?? 1,
      payloadSha256: json['payloadSha256'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
      stats: PackStats.fromJson(json['stats'] as Map<String, dynamic>?),
      status: PackStatus.tryParse(json['status']) ?? PackStatus.pending,
      storage: json.containsKey('storage')
          ? PackStorageRef.fromJson(json['storage'] as Map<String, dynamic>?)
          : null,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? ''),
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? ''),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory PackManifest.fromJsonString(String source) =>
      PackManifest.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
