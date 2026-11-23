// lib/features/great_library/services/pack_contribution_service.dart
//
// GLIB-006 — wizard đóng góp pack (PLAN-049, ADR-0031 D6).
//
// Service thuần (test được, không plugin): build `.i4upack` từ nguồn user
// chọn (export-as-pack từ vocab của mình, hoặc soạn mới tay), kiểm quota
// client (50 MB/pack — PackFile.build đã chặn; 10 pack/tháng — ideation §6.2),
// upload qua PackStorageBackend, ghi doc `gl_contributions` pending qua
// transport, lưu bản ghi local để màn "Đóng góp của tôi" theo dõi.
//
// AI gợi ý metadata ở service riêng (contribution_ai_suggest.dart) — nút
// opt-in BYOK, mặc định TẮT, service này KHÔNG gọi mạng ngoài upload/submit.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/pack_manifest.dart';
import 'contribution_store.dart';
import 'pack_file.dart';
import 'pack_storage_backend.dart';

/// Item vocab user nhập trong wizard (word/meaning bắt buộc).
class ContributionVocabInput {
  const ContributionVocabInput({
    required this.word,
    required this.meaning,
    this.phonetic,
    this.example,
  });

  final String word;
  final String meaning;
  final String? phonetic;
  final String? example;

  bool get isValid => word.trim().isNotEmpty && meaning.trim().isNotEmpty;
}

/// Metadata user soạn ở bước 2 (có thể đã qua AI gợi ý + sửa lại).
class ContributionMetadata {
  const ContributionMetadata({
    required this.title,
    this.description = '',
    this.srcLang = 'en',
    this.dstLang = 'vi',
    this.tags = const <String>[],
    this.level = 'mixed',
    this.license = PackLicense.selfMade,
  });

  final String title;
  final String description;
  final String srcLang;
  final String dstLang;
  final List<String> tags;
  final String level;
  final PackLicense license;
}

/// Kết quả build+submit.
class ContributionResult {
  const ContributionResult({
    required this.status,
    required this.contributionId,
    this.errorCode,
  });

  final ContributionStatus status;
  final String contributionId;

  /// Mã lỗi ổn định khi status == failed (cho test + UI).
  final String? errorCode;
}

enum ContributionStatus { submitted, failed }

/// Cổng ghi doc `gl_contributions` (Firestore transport hoặc fake test).
abstract class ContributionTransport {
  /// Tạo doc pending; trả contributionId (docId). Ném khi chưa đăng nhập /
  /// mạng lỗi / rules chặn.
  Future<String> submitContribution({
    required String packId,
    required Map<String, dynamic> manifestJson,
    required String storageBackend,
    required String storagePath,
    required int zipBytes,
    required String sha256,
  });
}

/// Exception mã hoá cho UI.
class ContributionException implements Exception {
  const ContributionException(this.code, [this.detail = '']);

  final String code;
  final String detail;

  @override
  String toString() => 'ContributionException($code) $detail';
}

class PackContributionService {
  PackContributionService({
    required ContributionStore store,
    required PackStorageBackend storage,
    required ContributionTransport transport,
    required String authorUid,
    String authorName = '',
    DateTime Function()? clock,
  })  : _store = store,
        _storage = storage,
        _transport = transport,
        _authorUid = authorUid,
        _authorName = authorName.trim().isEmpty ? 'Người dùng In4Up' : authorName,
        _clock = clock ?? DateTime.now;

  final ContributionStore _store;
  final PackStorageBackend _storage;
  final ContributionTransport _transport;
  final String _authorUid;
  final String _authorName;
  final DateTime Function() _clock;

  /// Định danh pack: gl_user_<slug>_<rand6> — không trùng pack seed.
  static String newPackId(String title, DateTime now) {
    final slug = _slugify(title);
    final rand = (now.microsecondsSinceEpoch % 0xFFFFFF)
        .toRadixString(36)
        .padLeft(6, '0');
    return 'glu_${slug.isEmpty ? 'pack' : slug}_$rand';
  }

