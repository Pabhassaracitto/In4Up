// lib/features/tts/engines/vieneu_tts_engine.dart

// VieNeu-TTS v3 Turbo engine (audio.cpp C API, GGUF, on-device, offline) cho
// TtsService (ticket TTS-VIENEU-001).
//
// PSRC-183/184/186 — một nguồn sự thật cho trạng thái model/worker:
//   * `isAvailable()` chỉ trả lời "có file model + lib native", KHÔNG cache
//     một lần `false` thành `true` như bản cũ.
//   * `getAvailableVoices()` chỉ đọc đĩa, KHÔNG nạp model 170 MB để liệt kê
//     giọng (picker Settings không được phép spawn worker).
//   * `init()` + `selectVoice()` dùng chung bản đồ giọng đã quét, nên giọng
//     mẫu đi kèm GGUF VÀ giọng clone đều được nạp đúng file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import './tts_engine.dart';
import 'package:in4up_stt/tts/vieneu_tts_core.dart';
import 'package:in4up_stt/tts/vieneu_tts_paths.dart';

/// Đường dẫn dữ liệu của một giọng đã quét được từ đĩa.
class _VoiceFiles {
  final String id;
  final String name;
  final String origin;
  final String refCodesPath;
  final String? speakerEmbeddingPath;

  const _VoiceFiles({
    required this.id,
    required this.name,
    required this.origin,
    required this.refCodesPath,
    this.speakerEmbeddingPath,
  });
}

/// VieNeu-TTS v3 Turbo neural TTS chạy hoàn toàn on-device (CPU, audio.cpp
/// GGUF). Không cần mạng, không cần Python runtime.
class VieneuTtsEngine implements TtsEngine {
  VieneuTtsEngine._();
  static final VieneuTtsEngine instance = VieneuTtsEngine._();

  final VieneuTtsCore _core = VieneuTtsCore.instance;

  VieneuModelVariant _modelVariant = VieneuModelVariant.q8_0;
  String? _modelPath;
  String? _voicesDir;
  String? _clonedVoicesDir;
  String? _selectedVoiceId;
  /// Giọng thực sự đang được worker native dùng (khác với giọng UI chọn).
  String? _workerVoiceId;
  bool _initialized = false;
  /// Vì sao engine CHƯA dùng được (null = không có trở ngại). UI/TtsService
  /// cần câu đúng sự thật thay vì luôn nói "chưa import model .gguf" — từ
  /// 1.29 thiếu `sea_g2p.bin` cũng là một lý do chặn.
  String? _blockingReason;
  Future<void>? _initFuture;
  final Map<String, _VoiceFiles> _voiceIndex = <String, _VoiceFiles>{};

  @override
  String get name => 'VieNeu-TTS (native)';

  @override
  String get id => 'vieneu_tts';

  @override
  int get maxCharsPerRequest => 3000; // audio.cpp tự chia đoạn dài (chunk)

  @override
  List<String> get supportedLanguages => const ['vi-VN'];

  /// Worker đã nạp model xong VÀ còn sống. UI dùng getter này để hiện
  /// trạng thái "engine" tách biệt với trạng thái "đã import model"
  /// (PSRC-183: hai badge không được mâu thuẫn nhau).
  bool get isInitialized => _initialized && _core.isInitialized;

  /// Model ưu tiên (biến thể đang chọn); nếu file biến thể đó chưa có nhưng
  /// biến thể khác đã import thì dùng biến thể có thật — picker không còn
  /// báo "Chưa import model" trong khi model Q8_0 đã sẵn sàng.
  Future<String?> _resolveModelPath() async {
    final preferred = await VieneuTtsCore.modelPathFor(_modelVariant);
    if (preferred != null) return preferred;
    for (final variant in VieneuModelVariant.values) {
      final path = await VieneuTtsCore.modelPathFor(variant);
      if (path != null) {
        _modelVariant = variant;
        return path;
      }
    }
    return null;
  }

  Future<void> _rememberPaths(String modelPath) {
    _modelPath = modelPath;
    _voicesDir = p.join(p.dirname(modelPath), 'voices');
    _clonedVoicesDir = p.join(p.dirname(modelPath), 'cloned_voices');
    return Future<void>.value();
  }

  /// Thư mục gốc chứa `voices/` + `cloned_voices/`. Vẫn trả về được khi
  /// chưa import GGUF ⇒ giọng mẫu import từ thư mục vẫn hiển thị (PSRC-186).
  Future<String> _voicesRoot() async {
    final model = await _resolveModelPath();
    if (model != null) {
      await _rememberPaths(model);
      return p.dirname(model);
    }
    final dir = await getApplicationDocumentsDirectory();
    final root = p.join(dir.path, 'vieneu_tts');
    _modelPath = null;
    _voicesDir = p.join(root, 'voices');
    _clonedVoicesDir = p.join(root, 'cloned_voices');
    return root;
  }

