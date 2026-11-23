// lib/features/great_library/services/pack_content.dart
//
// GLIB-005 — Thư Viện Chung I4U (PLAN-049).
// Schema nội dung `data/` trong `.i4upack` + parser THUẦN (không IO, không
// Flutter) → plan đã kiểm chứng cho PackImportService route theo loại pack.
//
// Contract data/ (v1 — tool seed GLIB-008 ghi đúng schema này):
//  - VocabPack : data/entries.json — [{word, meaning, phonetic?, example?,
//                                      audio?, image?}]
//  - AudioPack : data/tracks.json  — [{file, title?, lrc?, durationSec?}]
//  - ImagePack : data/items.json   — [{image, caption?, word?}]
// `audio`/`image`/`file` là tên TƯƠNG ĐỐI trong media/; `lrc` trong data/.
// Mã lỗi ổn định (test bắt đúng mã): content-missing-data, content-bad-json,
// content-not-array, content-item-invalid, content-media-missing,
// content-type-unknown.

import 'dart:convert';

import '../models/pack_manifest.dart';
import 'pack_file.dart';

/// Một mục từ vựng trong VocabPack.
class PackVocabItem {
  const PackVocabItem({
    required this.word,
    required this.meaning,
    this.phonetic,
    this.example,
    this.audioName,
    this.imageName,
  });

  final String word;
  final String meaning;
  final String? phonetic;
  final String? example;

  /// Tên file trong media/ (đã kiểm tồn tại lúc parse).
  final String? audioName;
  final String? imageName;
}

/// Một track trong AudioPack.
class PackAudioTrack {
  const PackAudioTrack({
    required this.fileName,
    required this.title,
    this.lrcName,
    this.durationSec,
  });

  /// Tên file trong media/ (đã kiểm tồn tại lúc parse).
  final String fileName;
  final String title;

  /// Tên file LRC trong data/ (đã kiểm tồn tại lúc parse).
  final String? lrcName;
  final int? durationSec;
}

/// Một ảnh trong ImagePack.
class PackImageItem {
  const PackImageItem({
    required this.imageName,
    this.caption = '',
    this.word,
  });

  /// Tên file trong media/ (đã kiểm tồn tại lúc parse).
  final String imageName;
  final String caption;
  final String? word;
}

/// Plan nội dung đã parse + validate — base cho 3 loại.
sealed class PackContentPlan {
  const PackContentPlan(this.manifest);

  final PackManifest manifest;

  /// Số mục nội dung (để UI/result báo).
  int get itemCount;
}

class VocabPackPlan extends PackContentPlan {
  const VocabPackPlan(super.manifest, this.items);

  final List<PackVocabItem> items;

  @override
  int get itemCount => items.length;
}

class AudioPackPlan extends PackContentPlan {
  const AudioPackPlan(super.manifest, this.tracks);

  final List<PackAudioTrack> tracks;

  @override
  int get itemCount => tracks.length;
}

class ImagePackPlan extends PackContentPlan {
  const ImagePackPlan(super.manifest, this.items);

  final List<PackImageItem> items;

  @override
  int get itemCount => items.length;
}

class PackContent {
  PackContent._();

  /// Parse [contents] thành plan theo `manifest.type`.
  /// Ném [FormatException] với message bắt đầu bằng mã lỗi ổn định.
  static PackContentPlan parse(PackContents contents) {
    final manifest = contents.manifest;
    switch (manifest.type) {
      case PackType.vocab:
        return VocabPackPlan(manifest, _parseVocab(contents));
      case PackType.audio:
        return AudioPackPlan(manifest, _parseAudio(contents));
      case PackType.image:
        return ImagePackPlan(manifest, _parseImageItems(contents));
      case null:
        throw const FormatException('content-type-unknown');
    }
  }

  // ---------------------------------------------------------------- helpers

  static List<dynamic> _readArray(
      PackContents contents, String name, String missingCode) {
    final raw = contents.dataFiles[name];
    if (raw == null) throw FormatException(missingCode);
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(raw));
    } on Object {
      throw FormatException('content-bad-json: $name');
    }
    if (decoded is! List) {
      throw FormatException('content-not-array: $name');
    }
    return decoded;
  }

  static Map<String, dynamic> _asMap(Object? item, String code) {
    if (item is! Map) throw FormatException(code);
    return item.cast<String, dynamic>();
  }

  static String _reqString(Map<String, dynamic> map, String key, String code) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$code: thiếu "$key"');
    }
    return value.trim();
  }

  static String? _optString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static void _requireMedia(PackContents contents, String name) {
    if (!contents.mediaFiles.containsKey(name)) {
      throw FormatException('content-media-missing: $name');
    }
  }

  static void _requireData(PackContents contents, String name) {
    if (!contents.dataFiles.containsKey(name)) {
      throw FormatException('content-media-missing: data/$name');
    }
  }

  // ------------------------------------------------------------------ vocab

  static List<PackVocabItem> _parseVocab(PackContents contents) {
    final rows = _readArray(contents, 'entries.json', 'content-missing-data');
    final items = <PackVocabItem>[];
    for (final row in rows) {
      final map = _asMap(row, 'content-item-invalid');
      final audio = _optString(map, 'audio');
      final image = _optString(map, 'image');
      if (audio != null) _requireMedia(contents, audio);
      if (image != null) _requireMedia(contents, image);
      items.add(PackVocabItem(
        word: _reqString(map, 'word', 'content-item-invalid'),
        meaning: _reqString(map, 'meaning', 'content-item-invalid'),
        phonetic: _optString(map, 'phonetic'),
        example: _optString(map, 'example'),
        audioName: audio,
        imageName: image,
      ));
    }
    return items;
  }

  // ------------------------------------------------------------------ audio

  static List<PackAudioTrack> _parseAudio(PackContents contents) {
    final rows = _readArray(contents, 'tracks.json', 'content-missing-data');
    final tracks = <PackAudioTrack>[];
    for (final row in rows) {
      final map = _asMap(row, 'content-item-invalid');
      final file = _reqString(map, 'file', 'content-item-invalid');
      _requireMedia(contents, file);
      final lrc = _optString(map, 'lrc');
      if (lrc != null) _requireData(contents, lrc);
      final duration = map['durationSec'];
      tracks.add(PackAudioTrack(
        fileName: file,
        title: _optString(map, 'title') ?? file,
        lrcName: lrc,
        durationSec: duration is num ? duration.toInt() : null,
      ));
    }
    return tracks;
  }

  // ------------------------------------------------------------------ image

  static List<PackImageItem> _parseImageItems(PackContents contents) {
    final rows = _readArray(contents, 'items.json', 'content-missing-data');
    final items = <PackImageItem>[];
    for (final row in rows) {
      final map = _asMap(row, 'content-item-invalid');
      final image = _reqString(map, 'image', 'content-item-invalid');
      _requireMedia(contents, image);
      items.add(PackImageItem(
        imageName: image,
        caption: _optString(map, 'caption') ?? '',
        word: _optString(map, 'word'),
      ));
    }
    return items;
  }
}