  static String _slugify(String text) {
    final buf = StringBuffer();
    for (final ch in text.toLowerCase().split('')) {
      if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
        buf.write(ch);
      } else if (ch == ' ' || ch == '-' || ch == '_') {
        buf.write('_');
      }
    }
    var slug = buf.toString();
    while (slug.contains('__')) {
      slug = slug.replaceAll('__', '_');
    }
    return slug.length > 32 ? slug.substring(0, 32) : slug;
  }

  int quotaUsedThisMonth() =>
      _store.countInMonth(_clock().millisecondsSinceEpoch);

  bool get quotaExceeded =>
      quotaUsedThisMonth() >= MemoryContributionStore.maxPerMonth;

  /// Build VocabPack từ danh sách từ (đã chạy TTS bulk trước đó ở tầng UI —
  /// [audioFiles] key = tên file media, bytes WAV/MP3). Ném
  /// [ContributionException] với mã ổn định.
  PackBuildResult buildVocabPack({
    required String packId,
    required ContributionMetadata meta,
    required List<ContributionVocabInput> items,
    Map<String, List<int>> audioFiles = const <String, List<int>>{},
  }) {
    if (quotaExceeded) {
      throw const ContributionException('quota-exceeded');
    }
    final valid = items.where((e) => e.isValid).toList(growable: false);
    if (valid.isEmpty) {
      throw const ContributionException('no-valid-items');
    }
    final entries = <Map<String, Object?>>[
      for (final e in valid)
        <String, Object?>{
          'word': e.word.trim(),
          'meaning': e.meaning.trim(),
          if (e.phonetic != null && e.phonetic!.trim().isNotEmpty)
            'phonetic': e.phonetic!.trim(),
          if (e.example != null && e.example!.trim().isNotEmpty)
            'example': e.example!.trim(),
          if (audioFiles.containsKey('${_slugify(e.word)}.wav'))
            'audio': '${_slugify(e.word)}.wav',
        },
    ];
    var payloadBytes = utf8.encode(jsonEncode(entries)).length;
    for (final b in audioFiles.values) {
      payloadBytes += b.length;
    }
    final manifest = PackManifest(
      id: packId,
      type: PackType.vocab,
      title: meta.title.trim(),
      description: meta.description.trim(),
      srcLang: meta.srcLang.trim(),
      dstLang: meta.dstLang.trim(),
      tags: meta.tags,
      level: meta.level,
      author: PackAuthor(uid: _authorUid, displayName: _authorName),
      license: meta.license,
      sizeBytes: payloadBytes,
      entryCount: entries.length,
      // Contribute luôn đi qua gl_contributions pending (D4).
      status: PackStatus.pending,
      storage: PackStorageRef(
        backend: _storage.backendId,
        path: 'contributions/$packId.i4upack',
      ),
      createdAt: _clock(),
      updatedAt: _clock(),
    );
    try {
      return PackFile.build(
        manifest: manifest,
        dataFiles: {'entries.json': utf8.encode(jsonEncode(entries))},
        mediaFiles: audioFiles,
      );
    } on FormatException catch (e) {
      throw ContributionException('manifest-invalid', e.message);
    } on StateError catch (e) {
      // payload-over-quota / payload-over-ceiling (50 MB mặc định).
      throw ContributionException('payload-over-quota', e.message);
    }
  }

  /// Upload pack + ghi gl_contributions pending + lưu local record.
  Future<ContributionResult> submit({
    required PackBuildResult pack,
    required String title,
  }) async {
    final manifest = pack.manifest;
    final ref = manifest.storage;
    if (ref == null) {
      return const ContributionResult(
          status: ContributionStatus.failed,
          contributionId: '',
          errorCode: 'storage-missing');
    }
    try {
      await _storage.upload(ref, pack.bytes);
    } on Object catch (e) {
      return ContributionResult(
          status: ContributionStatus.failed,
          contributionId: '',
          errorCode: 'upload-failed: $e');
    }
    final String contributionId;
    try {
      contributionId = await _transport.submitContribution(
        packId: manifest.id,
        manifestJson: manifest.toJson(),
        storageBackend: ref.backend,
        storagePath: ref.path,
        zipBytes: pack.bytes.length,
        sha256: pack.fileSha256,
      );
    } on Object catch (e) {
      return ContributionResult(
          status: ContributionStatus.failed,
          contributionId: '',
          errorCode: 'submit-failed: $e');
    }
    _store.add(ContributionRecord(
      contributionId: contributionId,
      packId: manifest.id,
      title: title,
      submittedAtMs: _clock().millisecondsSinceEpoch,
    ));
    return ContributionResult(
        status: ContributionStatus.submitted, contributionId: contributionId);
  }

  /// Gói tiện lợi cho wizard: build + submit một lần.
  Future<ContributionResult> buildAndSubmitVocab({
    required ContributionMetadata meta,
    required List<ContributionVocabInput> items,
    Map<String, List<int>> audioFiles = const <String, List<int>>{},
  }) async {
    final packId = newPackId(meta.title, _clock());
    final pack = buildVocabPack(
        packId: packId, meta: meta, items: items, audioFiles: audioFiles);
    return submit(pack: pack, title: meta.title.trim());
  }
}

/// Hữu ích cho UI hiển thị.
String describeContributionError(String code) => code;
