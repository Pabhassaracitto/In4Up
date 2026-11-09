#pragma once

/// ============================================================================
/// vieneu_tts.h — Thin C ABI over audio.cpp (github.com/0xShug0/audio.cpp)
/// for the VieNeu-TTS v3 Turbo GGUF family.
///
/// in4up integration of ticket TTS-VIENEU-001: on-device, offline Vietnamese
/// neural TTS for Tipiṭaka / Read mode, no Python runtime, no network.
///
/// Design notes (see docs/adr/0022-tts-vieneu-native-audio-cpp.md):
///  * audio.cpp already ships a stable C ABI (include/audiocpp.h); this
///    wrapper only exposes the small in4up contract: init / synthesize /
///    destroy, so Dart FFI stays identical to the UltraTimeStretch / llama.cpp
///    pattern already in the app.
///  * CPU backend only for the first version (audio.cpp CUDA/Vulkan/Metal
///    backends are deliberately out of scope — ticket § "Ngoài phạm vi").
///  * Model file is NOT bundled: user imports `vieneu-v3-turbo-q8_0.gguf`
///    (170 MB, Apache-2.0) manually, same as the Hy-MT .gguf import flow.
/// ============================================================================

#include <stddef.h>
#include <stdint.h>

#ifdef _WIN32
#  define VIENEU_TTS_API __declspec(dllexport)
#else
#  define VIENEU_TTS_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct VieneuTtsContext VieneuTtsContext;
typedef void * vieneu_tts_handle;

/// Chọn giọng đọc cho handle đã khởi tạo (áp dụng cho lần synthesize kế
/// tiếp). Gọi sau [vieneu_tts_create] khi người dùng đổi giọng trong Settings.
VIENEU_TTS_API void vieneu_tts_select_voice(
    vieneu_tts_handle handle,
    const char * voice_ref_codes_file,
    const char * speaker_embedding_file);

/// Trả về trạng thái synthesize (mirror mã audiocpp_status để FFI đơn giản).
typedef enum {
    VIENEU_TTS_OK = 0,
    VIENEU_TTS_ERR_INVALID_ARGUMENT = 1,
    VIENEU_TTS_ERR_LOAD_FAILED = 2,
    VIENEU_TTS_ERR_RUNTIME = 3,
    VIENEU_TTS_ERR_OUT_OF_MEMORY = 4,
    VIENEU_TTS_ERR_UNSUPPORTED_LANGUAGE = 5,
    VIENEU_TTS_ERR_NOT_READY = 6,
} vieneu_tts_status;

/// Khởi tạo engine và nạp model GGUF.
///
/// [model_path]   — đường dẫn file .gguf (bắt buộc).
/// [voice_ref_codes_file] — file mã âm thanh (`ref_codes.txt`, có thể NULL →
///                          dùng giọng mặc định đóng gói kèm model nếu có).
/// [speaker_embedding_file] — file nh embedding người nói (có thể NULL).
/// [threads]      — số luồng CPU (≤ 0 ⇒ mặc định của hệ thống).
///
/// Trả về NULL nếu nạp thất bại (thiếu file, kiến trúc không hỗ trợ,…); chi
/// tiết qua [vieneu_tts_last_error]. Free bằng [vieneu_tts_destroy].
VIENEU_TTS_API vieneu_tts_handle vieneu_tts_create(
    const char * model_path,
    const char * voice_ref_codes_file,
    const char * speaker_embedding_file,
    int threads);

/// Tổng hợp [text] (tiếng Việt, UTF-8) thành PCM float32 mono (khoảng [-1, 1]).
///
/// [language]     — "vi-VN" (engine hiện chỉ hỗ trợ tiếng Việt; ngôn ngữ khác
///                   ⇒ VIENEU_TTS_ERR_UNSUPPORTED_LANGUAGE, không crash).
/// [speaking_rate]|[pitch_shift] — điều hòa tốc độ / cao độ (1.0 / 0 = mặc
///                   định; giá trị ngoài khoảng bị cắt về khoảng an toàn).
///
/// [out_samples] được cấp phát bằng `malloc` trong heap native — người gọi
/// BẮT BUỘC gọi [vieneu_tts_free_audio] khi xong. Trả về số frame (mono) và
/// mẫu/giây qua [out_frames]/[out_sample_rate].
VIENEU_TTS_API vieneu_tts_status vieneu_tts_synthesize(
    vieneu_tts_handle handle,
    const char * text,
    const char * language,
    float speaking_rate,
    float pitch_shift,
    float ** out_samples,
    size_t * out_frames,
    int * out_sample_rate);

/// Giải phóng bộ đệm PCM do [vieneu_tts_synthesize] cấp phát.
VIENEU_TTS_API void vieneu_tts_free_audio(float * samples);

/// Giải phóng engine (an toàn gọi với NULL).
VIENEU_TTS_API void vieneu_tts_destroy(vieneu_tts_handle handle);

/// Chi tiết lỗi của lệnh gọi gần nhất trên thread này (borrowed, hết hạn tại
/// lệnh gọi kế tiếp). Không bao giờ NULL.
VIENEU_TTS_API const char * vieneu_tts_last_error(void);

/// 1 nếu [language] được hỗ trợ ("vi"/"vi-VN"), ngược lại 0.
VIENEU_TTS_API int vieneu_tts_language_supported(const char * language);

/// Clone giọng nói từ các file mẫu âm thanh.
///
/// [voice_id]        — mã giọng mới (tên thư mục trong voices/, ví dụ
///                      "giong_toi"). Không được trùng với giọng đã có.
/// [samples_dir]     — thư mục chứa các file WAV mẫu (khuyên dùng 30–60
///                      giây tổng cộng, mẫuSpeech 16kHz mono).
/// [output_embedding]— đường dẫn file speaker.emb.txt đầu ra (sẽ được tạo
///                      hoặc ghi đè).
///
/// Trả về 0 nếu thành công, mã lỗi VIENEU_TTS_ERR_* nếu thất bại.
/// Chi tiết qua [vieneu_tts_last_error].
VIENEU_TTS_API int vieneu_tts_clone_voice(
    const char * voice_id,
    const char * samples_dir,
    const char * output_embedding);

#ifdef __cplusplus
}  // extern "C"
#endif
