#include "vieneu_tts.h"

#include "audiocpp.h"  // audio.cpp C ABI — third_party/audio.cpp/include

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <string>
#include <vector>

namespace fs = std::filesystem;

namespace {

/// Chi tiết lỗi của lệnh gọi gần nhất trên thread này (borrowed: hết hạn tại
/// lệnh gọi tiếp theo). Dart FFI gọi tuần tự từ một isolate worker nên
/// thread-local là đủ và không cần khóa.
thread_local std::string g_last_error;

bool file_exists(const char * path) {
    if (!path || !*path) return false;
    std::error_code ec;
    return fs::exists(fs::path(path), ec);
}

/// Thư mục chứa file model.
fs::path model_folder(const char * model_path) {
    if (!model_path || !*model_path) return {};
    std::error_code ec;
    auto p = fs::weakly_canonical(fs::path(model_path), ec);
    if (ec) p = fs::path(model_path);
    return p.has_filename() ? p.parent_path() : p;
}

const char * kG2pDictName = "sea_g2p.bin";

#ifdef _WIN32
const char * kG2pLibCandidates[] = {"sea_g2p_rs.dll", "sea_g2p.dll", nullptr};
#elif defined(__APPLE__)
const char * kG2pLibCandidates[] = {"libsea_g2p_rs.dylib", "libsea_g2p.dylib", nullptr};
#else
const char * kG2pLibCandidates[] = {"libsea_g2p_rs.so", "libsea_g2p.so", nullptr};
#endif

const char * find_g2p_library(const fs::path & folder) {
    if (folder.empty()) return nullptr;
    for (const char * const * name = kG2pLibCandidates; *name; ++name) {
        if (file_exists((folder / *name).c_str())) return *name;
    }
    return nullptr;
}

}  // namespace

struct VieneuTtsContext {
    audiocpp_registry * registry = nullptr;
    audiocpp_model * model = nullptr;
    audiocpp_session * session = nullptr;

    std::string ref_codes_file;      // giọng đang chọn (ref_codes.txt)
    std::string speaker_embedding_file;

    std::string last_error;          // lỗi của lệnh gọi gần nhất trên handle này
    bool initialized = false;

    ~VieneuTtsContext() {
        if (session) audiocpp_session_free(session);
        if (model) audiocpp_model_free(model);
        if (registry) audiocpp_registry_free(registry);
    }
};

extern "C" VIENEU_TTS_API vieneu_tts_handle vieneu_tts_create(
    const char * model_path,
    const char * voice_ref_codes_file,
    const char * speaker_embedding_file,
    int threads) {
    g_last_error.clear();

    if (!model_path || !*model_path) {
        g_last_error = "vieneu_tts_create: model_path là bắt buộc";
        return nullptr;
    }
    if (!file_exists(model_path)) {
        g_last_error =
            "vieneu_tts_create: không tìm thấy file model: " +
            std::string(model_path);
        return nullptr;
    }

    audiocpp_registry * registry = nullptr;
    if (audiocpp_registry_create(nullptr, &registry) != AUDIOCPP_OK ||
        !registry) {
        g_last_error = "vieneu_tts_create: không tạo model registry: " +
                         std::string(audiocpp_last_error());
        return nullptr;
    }

    auto * ctx = new (std::nothrow) VieneuTtsContext();
    if (!ctx) {
        audiocpp_registry_free(registry);
        g_last_error = "vieneu_tts_create: hết bộ nhớ";
        return nullptr;
    }
    ctx->registry = registry;

    if (voice_ref_codes_file && *voice_ref_codes_file)
        ctx->ref_codes_file = voice_ref_codes_file;
    if (speaker_embedding_file && *speaker_embedding_file)
        ctx->speaker_embedding_file = speaker_embedding_file;

    const int n_threads = threads > 0 ? threads : 4;

    // Session options: backend CPU, số luồng, và (nếu có sẵn bên cạnh model)
    // sea-g2p để nhận văn bản tiếng Việt thuần thay vì chuỗi phoneme.
    audiocpp_options * session_options = audiocpp_options_create();
    const fs::path folder = model_folder(model_path);
    if (const char * g2p_lib = find_g2p_library(folder)) {
        if (file_exists((folder / kG2pDictName).c_str())) {
            audiocpp_options_set(session_options,
                                 "vieneu_v3_turbo.g2p_library",
                                 (folder / g2p_lib).u8string().c_str());
            audiocpp_options_set(session_options,
                                 "vieneu_v3_turbo.g2p_dict_file",
                                 (folder / kG2pDictName).u8string().c_str());
        }
    }

    audiocpp_backend_config backend{};
    backend.backend = "cpu";
    backend.device = 0;
    backend.threads = n_threads;

    audiocpp_model_config model_config{};
    model_config.family_hint = "vieneu_v3_turbo";

    if (audiocpp_model_load(ctx->registry, model_path, &model_config,
                            nullptr, &ctx->model) != AUDIOCPP_OK ||
        !ctx->model) {
    ctx->last_error = "vieneu_tts_create: nạp model thất bại: " +
                      std::string(audiocpp_last_error());
    g_last_error = ctx->last_error;
    delete ctx;
    audiocpp_options_free(session_options);
    return nullptr;
    }

    if (audiocpp_session_create(ctx->model, "tts", "offline", &backend,
                                session_options, &ctx->session) !=
            AUDIOCPP_OK ||
        !ctx->session) {
        ctx->last_error =
            "vieneu_tts_create: tạo session thất bại: " +
            std::string(audiocpp_last_error());
        g_last_error = ctx->last_error;
        delete ctx;
        audiocpp_options_free(session_options);
        return nullptr;
    }
    audiocpp_options_free(session_options);

    ctx->initialized = true;
    return ctx;
}

