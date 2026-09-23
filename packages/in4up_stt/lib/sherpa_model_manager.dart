// packages/in4up_stt/lib/sherpa_model_manager.dart
//
// SherpaModelManager — quản lý model Silero VAD, Piper TTS và Zipformer ASR (MODELS-001 / PLAN-023).
//
// TẤT CẢ chỉ chạy khi user bấm — không auto-download.
//
// Folders:
//   <documents>/sherpa_vad_models/silero_vad.onnx
//   <documents>/sherpa_piper_models/
//     espeak-ng-data/
//     <voice>.onnx + <voice>_tokens.txt [+ <voice>.onnx.json]
//   <documents>/sherpa_asr_models/
//     asr-vi-30M-int8/ (tokens.txt, encoder.int8.onnx, decoder.onnx, joiner.int8.onnx)
//     asr-en-20M-streaming-int8/ (tokens.txt, encoder*.onnx, decoder*.onnx, joiner*.onnx)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import 'asr_model_routing.dart';
import 'stt_engine_sherpa.dart';
import 'tts/piper_import_paths.dart';
import 'tts/piper_voice_catalog.dart';
import 'tts/sherpa_piper_tts_core.dart';

// Profile ASR + logic mapping ngôn ngữ ↔ profile nằm ở `asr_model_routing.dart`
// (thuần, test được không cần thiết bị). Re-export để code cũ giữ nguyên.
export 'asr_model_routing.dart'
    show
        AsrLiveRoute,
        AsrModelIssue,
        AsrModelRouter,
        AsrModelSelection,
        SherpaAsrProfile,
        kAsrLanguagePriority,
        kDefaultAsrLanguage,
        kSherpaAsrProfiles;

enum SherpaModelStatus { notInstalled, downloading, ready, error }

/// Loại encoder Zipformer ONNX (quyết định Online vs Offline recognizer).
enum SherpaAsrEncoderKind {
  /// Encoder streaming — chỉ dùng được với `OnlineRecognizer`.
  streaming,

  /// Encoder offline — chỉ dùng được với `OfflineRecognizer` (+ VAD).
  nonStreaming,

  /// Không đọc được metadata/tên không nói rõ (vd file test, file lạ).
  unknown,
}

class _EncoderKindCacheEntry {
  final SherpaAsrEncoderKind kind;
  final String? signature;

  const _EncoderKindCacheEntry(this.kind, this.signature);
}

/// Trạng thái import model Zipformer ASR.
enum SherpaAsrImportStatus {
  /// Đã copy + nhận diện model vào đúng profile.
  imported,

  /// Không nhận diện được profile nào (UI phải hỏi user chọn đúng thẻ model).
  unknownProfile,

  /// Nội dung model không khớp profile user chọn (vd model offline nhưng chọn
  /// thẻ EN streaming) — chặn để không tạo trạng thái SIGABRT.
  profileMismatch,

  /// Thiếu file (encoder/decoder/joiner/tokens).
  incompleteFiles,

  /// Nguồn không tồn tại/rỗng.
  sourceMissing,
  sourceEmpty,

  /// Lỗi khác (giải nén, copy…).
  failed,
}

/// Kết quả import model ASR — cho UI map sang chuỗi đã bản địa hoá.
class SherpaAsrImportResult {
  final SherpaAsrImportStatus status;

  /// Profile đích (đã cài khi [status] == imported).
  final SherpaAsrProfile? profile;

  /// Profile nhận diện từ nội dung file (nếu có).
  final SherpaAsrProfile? detectedProfile;

  /// Loại encoder đọc được từ file.
  final SherpaAsrEncoderKind encoderKind;

  /// Có nhận diện được nội dung model không.
  final bool contentRecognized;

  /// Chi tiết kỹ thuật (log/đường dẫn) — không phải chuỗi chrome.
  final String? detail;

  const SherpaAsrImportResult({
    required this.status,
    this.profile,
    this.detectedProfile,
    this.encoderKind = SherpaAsrEncoderKind.unknown,
    this.contentRecognized = false,
    this.detail,
  });

  bool get isSuccess => status == SherpaAsrImportStatus.imported;
}

/// Trạng thái 1 model đơn lẻ (Silero VAD, hoặc 1 profile Zipformer ASR).
class SherpaModelInfo {
  final SherpaModelStatus status;
  final double downloadProgress;
  final String? errorMessage;
  final String? localPath;

  const SherpaModelInfo({
    this.status = SherpaModelStatus.notInstalled,
    this.downloadProgress = 0,
    this.errorMessage,
    this.localPath,
  });

  bool get isReady => status == SherpaModelStatus.ready;
  bool get isDownloading => status == SherpaModelStatus.downloading;

  SherpaModelInfo copyWith({
    SherpaModelStatus? status,
    double? downloadProgress,
    String? errorMessage,
    String? localPath,
    bool clearError = false,
  }) {
    return SherpaModelInfo(
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      localPath: localPath ?? this.localPath,
    );
  }
}

/// Trạng thái Piper tổng thể (espeak + danh sách giọng).
class SherpaPiperInfo {
  final bool espeakInstalled;
  final List<PiperTtsVoice> voices;
  final SherpaModelStatus status;
  final double downloadProgress;
  final String? errorMessage;

  const SherpaPiperInfo({
    this.espeakInstalled = false,
    this.voices = const [],
    this.status = SherpaModelStatus.notInstalled,
    this.downloadProgress = 0,
    this.errorMessage,
  });

  bool get isDownloading => status == SherpaModelStatus.downloading;
  bool get isReady => voices.isNotEmpty && espeakInstalled;

