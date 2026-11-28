// lib/features/great_library/services/pack_import_sinks_io.dart
//
// GLIB-005 — Thư Viện Chung I4U (PLAN-049).
// Sink production (native, dart:io): Vocab → VocabularyProvider (+ ảnh qua
// VocabImageService); Audio → file persistent audio_imports/gl_<packId>/ +
// chỉ mục audio library + bind LRC (SourceArtifactStore); Image → kho
// vocabulary_images + index per-pack trong SharedPreferences.
//
// NGUYÊN TẮC ADDITIVE (KANBAN GLIB-005, không đụng ADR-0001): mọi merge chỉ
// ĐIỀN field còn trống — không ghi đè meaning/phonetic/example/SM-2 của user.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/audio_library_entry.dart';
import '../../../models/word_entry.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../services/audio_import_service.dart';
import '../../../services/source_artifact_store.dart';
import '../../../services/storage_service.dart';
import '../../vocab_image/vocab_image_service.dart';
import 'pack_content.dart';
import 'pack_import_service.dart';

/// InstalledPackStore bền vững qua SharedPreferences (key json map).
class PrefsInstalledPackStore implements InstalledPackStore {
  static const String key = 'gl_installed_packs';

  @override
  Future<Map<String, int>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return decoded.map((k, v) =>
          MapEntry('$k', v is num ? v.toInt() : int.tryParse('$v') ?? 0));
    } on Object {
      return <String, int>{};
    }
  }

  @override
  Future<void> writeAll(Map<String, int> versions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(versions));
  }
}

/// Vocab → WordEntry qua VocabularyProvider (đường vocab hiện có).
class GlVocabPackSink implements PackVocabSink {
  GlVocabPackSink({VocabularyProvider? vocabulary, VocabImageService? images})
      : _vocabulary = vocabulary ?? VocabularyProvider(),
        _images = images ?? VocabImageService.instance;

  final VocabularyProvider _vocabulary;
  final VocabImageService _images;

  @override
  Future<PackSinkResult> importVocab(
    VocabPackPlan plan,
    PackMediaLookup media, {
    required bool isUpdate,
  }) async {
    var added = 0;
    var merged = 0;
    var skipped = 0;
    final manifest = plan.manifest;
    final packTag = 'gl:${manifest.id}';

    for (final item in plan.items) {
      final existing = _vocabulary.findByWord(item.word);
      if (existing == null) {
        String? imagePath;
        final imageName = item.imageName;
        if (imageName != null) {
          final bytes = media.bytes(imageName);
          if (bytes != null) imagePath = await _images.saveFromBytes(bytes);
        }
        _vocabulary.addWord(WordEntry(
          id: 'gl_${manifest.id}_${_slug(item.word)}',
          word: item.word,
          meaning: item.meaning,
          phonetic: item.phonetic,
          phoneticSource:
              (item.phonetic ?? '').trim().isEmpty ? null : 'user',
          example: item.example,
          imageUrl: imagePath,
          tags: [...manifest.tags, packTag],
          language: manifest.srcLang.isEmpty ? 'en' : manifest.srcLang,
          topics: manifest.tags,
        ));
        added++;
        continue;
      }

      // ── Additive merge: chỉ điền field TRỐNG, không đụng SM-2/text user ──
      var changed = false;
      if (existing.meaning.trim().isEmpty && item.meaning.trim().isNotEmpty) {
        existing.meaning = item.meaning;
        changed = true;
      }
      if ((existing.phonetic ?? '').trim().isEmpty &&
          (item.phonetic ?? '').trim().isNotEmpty) {
        existing.phonetic = item.phonetic;
        existing.phoneticSource = 'user';
        changed = true;
      }
      if ((existing.example ?? '').trim().isEmpty &&
          (item.example ?? '').trim().isNotEmpty) {
        existing.example = item.example;
        changed = true;
      }
      final imageName = item.imageName;
      if (imageName != null) {
        final bytes = media.bytes(imageName);
        if (bytes != null) {
          if ((existing.imageUrl ?? '').trim().isEmpty) {
            final path = await _images.saveFromBytes(bytes);
            if (path != null) {
              existing.imageUrl = path;
              changed = true;
            }
          } else if ((existing.imageUrl2 ?? '').trim().isEmpty) {
            final path = await _images.saveFromBytes(bytes);
            if (path != null) {
              existing.imageUrl2 = path;
              changed = true;
            }
          }
        }
      }
      if (!existing.tags.contains(packTag)) {
        existing.tags.add(packTag);
        changed = true;
      }
      if (changed) {
        existing.updatedAt = DateTime.now();
        // updateWord(id) không tham số: chỉ persist + notify entry đã mutate.
        _vocabulary.updateWord(existing.id);
        merged++;
      } else {
        skipped++;
      }
    }
    return PackSinkResult(added: added, merged: merged, skipped: skipped);
  }

