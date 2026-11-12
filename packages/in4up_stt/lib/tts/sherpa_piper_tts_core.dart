// ignore_for_file: unintended_html_in_doc_comment
// packages/in4up_stt/lib/tts/sherpa_piper_tts_core.dart
//
// SherpaPiperTtsCore — Piper TTS (FastSpeech2 + HiFiGAN, CPU-friendly)
// qua sherpa_onnx. PLAN-009 step "TTS VITS/Piper — offline hoàn toàn".
//
// API v1.13.4 VERIFY từ source k2-fsa/sherpa-onnx (tag v1.13.4) + ví dụ
// chính thức dart-api-examples/tts/bin/piper.dart:
//
//   OfflineTtsVitsModelConfig(model, tokens, dataDir)   // Piper = VITS config
//   OfflineTtsModelConfig(vits: ..., numThreads: N)
//   OfflineTtsConfig(model: ..., maxNumSenetences: N)
//   tts.generateWithConfig(text:, config:, [onProgress:]) -> Audio{samples, sampleRate}
//
// Convention file (khớp bộ model Piper trên local user):
//   <modelsFolder>/
//     espeak-ng-data/            ← thư mục phonemizer (DÙNG CHUNG)
//     calmwoman3688.onnx         ← model giọng
//     calmwoman3688.onnx.json    ← config (chứa audio.sample_rate)
//     calmwoman3688_tokens.txt   ← tokens
//
//   Một "giọng" = 1 bộ (name.onnx + name_tokens.txt).
//   <name>.onnx.json đọc để lấy sample_rate (fallback 22050 — chuẩn Piper).
//
// PSRC-187 (audit 1.27.0) — ba thay đổi, đều có số đo/đối chiếu thật trong
// card PSRC-187 của KANBAN:
//   1. KHÁM + CHỮA giọng trước khi xuống native (`piper_voice_doctor.dart`):
//      sherpa-onnx `_Exit(-1)` khi model thiếu metadata / tokens sai / espeak
//      thiếu file — Dart không bắt được. Giọng Piper gốc của rhasspy (bộ
//      `.onnx` + `.onnx.json`) được thêm metadata còn thiếu để dùng được.
//   2. `maxNumSenetences: 1` thay cho 100: với 100, cả dòng dài bị nhồi vào
//      MỘT lượt chạy model — đo trên `vi_VN-vais1000-medium` (máy tính
//      x86-64, KHÔNG phải trên thiết bị): 786 ký tự ⇒ 935 MB, 2751 ký tự ⇒
//      3,4 GB RAM đỉnh. Mức đó nhiều khả năng đủ để Android giết app — đây là
//      suy ra từ số đo, chưa đo trên máy thật. Với 1: ~378 MB ở cả hai độ
//      dài đã đo, tổng hợp nhanh hơn 1,6–2,9 lần.
//   3. `OfflineTts` + generate chạy trong WORKER ISOLATE (`isolate_rpc.dart`)
//      như ví dụ Flutter chính thức của sherpa-onnx — trước đây là lời gọi
//      FFI đồng bộ trên luồng UI (vài giây tới hàng chục giây đứng hình).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../sherpa_bindings.dart';
import '../utils/src/isolate_rpc.dart';
import 'piper_import_paths.dart';
import 'piper_voice_doctor.dart';

/// Số câu sherpa-onnx đưa vào MỘT lượt chạy model.
///
/// PHẢI là 1 (đúng như mọi ví dụ chính thức của sherpa-onnx). Giá trị lớn hơn
/// nối mọi câu thành một chuỗi token duy nhất ⇒ bộ nhớ tăng theo BÌNH PHƯƠNG
/// độ dài văn bản (attention) — xem số đo ở đầu file.
const int kPiperMaxSentencesPerBatch = 1;

/// Kết quả khám một giọng Piper trước khi đưa xuống native (PSRC-187).
class PiperVoiceDiagnosis {
  const PiperVoiceDiagnosis.usable({this.repaired = const <String>[]})
      : problem = null;

  const PiperVoiceDiagnosis.blocked(String this.problem)
      : repaired = const <String>[];

  /// `null` = dùng được. Khác null = mã lý do KHÔNG được đưa xuống native,
  /// ví dụ `espeak:phonindex,phondata`, `model:missing:sample_rate`,
  /// `model:unsupported-frontend`, `tokens:duplicate:12`.
  final String? problem;

  /// Những thứ đã được chữa trong lần khám này: `metadata`, `tokens`.
  final List<String> repaired;

  bool get isUsable => problem == null;

  @override
  String toString() {
    if (problem != null) return 'blocked: $problem';
    if (repaired.isEmpty) return 'usable';
    return 'usable (repaired: ${repaired.join(', ')})';
  }
}

