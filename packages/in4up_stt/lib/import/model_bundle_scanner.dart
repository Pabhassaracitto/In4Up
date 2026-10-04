// packages/in4up_stt/lib/import/model_bundle_scanner.dart
//
// ModelBundleScanner — validator/scanner THỐNG NHẤT cho import model offline
// (I4U18-MODEL-IMPORT-001).
//
// Bối cảnh: 3 đường import (multi-file, folder, tar.bz2) từng tự đoán tên
// file theo cách khác nhau nên:
// - Chọn nhiều file kèm thư mục espeak → app không nhận espeak (file phontab
//   không có extension nên picker bỏ qua / path SAF không "gần" onnx).
// - Import folder báo "không tìm thấy .onnx + .txt" dù file tồn tại (file
//   nằm trong thư mục con, tên lạ — encoder-epoch-99-avg-1.int8.onnx…).
// - STT offline chọn đúng folder vẫn "không nhận dạng được" (scanner cũ lấy
//   file encoder/tokens ĐẦU TIÊN trong walk order, không group theo thư mục).
//
// Module này THUẦN Dart (không dart:io, không Flutter) để test được trên CI
// không thiết bị: input là danh sách file tương đối (posix path + size) —
// caller tự walk thư mục / dựng từ tên file user chọn.
//
// Nguyên tắc:
// - Group theo THƯ MỤC CHA: một bộ Zipformer/Piper hợp lệ nằm gọn trong 1
//   thư mục; chọn thư mục "đủ bộ nhất" thay vì file đầu tiên thấy được.
// - Nhận alias phổ biến: encoder/decoder/joiner/coupler/-epoch-99-avg-1,
//   tokens.txt/*_tokens.txt/*-tokens.txt, bpe.vocab, espeak-ng-data/*.
// - Phân loại rõ: Piper voice / eSpeak data / Zipformer ASR / Silero VAD /
//   Whisper GGML; file không thuộc loại nào = unclassified (không crash).
// - Báo thiếu CHÍNH XÁC: tên role + ví dụ tên file cần bổ sung.

/// Một file scanner nhìn thấy: đường dẫn tương đối (posix) + kích thước.
class ScannedFile {
  final String path;
  final int sizeBytes;

  const ScannedFile(this.path, {this.sizeBytes = 0});

  /// Tên file (không thư mục).
  String get name {
    final i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }

  /// Thư mục cha tương đối ('' = gốc của listing).
  String get dir {
    final i = path.lastIndexOf('/');
    return i < 0 ? '' : path.substring(0, i);
  }

  String get lowerName => name.toLowerCase();
  String get lowerPath => path.toLowerCase();

  @override
  String toString() => 'ScannedFile($path, $sizeBytes)';
}

/// Loại model bundle scanner nhận diện được.
enum ModelBundleKind {
  /// Giọng Piper (VITS): <voice>.onnx + tokens [+ .onnx.json].
  piperVoice,

  /// Dữ liệu phonemizer espeak-ng-data (phontab, phonindex, *_dict…).
  espeakData,

  /// Bộ Zipformer ASR: encoder + decoder + joiner (.onnx) + tokens.txt.
  zipformerAsr,

  /// Silero VAD (silero_vad.onnx ~629KB).
  sileroVad,

  /// Whisper GGML (ggml-*.bin).
  whisperGgml,
}

/// File theo từng role của bộ Zipformer ASR (trong 1 thư mục).
class ZipformerRoleFiles {
  final ScannedFile? encoder;
  final ScannedFile? decoder;
  final ScannedFile? joiner;
  final ScannedFile? tokens;
  final ScannedFile? bpeVocab;

  const ZipformerRoleFiles({
    this.encoder,
    this.decoder,
    this.joiner,
    this.tokens,
    this.bpeVocab,
  });

  /// Các role BẮT BUỘC còn thiếu (nhãn kỹ thuật + gợi ý tên file — UI tự
  /// bản địa hoá phần dẫn, giữ nguyên tên file để user đối chiếu).
  List<String> get missingRoles => [
        if (encoder == null) 'encoder (encoder*.onnx)',
        if (decoder == null) 'decoder (decoder*.onnx)',
        if (joiner == null) 'joiner (joiner*.onnx)',
        if (tokens == null) 'tokens (tokens.txt)',
      ];