  /// Câu giải thích vì sao engine chưa sẵn sàng (null = không có trở ngại).
  String? get blockingReason => _blockingReason;

  /// Từ điển phát âm SEA-G2P đã có cạnh model chưa?
  ///
  /// Model chỉ nhận **phoneme**, không nhận chữ thô: thiếu `sea_g2p.bin` thì
  /// audio.cpp ném lỗi ngay khi nạp — sau khi đã tốn ~170 MB RAM. Hàm này để
  /// chặn TRƯỚC và để UI nói đúng lý do (lane L6, ADR-0028).
  Future<bool> hasPhonemeDictionary() async {
    final model = await _resolveModelPath();
    final String dir;
    if (model != null) {
      dir = p.dirname(model);
    } else {
      final base = await getApplicationDocumentsDirectory();
      dir = p.join(base.path, 'vieneu_tts');
    }
    try {
      return await File(vieneuG2pDictionaryPath(dir)).exists();
    } catch (e) {
      debugPrint('⚠️ VieNeu-TTS: không kiểm được từ điển phát âm: $e');
      return false;
    }
  }

  /// Có thể dùng ngay bây giờ? (lib native + ít nhất một file .gguf)
  ///
  /// Không yêu cầu worker đã init: model import xong là "available"; việc nạp
  /// 170 MB diễn ra lazy khi synthesize / bấm "Khởi tạo engine".
  @override
  Future<bool> isAvailable() async {
    final model = await _resolveModelPath();
    if (model == null) {
      _modelPath = null;
      _voicesDir = null;
      _clonedVoicesDir = null;
      _initialized = false;
      _blockingReason = 'Chưa import model VieNeu-TTS (.gguf)';
      return false;
    }
    await _rememberPaths(model);
    // Bản cũ cache `_modelResolved = true` ngay cả khi lib native thiếu,
    // rồi lần gọi SAU trả true ⇒ trạng thái engine/model không nhất quán.
    return VieneuTtsCore.isNativeLibraryAvailable();
  }

  Future<bool> _hasVoiceData(File file) async {
    try {
      if (!await file.exists()) return false;
      final length = await file.length();
      if (length < 10) return false;
      if (p.extension(file.path).toLowerCase() == '.bin') return length > 32;
      return hasVieneuVoiceData(await file.readAsString());
    } catch (_) {
      // File nhị phân không đọc được như text nhưng có kích thước hợp lệ.
      try {
        return await file.length() > 32;
      } catch (_) {
        return false;
      }
    }
  }