/// Handler chạy TRONG worker isolate: giữ `OfflineTts` và gọi native ở đó.
///
/// sherpa-onnx phải được `initBindings()` trong MỖI isolate dùng API của nó
/// (ghi chú trong ví dụ Flutter chính thức) — [ensureSherpaBindings] giữ cờ
/// theo từng isolate nên gọi lại ở đây là đúng.
IsolateRpcHandler _piperWorkerFactory() {
  sherpa.OfflineTts? tts;
  return (String command, Map<String, Object?> args) {
    switch (command) {
      case 'select':
        ensureSherpaBindings();
        try {
          tts?.free();
        } catch (_) {}
        tts = null;
        final created = sherpa.OfflineTts(
          sherpa.OfflineTtsConfig(
            model: sherpa.OfflineTtsModelConfig(
              vits: sherpa.OfflineTtsVitsModelConfig(
                model: args['model'] as String,
                tokens: args['tokens'] as String,
                dataDir: args['dataDir'] as String,
              ),
              numThreads: (args['numThreads'] as int?) ?? 2,
              debug: args['debug'] == true,
            ),
            maxNumSenetences: kPiperMaxSentencesPerBatch,
          ),
        );
        tts = created;
        return <String, Object?>{
          'sampleRate': created.sampleRate,
          'numSpeakers': created.numSpeakers,
        };
      case 'generate':
        final engine = tts;
        if (engine == null) throw StateError('no Piper voice loaded');
        final audio = engine.generateWithConfig(
          text: args['text'] as String,
          config: sherpa.OfflineTtsGenerationConfig(
            sid: (args['sid'] as int?) ?? 0,
            speed: (args['speed'] as num?)?.toDouble() ?? 1.0,
            silenceScale: 0.2,
          ),
        );
        return <String, Object?>{
          'samples': audio.samples,
          'sampleRate': audio.sampleRate,
        };
      case 'release':
        try {
          tts?.free();
        } catch (_) {}
        tts = null;
        return null;
    }
    throw ArgumentError('unknown Piper worker command: $command');
  };
}

/// Model tại [path] có mục metadata `sample_rate` ở BẤT KỲ đâu trong file
/// không. Hàm top-level để chạy bằng `compute` (quét cả file 60 MB không được
/// nằm trên luồng UI).
bool _modelMentionsSampleRate(String path) =>
    _fileContainsBytesSync(path, kOnnxSampleRateKeyNeedle);

/// Dò [needle] trong toàn bộ file (đọc theo khối 1 MB). Dùng khi 64 KB cuối
/// file ONNX không thấy metadata.
bool _fileContainsBytesSync(String path, Uint8List needle) {
  final raf = File(path).openSync();
  try {
    const chunkSize = 1 << 20;
    final overlap = needle.length - 1;
    var carry = Uint8List(0);
    while (true) {
      final chunk = raf.readSync(chunkSize);
      if (chunk.isEmpty) return false;
      final buffer = Uint8List(carry.length + chunk.length)
        ..setAll(0, carry)
        ..setAll(carry.length, chunk);
      if (containsBytes(buffer, needle)) return true;
      carry = buffer.length > overlap
          ? Uint8List.fromList(
              Uint8List.sublistView(buffer, buffer.length - overlap),
            )
          : buffer;
    }
  } finally {
    raf.closeSync();
  }
}

/// Một giọng Piper phát hiện được trong thư mục model.
class PiperTtsVoice {
  final String name;
  final String modelPath;
  final String tokensPath;
  final String dataDir;
  final int sampleRate;

  const PiperTtsVoice({
    required this.name,
    required this.modelPath,
    required this.tokensPath,
    required this.dataDir,
    required this.sampleRate,
  });
}

/// Kết quả generate (PCM float32 mono [-1,1] + sample rate).
class PiperTtsAudio {
  final Float32List samples;
  final int sampleRate;

  const PiperTtsAudio({required this.samples, required this.sampleRate});
}

class SherpaPiperTtsCore {
  /// Thư mục model — đặt CÙNG quy ước với VAD (documents/...).
  /// Android: /sdcard/Android/data/<pkg>/documents/sherpa_piper_models/
  /// Windows: %LOCALAPPDATA%\<org>\<app>_documents/sherpa_piper_models/
  static const String modelsFolderName = 'sherpa_piper_models';
  static const String espeakDataFolder = 'espeak-ng-data';

  static const int defaultPiperSampleRate = 22050;