  String _slug(String word) {
    final slug = word
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'item' : slug;
  }
}

/// Audio → audio_imports/gl_<packId>/ + chỉ mục thư viện + bind LRC sidecar.
class GlAudioPackSink implements PackAudioSink {
  GlAudioPackSink({
    Future<Directory> Function()? documentsDir,
    StorageService? storage,
    SourceArtifactStore? artifacts,
  })  : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory,
        _storage = storage ?? StorageService(),
        _artifacts = artifacts ?? SourceArtifactStore.instance;

  final Future<Directory> Function() _documentsDir;
  final StorageService _storage;
  final SourceArtifactStore _artifacts;

  @override
  Future<PackSinkResult> importAudio(
    AudioPackPlan plan,
    PackMediaLookup media,
    Map<String, Uint8List> dataFiles, {
    required bool isUpdate,
  }) async {
    final root = await _documentsDir();
    final dir =
        Directory(p.join(root.path, AudioImportService.importDirName,
            'gl_${plan.manifest.id}'));
    if (!await dir.exists()) await dir.create(recursive: true);

    var added = 0;
    var skipped = 0;
    for (final track in plan.tracks) {
      final bytes = media.bytes(track.fileName);
      if (bytes == null) {
        skipped++;
        continue;
      }
      final file = File(p.join(dir.path, track.fileName));
      // Dedup: cùng tên + cùng độ dài → coi như đã import (không ghi đè).
      final exists = await file.exists() && await file.length() == bytes.length;
      if (!exists) {
        await file.writeAsBytes(bytes, flush: true);
      }

      final lrcName = track.lrcName;
      if (lrcName != null && dataFiles.containsKey(lrcName)) {
        final lrcFile = File(p.join(dir.path, lrcName));
        await lrcFile.writeAsBytes(dataFiles[lrcName]!, flush: true);
        await _artifacts.rememberLrc(
          audioPath: file.path,
          lrcPath: lrcFile.path,
        );
      }

      await _storage.saveAudioLibraryEntry(AudioLibraryEntry(
        libraryId: 'gl_${plan.manifest.id}_${_safeId(track.fileName)}',
        uri: file.path,
        title: track.title,
        folder: 'gl_${plan.manifest.id}',
        durationMs: (track.durationSec ?? 0) * 1000,
        sizeBytes: bytes.length,
        source: AudioSource.picked,
        addedAt: DateTime.now(),
      ));
      added++;
    }
    return PackSinkResult(added: added, skipped: skipped);
  }

  String _safeId(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
}

/// ImagePack → kho vocabulary_images (dùng chung với flashcard picker) +
/// index per-pack (caption/word) trong SharedPreferences.
class GlImagePackSink implements PackImageSink {
  GlImagePackSink({VocabImageService? images})
      : _images = images ?? VocabImageService.instance;

  final VocabImageService _images;

  static String indexKey(String packId) => 'gl_pack_images_$packId';

  @override
  Future<PackSinkResult> importImages(
    ImagePackPlan plan,
    PackMediaLookup media, {
    required bool isUpdate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = indexKey(plan.manifest.id);
    final existing = <Map<String, dynamic>>[];
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          existing.addAll(decoded.whereType<Map>()
              .map((e) => e.cast<String, dynamic>()));
        }
      } on Object {
        // index hỏng → dựng lại từ đầu (dữ liệu ảnh vẫn nằm trong kho).
      }
    }
    final knownPaths = existing.map((e) => e['path'] as String?).toSet();

    var added = 0;
    var skipped = 0;
    for (final item in plan.items) {
      final bytes = media.bytes(item.imageName);
      if (bytes == null) {
        skipped++;
        continue;
      }
      final path = await _images.saveFromBytes(bytes);
      if (path == null || knownPaths.contains(path)) {
        skipped++;
        continue;
      }
      existing.add(<String, dynamic>{
        'path': path,
        'caption': item.caption,
        if (item.word != null) 'word': item.word,
      });
      knownPaths.add(path);
      added++;
    }
    await prefs.setString(key, jsonEncode(existing));
    return PackSinkResult(added: added, skipped: skipped);
  }
}