  bool get isComplete => missingRoles.isEmpty;

  /// Điểm "đủ bộ" để chọn thư mục tốt nhất (role bắt buộc trước, phụ sau).
  int get completeness =>
      (encoder != null ? 8 : 0) +
      (decoder != null ? 8 : 0) +
      (joiner != null ? 8 : 0) +
      (tokens != null ? 8 : 0) +
      (bpeVocab != null ? 1 : 0);
}

/// Ứng viên giọng Piper: 1 file .onnx (+ tokens/config ghép được).
class PiperVoiceCandidate {
  final ScannedFile onnx;

  /// stem = tên onnx bỏ đuôi (vd `en_US-lessac-medium`).
  final String stem;

  /// tokens ghép theo stem cùng thư mục (`<stem>_tokens.txt` /
  /// `<stem>-tokens.txt`) — null nếu chỉ có tokens dùng chung / không có.
  final ScannedFile? ownTokens;

  /// `tokens.txt` dùng chung CÙNG THƯ MỤC với onnx.
  final ScannedFile? sharedTokens;

  /// Config `<stem>.onnx.json` cùng thư mục (không bắt buộc).
  final ScannedFile? config;

  const PiperVoiceCandidate({
    required this.onnx,
    required this.stem,
    this.ownTokens,
    this.sharedTokens,
    this.config,
  });

  ScannedFile? get tokens => ownTokens ?? sharedTokens;

  /// Phần còn thiếu của giọng (config KHÔNG bắt buộc — chỉ ghi chú).
  List<String> get missingParts => [
        if (tokens == null) 'tokens.txt (chung) hoặc ${stem}_tokens.txt',
      ];

  bool get isUsable => tokens != null;
}

/// Kết quả quét espeak-ng-data.
class EspeakDetection {
  /// File nằm dưới một thư mục `espeak-ng-data/…` (giữ cấu trúc khi copy).
  final List<ScannedFile> treeFiles;

  /// File espeak "lẻ" không nằm trong thư mục espeak (user chọn lẻ qua
  /// multi-file): phontab/phonindex/phondata/intonations/*_dict.
  final List<ScannedFile> looseLeaves;

  const EspeakDetection({
    this.treeFiles = const [],
    this.looseLeaves = const [],
  });

  bool get present => treeFiles.isNotEmpty || looseLeaves.isNotEmpty;

  bool get hasPhontab =>
      treeFiles.any((f) => f.lowerName == 'phontab') ||
      looseLeaves.any((f) => f.lowerName == 'phontab');

  int get fileCount => treeFiles.length + looseLeaves.length;
}

/// Báo cáo tổng hợp sau khi quét 1 nguồn import (folder / multi-file).
class ModelBundleReport {
  /// Giọng Piper (có thể nhiều giọng trong 1 folder).
  final List<PiperVoiceCandidate> piperVoices;

  /// eSpeak-ng-data nhận diện được.
  final EspeakDetection espeak;

  /// Bộ Zipformer "đủ nhất" theo nhóm thư mục — null nếu không thấy role nào.
  final ZipformerRoleFiles? zipformer;

  /// Thư mục (tương đối) chứa bộ Zipformer được chọn ('' = gốc).
  final String zipformerDir;

  /// File Silero VAD.
  final ScannedFile? sileroVad;

  /// File Whisper GGML (ggml-*.bin).
  final List<ScannedFile> whisperBins;

  /// Archive model (.tar.bz2/.tar.gz/.tgz/.zip) — caller tự giải nén rồi
  /// quét lại (scanner không đụng nội dung nén).
  final List<ScannedFile> archives;

  /// File nhìn "có vẻ model" nhưng không xếp được (onnx/tokens/vocab lạc).
  final List<ScannedFile> unclassified;

  /// Thư mục gốc chứa `espeak-ng-data` khi nhận diện được duy nhất
  /// ('' = không rõ / chỉ có file lẻ).
  final String espeakRootDir;

  const ModelBundleReport({
    this.piperVoices = const [],
    this.espeak = const EspeakDetection(),
    this.zipformer,
    this.zipformerDir = '',
    this.sileroVad,
    this.whisperBins = const [],
    this.archives = const [],
    this.unclassified = const [],
    this.espeakRootDir = '',
  });