  /// Language từ tên file giọng (quy ước Piper `xx_XX-...` hoặc prefix `vits-piper-xx_XX-...`);
  /// Tự động bóc tách prefix và nhận diện cả các tên model phổ biến (vi_VN, 25hours, vais1000, libritts...).
  /// Trả về BCP-47 chuẩn (e.g. `vi-VN`, `en-US`) hoặc `''` nếu không nhận diện được.
  static String langFromVoiceName(String name) {
    var clean = name.trim();
    if (clean.toLowerCase().endsWith('.onnx')) {
      clean = clean.substring(0, clean.length - '.onnx'.length);
    }

    // Bóc tách prefix thường gặp trong sherpa-onnx / piper bundles
    const prefixes = [
      'sherpa-onnx-vits-piper-',
      'sherpa_onnx_vits_piper_',
      'sherpa-onnx-vits-',
      'sherpa_onnx_vits_',
      'sherpa-onnx-',
      'sherpa_onnx_',
      'vits-piper-',
      'vits_piper_',
      'vits-vits-piper-',
      'vits-',
      'vits_',
      'piper-',
      'piper_',
    ];
    for (final pfx in prefixes) {
      if (clean.toLowerCase().startsWith(pfx)) {
        clean = clean.substring(pfx.length);
        break;
      }
    }

    // 1. Chuẩn xx_XX hoặc xx-XX ở đầu tên (e.g. `vi_VN-25hours`, `en_US-libritts`)
    final mStandard =
        RegExp(r'^([a-z]{2})[_-]([A-Za-z]{2})(?:[-_].*)?$', caseSensitive: false)
            .firstMatch(clean);
    if (mStandard != null) {
      return '${mStandard.group(1)!.toLowerCase()}-${mStandard.group(2)!.toUpperCase()}';
    }

    // 2. Chuẩn xx_... hoặc xx-... ở đầu tên (e.g. `vi_25hours`, `vi_vais1000`, `en_libritts`)
    final mBare = RegExp(r'^([a-z]{2})[-_].*$', caseSensitive: false).firstMatch(clean);
    if (mBare != null) {
      final code = mBare.group(1)!.toLowerCase();
      switch (code) {
        case 'vi':
          return 'vi-VN';
        case 'en':
          return 'en-US';
        case 'zh':
          return 'zh-CN';
        case 'fr':
          return 'fr-FR';
        case 'de':
          return 'de-DE';
        case 'es':
          return 'es-ES';
        case 'hi':
          return 'hi-IN';
        case 'ja':
          return 'ja-JP';
        case 'ko':
          return 'ko-KR';
        case 'th':
          return 'th-TH';
        case 'my':
          return 'my-MM';
        case 'km':
          return 'km-KH';
        case 'lo':
          return 'lo-LA';
        case 'si':
          return 'si-LK';
        case 'pi':
          return 'pi-IN';
        case 'sa':
          return 'sa-IN';
        case 'ta':
          return 'ta-IN';
        case 'bn':
          return 'bn-IN';
      }
    }

    // 3. Quét từ khóa ngôn ngữ / tên model phổ biến trong toàn bộ tên
    final lower = clean.toLowerCase();
    if (lower.contains('vietnamese') ||
        lower.contains('viettts') ||
        lower.contains('vais1000') ||
        lower.contains('25hours') ||
        lower.contains('vipsound') ||
        lower.contains('vi_vn') ||
        lower.contains('vi-vn')) {
      return 'vi-VN';
    }
    if (lower.contains('en_gb') || lower.contains('en-gb') || lower.contains('british')) {
      return 'en-GB';
    }
    if (lower.contains('english') ||
        lower.contains('libritts') ||
        lower.contains('lessac') ||
        lower.contains('alan') ||
        lower.contains('amy') ||
        lower.contains('ryan') ||
        lower.contains('en_us') ||
        lower.contains('en-us')) {
      return 'en-US';
    }
    if (lower.contains('french') || lower.contains('francais') || lower.contains('fr_fr') || lower.contains('fr-fr')) {
      return 'fr-FR';
    }
    if (lower.contains('german') || lower.contains('deutsch') || lower.contains('de_de') || lower.contains('de-de')) {
      return 'de-DE';
    }
    if (lower.contains('spanish') || lower.contains('espanol') || lower.contains('es_es') || lower.contains('es-es')) {
      return 'es-ES';
    }
    if (lower.contains('hindi') || lower.contains('hi_in') || lower.contains('hi-in')) {
      return 'hi-IN';
    }
    if (lower.contains('chinese') || lower.contains('mandarin') || lower.contains('zh_cn') || lower.contains('zh-cn') || lower.contains('cmn')) {
      return 'zh-CN';
    }
    if (lower.contains('japanese') || lower.contains('nihongo') || lower.contains('ja_jp') || lower.contains('ja-jp')) {
      return 'ja-JP';
    }
    if (lower.contains('korean') || lower.contains('ko_kr') || lower.contains('ko-kr')) {
      return 'ko-KR';
    }
    if (lower.contains('thai') || lower.contains('th_th') || lower.contains('th-th')) {
      return 'th-TH';
    }
    if (lower.contains('pali') || lower.contains('pli')) {
      return 'pi-IN';
    }
    if (lower.contains('sanskrit') || lower.contains('san')) {
      return 'sa-IN';
    }

    return '';
  }