  SherpaPiperInfo copyWith({
    bool? espeakInstalled,
    List<PiperTtsVoice>? voices,
    SherpaModelStatus? status,
    double? downloadProgress,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SherpaPiperInfo(
      espeakInstalled: espeakInstalled ?? this.espeakInstalled,
      voices: voices ?? this.voices,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Định nghĩa profile của model Zipformer ASR.
///
/// Chuyển sang `asr_model_routing.dart` (logic thuần, test được) và re-export
/// ở đây để mọi chỗ dùng cũ (`SherpaAsrProfile` qua `sherpa_model_manager.dart`)
/// không phải sửa import.

/// Trạng thái tổng thể của các profile Zipformer ASR.
class SherpaAsrInfo {
  final Map<String, SherpaModelInfo> profileStates;

  const SherpaAsrInfo({
    this.profileStates = const {},
  });

  SherpaModelInfo stateFor(String profileId) =>
      profileStates[profileId] ?? const SherpaModelInfo();

  bool isReady(String profileId) => stateFor(profileId).isReady;

  /// Id các profile đã cài (model nằm sẵn trên máy).
  List<String> get installedProfileIds => [
        for (final entry in profileStates.entries)
          if (entry.value.isReady) entry.key,
      ];

  /// Ngôn ngữ đã có model ASR (theo thứ tự profile khai báo).
  List<String> get installedLanguages => [
        for (final profile in kSherpaAsrProfiles)
          if (isReady(profile.id)) profile.language,
      ];

  /// Ngôn ngữ đã cài, ưu tiên VI rồi tới thứ tự ưu tiên (vi → en).
  String? get preferredInstalledLanguage {
    for (final profile in kSherpaAsrProfiles) {
      if (isReady(profile.id)) return profile.language;
    }
    return null;
  }

  SherpaAsrInfo copyWith({
    Map<String, SherpaModelInfo>? profileStates,
  }) {
    return SherpaAsrInfo(
      profileStates: profileStates ?? this.profileStates,
    );
  }
}

class SherpaModelManager {
  static SherpaModelManager? _instance;
  factory SherpaModelManager() => _instance ??= SherpaModelManager._internal();
  SherpaModelManager._internal();

  static const String vadFolderName = 'sherpa_vad_models';
  static const String vadFileName = 'silero_vad.onnx';
  static const String asrFolderName = 'sherpa_asr_models';

  /// k2-fsa silero_vad.onnx ~629KB; int8 ~208KB. HTML lỗi GitHub thường <80KB.
  static const int vadMinBytes = 80 * 1024;
  static const int vadMaxBytes = 40 * 1024 * 1024;

  static const String vadDownloadUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
      'silero_vad.onnx';

  static const List<String> vadDownloadUrls = [
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
        'silero_vad.onnx',
    'https://huggingface.co/csukuangfj/silero-vad/resolve/main/'
        'silero_vad.onnx?download=true',
  ];

  static const String defaultPiperVoice = 'en_US-libritts_r-medium';

  static String piperBundleUrl(String voice) =>
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/'
      'vits-piper-$voice.tar.bz2';

  /// Shared Piper phoneme tokens (sherpa). Used when HuggingFace only
  /// ships onnx+json (no tokens.txt).
  static const String piperTokensFallbackUrl =
      'https://huggingface.co/csukuangfj/vits-piper-en_US-lessac-medium/'
      'resolve/main/tokens.txt?download=true';

  /// Shared by every Piper voice (k2-fsa). ~1–2MB — not a full voice bundle.
  static const List<String> espeakArchiveUrls = [
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/'
        'espeak-ng-data.tar.bz2',
  ];

  /// Danh sách các profile Zipformer ASR được hỗ trợ sẵn.
  ///
  /// Nguồn sự thật nằm ở `asr_model_routing.dart` (`kSherpaAsrProfiles`) —
  /// KHÔNG bịa thêm profile ngôn ngữ ngoài 2 profile đã verify.
  static const List<SherpaAsrProfile> predefinedAsrProfiles = kSherpaAsrProfiles;

  static const String safEmptyPrefix = 'SAF_EMPTY:';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(minutes: 30),
      followRedirects: true,
      maxRedirects: 8,
      headers: const {
        'User-Agent': 'Mozilla/5.0 (compatible; in4upApp/1.0)',
        'Accept': '*/*',
      },
    ),
  );

  final _vadState =
      BehaviorSubject<SherpaModelInfo>.seeded(const SherpaModelInfo());
  final _piperState =
      BehaviorSubject<SherpaPiperInfo>.seeded(const SherpaPiperInfo());
  final _asrState =
      BehaviorSubject<SherpaAsrInfo>.seeded(const SherpaAsrInfo());

  CancelToken? _vadToken;
  CancelToken? _piperToken;
  final Map<String, CancelToken> _asrTokens = {};
  bool _initialized = false;
  String? _documentsDir;
  Future<void>? _initializing;
  DateTime? _lastRescanAt;
  static final Map<String, _EncoderKindCacheEntry> _encoderKindCache = {};

  Future<String> _documents() async {
    if (_documentsDir != null) return _documentsDir!;
    Directory base;
    try {
      base = await getApplicationDocumentsDirectory();
    } catch (_) {
      base = await getApplicationSupportDirectory();
    }
    _documentsDir = base.path;
    return base.path;
  }

  Future<String> _vadDir() async {
    final dir = Directory(p.join(await _documents(), vadFolderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> _asrDir() async {
    final dir = Directory(p.join(await _documents(), asrFolderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Nạp thư mục documents + quét lại model (idempotent, an toàn khi gọi
  /// song song nhiều nơi — Cabin/Engine/Settings cùng gọi lúc mở app).
  ///
  /// Trước CABIN-ASR-002 chỉ `tts_settings_section` gọi `initialize()`; vào
  /// Cabin trực tiếp thì `_documentsDir == null` ⇒ `hasAsrModel()` trả false
  /// dù model ĐÃ import → báo “chưa có model” sai.
  Future<void> initialize() {
    final inFlight = _initializing;
    if (inFlight != null) return inFlight;
    final future = _initializeInternal();
    _initializing = future;
    return future.whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initializeInternal() async {
    if (!_initialized) {
      await _documents();
      _initialized = true;
    }
    await rescan();
  }

  /// Bảo đảm state model còn “tươi” trước khi quyết định start live STT
  /// (user vừa import/tải model rồi mở Cabin ngay).
  Future<void> ensureFresh({
    Duration maxAge = const Duration(seconds: 5),
  }) async {
    if (_initializing != null) {
      await _initializing;
      return;
    }
    if (!_initialized || _lastRescanAt == null) {
      await initialize();
      return;
    }
    final age = DateTime.now().difference(_lastRescanAt!);
    if (age > maxAge) await initialize();
  }

  /// Trạng thái cài đặt của 1 profile ASR (theo state đã quét).
  bool isAsrProfileInstalled(String profileId) => asrInfo.isReady(profileId);

  /// Phân giải ngôn ngữ đang chọn → profile + trạng thái (có quét lại trước).
  ///
  /// Dùng cho cả Cabin và UI để chỉ có MỘT nguồn quyết định mapping.
  Future<AsrModelSelection> resolveAsrSelection(
    String language, {
    bool ensureFreshState = true,
  }) async {
    if (ensureFreshState) await ensureFresh();
    return AsrModelRouter.resolve(
      language,
      isInstalled: isAsrProfileInstalled,
    );
  }

  /// Ngôn ngữ mặc định khi user chưa chọn: model đã cài (ưu tiên VI),
  /// chưa có gì thì `vi` (fallback mặc định của app — có giải thích ở UI).
  Future<String> defaultCabinSourceLanguage({bool ensureFreshState = true}) async {
    if (ensureFreshState) await ensureFresh();
    return defaultCabinSourceLanguageSync();
  }

  /// Bản đồng bộ (đọc state đã quét) — dùng khi watch stream bắn sự kiện.
  String defaultCabinSourceLanguageSync() => AsrModelRouter.resolveDefaultLanguage(
        isInstalled: isAsrProfileInstalled,
      );

  Stream<SherpaModelInfo> watchVad() => _vadState.stream;
  SherpaModelInfo get vadInfo => _vadState.value;

  Stream<SherpaPiperInfo> watchPiper() => _piperState.stream;
  SherpaPiperInfo get piperInfo => _piperState.value;

  Stream<SherpaAsrInfo> watchAsr() => _asrState.stream;
  SherpaAsrInfo get asrInfo => _asrState.value;

  static bool isPlausibleVadFile(int size, {List<int>? head}) {
    if (size < vadMinBytes || size > vadMaxBytes) return false;
    if (head != null && head.isNotEmpty) {
      if (head[0] == 0x3C) return false; // '<' HTML
      final ascii = String.fromCharCodes(
        head.take(80).where((b) => b >= 32 && b < 127),
      ).toLowerCase();
      if (ascii.contains('<html') || ascii.contains('<!doctype')) return false;
    }
    return true;
  }

  Future<void> _replaceFile(String fromPath, String toPath) async {
    final src = File(fromPath);
    final dest = File(toPath);
    if (await dest.exists()) {
      try { await dest.delete(); } catch (_) {}
    }
    try {
      await src.rename(toPath);
    } catch (_) {
      await src.copy(toPath);
      try { await src.delete(); } catch (_) {}
    }
  }

  Future<void> rescan() async {
    try {
      // 1. Rescan VAD
      final vadFile = File(p.join(await _vadDir(), vadFileName));
      List<int>? head;
      if (vadFile.existsSync()) {
        final raf = await vadFile.open();
        try {
          head = await raf.read(64);
        } finally {
          await raf.close();
        }
      }
      final vadOk = vadFile.existsSync() &&
          isPlausibleVadFile(vadFile.lengthSync(), head: head);
      _vadState.add(vadOk
          ? SherpaModelInfo(
              status: SherpaModelStatus.ready, localPath: vadFile.path)
          : const SherpaModelInfo(status: SherpaModelStatus.notInstalled));

      // 2. Rescan Piper
      final voices = await SherpaPiperTtsCore.discoverVoices();
      final piperDir = Directory(
          p.join(await _documents(), SherpaPiperTtsCore.modelsFolderName));
      final espeakOk = _espeakPhontabReady(piperDir.path);
      _piperState.add(SherpaPiperInfo(
        espeakInstalled: espeakOk,
        voices: voices,
        status: voices.isEmpty
            ? SherpaModelStatus.notInstalled
            : SherpaModelStatus.ready,
      ));

      // 3. Rescan Zipformer ASR
      final asrStates = <String, SherpaModelInfo>{};
      final docs = await _documents();
      final detected = detectAsrModels(docs);
      for (final profile in predefinedAsrProfiles) {
        final paths = detected[profile.id];
        if (paths != null) {
          asrStates[profile.id] = SherpaModelInfo(
            status: SherpaModelStatus.ready,
            localPath: p.dirname(paths.encoder),
          );
        } else {
          // Giữ trạng thái đang tải nếu đang download
          final current = _asrState.value.stateFor(profile.id);
          if (current.isDownloading) {
            asrStates[profile.id] = current;
          } else {
            asrStates[profile.id] = const SherpaModelInfo(
              status: SherpaModelStatus.notInstalled,
            );
          }
        }
      }
      _asrState.add(SherpaAsrInfo(profileStates: asrStates));
    } catch (e) {
      debugPrint('⚠️ SherpaModelManager.rescan error: $e');
    } finally {
      _lastRescanAt = DateTime.now();
    }
  }

  // ── ZIPFORMER ASR ──────────────────────────────────────────────────────

  /// Loại encoder ONNX (dùng để route Online/Offline — tránh SIGABRT).
  static SherpaAsrEncoderKind detectEncoderKind(String encoderPath) {
    final file = File(encoderPath);
    if (!file.existsSync()) return SherpaAsrEncoderKind.unknown;

    FileStat? stat;
    try {
      stat = file.statSync();
    } catch (_) {}
    final signature = stat == null
        ? null
        : '${stat.size}|${stat.modified.millisecondsSinceEpoch}';
    final cached = _encoderKindCache[encoderPath];
    if (cached != null && cached.signature != null && cached.signature == signature) {
      return cached.kind;
    }

    // 1. Metadata ONNX (nội dung file là bằng chứng mạnh nhất — kể cả khi
    //    file bị đặt trong thư mục/profile có tên "streaming").
    var kind = SherpaAsrEncoderKind.unknown;
    try {
      final length = stat?.size ?? file.lengthSync();
      final readLen = length < 256 * 1024 ? length : 256 * 1024;
      if (readLen > 0) {
        final raf = file.openSync();
        try {
          final bytes = raf.readSync(readLen);
          final text = String.fromCharCodes(
            bytes.where((b) => b >= 32 && b < 127),
          ).toLowerCase();
          // CHỈ nhận bằng chứng MẠNH. `encoder_dims`/`query_head_dims`
          // KHÔNG đủ tin (có thể xuất hiện ở cả model offline — bản int8 của
          // model streaming còn không có chuỗi này, xem SHERPA-STREAM-001),
          // nên khi chỉ có dims thì trả `unknown` để route theo profile
          // (VI = offline+VAD, EN = streaming) thay vì đoán sai.
          if (text.contains('non-streaming')) {
            kind = SherpaAsrEncoderKind.nonStreaming;
          } else if (text.contains('streaming')) {
            kind = SherpaAsrEncoderKind.streaming;
          }
        } finally {
          raf.closeSync();
        }
      }
    } catch (_) {
      kind = SherpaAsrEncoderKind.unknown;
    }

    // 2. Tên file/thư mục (k2-fsa đặt tên model streaming luôn có "streaming",
    //    bản offline luôn có "non-streaming") — chỉ dùng khi ONNX im lặng.
    if (kind == SherpaAsrEncoderKind.unknown) {
      final lower = encoderPath.toLowerCase();
      if (lower.contains('non-streaming')) {
        kind = SherpaAsrEncoderKind.nonStreaming;
      } else if (lower.contains('streaming')) {
        kind = SherpaAsrEncoderKind.streaming;
      }
    }

    _encoderKindCache[encoderPath] = _EncoderKindCacheEntry(kind, signature);
    return kind;
  }

  /// Kiểm tra model có phải bản STREAMING hay không (2 lớp: metadata ONNX
  /// trước — nội dung file quyết định — rồi mới tới tên file/thư mục).
  ///
  /// Model streaming KHÔNG nạp được bằng `OfflineRecognizer` (SIGABRT
  /// “Got N Expected 39” — SHERPA-STREAM-001). Chỉ khi không đọc được thông
  /// tin nào mới trả `false` (đường cũ) — nhưng mọi đường gọi đều còn guard
  /// thứ 2 (`SherpaSttEngine`) nên không thể lọt streaming vào offline.
  static bool isStreamingEncoderOnnx(String encoderPath) =>
      detectEncoderKind(encoderPath) == SherpaAsrEncoderKind.streaming;

  /// Tên file/thư mục có dấu hiệu model STREAMING (k2-fsa luôn đặt tên như
  /// vậy). Dùng ở bước import để chặn import model streaming vào profile
  /// offline (và ngược lại) khi metadata ONNX không đọc được.
  static bool nameLooksStreamingModel(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('non-streaming')) return false;
    return lower.contains('streaming');
  }

  SherpaModelPaths? _findAsrModelInDirSync(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return null;

    final files = <String>[];
    try {
      for (final entity in dir.listSync(recursive: true, followLinks: true)) {
        if (entity is File) files.add(entity.path);
      }
    } catch (_) {}

    String? encoder;
    String? decoder;
    String? joiner;
    String? tokens;

    for (final f in files) {
      final name = p.basename(f).toLowerCase();
      final file = File(f);
      if (!file.existsSync() || file.lengthSync() < 1000) continue;

      if (name == 'tokens.txt' ||
          name.endsWith('_tokens.txt') ||
          (name.contains('tokens') && name.endsWith('.txt'))) {
        tokens ??= f;
      } else if (name.endsWith('.onnx')) {
        if (name.contains('encoder')) {
          if (name.contains('int8') || encoder == null) {
            encoder = f;
          }
        } else if (name.contains('decoder')) {
          decoder ??= f;
        } else if (name.contains('joiner')) {
          if (name.contains('int8') || joiner == null) {
            joiner = f;
          }
        }
      }
    }

    if (encoder != null && decoder != null && joiner != null && tokens != null) {
      return SherpaModelPaths(
        encoder: encoder,
        decoder: decoder,
        joiner: joiner,
        tokens: tokens,
        isStreaming: isStreamingEncoderOnnx(encoder),
      );
    }
    return null;
  }

  /// Dò TẤT CẢ model ASR có trên máy theo profile.
  ///
  /// Nguồn (theo thứ tự ưu tiên):
  /// 1. thư mục chuẩn `<documents>/sherpa_asr_models/<profileId>/`;
  /// 2. thư mục con khác trong `sherpa_asr_models/` (user giải nén/import
  ///    nguyên tên archive, vd `sherpa-onnx-zipformer-vi-30M-int8-...`)
  ///    — chỉ nhận khi NHẬN DIỆN ĐƯỢC đúng profile (streaming ↔ EN, token
  ///    tiếng Việt ↔ VI), KHÔNG đoán bừa sang profile khác.
  Map<String, SherpaModelPaths> detectAsrModels(String documentsDir) {
    final result = <String, SherpaModelPaths>{};

    // 1. Folder chuẩn theo profile.
    for (final profile in predefinedAsrProfiles) {
      final paths = _findAsrModelInDirSync(
        p.join(documentsDir, asrFolderName, profile.id),
      );
      if (paths != null) {
        result[profile.id] = paths;
      }
    }

    // 2. Folder “lạ” trong sherpa_asr_models/ (import theo tên archive).
    final root = Directory(p.join(documentsDir, asrFolderName));
    if (root.existsSync()) {
      List<Directory> subDirs = const [];
      try {
        subDirs = root
            .listSync(followLinks: true)
            .whereType<Directory>()
            .toList();
      } catch (_) {}

      // Cả trường hợp user copy file model trực tiếp vào sherpa_asr_models/
      // (chỉ khi không có thư mục con — tránh trộn file của nhiều profile).
      if (subDirs.isEmpty) {
        final rootPaths = _findAsrModelInDirSync(root.path);
        if (rootPaths != null) {
          final profile = _matchProfileForPaths(
            rootPaths,
            folderName: p.basename(root.path),
          );
          if (profile != null && !result.containsKey(profile.id)) {
            result[profile.id] = rootPaths;
          }
        }
      }

      for (final dir in subDirs) {
        final name = p.basename(dir.path);
        if (predefinedAsrProfiles.any((profile) => profile.id == name)) {
          continue; // đã xử lý ở bước 1
        }
        final paths = _findAsrModelInDirSync(dir.path);
        if (paths == null) continue;
        final profile = _matchProfileForPaths(paths, folderName: name);
        if (profile != null && !result.containsKey(profile.id)) {
          result[profile.id] = paths;
          debugPrint('ℹ️ ASR model ngoài folder chuẩn → profile '
              '${profile.id}: ${dir.path}');
        }
      }
    }

    return result;
  }

  /// Nhận diện profile từ nội dung file + tên thư mục (KHÔNG đoán sang
  /// profile ngôn ngữ khác — không khớp thì trả `null`).
  SherpaAsrProfile? _matchProfileForPaths(
    SherpaModelPaths paths, {
    required String folderName,
  }) {
    return matchAsrProfile(
      isStreaming: paths.isStreaming,
      encoderPath: paths.encoder,
      tokensPath: paths.tokens,
      folderName: folderName,
    );
  }

  /// Nhận diện profile Zipformer cho một bộ file model.
  ///
  /// Trả `null` khi không đủ căn cứ — KHÔNG map bừa sang profile ngôn ngữ
  /// khác (CABIN-ASR-002: model lạ từng bị nhét vào folder EN streaming, rồi
  /// chính tên folder “streaming” làm sai guard Online/Offline).
  static SherpaAsrProfile? matchAsrProfile({
    required bool isStreaming,
    String? encoderPath,
    String? tokensPath,
    String? folderName,
  }) {
    final nameHaystack = [
      if (encoderPath != null) encoderPath,
      if (folderName != null) folderName,
    ].join(' ');
    final looksVi = asrTokensLookVietnamese(tokensPath) ||
        _nameLooksLanguage(nameHaystack, 'vi');
    final looksEn = _nameLooksLanguage(nameHaystack, 'en');

    if (isStreaming) {
      // App chỉ có 1 profile streaming (EN) và KHÔNG có VI streaming — nếu
      // tên nói tiếng Việt thì đây không phải profile nào của app.
      if (looksVi && !looksEn) return null;
      return AsrModelRouter.profileForLanguage('en');
    }

    // Nhánh offline: chỉ nhận VI (profile offline duy nhất của app).
    if (!looksVi) return null;
    return AsrModelRouter.profileForLanguage('vi');
  }

  /// tokens.txt có ký tự đặc trưng tiếng Việt (BPE VI chứa âm tiết có dấu).
  static bool asrTokensLookVietnamese(String? tokensPath) {
    if (tokensPath == null) return false;
    try {
      final file = File(tokensPath);
      if (!file.existsSync()) return false;
      final length = file.lengthSync();
      final readLen = length > 512 * 1024 ? 512 * 1024 : length;
      if (readLen <= 0) return false;
      final raf = file.openSync();
      try {
        final bytes = raf.readSync(readLen);
        final text = utf8.decode(bytes, allowMalformed: true);
        return RegExp(
          r'[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợ'
          r'ùúủũụưừứửữựỳýỷỹỵđ]',
        ).hasMatch(text);
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return false;
    }
  }

  /// Tên file/thư mục có nhắc tới mã ngôn ngữ (vi/en) như một token riêng.
  static bool _nameLooksLanguage(String text, String language) {
    final lower = text.toLowerCase();
    if (language == 'vi' && lower.contains('vietnam')) return true;
    return RegExp('(^|[^a-z])${RegExp.escape(language)}([^a-z]|\$)')
        .hasMatch(lower);
  }

  /// Lấy model paths cho một ngôn ngữ hoặc profile ID.
  ///
  /// KHÔNG còn fallback `orElse: predefinedAsrProfiles.first` (CABIN-ASR-002:
  /// hỏi `zh`/`fr` trước đây bị trả về profile VI) — ngôn ngữ không có profile
  /// ⇒ `null` để UI báo “chưa hỗ trợ offline”.
  SherpaModelPaths? getAsrModelPaths(String languageOrProfileId) {
    final docs = _documentsDir;
    if (docs == null) return null;

    final profile = AsrModelRouter.profileForIdOrLanguage(languageOrProfileId);
    if (profile == null) return null;

    // Thư mục chuẩn trước…
    final canonical = _findAsrModelInDirSync(
      p.join(docs, asrFolderName, profile.id),
    );
    if (canonical != null) return canonical;

    // …rồi tới model đã import với tên thư mục khác nhưng nhận diện được.
    return detectAsrModels(docs)[profile.id];
  }

  /// Kiểm tra xem đã có model Zipformer ASR cho ngôn ngữ/profile này chưa.
  bool hasAsrModel(String languageOrProfileId) =>
      getAsrModelPaths(languageOrProfileId) != null;

  /// Tải về bundle Zipformer ASR theo profileId.
  Future<String?> downloadAsrModel(String profileId) async {
    final profile = predefinedAsrProfiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => throw ArgumentError('Unknown profile: $profileId'),
    );

    final currentInfo = asrInfo.stateFor(profileId);
    if (currentInfo.isDownloading) return null;

    final token = CancelToken();
    _asrTokens[profileId] = token;

    final states = Map<String, SherpaModelInfo>.from(_asrState.value.profileStates);
    states[profileId] = const SherpaModelInfo(status: SherpaModelStatus.downloading);
    _asrState.add(_asrState.value.copyWith(profileStates: states));

    try {
      final docs = await _documents();
      final downloadsDir = Directory(p.join(docs, 'downloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final savePath = p.join(downloadsDir.path, profile.archiveName);
      final tmpPath = '$savePath.tmp';

      debugPrint('📥 Download Zipformer ASR $profileId từ: ${profile.downloadUrl}');
      await _dio.download(
        profile.downloadUrl,
        tmpPath,
        cancelToken: token,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final cur = Map<String, SherpaModelInfo>.from(_asrState.value.profileStates);
            cur[profileId] = SherpaModelInfo(
              status: SherpaModelStatus.downloading,
              downloadProgress: received / total,
            );
            _asrState.add(_asrState.value.copyWith(profileStates: cur));
          }
        },
      );

      final tmp = File(tmpPath);
      if (!await tmp.exists() || tmp.lengthSync() < 1000000) {
        throw Exception(
          'File tải về quá nhỏ (${tmp.existsSync() ? tmp.lengthSync() : 0} bytes)',
        );
      }
      await _replaceFile(tmpPath, savePath);

      final targetDir = p.join(docs, asrFolderName, profile.id);
      final target = Directory(targetDir);
      if (await target.exists()) {
        await target.delete(recursive: true);
      }
      await target.create(recursive: true);

      await _extractTarBz2(savePath, targetDir);

      try { await File(savePath).delete(); } catch (_) {}

      await rescan();
      debugPrint('✅ ASR $profileId đã cài vào $targetDir');
      return targetDir;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        final cur = Map<String, SherpaModelInfo>.from(_asrState.value.profileStates);
        cur[profileId] = const SherpaModelInfo(status: SherpaModelStatus.notInstalled);
        _asrState.add(_asrState.value.copyWith(profileStates: cur));
        return null;
      }
      final cur = Map<String, SherpaModelInfo>.from(_asrState.value.profileStates);
      cur[profileId] = SherpaModelInfo(
        status: SherpaModelStatus.error,
        errorMessage: 'HTTP ${e.response?.statusCode ?? '-'} ${e.message}',
      );
      _asrState.add(_asrState.value.copyWith(profileStates: cur));
      return null;
    } catch (e) {
      final cur = Map<String, SherpaModelInfo>.from(_asrState.value.profileStates);
      cur[profileId] = SherpaModelInfo(
        status: SherpaModelStatus.error,
        errorMessage: 'Lỗi tải ASR: $e',
      );
      _asrState.add(_asrState.value.copyWith(profileStates: cur));
      return null;
    } finally {
      _asrTokens.remove(profileId);
      await rescan();
    }
  }

  void cancelAsrDownload(String profileId) {
    _asrTokens[profileId]?.cancel('User cancelled');
    _asrTokens.remove(profileId);
    final cur = Map<String, SherpaModelInfo>.from(_asrState.value.profileStates);
    cur[profileId] = const SherpaModelInfo(status: SherpaModelStatus.notInstalled);
    _asrState.add(_asrState.value.copyWith(profileStates: cur));
  }

  Future<void> deleteAsrModel(String profileId) async {
    try {
      final docs = await _documents();
      final dir = Directory(p.join(docs, asrFolderName, profileId));
      if (await dir.exists()) await dir.delete(recursive: true);
      await rescan();
      debugPrint('🗑️ Deleted ASR model: $profileId');
    } catch (e) {
      debugPrint('⚠️ Delete ASR model error: $e');
    }
  }

  /// Kết quả import model Zipformer ASR (dùng cho UI hiển thị message
  /// đã bản địa hoá — không nhét chuỗi tiếng Việt vào package).
  Future<SherpaAsrImportResult> importAsrFolderResult(
    String folderPath, {
    String? targetProfileId,
  }) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      return const SherpaAsrImportResult(
        status: SherpaAsrImportStatus.sourceMissing,
        detail: 'Thư mục không tồn tại',
      );
    }
    final listing = await _walkPaths(dir.path);
    if (listing.isEmpty) {
      return const SherpaAsrImportResult(
        status: SherpaAsrImportStatus.sourceEmpty,
        detail: 'Thư mục rỗng',
      );
    }
    return _importAsrListing(
      listing,
      sourceLabel: dir.path,
      targetProfileId: targetProfileId,
    );
  }

  Future<SherpaAsrImportResult> importAsrFilesResult(
    List<String> filePaths, {
    String? targetProfileId,
  }) async {
    if (filePaths.isEmpty) {
      return const SherpaAsrImportResult(
        status: SherpaAsrImportStatus.sourceEmpty,
        detail: 'Chưa chọn file nào',
      );
    }
    return _importAsrListing(
      filePaths,
      sourceLabel: filePaths.first,
      targetProfileId: targetProfileId,
    );
  }

  /// Bản cũ trả chuỗi tiếng Việt (giữ để không phá call-site cũ).
  Future<String> importAsrFolder(String folderPath, {String? targetProfileId}) async {
    final result =
        await importAsrFolderResult(folderPath, targetProfileId: targetProfileId);
    return describeAsrImportResult(result);
  }

  Future<String> importAsrFiles(List<String> filePaths, {String? targetProfileId}) async {
    final result =
        await importAsrFilesResult(filePaths, targetProfileId: targetProfileId);
    return describeAsrImportResult(result);
  }

  /// Mô tả kết quả import bằng tiếng Việt (legacy call-sites).
  static String describeAsrImportResult(SherpaAsrImportResult result) {
    final name = result.profile?.name ?? '';
    switch (result.status) {
      case SherpaAsrImportStatus.imported:
        return '✅ Đã import model Zipformer ASR: $name';
      case SherpaAsrImportStatus.sourceMissing:
        return 'Thư mục không tồn tại';
      case SherpaAsrImportStatus.sourceEmpty:
        return 'Chưa chọn file/thư mục nào';
      case SherpaAsrImportStatus.incompleteFiles:
        return 'Import thất bại: cần đủ 4 file (encoder, decoder, joiner .onnx + tokens.txt)';
      case SherpaAsrImportStatus.unknownProfile:
        return 'Import thất bại: không nhận diện được model này là '
            'Tiếng Việt (offline) hay English (streaming) — '
            'hãy bấm Import ở đúng thẻ model.';
      case SherpaAsrImportStatus.profileMismatch:
        return 'Import thất bại: model không khớp profile đã chọn'
            '${result.detectedProfile == null ? '' : ' (nhận diện: ${result.detectedProfile!.name})'}.';
      case SherpaAsrImportStatus.failed:
        return 'Import thất bại: ${result.detail ?? 'lỗi không xác định'}';
    }
  }

  /// Import chung cho folder/file — có NHẬN DIỆN + KIỂM TRA khớp profile.
  ///
  /// Quy tắc (CABIN-ASR-002 / SHERPA-STREAM-001):
  /// - Model streaming chỉ vào profile EN streaming; model offline chỉ vào
  ///   profile VI offline. Không bao giờ nhét model lạ vào folder
  ///   `asr-en-20M-streaming-int8` (chính tên folder đó làm sai guard
  ///   Online/Offline → SIGABRT “Expected 39”).
  /// - Không nhận diện được thì trả `unknownProfile` để UI báo user chọn
  ///   đúng profile, KHÔNG đoán bừa.
  Future<SherpaAsrImportResult> _importAsrListing(
    List<String> listing, {
    required String sourceLabel,
    String? targetProfileId,
  }) async {
    String? tokensPath;
    String? encoderPath;
    for (final path in listing) {
      final name = p.basename(path).toLowerCase();
      if (name.contains('tokens') && name.endsWith('.txt')) {
        tokensPath = path;
      } else if (name.contains('encoder') && name.endsWith('.onnx')) {
        encoderPath = path;
      }
    }

    final encoderKind = encoderPath == null
        ? SherpaAsrEncoderKind.unknown
        : detectEncoderKind(encoderPath);
    // Bằng chứng streaming = metadata ONNX HOẶC tên file/thư mục nguồn.
    final streamingEvidence = encoderKind == SherpaAsrEncoderKind.streaming ||
        nameLooksStreamingModel('$sourceLabel ${encoderPath ?? ''}');
    final detected = matchAsrProfile(
      isStreaming: streamingEvidence,
      encoderPath: encoderPath,
      tokensPath: tokensPath,
      folderName: sourceLabel,
    );

    final explicit = targetProfileId == null
        ? null
        : AsrModelRouter.profileForIdOrLanguage(targetProfileId);

    // Sai lệch chặn cứng: kind ONNX nói ngược lại profile đích.
    SherpaAsrProfile? target = explicit ?? detected;
    if (target == null) {
      return SherpaAsrImportResult(
        status: SherpaAsrImportStatus.unknownProfile,
        detectedProfile: detected,
        encoderKind: encoderKind,
        contentRecognized: false,
      );
    }
    if (streamingEvidence && !target.isStreaming) {
      return SherpaAsrImportResult(
        status: SherpaAsrImportStatus.profileMismatch,
        profile: target,
        detectedProfile: detected,
        encoderKind: encoderKind,
        contentRecognized: detected != null,
      );
    }
    if (encoderKind == SherpaAsrEncoderKind.nonStreaming && target.isStreaming) {
      return SherpaAsrImportResult(
        status: SherpaAsrImportStatus.profileMismatch,
        profile: target,
        detectedProfile: detected,
        encoderKind: encoderKind,
        contentRecognized: detected != null,
      );
    }
    if (detected != null && detected.id != target.id) {
      return SherpaAsrImportResult(
        status: SherpaAsrImportStatus.profileMismatch,
        profile: target,
        detectedProfile: detected,
        encoderKind: encoderKind,
        contentRecognized: true,
      );
    }

    // Metadata ONNX im lặng (bản int8 thật thường vậy — SHERPA-STREAM-001):
    // chỉ nhận model có BẰNG CHỨNG khớp profile đích (tên archive/thư mục
    // hoặc tokens đúng ngôn ngữ). Model lạ lọt vào profile sai ⇒ model
    // streaming vào OfflineRecognizer = SIGABRT “Expected 39”.
    if (encoderKind == SherpaAsrEncoderKind.unknown) {
      final nameHaystack = '$sourceLabel ${encoderPath ?? ''}';
      final evidenceForTarget = target.isStreaming
          ? nameLooksStreamingModel(nameHaystack)
          : (asrTokensLookVietnamese(tokensPath) ||
              _nameLooksLanguage(nameHaystack, 'vi'));
      if (!evidenceForTarget) {
        return SherpaAsrImportResult(
          status: SherpaAsrImportStatus.unknownProfile,
          detectedProfile: detected,
          encoderKind: encoderKind,
          contentRecognized: false,
          detail: 'Không đọc được metadata ONNX và không có bằng chứng '
              'ngôn ngữ/loại model cho profile ${target.id}',
        );
      }
    }

    final docs = await _documents();
    final destDir = p.join(docs, asrFolderName, target.id);
    await Directory(destDir).create(recursive: true);

    var copied = 0;
    var archivePath = '';

    for (final path in listing) {
      final name = p.basename(path).toLowerCase();
      if (name.endsWith('.tar.bz2') || name.endsWith('.zip')) {
        archivePath = path;
        continue;
      }
      if (name == 'tokens.txt' ||
          name.endsWith('_tokens.txt') ||
          (name.contains('tokens') && name.endsWith('.txt')) ||
          name.endsWith('.onnx')) {
        final dest = p.join(destDir, p.basename(path));
        if (await _tryCopyFile(path, dest)) copied++;
      }
    }

    if (copied == 0 && archivePath.isNotEmpty) {
      try {
        if (archivePath.toLowerCase().endsWith('.tar.bz2')) {
          await _extractTarBz2(archivePath, destDir);
        }
      } catch (e) {
        return SherpaAsrImportResult(
          status: SherpaAsrImportStatus.failed,
          profile: target,
          detectedProfile: detected,
          encoderKind: encoderKind,
          contentRecognized: detected != null,
          detail: 'Giải nén archive thất bại: $e',
        );
      }
    }

    await rescan();
    final installed = _findAsrModelInDirSync(destDir);
    if (installed == null) {
      return SherpaAsrImportResult(
        status: SherpaAsrImportStatus.incompleteFiles,
        profile: target,
        detectedProfile: detected,
        encoderKind: encoderKind,
        contentRecognized: detected != null,
      );
    }
    // Model vừa cài: loại encoder thực tế lấy từ file đã copy (nguồn sự thật
    // cho route Online/Offline).
    return SherpaAsrImportResult(
      status: SherpaAsrImportStatus.imported,
      profile: target,
      detectedProfile: detected,
      encoderKind: detectedKindFor(installed),
      contentRecognized: detected != null || explicit != null,
      detail: destDir,
    );
  }

  /// Loại encoder của model đã nằm trên máy.
  static SherpaAsrEncoderKind detectedKindFor(SherpaModelPaths paths) =>
      detectEncoderKind(paths.encoder);

  // ── SILERO VAD ─────────────────────────────────────────────────────────

  Future<bool> downloadVad({int maxRetries = 2}) async {
    if (vadInfo.isReady) return true;
    if (vadInfo.isDownloading) return false;

    final token = CancelToken();
    _vadToken = token;
    _vadState.add(const SherpaModelInfo(status: SherpaModelStatus.downloading));

    try {
      final dir = await _vadDir();
      final savePath = p.join(dir, vadFileName);
      final tmpPath = '$savePath.tmp';
      String lastError = '';

      var ok = false;
      for (final url in vadDownloadUrls) {
        if (ok || token.isCancelled) break;
        var attempt = 0;
        while (attempt < maxRetries && !ok && !token.isCancelled) {
          attempt++;
          try {
            debugPrint('📥 Download $vadFileName từ: $url (lần $attempt)');
            await _dio.download(
              url,
              tmpPath,
              cancelToken: token,
              deleteOnError: true,
              onReceiveProgress: (received, total) {
                if (total > 0) {
                  _vadState.add(_vadState.value
                      .copyWith(downloadProgress: received / total));
                }
              },
            );
            final tmp = File(tmpPath);
            if (!await tmp.exists()) {
              lastError = 'Không ghi được file tạm';
              continue;
            }
            final size = tmp.lengthSync();
            final head = await tmp.openRead(0, 64).first;
            if (!isPlausibleVadFile(size, head: head)) {
              lastError =
                  'File tải về không phải model ($size bytes) — URL trả HTML/lỗi.';
              try { await tmp.delete(); } catch (_) {}
              continue;
            }
            await _replaceFile(tmpPath, savePath);
            ok = true;
          } on DioException catch (e) {
            if (CancelToken.isCancel(e)) break;
            lastError = 'HTTP ${e.response?.statusCode ?? '-'} ${e.message}';
            debugPrint('⚠️ Download VAD thất bại ($url $attempt): $lastError');
            if (attempt < maxRetries) {
              await Future.delayed(Duration(seconds: attempt * 2));
            }
          } catch (e) {
            lastError = '$e';
            debugPrint('⚠️ Download VAD error ($url $attempt): $e');
            if (attempt < maxRetries) {
              await Future.delayed(Duration(seconds: attempt * 2));
            }
          }
        }
      }

      _vadToken = null;
      if (ok) {
        await rescan();
        debugPrint('✅ Download VAD xong: $savePath');
        return true;
      }
      _vadState.add(SherpaModelInfo(
        status: SherpaModelStatus.notInstalled,
        errorMessage:
            'Không tải được $vadFileName. $lastError. Thử lại (Wi-Fi) hoặc Import '
            'file silero_vad.onnx (k2-fsa ~629KB, không phải bắt >1MB).',
      ));
      return false;
    } catch (e) {
      _vadToken = null;
      _vadState.add(SherpaModelInfo(
        status: SherpaModelStatus.error,
        errorMessage: 'Lỗi tải VAD: $e',
      ));
      return false;
    }
  }

  Future<bool> importVadFromPath(String sourcePath) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return false;
      final size = src.lengthSync();
      final head = await src.openRead(0, 64).first;
      if (!isPlausibleVadFile(size, head: head)) {
        debugPrint('❌ File VAD không hợp lệ ($sourcePath, $size bytes)');
        return false;
      }
      final savePath = p.join(await _vadDir(), vadFileName);
      final existing = File(savePath);
      if (await existing.exists()) await existing.delete();
      await src.copy(savePath);
      await rescan();
      debugPrint('✅ Import VAD: $savePath');
      return true;
    } catch (e) {
      debugPrint('❌ Import VAD error: $e');
      return false;
    }
  }

  void cancelVadDownload() {
    _vadToken?.cancel('User cancelled');
    _vadToken = null;
    _vadState.add(const SherpaModelInfo(status: SherpaModelStatus.notInstalled));
  }

  Future<void> deleteVad() async {
    try {
      final f = File(p.join(await _vadDir(), vadFileName));
      if (await f.exists()) await f.delete();
      await rescan();
      debugPrint('🗑️ Deleted VAD model');
    } catch (e) {
      debugPrint('⚠️ Delete VAD error: $e');
    }
  }

  // ── PIPER TTS ──────────────────────────────────────────────────────────

  Future<String> _piperDir() async {
    final dir = Directory(
        p.join(await _documents(), SherpaPiperTtsCore.modelsFolderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  bool _espeakPhontabReady(String piperDir) {
    final phontab = File(
      p.join(piperDir, SherpaPiperTtsCore.espeakDataFolder, 'phontab'),
    );
    return phontab.existsSync() && phontab.lengthSync() > 64;
  }

  Future<bool> get hasEspeak async =>
      _espeakPhontabReady(await _piperDir());

  bool _isOnnxModelName(String name) => PiperImportPaths.isOnnxModelName(name);

  Future<bool> _tryCopyFile(String fromPath, String toPath) async {
    try {
      final dest = File(toPath);
      await dest.parent.create(recursive: true);
      final src = File(fromPath);
      if (src.existsSync()) {
        await src.copy(toPath);
        return true;
      }
      final bytes = await File(fromPath).readAsBytes();
      if (bytes.isEmpty) return false;
      await dest.writeAsBytes(bytes, flush: true);
      return true;
    } catch (e) {
      debugPrint('⚠️ Piper copy $fromPath → $toPath: $e');
      return false;
    }
  }

  Future<List<String>> _walkPaths(String root) async {
    final out = <String>[];
    Future<void> walk(Directory dir, int depth) async {
      if (depth > 12) return;
      try {
        await for (final entity in dir.list(followLinks: true)) {
          try {
            final type = await FileSystemEntity.type(entity.path);
            if (type == FileSystemEntityType.directory) {
              await walk(Directory(entity.path), depth + 1);
            } else {
              out.add(entity.path);
            }
          } catch (_) {
            out.add(entity.path);
          }
        }
      } catch (e) {
        try {
          for (final entity in dir.listSync(recursive: true, followLinks: true)) {
            out.add(entity.path);
          }
        } catch (e2) {
          debugPrint('⚠️ Piper walk ${dir.path}: $e / $e2');
        }
      }
    }

    await walk(Directory(root), 0);
    return out;
  }

  Future<int> _copyEspeakTree(Directory srcRoot) async {
    final files = await _walkPaths(srcRoot.path);
    if (files.isEmpty) return 0;
    final destRoot = Directory(
        p.join(await _piperDir(), SherpaPiperTtsCore.espeakDataFolder));
    if (!await destRoot.exists()) await destRoot.create(recursive: true);
    var n = 0;
    for (final path in files) {
      final rel = p.relative(path, from: srcRoot.path);
      final dest = p.join(destRoot.path, PiperImportPaths.posixRel(rel));
      if (await _tryCopyFile(path, dest)) n++;
    }
    return n;
  }

  Future<bool> _importEspeakNear(List<String> paths) async {
    for (final path in paths) {
      var dir = Directory(p.dirname(path));
      for (var i = 0; i < 5; i++) {
        final direct =
            Directory(p.join(dir.path, PiperImportPaths.espeakFolder));
        if (await _copyEspeakTree(direct) > 0) return true;
        try {
          for (final entity in dir.listSync()) {
            if (PiperImportPaths.looksLikeEspeakRoot(p.basename(entity.path))) {
              if (await _copyEspeakTree(Directory(entity.path)) > 0) {
                return true;
              }
            }
          }
        } catch (_) {
          final listing = await _walkPaths(dir.path);
          var copied = 0;
          for (final filePath in listing) {
            final rel = p.relative(filePath, from: dir.path);
            final tail = PiperImportPaths.espeakTail(rel);
            if (tail == null || tail == PiperImportPaths.espeakFolder) {
              continue;
            }
            final dest = p.join(await _piperDir(), tail);
            if (await _tryCopyFile(filePath, dest)) copied++;
          }
          if (copied > 0) return true;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    return false;
  }

  Future<String> _ensureEspeakAfterImport(String prefix) async {
    await rescan();
    if (piperInfo.espeakInstalled) return prefix;
    final fetched = await downloadEspeakData();
    await rescan();
    if (piperInfo.espeakInstalled) {
      return '$prefix · đã tải espeak-ng-data (phonemizer dùng chung mọi giọng)';
    }
    return '$prefix · $fetched';
  }

  /// Download k2-fsa `espeak-ng-data.tar.bz2` (shared phonemizer). User-tap only.
  Future<String> downloadEspeakData() async {
    if (await hasEspeak) return 'espeak-ng-data đã có';
    if (piperInfo.isDownloading) {
      return 'Đang tải Piper — đợi xong rồi bấm Tải phonemizer.';
    }

    final token = CancelToken();
    _piperToken = token;
    _piperState.add(_piperState.value.copyWith(
      status: SherpaModelStatus.downloading,
      clearError: true,
    ));

    try {
      final docs = await _documents();
      final downloadsDir = Directory(p.join(docs, 'downloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final savePath = p.join(downloadsDir.path, 'espeak-ng-data.tar.bz2');
      final tmpPath = '$savePath.tmp';
      String lastError = '';
      var ok = false;

      for (final url in espeakArchiveUrls) {
        if (ok || token.isCancelled) break;
        try {
          debugPrint('📥 Download espeak-ng-data từ: $url');
          await _dio.download(
            url,
            tmpPath,
            cancelToken: token,
            deleteOnError: true,
            onReceiveProgress: (received, total) {
              if (total > 0) {
                _piperState.add(_piperState.value
                    .copyWith(downloadProgress: received / total));
              }
            },
          );
          final tmp = File(tmpPath);
          if (!await tmp.exists() || tmp.lengthSync() < 20 * 1024) {
            lastError =
                'Archive quá nhỏ (${tmp.existsSync() ? tmp.lengthSync() : 0} bytes)';
            try {
              await tmp.delete();
            } catch (_) {}
            continue;
          }
          await _replaceFile(tmpPath, savePath);
          ok = true;
        } on DioException catch (e) {
          if (CancelToken.isCancel(e)) break;
          lastError = 'HTTP ${e.response?.statusCode ?? '-'} ${e.message}';
        } catch (e) {
          lastError = '$e';
        }
      }

      if (!ok) {
        _piperState.add(_piperState.value.copyWith(
          status: SherpaModelStatus.notInstalled,
          errorMessage:
              'Không tải được espeak-ng-data. $lastError. Thử Wi-Fi.',
        ));
        return 'Không tải được espeak-ng-data. $lastError';
      }

      final extractDir = p.join(downloadsDir.path, 'espeak-ng-data-extracted');
      final extract = Directory(extractDir);
      if (await extract.exists()) await extract.delete(recursive: true);
      await extract.create(recursive: true);
      await _extractTarBz2(savePath, extractDir);

      var src = Directory(p.join(extractDir, PiperImportPaths.espeakFolder));
      if (!src.existsSync()) {
        final listing = await _walkPaths(extractDir);
        for (final f in listing) {
          if (p.basename(f).toLowerCase() == 'phontab') {
            src = Directory(p.dirname(f));
            break;
          }
        }
      }
      final copied = await _copyEspeakTree(src);
      try {
        await File(savePath).delete();
      } catch (_) {}
      try {
        await extract.delete(recursive: true);
      } catch (_) {}

      await rescan();
      if (copied > 0 && piperInfo.espeakInstalled) {
        debugPrint('✅ espeak-ng-data: $copied files');
        return '✅ Đã cài espeak-ng-data ($copied file)';
      }
      return 'Giải nén espeak nhưng không thấy phontab';
    } catch (e) {
      _piperState.add(_piperState.value.copyWith(
        status: SherpaModelStatus.error,
        errorMessage: 'Lỗi tải espeak-ng-data: $e',
      ));
      return 'Lỗi tải espeak-ng-data: $e';
    } finally {
      _piperToken = null;
      if (_piperState.value.isDownloading) await rescan();
    }
  }

  /// Copy named blobs (Android SAF often has bytes but no readable path).
  Future<String> importPiperNamedBytes(Map<String, Uint8List> files) async {
    if (files.isEmpty) return 'Chưa chọn file nào';
    final destDir = await _piperDir();
    var onnx = 0;
    Uint8List? archive;
    var archiveName = '';
    for (final entry in files.entries) {
      final name = p.basename(entry.key);
      final bytes = entry.value;
      if (bytes.isEmpty) continue;
      if (PiperImportPaths.isPiperArchiveName(name) && archive == null) {
        archive = bytes;
        archiveName = name;
        continue;
      }
      if (PiperImportPaths.isEspeakLeafName(name)) {
        final dest = File(p.join(destDir, PiperImportPaths.espeakFolder, name));
        await dest.parent.create(recursive: true);
        await dest.writeAsBytes(bytes, flush: true);
        continue;
      }
      if (!_isOnnxModelName(name) &&
          !PiperImportPaths.isTokensName(name) &&
          !PiperImportPaths.isOnnxJsonName(name)) {
        continue;
      }
      final dest = File(p.join(destDir, name));
      await dest.writeAsBytes(bytes, flush: true);
      if (_isOnnxModelName(name)) onnx++;
    }
    if (onnx == 0 && archive != null) {
      final extractDir = p.join(destDir, '_archive_extract');
      await Directory(extractDir).create(recursive: true);
      final tmp = File(p.join(extractDir, archiveName));
      await tmp.writeAsBytes(archive, flush: true);
      if (archiveName.toLowerCase().endsWith('.tar.bz2')) {
        await _extractTarBz2(tmp.path, extractDir);
      }
      return importPiperFolder(extractDir);
    }
    if (onnx == 0) {
      return 'Thiếu file .onnx — chọn .onnx + tokens.txt (và .onnx.json nếu có).';
    }
    await _normalizeSharedTokens(destDir);
    return _ensureEspeakAfterImport('✅ Đã import $onnx file model');
  }

  Future<String> importPiperFiles(List<String> paths) async {
    if (paths.isEmpty) return 'Chưa chọn file nào';
    final destDir = await _piperDir();
    var onnx = 0;
    var archivePath = '';
    for (final path in paths) {
      final name = p.basename(path);
      if (PiperImportPaths.isPiperArchiveName(name) && archivePath.isEmpty) {
        archivePath = path;
        continue;
      }
      if (PiperImportPaths.isEspeakLeafName(name)) {
        await _tryCopyFile(
          path,
          p.join(destDir, PiperImportPaths.espeakFolder, name),
        );
        continue;
      }
      if (!_isOnnxModelName(name) &&
          !PiperImportPaths.isTokensName(name) &&
          !PiperImportPaths.isOnnxJsonName(name)) {
        continue;
      }
      final ok = await _tryCopyFile(path, p.join(destDir, name));
      if (ok && _isOnnxModelName(name)) onnx++;
    }
    if (onnx == 0 && archivePath.isNotEmpty) {
      try {
        final extractDir = p.join(
          p.dirname(archivePath),
          '${p.basename(archivePath)}-extracted',
        );
        await Directory(extractDir).create(recursive: true);
        if (archivePath.toLowerCase().endsWith('.tar.bz2')) {
          await _extractTarBz2(archivePath, extractDir);
        }
        return importPiperFolder(extractDir);
      } catch (e) {
        return 'Có archive nhưng không giải nén được: $e';
      }
    }
    if (onnx == 0) {
      return 'Thiếu file .onnx — chọn cả bộ (onnx + tokens [+ json]). '
          'espeak-ng-data lấy tự động nếu nằm cạnh file.';
    }
    await _importEspeakNear(paths);
    await _normalizeSharedTokens(destDir);
    return _ensureEspeakAfterImport('✅ Đã import $onnx file model');
  }

  Future<String> importPiperFolder(String folderPath) async {
    var dir = Directory(folderPath);
    if (!await dir.exists()) return 'Thư mục không tồn tại';

    if (PiperImportPaths.looksLikeEspeakRoot(p.basename(dir.path))) {
      await _copyEspeakTree(dir);
      dir = dir.parent;
    }

    final destDir = await _piperDir();
    var copiedOnnx = 0;
    var copiedTokens = 0;
    var copiedJson = 0;
    var copiedEspeak = 0;
    final seen = <String>[];
    var archivePath = '';

    final listing = await _walkPaths(dir.path);
    for (final path in listing) {
      final name = p.basename(path);
      final rel = p.relative(path, from: dir.path);
      if (seen.length < 24) seen.add(PiperImportPaths.posixRel(rel));

      final espeakTail = PiperImportPaths.espeakTail(rel);
      if (espeakTail != null && espeakTail != PiperImportPaths.espeakFolder) {
        final dest = p.join(destDir, espeakTail);
        if (await _tryCopyFile(path, dest)) copiedEspeak++;
        continue;
      }

      if (_isOnnxModelName(name)) {
        if (await _tryCopyFile(path, p.join(destDir, name))) copiedOnnx++;
      } else if (PiperImportPaths.isTokensName(name)) {
        if (await _tryCopyFile(path, p.join(destDir, name))) copiedTokens++;
      } else if (PiperImportPaths.isOnnxJsonName(name)) {
        if (await _tryCopyFile(path, p.join(destDir, name))) copiedJson++;
      } else if (PiperImportPaths.isPiperArchiveName(name) &&
          archivePath.isEmpty) {
        archivePath = path;
      }
    }

    if (copiedOnnx == 0 && archivePath.isNotEmpty) {
      try {
        final extractDir = p.join(
          p.dirname(archivePath),
          '${p.basename(archivePath)}-extracted',
        );
        await Directory(extractDir).create(recursive: true);
        if (archivePath.toLowerCase().endsWith('.tar.bz2')) {
          await _extractTarBz2(archivePath, extractDir);
        }
        return importPiperFolder(extractDir);
      } catch (e) {
        return 'Có archive nhưng không giải nén được: $e';
      }
    }

    if (copiedOnnx == 0) {
      final parent = dir.parent;
      if (parent.path != dir.path) {
        final parentListing = await _walkPaths(parent.path);
        final parentOnnx = parentListing
            .where((f) => _isOnnxModelName(p.basename(f)))
            .toList();
        if (parentOnnx.isNotEmpty) {
          return importPiperFolder(parent.path);
        }
      }
      if (seen.isEmpty) {
        return '$safEmptyPrefix$folderPath';
      }
      return 'Không tìm thấy file .onnx trong "$folderPath". '
          'App thấy: ${seen.join(', ')}. '
          'Hãy Import file (.onnx + tokens.txt) hoặc Tải phonemizer.';
    }

    if (copiedEspeak == 0) {
      await _importEspeakNear(listing);
    }

    await _normalizeSharedTokens(destDir);
    debugPrint(
        '✅ Import Piper folder: $copiedOnnx onnx, $copiedTokens tokens, '
        '$copiedJson json, $copiedEspeak espeak files');
    return _ensureEspeakAfterImport(
      '✅ Đã import $copiedOnnx file model, $copiedTokens tokens, '
      '$copiedJson config',
    );
  }

  Future<void> _normalizeSharedTokens(String destDir) async {
    final dir = Directory(destDir);
    if (!dir.existsSync()) return;
    final onnxStems = <String>[];
    for (final entity in dir.listSync()) {
      final name = p.basename(entity.path);
      if (_isOnnxModelName(name)) {
        onnxStems.add(name.substring(0, name.length - '.onnx'.length));
      }
    }
    final shared = File(p.join(destDir, 'tokens.txt'));
    if (!shared.existsSync() || onnxStems.isEmpty) return;
    for (final stem in onnxStems) {
      final named = File(p.join(destDir, '${stem}_tokens.txt'));
      if (!named.existsSync()) {
        await shared.copy(named.path);
      }
    }
  }

  /// Tải bundle + tự giải nén + cài vào sherpa_piper_models.
  /// Ưu tiên k2-fsa tar.bz2; nếu 404 thì HuggingFace rhasspy/piper-voices.
  Future<String?> downloadPiperBundle({
    required String voice,
  }) async {
    if (piperInfo.isDownloading) return null;

    final token = CancelToken();
    _piperToken = token;
    _piperState.add(_piperState.value.copyWith(
        status: SherpaModelStatus.downloading, clearError: true));

    try {
      final fromK2 = await _downloadPiperK2Fsa(voice, token);
      if (fromK2 != null) return fromK2;
      if (token.isCancelled) return null;

      final fromHf = await _downloadPiperHuggingFace(voice, token);
      if (fromHf != null) return fromHf;

      _piperState.add(SherpaPiperInfo(
        espeakInstalled: _piperState.value.espeakInstalled,
        voices: _piperState.value.voices,
        errorMessage:
            'Could not download Piper $voice (k2-fsa + HuggingFace). '
            'Use Wi-Fi and try again.',
      ));
      return null;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _piperState.add(_piperState.value
            .copyWith(status: SherpaModelStatus.notInstalled, clearError: true));
        return null;
      }
      _piperState.add(SherpaPiperInfo(
        espeakInstalled: _piperState.value.espeakInstalled,
        voices: _piperState.value.voices,
        errorMessage:
            'Could not download Piper (HTTP ${e.response?.statusCode ?? '-'}). '
            'Use Wi-Fi and try again.',
      ));
      return null;
    } catch (e) {
      _piperState.add(SherpaPiperInfo(
        espeakInstalled: _piperState.value.espeakInstalled,
        voices: _piperState.value.voices,
        errorMessage: 'Piper download/install error: $e',
      ));
      return null;
    } finally {
      _piperToken = null;
      if (_piperState.value.isDownloading) {
        await rescan();
      }
    }
  }

  Future<String?> _downloadPiperK2Fsa(String voice, CancelToken token) async {
    final url = piperBundleUrl(voice);
    final docs = await _documents();
    final downloadsDir = Directory(p.join(docs, 'downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    final fileName = 'vits-piper-$voice.tar.bz2';
    final savePath = p.join(downloadsDir.path, fileName);
    final tmpPath = '$savePath.tmp';

    debugPrint('📥 Piper k2-fsa $voice: $url');
    try {
      await _dio.download(
        url,
        tmpPath,
        cancelToken: token,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _piperState.add(_piperState.value
                .copyWith(downloadProgress: received / total * 0.9));
          }
        },
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      debugPrint('⚠️ k2-fsa Piper miss: ${e.response?.statusCode}');
      try {
        await File(tmpPath).delete();
      } catch (_) {}
      return null;
    }

    final tmp = File(tmpPath);
    if (!await tmp.exists() || tmp.lengthSync() < 1000000) {
      try {
        await tmp.delete();
      } catch (_) {}
      return null;
    }
    await _replaceFile(tmpPath, savePath);

    final extractDir =
        p.join(downloadsDir.path, 'vits-piper-$voice-extracted');
    final extract = Directory(extractDir);
    if (await extract.exists()) {
      await extract.delete(recursive: true);
    }
    await extract.create(recursive: true);
    await _extractTarBz2(savePath, extractDir);

    final msg = await importPiperFolder(extractDir);
    try {
      await File(savePath).delete();
    } catch (_) {}
    try {
      await extract.delete(recursive: true);
    } catch (_) {}
    if (!msg.startsWith('✅')) return null;
    await rescan();
    return await _piperDir();
  }

  Future<String?> _downloadPiperHuggingFace(
    String voice,
    CancelToken token,
  ) async {
    final offer = PiperVoiceCatalog.byId(voice);
    if (offer == null) return null;

    final destDir = await _piperDir();
    final onnxDest = p.join(destDir, '${offer.id}.onnx');
    final jsonDest = p.join(destDir, '${offer.id}.onnx.json');
    final tmpOnnx = '$onnxDest.tmp';
    final tmpJson = '$jsonDest.tmp';

    debugPrint('📥 Piper HuggingFace ${offer.id}: ${offer.hfOnnxUrl}');
    await _dio.download(
      offer.hfOnnxUrl,
      tmpOnnx,
      cancelToken: token,
      deleteOnError: true,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          _piperState.add(_piperState.value
              .copyWith(downloadProgress: received / total));
        }
      },
    );
    final onnxFile = File(tmpOnnx);
    if (!await onnxFile.exists() || onnxFile.lengthSync() < 1024 * 1024) {
      try {
        await onnxFile.delete();
      } catch (_) {}
      return null;
    }
    await _replaceFile(tmpOnnx, onnxDest);

    try {
      await _dio.download(
        offer.hfJsonUrl,
        tmpJson,
        cancelToken: token,
        deleteOnError: true,
      );
      final jf = File(tmpJson);
      if (await jf.exists() && jf.lengthSync() > 64) {
        await _replaceFile(tmpJson, jsonDest);
      }
    } catch (e) {
      debugPrint('⚠️ Piper json optional: $e');
    }

    await _ensurePiperTokens(destDir, offer.id);
    await _ensureEspeakAfterImport('HF');
    await rescan();
    if (piperInfo.voices.any((v) => v.name == offer.id)) {
      return destDir;
    }
    return destDir;
  }

  Future<void> _ensurePiperTokens(String destDir, String voiceId) async {
    final named = File(p.join(destDir, '${voiceId}_tokens.txt'));
    final shared = File(p.join(destDir, 'tokens.txt'));
    if (named.existsSync() && named.lengthSync() > 1024) return;
    if (shared.existsSync() && shared.lengthSync() > 1024) {
      await shared.copy(named.path);
      return;
    }
    for (final entity in Directory(destDir).listSync()) {
      final n = p.basename(entity.path);
      if (n.endsWith('_tokens.txt') && File(entity.path).lengthSync() > 1024) {
        await File(entity.path).copy(named.path);
        return;
      }
    }
    try {
      final tmp = p.join(destDir, 'tokens.txt.tmp');
      await _dio.download(piperTokensFallbackUrl, tmp, deleteOnError: true);
      final f = File(tmp);
      if (await f.exists() && f.lengthSync() > 1024) {
        await _replaceFile(tmp, named.path);
        if (!shared.existsSync()) await named.copy(shared.path);
      }
    } catch (e) {
      debugPrint('⚠️ Piper tokens fallback: $e');
    }
  }

  Future<void> _extractTarBz2(String tarBz2Path, String destDir) async {
    final raw = await File(tarBz2Path).readAsBytes();
    final tarBytes = BZip2Decoder().decodeBytes(raw);
    final archive = TarDecoder().decodeBytes(tarBytes);
    for (final file in archive) {
      final name = PiperImportPaths.posixRel(file.name);
      if (name.isEmpty || name == '.' || name == './') continue;
      final outPath = p.join(destDir, name);
      if (file.isDirectory || name.endsWith('/')) {
        await Directory(outPath).create(recursive: true);
        continue;
      }
      final out = File(outPath);
      await out.parent.create(recursive: true);
      final content = file.content;
      if (content is List<int>) {
        await out.writeAsBytes(content, flush: true);
      } else if (content is Uint8List) {
        await out.writeAsBytes(content, flush: true);
      }
    }
  }

  void cancelPiperDownload() {
    _piperToken?.cancel('User cancelled');
    _piperToken = null;
    _piperState.add(_piperState.value
        .copyWith(status: SherpaModelStatus.notInstalled, clearError: true));
  }

  Future<void> deletePiperVoice(String voiceName) async {
    try {
      final dir = await _piperDir();
      for (final suffix in [
        '$voiceName.onnx',
        '${voiceName}_tokens.txt',
        '$voiceName.onnx.json',
      ]) {
        final f = File(p.join(dir, suffix));
        if (await f.exists()) await f.delete();
      }
      await rescan();
      debugPrint('🗑️ Deleted Piper voice: $voiceName');
    } catch (e) {
      debugPrint('⚠️ Delete Piper voice error: $e');
    }
  }

  Future<void> deletePiperAll() async {
    try {
      final dir = Directory(
          p.join(await _documents(), SherpaPiperTtsCore.modelsFolderName));
      if (await dir.exists()) await dir.delete(recursive: true);
      await rescan();
      debugPrint('🗑️ Deleted all Piper models');
    } catch (e) {
      debugPrint('⚠️ Delete Piper all error: $e');
    }
  }

  void dispose() {
    _vadToken?.cancel('Disposed');
    _piperToken?.cancel('Disposed');
    for (final token in _asrTokens.values) {
      token.cancel('Disposed');
    }
    _asrTokens.clear();
    _vadState.close();
    _piperState.close();
    _asrState.close();
    _instance = null;
  }
}