extern "C" VIENEU_TTS_API void vieneu_tts_select_voice(
    vieneu_tts_handle handle,
    const char * voice_ref_codes_file,
    const char * speaker_embedding_file) {
    auto * ctx = static_cast<VieneuTtsContext *>(handle);
    if (!ctx) return;
    ctx->last_error.clear();
    if (voice_ref_codes_file && *voice_ref_codes_file)
        ctx->ref_codes_file = voice_ref_codes_file;
    else
        ctx->ref_codes_file.clear();
    if (speaker_embedding_file && *speaker_embedding_file)
        ctx->speaker_embedding_file = speaker_embedding_file;
    else
        ctx->speaker_embedding_file.clear();
}

extern "C" VIENEU_TTS_API vieneu_tts_status vieneu_tts_synthesize(
    vieneu_tts_handle handle,
    const char * text,
    const char * language,
    float speaking_rate,
    float pitch_shift,
    float ** out_samples,
    size_t * out_frames,
    int * out_sample_rate) {
    auto * ctx = static_cast<VieneuTtsContext *>(handle);
    if (!ctx || !ctx->initialized || !ctx->session) {
        g_last_error = "vieneu_tts_synthesize: engine chưa sẵn sàng";
        return VIENEU_TTS_ERR_NOT_READY;
    }
    if (!text || !*text) {
        ctx->last_error = "vieneu_tts_synthesize: text trống";
        return VIENEU_TTS_ERR_INVALID_ARGUMENT;
    }
    if (!language || !*language ||
        (std::strncmp(language, "vi", 2) != 0)) {
        g_last_error =
            "vieneu_tts_synthesize: VieNeu-TTS chỉ hỗ trợ tiếng Việt (vi), ";
        g_last_error += language ? language : "";
        g_last_error += " — không đọc Pali/mūla gốc";
        ctx->last_error = g_last_error;
        return VIENEU_TTS_ERR_UNSUPPORTED_LANGUAGE;
    }
    if (!out_samples || !out_frames || !out_sample_rate) {
        g_last_error =
            "vieneu_tts_synthesize: tham số đầu ra không hợp lệ";
        ctx->last_error = g_last_error;
        return VIENEU_TTS_ERR_INVALID_ARGUMENT;
    }

    *out_samples = nullptr;
    *out_frames = 0;
    *out_sample_rate = 0;
    ctx->last_error.clear();

    // Cắt các tham số về khoảng an toàn (audio.cpp định nghĩa mặc định: rate
    // 1.0, pitch 0 semitone).
    const float rate = std::clamp(speaking_rate, 0.1f, 4.0f);
    const float pitch = std::clamp(pitch_shift, -12.0f, 12.0f);

    audiocpp_request * request = audiocpp_request_create();
    if (!request) {
        ctx->last_error = "vieneu_tts_synthesize: không tạo request";
        return VIENEU_TTS_ERR_RUNTIME;
    }

    if (audiocpp_request_set_text(request, text, language) != AUDIOCPP_OK) {
        ctx->last_error = "vieneu_tts_synthesize: đặt text thất bại: " +
                          std::string(audiocpp_last_error());
        g_last_error = ctx->last_error;
        audiocpp_request_free(request);
        return VIENEU_TTS_ERR_RUNTIME;
    }

    // Điều hòa tốc độ / cao độ qua C ABI của audio.cpp.
    if (audiocpp_request_set_speaking_rate(request, rate) != AUDIOCPP_OK) {
        ctx->last_error = "vieneu_tts_synthesize: đặt speaking_rate thất bại: " +
                          std::string(audiocpp_last_error());
        g_last_error = ctx->last_error;
        audiocpp_request_free(request);
        return VIENEU_TTS_ERR_RUNTIME;
    }
    if (audiocpp_request_set_pitch_shift(request, pitch) != AUDIOCPP_OK) {
        ctx->last_error = "vieneu_tts_synthesize: đặt pitch_shift thất bại: " +
                          std::string(audiocpp_last_error());
        g_last_error = ctx->last_error;
        audiocpp_request_free(request);
        return VIENEU_TTS_ERR_RUNTIME;
    }

    // Giọng preset: các file bên cạnh model trong thư mục voices/<id>/.
    if (!ctx->ref_codes_file.empty() &&
        file_exists(ctx->ref_codes_file.c_str())) {
        if (audiocpp_request_set_option(request, "reference_codes_file",
                                        ctx->ref_codes_file.c_str()) !=
            AUDIOCPP_OK) {
            ctx->last_error =
                "vieneu_tts_synthesize: đặt reference_codes_file thất bại: " +
                std::string(audiocpp_last_error());
            g_last_error = ctx->last_error;
            audiocpp_request_free(request);
            return VIENEU_TTS_ERR_RUNTIME;
        }
    }
    if (!ctx->speaker_embedding_file.empty() &&
        file_exists(ctx->speaker_embedding_file.c_str())) {
        if (audiocpp_request_set_option(request, "speaker_embedding_file",
                                        ctx->speaker_embedding_file.c_str()) !=
            AUDIOCPP_OK) {
            ctx->last_error =
                "vieneu_tts_synthesize: đặt speaker_embedding_file thất bại: " +
                std::string(audiocpp_last_error());
            g_last_error = ctx->last_error;
            audiocpp_request_free(request);
            return VIENEU_TTS_ERR_RUNTIME;
        }
    }

    audiocpp_result * result = nullptr;
    if (audiocpp_session_run(ctx->session, request, &result) != AUDIOCPP_OK ||
        !result) {
        ctx->last_error =
            "vieneu_tts_synthesize: tổng hợp thất bại: " +
            std::string(audiocpp_last_error());
        g_last_error = ctx->last_error;
        audiocpp_request_free(request);
        return VIENEU_TTS_ERR_RUNTIME;
    }

    const float * samples = nullptr;
    size_t frames = 0;
    int sample_rate = 0;
    int channels = 0;
    if (audiocpp_result_audio(result, &samples, &frames, &sample_rate,
                              &channels) != AUDIOCPP_OK || !samples ||
        frames == 0) {
        ctx->last_error =
            "vieneu_tts_synthesize: không có âm thanh đầu ra";
        g_last_error = ctx->last_error;
        audiocpp_result_free(result);
        audiocpp_request_free(request);
        return VIENEU_TTS_ERR_RUNTIME;
    }

    // Copy PCM sang bộ đệm malloc — Dart FFI đọc rồi gọi free_audio.
    float * out = static_cast<float *>(
        std::malloc(frames * sizeof(float)));
    if (!out) {
        ctx->last_error = "vieneu_tts_synthesize: hết bộ nhớ";
        g_last_error = ctx->last_error;
        audiocpp_result_free(result);
        audiocpp_request_free(request);
        return VIENEU_TTS_ERR_OUT_OF_MEMORY;
    }
    std::memcpy(out, samples, frames * sizeof(float));

    *out_samples = out;
    *out_frames = frames;
    *out_sample_rate = sample_rate;

    audiocpp_result_free(result);
    audiocpp_request_free(request);
    return VIENEU_TTS_OK;
}

extern "C" VIENEU_TTS_API void vieneu_tts_free_audio(float * samples) {
    std::free(samples);
}

extern "C" VIENEU_TTS_API void vieneu_tts_destroy(vieneu_tts_handle handle) {
    delete static_cast<VieneuTtsContext *>(handle);
}

extern "C" VIENEU_TTS_API const char * vieneu_tts_last_error(void) {
    return g_last_error.c_str();
}

extern "C" VIENEU_TTS_API int vieneu_tts_language_supported(
    const char * language) {
    if (!language || !*language) return 0;
    return std::strncmp(language, "vi", 2) == 0 ? 1 : 0;
}