  /// Các loại model bundle có mặt trong nguồn.
  Set<ModelBundleKind> get kinds => {
        if (piperVoices.isNotEmpty) ModelBundleKind.piperVoice,
        if (espeak.present) ModelBundleKind.espeakData,
        if (zipformer != null) ModelBundleKind.zipformerAsr,
        if (sileroVad != null) ModelBundleKind.sileroVad,
        if (whisperBins.isNotEmpty) ModelBundleKind.whisperGgml,
      };

  /// Bộ Zipformer đủ dùng — mọi role bắt buộc đều có.
  bool get hasCompleteZipformer => zipformer?.isComplete ?? false;

  /// Piper dùng được = ≥1 giọng có tokens (espeak có thể cài riêng).
  bool get hasUsablePiperVoice => piperVoices.any((v) => v.isUsable);
}

/// Scanner tĩnh — toàn hàm thuần.
class ModelBundleScanner {
  ModelBundleScanner._();

  static const String espeakFolder = 'espeak-ng-data';

  // ── Nhận diện tên file (alias) ────────────────────────────────────────

  /// Chuẩn hoá path Windows → posix để so khớp.
  static String normSep(String path) => path.replaceAll('\\', '/');

  static bool isOnnx(String name) => name.toLowerCase().endsWith('.onnx');

  static bool isOnnxJson(String name) =>
      name.toLowerCase().endsWith('.onnx.json');

  static bool isSileroVadName(String name) {
    final lower = name.toLowerCase();
    return lower.startsWith('silero_vad') && lower.endsWith('.onnx');
  }

  static bool isWhisperBinName(String name) {
    final lower = name.toLowerCase();
    return lower.startsWith('ggml-') && lower.endsWith('.bin');
  }