  Future<Map<String, String>> _readManifest(Directory voicesDir) async {
    final manifest = File(p.join(voicesDir.path, 'manifest.json'));
    if (!await manifest.exists()) return <String, String>{};
    try {
      return parseVieneuVoiceNames(await manifest.readAsString());
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _scanVoiceDirectory(
    Directory parent,
    Map<String, _VoiceFiles> index,
    Map<String, String> names, {
    required String origin,
  }) async {
    if (!await parent.exists()) return;
    await for (final entity in parent.list()) {
      if (entity is! Directory) continue;
      final voiceId = p.basename(entity.path);
      if (voiceId.startsWith('_') ||
          voiceId == vieneuTempSamplesDirName ||
          index.containsKey(voiceId)) {
        continue;
      }
      final refTxt = File(p.join(entity.path, 'ref_codes.txt'));
      final refBin = File(p.join(entity.path, 'ref_codes.bin'));
      final emb = File(p.join(entity.path, 'speaker.emb.txt'));
      final hasTxt = await _hasVoiceData(refTxt);
      final hasBin = await _hasVoiceData(refBin);
      final hasEmb = await _hasVoiceData(emb);
      if (!hasTxt && !hasBin && !hasEmb) continue;
      index[voiceId] = _VoiceFiles(
        id: voiceId,
        name: names[voiceId] ?? voiceId.replaceAll('_', ' '),
        origin: origin,
        refCodesPath: hasTxt ? refTxt.path : (hasBin ? refBin.path : ''),
        speakerEmbeddingPath: hasEmb ? emb.path : null,
      );
    }
  }

  /// Giọng preset (voices/) + giọng đã clone (cloned_voices/).
  ///
  /// KHÔNG gọi `_core.init()` ở đây: Settings chỉ cần đọc đĩa, không nạp
  /// model 170 MB (nguyên nhân văng app / timeout khi mở cài đặt — PSRC-187).
  /// Placeholder `ref_codes.txt` chỉ chứa comment bị bỏ qua (PSRC-186/187).
  @override
  Future<List<TtsVoice>> getAvailableVoices(String language) async {
    if (!language.startsWith('vi')) return <TtsVoice>[];
    final root = await _voicesRoot();
    final voicesDir = Directory(p.join(root, 'voices'));
    final clonedDir = Directory(p.join(root, 'cloned_voices'));
    final index = <String, _VoiceFiles>{};

    await _scanVoiceDirectory(
      voicesDir,
      index,
      await _readManifest(voicesDir),
      origin: 'preset',
    );
    await _scanVoiceDirectory(
      clonedDir,
      index,
      const <String, String>{},
      origin: 'cloned',
    );

    // Chưa có giọng nào (chỉ import .gguf): vẫn hiện giọng mặc định embed
    // trong GGUF. audio.cpp nhận refCodes=nullptr và dùng giọng của model.
    if (index.isEmpty) {
      index[VieneuTtsCore.defaultVoiceId] = _VoiceFiles(
        id: VieneuTtsCore.defaultVoiceId,
        name: VieneuTtsCore.defaultVoiceId.replaceAll('_', ' '),
        origin: 'default',
        refCodesPath: '',
        speakerEmbeddingPath: null,
      );
    }

    _voiceIndex
      ..clear()
      ..addAll(index);
    final sorted = index.values.toList()
      ..sort((a, b) {
        final aDefault = a.id == VieneuTtsCore.defaultVoiceId ? 0 : 1;
        final bDefault = b.id == VieneuTtsCore.defaultVoiceId ? 0 : 1;
        return aDefault.compareTo(bDefault);
      });
    return sorted
        .map((v) => TtsVoice(
              id: v.id,
              name: v.name,
              language: 'vi-VN',
              gender: 'unknown',
              engine: id,
              isNeural: true,
              origin: v.origin,
            ))
        .toList();
  }

  /// Khởi tạo worker (nạp model vào native isolate). Gọi từ TtsService trước
  /// lần synthesize đầu tiên; thất bại thì engine remains unavailable và
  /// TtsService fallback bình thường.
  Future<void> init({String? voiceId, VieneuModelVariant? modelVariant}) {
    final requestedVariant = modelVariant ?? _modelVariant;
    final requestedVoice =
        voiceId ?? _selectedVoiceId ?? VieneuTtsCore.defaultVoiceId;
    final inFlight = _initFuture;
    if (inFlight != null) {
      return inFlight.catchError((_) {}).then((_) => init(
            voiceId: requestedVoice,
            modelVariant: requestedVariant,
          ));
    }
    final future = _initOnce(
      voiceId: requestedVoice,
      modelVariant: requestedVariant,
    );
    _initFuture = future;
    future.whenComplete(() {
      if (identical(_initFuture, future)) _initFuture = null;
    });
    return future;
  }

  Future<void> _initOnce({
    required String voiceId,
    required VieneuModelVariant modelVariant,
  }) async {
    final changedVariant = modelVariant != _modelVariant;
    _modelVariant = modelVariant;
    if (changedVariant) {
      _modelPath = null;
      _voicesDir = null;
      _clonedVoicesDir = null;
      _initialized = false;
      _workerVoiceId = null;
    }
    final model = await VieneuTtsCore.modelPathFor(modelVariant);
    if (model == null) {
      _initialized = false;
      _workerVoiceId = null;
      if (_core.isInitialized) await _core.dispose();
      return;
    }
    await _rememberPaths(model);

    // PSRC-187 (audit 1.27.0): bản cài KHÔNG có thư viện native thì dừng ở
    // đây — không quét thư mục giọng và không gọi `_core.init` ở mỗi câu đọc;
    // `TtsService` chuyển sang engine kế tiếp. (`VieneuTtsCore.init` cũng tự
    // chặn trước khi spawn worker; kết quả dò thư viện được nhớ nên phép hỏi
    // này không tốn gì.)
    if (!await VieneuTtsCore.isNativeLibraryAvailable()) {
      _initialized = false;
      _workerVoiceId = null;
      return;
    }

    // Lane L6 / ADR-0028: thiếu `sea_g2p.bin` thì model KHÔNG đọc được câu
    // nào (audio.cpp ném lỗi ở bước nạp, sau khi đã cấp ~170 MB). Chặn trước
    // và ghi lý do để UI/TtsService nói đúng sự thật.
    if (!await hasPhonemeDictionary()) {
      _initialized = false;
      _workerVoiceId = null;
      _blockingReason =
          'Thiếu từ điển phát âm sea_g2p.bin — tải trong Cài đặt › Giọng đọc';
      debugPrint('⚠️ VieNeu-TTS: thiếu ${vieneuG2pDictFileName} cạnh model');
      if (_core.isInitialized) await _core.dispose();
      return;
    }

    // Bản đồ giọng phải được quét TRƯỚC khi init để worker nhận đúng
    // ref_codes/speaker.emb của giọng mẫu hoặc giọng clone.
    await getAvailableVoices('vi-VN');
    final files = _voiceIndex[voiceId];

    try {
      await _core.init(
        modelPath: model,
        voiceId: voiceId,
        refCodesFile: (files?.refCodesPath.isNotEmpty ?? false)
            ? files!.refCodesPath
            : null,
        speakerEmbeddingFile: files?.speakerEmbeddingPath,
        clonedVoicesDir: _clonedVoicesDir,
      );
      _initialized = _core.isInitialized;
      if (_initialized) {
        _blockingReason = null;
        _selectedVoiceId = voiceId;
        // Worker có thể đã init từ trước với giọng khác ⇒ áp lại giọng đang
        // chọn, tránh "UI chọn giọng A nhưng native đọc giọng B".
        await selectVoice(voiceId);
      }
    } catch (e) {
      debugPrint('⚠️ VieNeu-TTS init error: $e');
      _initialized = false;
      _workerVoiceId = null;
    }
  }

  /// Đổi giọng đọc. Truyền đường dẫn file tuyệt đối đã quét được, kể cả
  /// giọng nằm ở `cloned_voices/` (PSRC-184/186).
  Future<void> selectVoice(String voiceId) async {
    _selectedVoiceId = voiceId;
    // Chọn giọng khi worker chưa nạp model là hợp lệ (Settings mở trước khi
    // phát). Lưu lựa chọn; `_initOnce` sẽ áp nó ngay sau khi worker sẵn sàng.
    if (!_core.isInitialized) return;
    final root = await _voicesRoot();
    if (_voiceIndex.isEmpty) await getAvailableVoices('vi-VN');
    final files = _voiceIndex[voiceId];
    try {
      await _core.selectVoice(
        voiceId,
        p.join(root, 'voices'),
        clonedVoicesDir: p.join(root, 'cloned_voices'),
        refCodesFile: (files?.refCodesPath.isNotEmpty ?? false)
            ? files!.refCodesPath
            : null,
        speakerEmbeddingFile: files?.speakerEmbeddingPath,
      );
      _selectedVoiceId = voiceId;
      _workerVoiceId = voiceId;
    } catch (e) {
      debugPrint('⚠️ VieNeu-TTS selectVoice error: $e');
      _workerVoiceId = null;
      rethrow;
    }
  }

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String language,
    double speed = 1.0,
    double pitch = 1.0,
    String? voiceId,
  }) async {
    // Chỉ đọc tiếng Việt — guard phòng hộ cho read mode đa ngôn ngữ
    // (Tipiṭaka: Pali = 'hi', Anh = 'en' đọc bằng engine khác).
    if (!language.startsWith('vi')) {
      return TtsResult.failure(
        error: 'VieNeu-TTS chỉ hỗ trợ tiếng Việt ($language)',
        engine: name,
      );
    }

    await init(voiceId: voiceId ?? _selectedVoiceId, modelVariant: _modelVariant);
    if (!_initialized) {
      return TtsResult.failure(
        error: _blockingReason ??
            'VieNeu-TTS chưa sẵn sàng (chưa import model .gguf)',
        engine: name,
      );
    }

    try {
      final desiredVoice =
          voiceId ?? _selectedVoiceId ?? VieneuTtsCore.defaultVoiceId;
      if (desiredVoice != _workerVoiceId) {
        await selectVoice(desiredVoice);
      }
      final result = await _core.synthesize(
        text: text,
        language: language,
        speed: speed,
        pitch: pitch,
        voiceId: desiredVoice,
      );
      if (result == null) {
        return TtsResult.failure(
          error: 'VieNeu-TTS không tổng hợp được âm thanh',
          engine: name,
        );
      }
      return TtsResult.successBytes(data: result.wavBytes, engine: name);
    } catch (e) {
      debugPrint('⚠️ VieNeu-TTS synthesize error: $e');
      return TtsResult.failure(error: 'VieNeu-TTS lỗi: $e', engine: name);
    }
  }

  /// Sau khi import/đổi model: dọn worker cũ để lần phát tới nạp ĐÚNG file
  /// vừa import (PSRC-183). Không gọi init ở đây — tránh nạp 170 MB ngay
  /// trong lúc người dùng còn đang ở màn cài đặt.
  Future<void> invalidate() async {
    await _core.dispose();
    _initialized = false;
    _blockingReason = null;
    _workerVoiceId = null;
    _modelPath = null;
    _voicesDir = null;
    _clonedVoicesDir = null;
    _voiceIndex.clear();
  }

  void dispose() {
    _core.dispose();
    _initialized = false;
    _workerVoiceId = null;
  }
}