  /// Worker isolate đang giữ `OfflineTts` (PSRC-187).
  IsolateRpcClient? _worker;
  Future<IsolateRpcClient>? _workerStarting;
  PiperTtsVoice? _activeVoice;
  String? _lastProblem;

  PiperTtsVoice? get activeVoice => _activeVoice;

  /// Lý do lần [selectVoice] gần nhất thất bại (mã của [PiperVoiceDiagnosis]
  /// hoặc `native:<lỗi>`), `null` nếu thành công.
  String? get lastProblem => _lastProblem;

  /// Phonemizer (espeak-ng-data) đã sẵn sàng.
  ///
  /// ★ BẮT BUỘC kiểm tra TRƯỚC khi tạo `OfflineTts`: sherpa-onnx (C++)
  /// khởi tạo espeak lúc init — thiếu dữ liệu thì espeak gọi `exit(1)`, cả
  /// app biến mất (Dart try/catch không bắt được).
  ///
  /// PSRC-187: trước đây chỉ kiểm `phontab`. Đã đối chiếu với sherpa-onnx
  /// 1.13.6 thật: thư mục CHỈ có `phontab` vẫn làm tiến trình thoát ở
  /// `phonindex` ⇒ nay phải đủ cả 4 file trong [kEspeakRequiredDataFiles].
  static Future<bool> isEspeakReady() async {
    try {
      final dir = await _modelsDir();
      return missingEspeakFiles(p.join(dir.path, espeakDataFolder)).isEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Các file bắt buộc của espeak-ng-data đang THIẾU (hoặc rỗng) trong
  /// [dataDir].
  static List<String> missingEspeakFiles(String dataDir) {
    final missing = <String>[];
    for (final name in kEspeakRequiredDataFiles) {
      try {
        final file = File(p.join(dataDir, name));
        if (!file.existsSync() || file.lengthSync() <= 64) missing.add(name);
      } catch (_) {
        missing.add(name);
      }
    }
    return missing;
  }

  static final Map<String, PiperVoiceDiagnosis> _diagnosisCache =
      <String, PiperVoiceDiagnosis>{};

  static String? _voiceIdentity(PiperTtsVoice voice) {
    try {
      final model = File(voice.modelPath).statSync();
      final tokens = File(voice.tokensPath).statSync();
      if (model.type == FileSystemEntityType.notFound ||
          tokens.type == FileSystemEntityType.notFound) {
        return null;
      }
      return '${voice.modelPath}|${model.size}|'
          '${model.modified.millisecondsSinceEpoch}|${tokens.size}|'
          '${tokens.modified.millisecondsSinceEpoch}';
    } catch (_) {
      return null;
    }
  }

  /// KHÁM một giọng trước khi đưa xuống native, CHỮA những gì chữa được
  /// (PSRC-187 — luật và bằng chứng: `piper_voice_doctor.dart`).
  ///
  /// Thứ tự: espeak-ng-data đủ file → kích thước file → metadata ONNX (thiếu
  /// thì thêm từ `<voice>.onnx.json`) → tokens.txt (chuẩn hoá / sinh lại từ
  /// config). Kết quả "dùng được" được nhớ theo kích thước + mtime của file
  /// nên các câu sau không phải đọc lại.
  static Future<PiperVoiceDiagnosis> examineVoice(PiperTtsVoice voice) async {
    final missingEspeak = missingEspeakFiles(voice.dataDir);
    if (missingEspeak.isNotEmpty) {
      return PiperVoiceDiagnosis.blocked('espeak:${missingEspeak.join(',')}');
    }
    final before = _voiceIdentity(voice);
    if (before == null) {
      return const PiperVoiceDiagnosis.blocked('files:missing');
    }
    final cached = _diagnosisCache[before];
    if (cached != null) return cached;

    PiperVoiceDiagnosis result;
    try {
      result = await _examineVoiceUncached(voice);
    } catch (e) {
      result = PiperVoiceDiagnosis.blocked('exam-failed:$e');
    }
    // Chỉ nhớ kết quả TỐT: giọng bị chặn có thể được người dùng sửa (cài
    // phonemizer, import lại) mà không đổi kích thước file model.
    if (result.isUsable) {
      final after = _voiceIdentity(voice);
      if (after != null) {
        _diagnosisCache[after] = const PiperVoiceDiagnosis.usable();
      }
    }
    return result;
  }

  static Future<PiperVoiceDiagnosis> _examineVoiceUncached(
    PiperTtsVoice voice,
  ) async {
    if (!isVoiceFilesPlausible(voice)) {
      return const PiperVoiceDiagnosis.blocked('files:too-small');
    }
    final repaired = <String>[];

    // Config Piper gốc (nếu có) — nguồn sự thật cho metadata + bảng token.
    String? configJson;
    try {
      final config = File('${voice.modelPath}.json');
      if (config.existsSync()) configJson = await config.readAsString();
    } catch (_) {
      configJson = null;
    }

    // ── Metadata ONNX ────────────────────────────────────────────────────
    var meta = await _readModelMetadata(voice.modelPath);
    var verdict = assessSherpaVitsMetadata(meta);
    // Model đi qua bộ phát âm Piper ⇒ tokens phải có `_ ^ $`.
    var needSymbols = verdict.usesPiperPhonemizer;
    if (verdict.isMissingRequired) {
      final derived =
          configJson == null ? null : sherpaMetadataFromPiperConfig(configJson);
      // `sample_rate` có nằm đâu đó trong file mà phần đuôi không đọc ra
      // không? (phòng model được ghi theo thứ tự trường khác thường)
      final hasSampleRate = meta.containsKey('sample_rate') ||
          await compute(_modelMentionsSampleRate, voice.modelPath);
      if (hasSampleRate && (meta.isEmpty || derived == null)) {
        // Metadata CÓ nhưng không đọc đủ được từ đuôi file ⇒ không chặn oan
        // một giọng đang dùng tốt, không ghi thêm gì: giữ hành vi cũ.
        debugPrint(
          'ℹ️ SherpaPiperTtsCore: ${voice.name} có metadata nhưng không đọc '
          'đủ từ đuôi file (${verdict.problem}) — bỏ qua bước kiểm metadata',
        );
        needSymbols = false;
      } else if (derived == null) {
        // Không có `sample_rate` ở đâu trong file và không có config Piper để
        // suy ra ⇒ native CHẮC CHẮN thoát. Chặn.
        return PiperVoiceDiagnosis.blocked('model:${verdict.problem}');
      } else {
        final toAdd = <String, String>{
          for (final entry in derived.entries)
            if ((meta[entry.key] ?? '').isEmpty) entry.key: entry.value,
        };
        if (!await _appendModelMetadata(voice.modelPath, toAdd)) {
          return const PiperVoiceDiagnosis.blocked('model:repair-failed');
        }
        meta = await _readModelMetadata(voice.modelPath);
        verdict = assessSherpaVitsMetadata(meta);
        if (!verdict.isSafe) {
          return PiperVoiceDiagnosis.blocked('model:${verdict.problem}');
        }
        needSymbols = verdict.usesPiperPhonemizer;
        repaired.add('metadata');
        debugPrint(
          '🩺 SherpaPiperTtsCore: ${voice.name} là giọng Piper GỐC (thiếu '
          'metadata sherpa-onnx) — đã thêm ${toAdd.keys.join(', ')} từ '
          '${p.basename(voice.modelPath)}.json',
        );
      }
    } else if (!verdict.isSafe) {
      return PiperVoiceDiagnosis.blocked('model:${verdict.problem}');
    }

    // ── tokens.txt ───────────────────────────────────────────────────────
    final tokensFile = File(voice.tokensPath);
    final rawTokens =
        utf8.decode(await tokensFile.readAsBytes(), allowMalformed: true);
    var tokensProblem =
        validatePiperTokens(rawTokens, requirePiperSymbols: needSymbols);
    if (tokensProblem != null) {
      // 1) chuẩn hoá (BOM / CRLF / dòng trống / khoảng trắng cuối dòng)
      var fixed = normalizePiperTokens(rawTokens);
      tokensProblem =
          validatePiperTokens(fixed, requirePiperSymbols: needSymbols);
      // 2) vẫn hỏng ⇒ sinh lại từ `phoneme_id_map` của config Piper (chỉ khi
      //    đây là file tokens RIÊNG của giọng — không ghi đè `tokens.txt`
      //    dùng chung bằng bảng của một giọng).
      final ownTokens =
          p.basename(voice.tokensPath).toLowerCase() != 'tokens.txt';
      if (tokensProblem != null && configJson != null && ownTokens) {
        final regenerated =
            PiperImportPaths.tokensFromPiperConfigJson(configJson);
        if (regenerated != null &&
            validatePiperTokens(
                  regenerated,
                  requirePiperSymbols: needSymbols,
                ) ==
                null) {
          fixed = regenerated;
          tokensProblem = null;
        }
      }
      if (tokensProblem != null) {
        return PiperVoiceDiagnosis.blocked('tokens:$tokensProblem');
      }
      if (!await _replaceFileAtomically(tokensFile.path, utf8.encode(fixed))) {
        return const PiperVoiceDiagnosis.blocked('tokens:repair-failed');
      }
      repaired.add('tokens');
      debugPrint(
        '🩺 SherpaPiperTtsCore: đã chuẩn hoá tokens của ${voice.name}',
      );
    }

    return PiperVoiceDiagnosis.usable(repaired: repaired);
  }

  /// Đọc `metadata_props` ở [kOnnxMetadataTailBytes] byte cuối file ONNX.
  static Future<Map<String, String>> _readModelMetadata(String path) async {
    final raf = await File(path).open();
    try {
      final length = await raf.length();
      final start =
          length > kOnnxMetadataTailBytes ? length - kOnnxMetadataTailBytes : 0;
      await raf.setPosition(start);
      final tail = await raf.read(length - start);
      return readOnnxMetadataProps(tail);
    } finally {
      await raf.close();
    }
  }

  /// Ghi [bytes] vào [path] theo kiểu ghi-tạm-rồi-đổi-tên (không bao giờ để
  /// lại file dở dang nếu app bị tắt giữa chừng).
  static Future<bool> _replaceFileAtomically(
    String path,
    List<int> bytes,
  ) async {
    final tmp = File('$path.fix.tmp');
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(path);
      return true;
    } catch (e) {
      debugPrint('⚠️ SherpaPiperTtsCore: không ghi được $path: $e');
      try {
        if (tmp.existsSync()) tmp.deleteSync();
      } catch (_) {}
      return false;
    }
  }

  /// Thêm [entries] vào `metadata_props` của model bằng cách NỐI vào cuối
  /// file (xem `encodeOnnxMetadataProps`). Làm trên BẢN SAO rồi đổi tên ⇒
  /// file gốc không bao giờ ở trạng thái ghi dở (file ONNX hỏng đuôi làm ORT
  /// ném ngoại lệ C++ không ai bắt).
  static Future<bool> _appendModelMetadata(
    String modelPath,
    Map<String, String> entries,
  ) async {
    if (entries.isEmpty) return true;
    final tmp = File('$modelPath.meta.tmp');
    try {
      if (tmp.existsSync()) tmp.deleteSync();
      await File(modelPath).copy(tmp.path);
      final raf = await tmp.open(mode: FileMode.append);
      try {
        await raf.writeFrom(encodeOnnxMetadataProps(entries));
        await raf.flush();
      } finally {
        await raf.close();
      }
      await tmp.rename(modelPath);
      return true;
    } catch (e) {
      debugPrint('⚠️ SherpaPiperTtsCore: không thêm được metadata: $e');
      try {
        if (tmp.existsSync()) tmp.deleteSync();
      } catch (_) {}
      return false;
    }
  }

  /// File model còn "nguyên vẹn" đủ để native load (bắt tải về CẮT GIỮA:
  /// onnx quá nhỏ = file hỏng — load ORT trên file hỏng cũng có thể crash).
  /// Ngưỡng tokens THẤP (≥128B, xem `kMinPiperTokensBytes`): file tokens
  /// Piper hợp lệ có thể rất nhỏ (vài trăm byte) — ngưỡng cao hơn sẽ loại
  /// nhầm giọng tốt → Piper báo "chưa cài" dù model nguyên vẹn.
  static bool isVoiceFilesPlausible(PiperTtsVoice v) {
    try {
      final onnx = File(v.modelPath);
      if (!onnx.existsSync() || onnx.lengthSync() < 1024 * 1024) return false;
      final tokens = File(v.tokensPath);
      if (!tokens.existsSync() || tokens.lengthSync() < kMinPiperTokensBytes) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Directory> _modelsDir() async {
    Directory base;
    try {
      base = await getApplicationDocumentsDirectory();
    } catch (_) {
      base = await getApplicationSupportDirectory();
    }
    final dir = Directory(p.join(base.path, modelsFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Quét thư mục model → danh sách giọng.
  ///
  /// Hỗ trợ 2 layout:
  /// 1. **rhasspy/user**: `<name>.onnx` + `<name>_tokens.txt`
  ///    [+ `<name>.onnx.json` chứa audio.sample_rate]
  /// 2. **bundle k2-fsa chính thức** (vits-piper-*.tar.bz2):
  ///    `<name>.onnx` + `tokens.txt` DÙNG CHUNG + `espeak-ng-data/`
  ///    (không có .onnx.json — fallback 22050Hz chuẩn Piper)
  static Future<List<PiperTtsVoice>> discoverVoices() async {
    try {
      final dir = await _modelsDir();
      final dataDir = p.join(dir.path, espeakDataFolder);
      final dataOk = missingEspeakFiles(dataDir).isEmpty;

      final files = dir.listSync(followLinks: true);
      final onnxFiles = <File>[];
      for (final entity in files) {
        final lower = entity.path.toLowerCase();
        if (lower.endsWith('.onnx') && !lower.endsWith('.onnx.json')) {
          final f = File(entity.path);
          if (f.existsSync()) onnxFiles.add(f);
        }
      }
      // tokens.txt dùng chung có thể áp dụng cho mọi file onnx chưa có tokens riêng
      // (hoặc tự nhân bản ra <name>_tokens.txt)
      final sharedTokens = File(p.join(dir.path, 'tokens.txt'));
      // M4U-IMPORT-002: tokens rỗng/hỏng KHÔNG phải bảng token — để nó qua
      // là giọng "chạy được" nhưng phát ra tiếng rỗng (log native
      // "tokens=0KB"). Ngưỡng dùng CHUNG với manager (kMinPiperTokensBytes).
      final sharedTokensUsable = sharedTokens.existsSync() &&
          sharedTokens.lengthSync() >= kMinPiperTokensBytes;

      final voices = <PiperTtsVoice>[];
      for (final file in onnxFiles) {
        final fileName = p.basename(file.path);
        final name =
            fileName.substring(0, fileName.length - '.onnx'.length);

        String? tokensPath;
        final perNameTokens = p.join(dir.path, '${name}_tokens.txt');
        final perNameFile = File(perNameTokens);
        if (perNameFile.existsSync() &&
            perNameFile.lengthSync() >= kMinPiperTokensBytes) {
          tokensPath = perNameTokens;
        } else if (sharedTokensUsable) {
          tokensPath = sharedTokens.path;
          // Tự nhân bản ra file riêng để các lần sau nhận diện nhanh và ổn định
          try {
            sharedTokens.copySync(perNameTokens);
            tokensPath = perNameTokens;
          } catch (_) {}
        }
        if (tokensPath == null) continue;

        final sampleRate =
            _readSampleRate(p.join(dir.path, '$name.onnx.json')) ??
                defaultPiperSampleRate;

        voices.add(PiperTtsVoice(
          name: name,
          modelPath: file.path,
          tokensPath: tokensPath,
          dataDir: dataDir,
          sampleRate: sampleRate,
        ));
      }
      voices.sort((a, b) => a.name.compareTo(b.name));
      if (!dataOk) {
        debugPrint(
          '⚠️ SherpaPiperTtsCore: thiếu thư mục $espeakDataFolder trong '
          '${dir.path} — Piper cần phonemizer data',
        );
      }
      return voices;
    } catch (e) {
      debugPrint('⚠️ SherpaPiperTtsCore.discoverVoices error: $e');
      return const [];
    }
  }

  /// sample_rate từ config Piper (<name>.onnx.json → audio.sample_rate)
  static int? _readSampleRate(String jsonPath) {
    try {
      final raw = File(jsonPath).readAsStringSync();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final audio = map['audio'];
      if (audio is Map<String, dynamic>) {
        final sr = audio['sample_rate'];
        if (sr is int && sr > 0) return sr;
      }
    } catch (_) {}
    return null;
  }

  Future<IsolateRpcClient> _ensureWorker() {
    final existing = _worker;
    if (existing != null && existing.isAlive) {
      return Future<IsolateRpcClient>.value(existing);
    }
    final starting = _workerStarting;
    if (starting != null) return starting;
    final future = IsolateRpcClient.spawn(
      _piperWorkerFactory,
      debugName: 'piper-tts',
    ).then((client) {
      _worker = client;
      return client;
    }).whenComplete(() {
      _workerStarting = null;
    });
    _workerStarting = future;
    return future;
  }

  void _dropWorker() {
    final worker = _worker;
    _worker = null;
    _activeVoice = null;
    if (worker != null) {
      unawaited(worker.close(grace: Duration.zero));
    }
  }

  /// Chọn giọng (tạo `OfflineTts` trong worker isolate — giữ nguyên giữa các
  /// câu; đổi giọng mới tạo lại).
  ///
  /// Trả `false` (kèm [lastProblem]) khi giọng không qua được bước khám hoặc
  /// native không nạp được ⇒ `TtsService` tự chuyển sang engine kế tiếp.
  Future<bool> selectVoice(String voiceName) async {
    final voices = await discoverVoices();
    PiperTtsVoice? voice;
    for (final v in voices) {
      if (v.name == voiceName) {
        voice = v;
        break;
      }
    }
    if (voice == null) {
      debugPrint('⚠️ SherpaPiperTtsCore: giọng không tồn tại: $voiceName');
      _lastProblem = 'voice:not-found';
      return false;
    }
    final current = _worker;
    if (_activeVoice?.name == voiceName &&
        current != null &&
        current.isAlive) {
      return true;
    }

    // ★ KHÁM TRƯỚC khi xuống native (PSRC-187). Mọi điều kiện ở đây là điều
    // kiện làm sherpa-onnx/espeak tự thoát tiến trình — Dart không bắt được.
    final diagnosis = await examineVoice(voice);
    if (!diagnosis.isUsable) {
      _lastProblem = diagnosis.problem;
      debugPrint(
        '⛔ SherpaPiperTtsCore: KHÔNG nạp giọng $voiceName — '
        '${diagnosis.problem} (tránh native tự thoát làm văng app)',
      );
      return false;
    }

    try {
      debugPrint(
        '🎙️ SherpaPiperTtsCore: init native "$voiceName" trong worker — '
        'onnx=${File(voice.modelPath).lengthSync() ~/ 1024}KB, '
        'tokens=${File(voice.tokensPath).lengthSync()}B, espeak=OK, '
        'numThreads=2, maxNumSentences=$kPiperMaxSentencesPerBatch',
      );
      final worker = await _ensureWorker();
      await worker.call(
        'select',
        args: <String, Object?>{
          'model': voice.modelPath,
          'tokens': voice.tokensPath,
          'dataDir': voice.dataDir,
          'numThreads': 2,
          'debug': kDebugMode,
        },
        timeout: const Duration(minutes: 2),
      );
      _activeVoice = voice;
      _lastProblem = null;
      debugPrint('🎙️ SherpaPiperTtsCore: giọng "$voiceName" sẵn sàng '
          '(${voice.sampleRate}Hz)');
      return true;
    } catch (e) {
      debugPrint('⚠️ SherpaPiperTtsCore.selectVoice lỗi: $e');
      _lastProblem = 'native:$e';
      _dropWorker();
      return false;
    }
  }

  /// Generate audio cho text (giọng hiện tại). Trả null nếu lỗi/
  /// chưa chọn giọng.
  ///
  /// Chạy trong worker isolate ⇒ không chặn luồng UI dù văn bản dài.
  Future<PiperTtsAudio?> generate({
    required String text,
    double speed = 1.0,
    int sid = 0,
  }) async {
    final worker = _worker;
    final voice = _activeVoice;
    if (worker == null || !worker.isAlive || voice == null) return null;
    if (text.trim().isEmpty) return null;

    try {
      final reply = await worker.call(
        'generate',
        args: <String, Object?>{
          'text': text,
          'speed': speed <= 0 ? 1.0 : speed,
          'sid': sid,
        },
        timeout: const Duration(minutes: 5),
      );
      if (reply is! Map) return null;
      final samples = reply['samples'];
      if (samples is! Float32List || samples.isEmpty) return null;
      final rate = reply['sampleRate'];
      return PiperTtsAudio(
        samples: samples,
        sampleRate: rate is int && rate > 0 ? rate : voice.sampleRate,
      );
    } on TimeoutException catch (e) {
      // Worker kẹt trong native ⇒ bỏ worker này, lần sau tạo mới.
      debugPrint('⚠️ SherpaPiperTtsCore.generate quá hạn: $e');
      _dropWorker();
      return null;
    } on IsolateRpcClosedException catch (e) {
      debugPrint('⚠️ SherpaPiperTtsCore.generate: worker đã đóng: $e');
      _dropWorker();
      return null;
    } catch (e) {
      debugPrint('⚠️ SherpaPiperTtsCore.generate lỗi: $e');
      return null;
    }
  }

  /// Encode PCM float32 mono → WAV bytes (16-bit PCM) — cho TtsCache/
  /// just_audio (TtsResult.audioData).
  static Uint8List encodeWavBytes(Float32List samples, int sampleRate) {
    final dataSize = samples.length * 2;
    final buf = BytesBuilder();
    void writeAscii(String s) {
      for (final c in s.codeUnits) {
        buf.addByte(c);
      }
    }

    void writeU32(int v) {
      buf
        ..addByte(v & 0xFF)
        ..addByte((v >> 8) & 0xFF)
        ..addByte((v >> 16) & 0xFF)
        ..addByte((v >> 24) & 0xFF);
    }

    void writeU16(int v) {
      buf
        ..addByte(v & 0xFF)
        ..addByte((v >> 8) & 0xFF);
    }

    writeAscii('RIFF');
    writeU32(36 + dataSize);
    writeAscii('WAVE');
    writeAscii('fmt ');
    writeU32(16); // fmt chunk size
    writeU16(1); // PCM
    writeU16(1); // mono
    writeU32(sampleRate);
    writeU32(sampleRate * 2); // byte rate
    writeU16(2); // block align
    writeU16(16); // bits per sample
    writeAscii('data');
    writeU32(dataSize);
    for (final s in samples) {
      final v = (s * 32767).round().clamp(-32768, 32767);
      buf
        ..addByte(v & 0xFF)
        ..addByte((v >> 8) & 0xFF);
    }
    return buf.toBytes();
  }

  /// Giải phóng worker + `OfflineTts` — chỉ khi app dừng hẳn.
  void dispose() {
    _dropWorker();
  }
}