  static bool isArchiveName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.tar.bz2') ||
        lower.endsWith('.tar.gz') ||
        lower.endsWith('.tgz') ||
        lower.endsWith('.zip');
  }

  /// File tokens của Piper (tokens.txt dùng chung hoặc <voice>_tokens.txt).
  static bool isTokensName(String name) {
    final lower = name.toLowerCase();
    return lower == 'tokens.txt' ||
        lower.endsWith('_tokens.txt') ||
        lower.endsWith('-tokens.txt');
  }

  /// File espeak-ng-data "lẻ" (không extension) của bundle k2-fsa.
  static bool isEspeakLeafName(String name) {
    switch (name.toLowerCase()) {
      case 'phontab':
      case 'phonindex':
      case 'phondata':
      case 'intonations':
        return true;
    }
    return name.toLowerCase().endsWith('_dict');
  }

  static bool isBpeVocabName(String name) {
    final lower = name.toLowerCase();
    return lower == 'bpe.vocab' || lower == 'bpe.vocab.txt';
  }

  /// onnx thuộc role ENCODER của Zipformer
  /// (encoder*.onnx, encoder-epoch-99-avg-1.int8.onnx…).
  static bool isAsrEncoderName(String name) {
    if (!isOnnx(name)) return false;
    return name.toLowerCase().contains('encoder');
  }

  static bool isAsrDecoderName(String name) {
    if (!isOnnx(name)) return false;
    return name.toLowerCase().contains('decoder');
  }

  static bool isAsrJoinerName(String name) {
    if (!isOnnx(name)) return false;
    final lower = name.toLowerCase();
    // 'coupler' = tên cũ của joiner ở một số model conv-emformer.
    return lower.contains('joiner') || lower.contains('coupler');
  }

  static bool _isAsrRoleName(String name) =>
      isAsrEncoderName(name) || isAsrDecoderName(name) || isAsrJoinerName(name);

  /// onnx ứng viên làm giọng Piper: không phải role ASR, không phải VAD,
  /// không phải whisper-onnx (sherpa whisper: tiny-encoder/-decoder…).
  static bool isPiperVoiceOnnxName(String name) {
    if (!isOnnx(name) || isOnnxJson(name)) return false;
    if (isSileroVadName(name)) return false;
    if (_isAsrRoleName(name)) return false;
    final lower = name.toLowerCase();
    if (lower.contains('whisper')) return false;
    if (RegExp(r'(^|[^a-z])vad([^a-z]|$)').hasMatch(lower)) return false;
    return true;
  }

  /// File nằm dưới thư mục espeak-ng-data: trả về phần đuôi
  /// `espeak-ng-data/…` (posix) để copy giữ cấu trúc; null nếu không.
  static String? espeakTail(String posixRelPath) {
    final lower = posixRelPath.toLowerCase();
    const needle = '$espeakFolder/';
    final idx = lower.indexOf(needle);
    if (idx < 0) {
      if (lower == espeakFolder || lower.endsWith('/$espeakFolder')) {
        return espeakFolder;
      }
      return null;
    }
    return posixRelPath.substring(idx);
  }

  /// stem của "tokens ghép theo stem": `<stem>_tokens.txt` → `<stem>`.
  static String? tokensStem(String name) {
    final lower = name.toLowerCase();
    for (final suffix in const ['_tokens.txt', '-tokens.txt']) {
      if (lower.endsWith(suffix) && lower != 'tokens.txt') {
        return name.substring(0, name.length - suffix.length);
      }
    }
    return null;
  }

  // ── Quét chính ─────────────────────────────────────────────────────────

  /// Quét danh sách file (tên + thư mục cha là đủ) → báo cáo phân loại +
  /// thiếu file. KHÔNG đọc nội dung / không quyết streaming vs offline (việc
  /// đó của `SherpaModelManager.detectEncoderKind` — bằng chứng nội dung).
  static ModelBundleReport scan(List<ScannedFile> files) {
    final normalized = <ScannedFile>[
      for (final f in files)
        ScannedFile(normSep(f.path), sizeBytes: f.sizeBytes),
    ];

    // 1. Archive tách riêng (caller giải nén rồi quét lại).
    final archives = <ScannedFile>[];
    final rest = <ScannedFile>[];
    for (final f in normalized) {
      if (isArchiveName(f.name)) {
        archives.add(f);
      } else {
        rest.add(f);
      }
    }

    // 2. eSpeak: file dưới `espeak-ng-data/` + file leaf chọn lẻ.
    final espeakTree = <ScannedFile>[];
    final espeakLoose = <ScannedFile>[];
    final afterEspeak = <ScannedFile>[];
    final espeakRoots = <String>{};
    for (final f in rest) {
      final tail = espeakTail(f.path);
      if (tail != null && tail != espeakFolder) {
        espeakTree.add(f);
        // Gốc chứa thư mục espeak-ng-data ('' = nằm ngay gốc listing).
        if (f.path.length > tail.length + 1) {
          espeakRoots.add(f.path.substring(0, f.path.length - tail.length - 1));
        } else {
          espeakRoots.add('');
        }
      } else if (tail == null && isEspeakLeafName(f.name)) {
        espeakLoose.add(f);
      } else {
        afterEspeak.add(f);
      }
    }

    // 3. VAD + Whisper GGML.
    ScannedFile? vad;
    final whisperBins = <ScannedFile>[];
    final generic = <ScannedFile>[];
    for (final f in afterEspeak) {
      if (isSileroVadName(f.name)) {
        vad ??= f;
      } else if (isWhisperBinName(f.name)) {
        whisperBins.add(f);
      } else {
        generic.add(f);
      }
    }

    // 4. Zipformer: group theo thư mục cha — một bộ hợp lệ nằm gọn 1 thư
    // mục. tokens/bpe.vocab CHỈ gán cho thư mục đã có ≥1 onnx role (không
    // cướp tokens.txt của Piper trong bundle vits-piper-*).
    var bestRoles = const ZipformerRoleFiles();
    var bestDir = '';
    var bestDirSize = 1 << 30;
    final byDir = <String, List<ScannedFile>>{};
    for (final f in generic) {
      byDir.putIfAbsent(f.dir, () => []).add(f);
    }
    for (final entry in byDir.entries) {
      ScannedFile? enc;
      ScannedFile? dec;
      ScannedFile? joi;
      ScannedFile? tok;
      ScannedFile? bpe;
      for (final f in entry.value) {
        if (isAsrEncoderName(f.name)) {
          // Ưu tiên int8 (đúng profile app) khi có cả hai bản.
          if (enc == null ||
              (f.lowerName.contains('int8') &&
                  !enc.lowerName.contains('int8'))) {
            enc = f;
          }
        } else if (isAsrDecoderName(f.name)) {
          dec ??= f;
        } else if (isAsrJoinerName(f.name)) {
          if (joi == null ||
              (f.lowerName.contains('int8') &&
                  !joi.lowerName.contains('int8'))) {
            joi = f;
          }
        }
      }
      final hasRoleOnnx = enc != null || dec != null || joi != null;
      if (hasRoleOnnx) {
        for (final f in entry.value) {
          if (isTokensName(f.name)) {
            tok ??= f;
          } else if (isBpeVocabName(f.name)) {
            bpe ??= f;
          }
        }
      }
      final roles = ZipformerRoleFiles(
        encoder: enc,
        decoder: dec,
        joiner: joi,
        tokens: tok,
        bpeVocab: bpe,
      );
      final score = roles.completeness;
      final dirSize = entry.value.length;
      if (score > 0 &&
          (score > bestRoles.completeness ||
              (score == bestRoles.completeness && dirSize < bestDirSize))) {
        bestRoles = roles;
        bestDir = entry.key;
        bestDirSize = dirSize;
      }
    }

    // 5. Piper voices: ghép onnx với tokens/config CÙNG THƯ MỤC.
    final voices = <PiperVoiceCandidate>[];
    for (final entry in byDir.entries) {
      final dirFiles = entry.value;
      ScannedFile? sharedTokens;
      final stemTokens = <String, ScannedFile>{};
      for (final f in dirFiles) {
        if (f.lowerName == 'tokens.txt') sharedTokens ??= f;
        final stem = tokensStem(f.name);
        if (stem != null) stemTokens[stem.toLowerCase()] = f;
      }
      for (final f in dirFiles) {
        if (!isPiperVoiceOnnxName(f.name)) continue;
        // File đã xếp vào bộ Zipformer được chọn → bỏ qua.
        if (f.path == bestRoles.encoder?.path ||
            f.path == bestRoles.decoder?.path ||
            f.path == bestRoles.joiner?.path) {
          continue;
        }
        final stem = f.name.substring(0, f.name.length - '.onnx'.length);
        ScannedFile? config;
        for (final g in dirFiles) {
          if (isOnnxJson(g.name) &&
              g.lowerName == '${stem.toLowerCase()}.onnx.json') {
            config = g;
            break;
          }
        }
        voices.add(PiperVoiceCandidate(
          onnx: f,
          stem: stem,
          ownTokens: stemTokens[stem.toLowerCase()],
          sharedTokens: sharedTokens,
          config: config,
        ));
      }
    }

    // 6. Unclassified: file có đuôi/tên model nhưng không xếp được nhóm nào.
    final knownPaths = <String>{
      for (final v in voices) ...[
        v.onnx.path,
        if (v.ownTokens != null) v.ownTokens!.path,
        if (v.sharedTokens != null) v.sharedTokens!.path,
        if (v.config != null) v.config!.path,
      ],
      for (final f in espeakTree) f.path,
      for (final f in espeakLoose) f.path,
      for (final f in whisperBins) f.path,
      for (final f in archives) f.path,
      if (vad != null) vad.path,
      if (bestRoles.encoder != null) bestRoles.encoder!.path,
      if (bestRoles.decoder != null) bestRoles.decoder!.path,
      if (bestRoles.joiner != null) bestRoles.joiner!.path,
      if (bestRoles.tokens != null) bestRoles.tokens!.path,
      if (bestRoles.bpeVocab != null) bestRoles.bpeVocab!.path,
    };
    final unclassified = <ScannedFile>[];
    for (final f in normalized) {
      if (knownPaths.contains(f.path)) continue;
      final lower = f.lowerName;
      final looksModel = lower.endsWith('.onnx') ||
          lower.endsWith('.bin') ||
          lower.contains('tokens') ||
          isEspeakLeafName(f.name);
      if (looksModel) unclassified.add(f);
    }

    // Không expose bộ Zipformer "rỗng" (chỉ tokens rơi rớt, không onnx).
    final zip = bestRoles.encoder != null ||
            bestRoles.decoder != null ||
            bestRoles.joiner != null
        ? bestRoles
        : null;

    return ModelBundleReport(
      piperVoices: voices,
      espeak: EspeakDetection(treeFiles: espeakTree, looseLeaves: espeakLoose),
      zipformer: zip,
      zipformerDir: zip == null ? '' : bestDir,
      sileroVad: vad,
      whisperBins: whisperBins,
      archives: archives,
      unclassified: unclassified,
      espeakRootDir: espeakRoots.length == 1 ? espeakRoots.first : '',
    );
  }
}
