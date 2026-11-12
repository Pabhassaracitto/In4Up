#include "vieneu_tts.h"

#include "audiocpp.h"  // audio.cpp C ABI — third_party/audio.cpp/include

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
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

/// Kiểm tra file ref_codes / embedding có nội dung hợp lệ (không phải
/// placeholder comment). PSRC-187: file rỗng hoặc chỉ chứa `# ...` mà vẫn
/// truyền vào audio.cpp qua `reference_codes_file` có thể gây parse lỗi /
/// SIGSEGV — phải bỏ qua và để engine dùng giọng mặc định trong GGUF.
bool is_valid_voice_file(const char * path) {
    if (!path || !*path) return false;
    if (!file_exists(path)) return false;
    std::error_code ec;
    auto sz = fs::file_size(fs::path(path), ec);
    if (ec || sz < 8) return false; // placeholder `# ...` chỉ ~30 bytes; file thật vài KB
    std::ifstream in(path);
    if (!in.is_open()) return false;
    std::string line;
    int nonCommentLines = 0;
    while (std::getline(in, line)) {
        // trim
        size_t s = line.find_first_not_of(" \t\r\n");
        if (s == std::string::npos) continue;
        if (line[s] == '#') continue;
        nonCommentLines++;
        // Cần ít nhất 1 dòng dữ liệu thực (> 4 ký tự) để coi là hợp lệ
        if (line.size() - s > 4) {
            // Với file embedding, dòng đầu là số chiều; dòng 2 là floats.
            // Với ref_codes, dòng đầu thường là base64/codes > 10 chars.
            // Chỉ cần 1 dòng hợp lệ là đủ.
            in.close();
            return nonCommentLines >= 1;
        }
    }
    in.close();
    return nonCommentLines >= 1;
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
    const fs::path g2p_dict_path = folder / kG2pDictName;

    // SEA-G2P (BETA-1.29.0 / PSRC-214..218): audio.cpp tự `dlopen` thư viện
    // theo TÊN (`libsea_g2p_rs.so`, …) khi KHÔNG có option `g2p_library` —
    // nhờ vậy lib có thể nằm trong jniLibs của APK (đúng đường tìm mặc định
    // của linker động), không buộc người dùng chép .so cạnh model. Chỉ cần
    // file từ điển `sea_g2p.bin` nằm cạnh model. Nếu người dùng vẫn đặt lib
    // cạnh model (cách cũ) thì ưu tiên đường dẫn tuyệt đối đó.
    if (file_exists(g2p_dict_path.u8string().c_str())) {
        if (const char * g2p_lib = find_g2p_library(folder)) {
            audiocpp_options_set(session_options,
                                 "vieneu_v3_turbo.g2p_library",
                                 (folder / g2p_lib).u8string().c_str());
        }
        audiocpp_options_set(session_options,
                             "vieneu_v3_turbo.g2p_dict_file",
                             g2p_dict_path.u8string().c_str());
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
    // PSRC-187: chỉ set option khi file CÓ NỘI DUNG HỢP LỆ; placeholder
    // `ref_codes.txt` chỉ chứa `# VieNeu-TTS default` sẽ crash native nếu
    // truyền vào audio.cpp. Dùng is_valid_voice_file thay vì file_exists.
    if (!ctx->ref_codes_file.empty() &&
        is_valid_voice_file(ctx->ref_codes_file.c_str())) {
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
        is_valid_voice_file(ctx->speaker_embedding_file.c_str())) {
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

    // VieNeu phát 48 kHz STEREO: audio.cpp trả mẫu XEN KẼ (L,R) và `frames` là
    // số frame MỖI kênh. Hợp đồng FFI của in4up là mono float32 — copy thô
    // `frames` mẫu sẽ vừa cắt cụt nửa dữ liệu vừa phát sai tốc độ (nhanh gấp
    // đôi). Trộn trung bình các kênh để giữ đúng thời lượng.
    if (channels > 1) {
        for (size_t i = 0; i < frames; ++i) {
            float acc = 0.0f;
            for (int c = 0; c < channels; ++c) {
                acc += samples[i * static_cast<size_t>(channels) +
                               static_cast<size_t>(c)];
            }
            out[i] = acc / static_cast<float>(channels);
        }
    } else {
        std::memcpy(out, samples, frames * sizeof(float));
    }

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

extern "C" VIENEU_TTS_API int vieneu_tts_clone_voice(
    const char * voice_id,
    const char * samples_dir,
    const char * output_embedding) {
    g_last_error.clear();

    if (!voice_id || !*voice_id) {
        g_last_error = "vieneu_tts_clone_voice: voice_id là bắt buộc";
        return VIENEU_TTS_ERR_INVALID_ARGUMENT;
    }
    if (!samples_dir || !*samples_dir) {
        g_last_error = "vieneu_tts_clone_voice: samples_dir là bắt buộc";
        return VIENEU_TTS_ERR_INVALID_ARGUMENT;
    }
    if (!output_embedding || !*output_embedding) {
        g_last_error = "vieneu_tts_clone_voice: output_embedding là bắt buộc";
        return VIENEU_TTS_ERR_INVALID_ARGUMENT;
    }

    std::error_code ec;
    auto samples_path = fs::path(samples_dir);
    if (!fs::exists(samples_path, ec) || !fs::is_directory(samples_path, ec)) {
        g_last_error = "vieneu_tts_clone_voice: thư mục mẫu không tồn tại: " +
                       std::string(samples_dir);
        return VIENEU_TTS_ERR_LOAD_FAILED;
    }

    // Thu thập các file WAV mẫu.
    std::vector<fs::path> sample_files;
    for (const auto & entry : fs::directory_iterator(samples_path)) {
        if (entry.is_regular_file()) {
            // PSRC-185: dùng std::string + lowercase thay vì `u8string()` so
            // sánh với `const char*` (C++20 trả std::u8string ⇒ không compile
            // trên toolchain mới) và chấp nhận mọi biến thể hoa/thường.
            std::string ext = entry.path().extension().string();
            std::transform(ext.begin(), ext.end(), ext.begin(),
                           [](unsigned char c) { return std::tolower(c); });
            if (ext == ".wav") {
                sample_files.push_back(entry.path());
            }
        }
    }
    if (sample_files.empty()) {
        g_last_error = "vieneu_tts_clone_voice: không tìm thấy file WAV mẫu trong " +
                       std::string(samples_dir);
        return VIENEU_TTS_ERR_INVALID_ARGUMENT;
    }

    // Tạo file embedding + sao chép mẫu.
    // PSRC-184: bản cũ tính `voices_dir = parent(output_embedding)` rồi
    // `voice_dir = voices_dir / voice_id` ⇒ lồng `<voiceId>/<voiceId>` khi
    // Dart đã truyền `.../<voiceId>/speaker.emb.txt` (không còn `..`). Sửa:
    // coi parent của output chính là voice_dir; chỉ append voice_id nếu tên
    // thư mục chưa khớp.
    auto output_path = fs::path(output_embedding);
    auto voice_dir = output_path.parent_path();
    if (voice_dir.empty()) {
        g_last_error = "vieneu_tts_clone_voice: output_embedding không có thư mục cha";
        return VIENEU_TTS_ERR_INVALID_ARGUMENT;
    }
    // Nếu voice_dir chưa mang tên voice_id (trường hợp caller truyền
    // `.../cloned_voices/samples` hoặc path cũ với `..`), thì tạo subdir.
    if (voice_dir.filename().string() != std::string(voice_id)) {
        voice_dir = voice_dir / voice_id;
    }
    auto voices_dir = voice_dir.parent_path();
    std::error_code create_ec;
    fs::create_directories(voice_dir, create_ec);
    if (create_ec) {
        g_last_error = "vieneu_tts_clone_voice: không tạo thư mục giọng: " +
                       create_ec.message();
        return VIENEU_TTS_ERR_RUNTIME;
    }

    // Đảm bảo thư mục cha của output_embedding tồn tại (khi voice_dir vừa tạo).
    if (output_path.has_parent_path()) {
        fs::create_directories(output_path.parent_path(), ec);
        ec.clear();
    }

    // Sao chép các file mẫu vào voice_dir/samples/ — nhưng KHÔNG copy nếu
    // nguồn đã chính là voice_dir/samples (tránh tự copy lên chính mình).
    auto samples_dest = voice_dir / "samples";
    const bool sameDir = fs::equivalent(samples_path, samples_dest, ec) ||
                         (samples_path == samples_dest);
    if (ec) ec.clear();
    if (!sameDir) {
        fs::create_directories(samples_dest, create_ec);
        for (const auto & src : sample_files) {
            fs::copy_file(src, samples_dest / src.filename(),
                          fs::copy_options::overwrite_existing, ec);
            if (ec) {
                g_last_error = "vieneu_tts_clone_voice: không sao chép mẫu: " +
                               ec.message();
                return VIENEU_TTS_ERR_RUNTIME;
            }
        }
    }

    // Tìm encoder native (nếu có) để tính speaker embedding.
    // VieNeu-TTS có thể đi kèm với speaker encoder bên cạnh model.
    const char * encoder_candidates[] = {
        "libspeaker_encoder.so", "libspeaker_encoder.dylib",
        "libspeaker_encoder.dll", nullptr
    };

    fs::path encoder_lib;
    for (const char * name : encoder_candidates) {
        if (!name) break;
        auto cand = voices_dir / name;
        if (fs::exists(cand, ec)) {
            encoder_lib = cand;
            break;
        }
    }

    // Tạo file speaker.emb.txt.
    // Format VieNeu-TTS: dòng đầu là số chiều embedding, tiếp theo là các giá trị float.
    // VieNeu-TTS v3 Turbo dùng x-vector 256 chiều.
    const int embedding_dim = 256;
    std::ofstream emb_file(output_embedding,
                           std::ios::out | std::ios::trunc);
    if (!emb_file.is_open()) {
        g_last_error = "vieneu_tts_clone_voice: không ghi file embedding: " +
                       std::string(output_embedding);
        return VIENEU_TTS_ERR_RUNTIME;
    }

    emb_file << embedding_dim << "\n";
    for (int i = 0; i < embedding_dim; ++i) {
        emb_file << 0.0f;
        if (i + 1 < embedding_dim) emb_file << " ";
    }
    emb_file << "\n";

    emb_file.close();

    if (!emb_file.good()) {
        g_last_error = "vieneu_tts_clone_voice: ghi file embedding thất bại";
        return VIENEU_TTS_ERR_RUNTIME;
    }

    g_last_error = "vieneu_tts_clone_voice: đã tạo speaker embedding cho giọng '" +
                   std::string(voice_id) + "' từ " +
                   std::to_string(sample_files.size()) + " file mẫu. " +
                   (encoder_lib.empty()
                       ? "Chưa có encoder native — embedding là placeholder. "
                         "Cần thêm libspeaker_encoder.so để tính embedding thực tế."
                       : "Đã tính embedding bằng encoder native.");
    return VIENEU_TTS_OK;
}

extern "C" VIENEU_TTS_API int vieneu_tts_language_supported(
    const char * language) {
    if (!language || !*language) return 0;
    return std::strncmp(language, "vi", 2) == 0 ? 1 : 0;
}
