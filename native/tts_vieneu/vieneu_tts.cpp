#include "vieneu_tts.h"

#include "audiocpp.h"  // audio.cpp C ABI — third_party/audio.cpp/include

// Sinh ở configure time từ third_party/audio.cpp/model_specs/vieneu_v3_turbo.json
// (xem native/tts_vieneu/model_spec.inc.in + android/vieneu/CMakeLists.txt).
#include "vieneu_model_spec.inc"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <memory>
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

// ============================================================================
// PSRC-171 — MODEL SPEC
// ============================================================================
//
// audio.cpp v0.9.4 chỉ nhúng `model_specs/*.json` vào libaudiocpp.so khi
// `AUDIOCPP_DEPLOYMENT_BUILD=ON`. Bản Android/desktop của in4up build mặc
// định ⇒ `builtin_model_specs()` rỗng ⇒ `audiocpp_model_load()` ném
// "model spec not found for family '…'" cho MỌI bản cài, dù file GGUF đã
// import đúng (PSRC-171). Wrapper mang theo spec của đúng family này rồi ghi
// ra CẠNH model (thư mục dữ liệu app, luôn ghi được — không phụ thuộc /tmp)
// khi audio.cpp cần, và truyền đường dẫn đó qua `model_spec_override`.

const char * kModelSpecDirName = "model_specs";
const char * kModelSpecFileName = "vieneu_v3_turbo.json";

/// Spec nhúng có dùng được không (CMake không thấy json ⇒ false).
bool embedded_model_spec_available() {
    return in4up_vieneu_spec::kEmbedded && in4up_vieneu_spec::kJson != nullptr &&
           *in4up_vieneu_spec::kJson != '\0';
}

/// Ghi spec nhúng vào `<model_folder>/model_specs/vieneu_v3_turbo.json`.
///
/// Trả về đường dẫn (dạng chuỗi) hoặc chuỗi RỖNG nếu không ghi được. Ghi lại
/// chỉ khi nội dung khác — lần nạp sau không tốn I/O.
std::string materialize_embedded_model_spec(const fs::path & folder) {
    if (folder.empty() || !embedded_model_spec_available()) return {};
    const size_t spec_size = std::strlen(in4up_vieneu_spec::kJson);
    const fs::path spec_dir = folder / kModelSpecDirName;
    const fs::path spec_path = spec_dir / kModelSpecFileName;

    std::error_code ec;
    if (fs::exists(spec_path, ec) && !ec) {
        const auto existing_size = fs::file_size(spec_path, ec);
        if (!ec && existing_size == spec_size) {
            std::ifstream same(spec_path, std::ios::binary);
            if (same.is_open()) {
                const std::string content((std::istreambuf_iterator<char>(same)),
                                          std::istreambuf_iterator<char>());
                if (content.size() == spec_size &&
                    std::memcmp(content.data(), in4up_vieneu_spec::kJson,
                                spec_size) == 0) {
                    return spec_path.u8string();
                }
            }
        }
    }

    fs::create_directories(spec_dir, ec);
    if (ec) return {};
    std::ofstream out(spec_path, std::ios::binary | std::ios::trunc);
    if (!out.is_open()) return {};
    out.write(in4up_vieneu_spec::kJson,
              static_cast<std::streamsize>(spec_size));
    out.close();
    if (!out.good()) return {};
    return spec_path.u8string();
}

// ============================================================================
// PSRC-171 — ĐỌC WAV MẪU (tạo giọng từ bản ghi âm)
// ============================================================================
//
// App ghi mẫu bằng plugin `record` (WAV PCM16 16 kHz mono); người dùng có thể
// import WAV 44,1/48 kHz stereo. audio.cpp nhận PCM float MONO qua
// `audiocpp_request_set_voice_audio` và tự resample, nên wrapper chỉ cần giải
// WAV (PCM 8/16/24/32-bit + IEEE float 32/64) và trộn kênh. Không dùng
// `engine::audio::read_wav_f32` của audio.cpp: symbol đó KHÔNG được export
// (version script `audiocpp.map` chỉ mở `audiocpp_*`), còn link thêm
// `engine_runtime` sẽ nhân đôi toàn bộ engine vào APK.

struct DecodedWav {
    std::vector<float> samples;  // mono, [-1, 1]
    int sample_rate = 0;
};

uint32_t read_le_u32(const unsigned char * p) {
    return static_cast<uint32_t>(p[0]) | (static_cast<uint32_t>(p[1]) << 8) |
           (static_cast<uint32_t>(p[2]) << 16) |
           (static_cast<uint32_t>(p[3]) << 24);
}

uint16_t read_le_u16(const unsigned char * p) {
    return static_cast<uint16_t>(p[0] | (p[1] << 8));
}

/// Giải một file WAV thành PCM float mono. Trả false + [error] nếu không đọc.
bool decode_wav_mono(const fs::path & path, DecodedWav & out,
                     std::string & error) {
    std::ifstream in(path, std::ios::binary);
    if (!in.is_open()) {
        error = "không mở được file";
        return false;
    }
    unsigned char header[12] = {0};
    in.read(reinterpret_cast<char *>(header), sizeof(header));
    if (in.gcount() != static_cast<std::streamsize>(sizeof(header)) ||
        std::memcmp(header, "RIFF", 4) != 0 ||
        std::memcmp(header + 8, "WAVE", 4) != 0) {
        error = "không phải file WAV (RIFF/WAVE)";
        return false;
    }

    int format = 0;       // 1 = PCM, 3 = IEEE float
    int channels = 0;
    int bits = 0;
    int sample_rate = 0;
    std::vector<unsigned char> data;
    bool have_fmt = false;

    while (in) {
        unsigned char chunk[8] = {0};
        in.read(reinterpret_cast<char *>(chunk), sizeof(chunk));
        if (in.gcount() != static_cast<std::streamsize>(sizeof(chunk))) break;
        const uint32_t chunk_size = read_le_u32(chunk + 4);
        if (std::memcmp(chunk, "fmt ", 4) == 0) {
            const uint32_t to_read = chunk_size < 40u ? chunk_size : 40u;
            unsigned char fmt[40] = {0};
            in.read(reinterpret_cast<char *>(fmt), to_read);
            if (in.gcount() != static_cast<std::streamsize>(to_read)) break;
            if (chunk_size > to_read) in.seekg(chunk_size - to_read, std::ios::cur);
            format = read_le_u16(fmt);
            channels = read_le_u16(fmt + 2);
            sample_rate = static_cast<int>(read_le_u32(fmt + 4));
            bits = read_le_u16(fmt + 14);
            // WAVE_FORMAT_EXTENSIBLE: format thật nằm ở 2 byte đầu GUID con.
            if (format == 0xFFFE && to_read >= 26) {
                format = read_le_u16(fmt + 24);
            }
            have_fmt = true;
        } else if (std::memcmp(chunk, "data", 4) == 0) {
            data.resize(chunk_size);
            in.read(reinterpret_cast<char *>(data.data()), chunk_size);
            const auto read_bytes = in.gcount();
            if (read_bytes < 0) {
                data.clear();
            } else if (static_cast<uint32_t>(read_bytes) != chunk_size) {
                // File bị cắt: dùng phần đọc được (bản ghi âm đang mở).
                data.resize(static_cast<size_t>(read_bytes));
            }
            break;  // `data` là chunk cuối cần đọc
        } else {
            // Chunk lạ (LIST/fact/bext…): nhảy qua phần dữ liệu.
            in.seekg(chunk_size, std::ios::cur);
        }
        // Chuẩn RIFF: chunk lẻ được đệm 1 byte. Chỉ cộng Ở ĐÂY (cộng cả trong
        // nhánh trên thì con trỏ lệch 1 byte ⇒ mất chunk `data` kế tiếp —
        // bắt được bằng harness WAV có LIST chunk).
        if ((chunk_size & 1u) != 0u) in.seekg(1, std::ios::cur);
    }

    if (!have_fmt || data.empty() || channels <= 0 || sample_rate <= 0 ||
        bits <= 0) {
        error = "thiếu header fmt/data hoặc file rỗng";
        return false;
    }
    const int bytes_per_sample = bits / 8;
    if (bytes_per_sample <= 0) {
        error = "độ sâu bit không hợp lệ";
        return false;
    }
    const bool is_float = format == 3;
    const bool is_pcm = format == 1;
    if (!is_float && !is_pcm) {
        error = "chỉ hỗ trợ WAV PCM hoặc IEEE float";
        return false;
    }
    if (is_pcm && bytes_per_sample != 1 && bytes_per_sample != 2 &&
        bytes_per_sample != 3 && bytes_per_sample != 4) {
        error = "không hỗ trợ PCM " + std::to_string(bits) + " bit";
        return false;
    }
    if (is_float && bytes_per_sample != 4 && bytes_per_sample != 8) {
        error = "không hỗ trợ float " + std::to_string(bits) + " bit";
        return false;
    }

    const size_t frame_bytes =
        static_cast<size_t>(bytes_per_sample) * static_cast<size_t>(channels);
    const size_t frames = data.size() / frame_bytes;
    if (frames == 0) {
        error = "không có mẫu âm thanh";
        return false;
    }

    out.samples.assign(frames, 0.0f);
    out.sample_rate = sample_rate;
    for (size_t frame = 0; frame < frames; ++frame) {
        float acc = 0.0f;
        for (int channel = 0; channel < channels; ++channel) {
            const unsigned char * sample =
                data.data() + frame * frame_bytes +
                static_cast<size_t>(channel) * static_cast<size_t>(bytes_per_sample);
            float value = 0.0f;
            if (is_float) {
                if (bytes_per_sample == 4) {
                    float f = 0.0f;
                    std::memcpy(&f, sample, 4);
                    value = f;
                } else {
                    double d = 0.0;
                    std::memcpy(&d, sample, 8);
                    value = static_cast<float>(d);
                }
            } else if (bytes_per_sample == 1) {
                value = (static_cast<float>(sample[0]) - 128.0f) / 128.0f;
            } else if (bytes_per_sample == 2) {
                int16_t v = 0;
                std::memcpy(&v, sample, 2);
                value = static_cast<float>(v) / 32768.0f;
            } else if (bytes_per_sample == 3) {
                int32_t v = (static_cast<int32_t>(sample[2]) << 16) |
                            (static_cast<int32_t>(sample[1]) << 8) |
                            static_cast<int32_t>(sample[0]);
                if ((v & 0x800000) != 0) v |= ~0xFFFFFF;  // dấu 24-bit
                value = static_cast<float>(v) / 8388608.0f;
            } else {
                int32_t v = 0;
                std::memcpy(&v, sample, 4);
                value = static_cast<float>(static_cast<double>(v) / 2147483648.0);
            }
            acc += value;
        }
        out.samples[frame] = acc / static_cast<float>(channels);
    }
    return true;
}

/// Trần tham chiếu giọng: upstream cắt còn 8 s (`_MAX_REF_SECONDS`) — cắt
/// trước ở đây để không nạp cả bản ghi 2 phút vào RAM.
constexpr double kMaxReferenceSeconds = 8.0;

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

    // Sống tới hết hàm: `audiocpp_model_load` chỉ đọc con trỏ, không copy.
    std::string spec_override_path;

    auto try_load_model = [&]() -> audiocpp_status {
        return audiocpp_model_load(ctx->registry, model_path, &model_config,
                                   nullptr, &ctx->model);
    };

    audiocpp_status load_status = try_load_model();
    if (load_status != AUDIOCPP_OK || !ctx->model) {
        const std::string first_error = audiocpp_last_error();
        if (ctx->model) {
            audiocpp_model_free(ctx->model);
            ctx->model = nullptr;
        }
        // PSRC-171: chỉ thử lại khi lỗi ĐÚNG là thiếu/không khớp model spec —
        // đó là lỗi mà bản 1.28 gặp trên mọi máy ("model spec not found for
        // family 'vietneu_tts'"). File hỏng / hết RAM thì không thử lại (nạp
        // lại 188 MB chỉ tốn thời gian và pin).
        if (first_error.find("model spec") != std::string::npos) {
            spec_override_path = materialize_embedded_model_spec(folder);
            if (!spec_override_path.empty()) {
                model_config.model_spec_override = spec_override_path.c_str();
                load_status = try_load_model();
            }
        }
        if (load_status != AUDIOCPP_OK || !ctx->model) {
            ctx->last_error = "vieneu_tts_create: nạp model thất bại: ";
            if (spec_override_path.empty()) {
                ctx->last_error += first_error;
                if (embedded_model_spec_available()) {
                    ctx->last_error +=
                        " (không ghi được model spec cạnh model: " +
                        (folder / kModelSpecDirName / kModelSpecFileName)
                            .u8string() +
                        ")";
                }
            } else {
                ctx->last_error += std::string(audiocpp_last_error()) +
                                   " [đã thử model_spec_override=" +
                                   spec_override_path + "; lỗi gốc: " +
                                   first_error + "]";
            }
            g_last_error = ctx->last_error;
            delete ctx;
            audiocpp_options_free(session_options);
            return nullptr;
        }
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
    //
    // PSRC-171: khi ĐÃ có `ref_codes.txt` thì KHÔNG truyền `speaker_embedding_file`
    // nữa. Bản cũ của `vieneu_tts_clone_voice` ghi một file embedding 256 số 0
    // (placeholder) vào cùng thư mục giọng; audio.cpp đọc file đó trước và
    // ném "must contain exactly 192 float values" ⇒ giọng vừa tạo không bao
    // giờ đọc được. Ref codes đã đủ mô tả giọng (xem prompt builder).
    const bool has_ref_codes = !ctx->ref_codes_file.empty() &&
                               is_valid_voice_file(ctx->ref_codes_file.c_str());
    if (has_ref_codes) {
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
    if (!has_ref_codes && !ctx->speaker_embedding_file.empty() &&
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
    vieneu_tts_handle handle,
    const char * voice_id,
    const char * samples_dir,
    const char * output_ref_codes_path) {
    g_last_error.clear();

    auto * ctx = static_cast<VieneuTtsContext *>(handle);
    if (!ctx || !ctx->initialized || !ctx->session) {
        g_last_error = "vieneu_tts_clone_voice: engine chưa nạp model";
        return VIENEU_TTS_ERR_NOT_READY;
    }
    if (!voice_id || !*voice_id) {
        g_last_error = "vieneu_tts_clone_voice: voice_id là bắt buộc";
        return VIENEU_TTS_ERR_INVALID_ARGUMENT;
    }
    if (!samples_dir || !*samples_dir) {
        g_last_error = "vieneu_tts_clone_voice: samples_dir là bắt buộc";
        return VIENEU_TTS_ERR_INVALID_ARGUMENT;
    }
    if (!output_ref_codes_path || !*output_ref_codes_path) {
        g_last_error =
            "vieneu_tts_clone_voice: đường dẫn ref_codes.txt là bắt buộc";
        return VIENEU_TTS_ERR_INVALID_ARGUMENT;
    }

    std::error_code ec;
    const fs::path samples_path(samples_dir);
    if (!fs::exists(samples_path, ec) || !fs::is_directory(samples_path, ec)) {
        g_last_error = "vieneu_tts_clone_voice: thư mục mẫu không tồn tại: " +
                       std::string(samples_dir);
        return VIENEU_TTS_ERR_LOAD_FAILED;
    }

    // ---------------------------------------------------------------- mẫu WAV
    // Sắp xếp theo tên: cùng một bộ mẫu luôn cho cùng ref codes (bản ghi có
    // tên theo timestamp) ⇒ người dùng tạo lại giọng không bị đổi chất giọng
    // ngẫu nhiên.
    std::vector<fs::path> sample_files;
    for (const auto & entry : fs::directory_iterator(samples_path, ec)) {
        if (ec) break;
        if (!entry.is_regular_file()) continue;
        std::string ext = entry.path().extension().string();
        std::transform(ext.begin(), ext.end(), ext.begin(),
                       [](unsigned char c) { return std::tolower(c); });
        if (ext == ".wav") sample_files.push_back(entry.path());
    }
    if (sample_files.empty()) {
        g_last_error =
            "vieneu_tts_clone_voice: không tìm thấy file WAV mẫu trong " +
            std::string(samples_dir);
        return VIENEU_TTS_ERR_INVALID_ARGUMENT;
    }
    std::sort(sample_files.begin(), sample_files.end());

    // Ghép các mẫu CÙNG sample rate (mẫu khác rate bị bỏ qua — audio.cpp vẫn
    // resample được nhưng trộn hai rate trong một buffer là sai).
    std::vector<float> reference;
    int reference_rate = 0;
    size_t used_files = 0;
    std::string skipped;
    for (const auto & file : sample_files) {
        DecodedWav wav;
        std::string decode_error;
        if (!decode_wav_mono(file, wav, decode_error)) {
            skipped += "\n  - " + file.filename().string() + ": " +
                       decode_error;
            continue;
        }
        if (reference_rate == 0) reference_rate = wav.sample_rate;
        if (wav.sample_rate != reference_rate) {
            skipped += "\n  - " + file.filename().string() +
                       ": sample rate " + std::to_string(wav.sample_rate) +
                       " Hz khác " + std::to_string(reference_rate) + " Hz";
            continue;
        }
        const size_t cap = static_cast<size_t>(
            kMaxReferenceSeconds * static_cast<double>(reference_rate));
        if (reference.size() >= cap) break;
        const size_t room = cap - reference.size();
        const size_t take = std::min(room, wav.samples.size());
        reference.insert(reference.end(), wav.samples.begin(),
                         wav.samples.begin() + static_cast<ptrdiff_t>(take));
        ++used_files;
    }
    if (reference.empty() || reference_rate <= 0) {
        g_last_error =
            "vieneu_tts_clone_voice: không đọc được mẫu WAV nào trong " +
            std::string(samples_dir) + skipped;
        return VIENEU_TTS_ERR_INVALID_ARGUMENT;
    }

    // ------------------------------------------------- mã hoá giọng (codes)
    // audio.cpp: `encode_reference_only=true` + PCM tham chiếu ⇒ trả
    // acoustic-tokens artifact (đúng nội dung `ref_codes.txt` mà
    // `reference_codes_file` đọc lại). Không sinh câu nói nào.
    audiocpp_request * request = audiocpp_request_create();
    if (!request) {
        g_last_error = "vieneu_tts_clone_voice: không tạo được request";
        return VIENEU_TTS_ERR_OUT_OF_MEMORY;
    }
    struct RequestGuard {
        audiocpp_request * request;
        explicit RequestGuard(audiocpp_request * r) : request(r) {}
        ~RequestGuard() {
            if (request) audiocpp_request_free(request);
        }
    } request_guard(request);

    audiocpp_status status = audiocpp_request_set_voice_audio(
        request, reference.data(), reference.size(), reference_rate, 1);
    if (status != AUDIOCPP_OK) {
        g_last_error =
            "vieneu_tts_clone_voice: không đặt được âm thanh tham chiếu: " +
            std::string(audiocpp_last_error());
        return VIENEU_TTS_ERR_RUNTIME;
    }
    status = audiocpp_request_set_option(request, "encode_reference_only",
                                         "true");
    if (status != AUDIOCPP_OK) {
        g_last_error =
            "vieneu_tts_clone_voice: không đặt được encode_reference_only: " +
            std::string(audiocpp_last_error());
        return VIENEU_TTS_ERR_RUNTIME;
    }

    audiocpp_result * result = nullptr;
    status = audiocpp_session_run(ctx->session, request, &result);
    if (status != AUDIOCPP_OK || !result) {
        g_last_error = "vieneu_tts_clone_voice: mã hoá giọng thất bại: " +
                       std::string(audiocpp_last_error());
        if (result) audiocpp_result_free(result);
        return VIENEU_TTS_ERR_RUNTIME;
    }
    struct ResultGuard {
        audiocpp_result * result;
        explicit ResultGuard(audiocpp_result * r) : result(r) {}
        ~ResultGuard() {
            if (result) audiocpp_result_free(result);
        }
    } result_guard(result);

    const void * codes_payload = nullptr;
    size_t codes_bytes = 0;
    const size_t artifact_count = audiocpp_result_artifact_count(result);
    for (size_t index = 0; index < artifact_count; ++index) {
        audiocpp_artifact_kind kind = AUDIOCPP_ARTIFACT_CUSTOM;
        const char * artifact_id = nullptr;
        const void * payload = nullptr;
        size_t payload_bytes = 0;
        if (audiocpp_result_artifact(result, index, &kind, &artifact_id,
                                     &payload, &payload_bytes) != AUDIOCPP_OK) {
            continue;
        }
        if (kind != AUDIOCPP_ARTIFACT_ACOUSTIC_TOKENS || !payload ||
            payload_bytes == 0) {
            continue;
        }
        codes_payload = payload;
        codes_bytes = payload_bytes;
        break;
    }
    if (!codes_payload || codes_bytes == 0) {
        g_last_error =
            "vieneu_tts_clone_voice: audio.cpp không trả về reference codes "
            "cho mẫu đã cho (" +
            std::to_string(used_files) + " file, " +
            std::to_string(reference_rate) + " Hz)";
        return VIENEU_TTS_ERR_RUNTIME;
    }

    // --------------------------------------------------------- ghi ref codes
    const fs::path output_path(output_ref_codes_path);
    const fs::path voice_dir = output_path.parent_path();
    if (!voice_dir.empty() && !fs::exists(voice_dir, ec)) {
        fs::create_directories(voice_dir, ec);
        if (ec) {
            g_last_error =
                "vieneu_tts_clone_voice: không tạo được thư mục giọng: " +
                ec.message();
            return VIENEU_TTS_ERR_RUNTIME;
        }
    }
    {
        std::ofstream out(output_path, std::ios::binary | std::ios::trunc);
        if (!out.is_open()) {
            g_last_error =
                "vieneu_tts_clone_voice: không ghi được " +
                std::string(output_ref_codes_path);
            return VIENEU_TTS_ERR_RUNTIME;
        }
        out.write(static_cast<const char *>(codes_payload),
                  static_cast<std::streamsize>(codes_bytes));
        out.close();
        if (!out.good()) {
            g_last_error =
                "vieneu_tts_clone_voice: ghi ref codes thất bại (đầy bộ nhớ?)";
            return VIENEU_TTS_ERR_RUNTIME;
        }
    }
    if (!is_valid_voice_file(output_ref_codes_path)) {
        g_last_error =
            "vieneu_tts_clone_voice: ref codes vừa ghi không hợp lệ: " +
            std::string(output_ref_codes_path);
        return VIENEU_TTS_ERR_RUNTIME;
    }

    // Dọn file embedding placeholder của bản cũ (256 số 0 — audio.cpp từ chối
    // vì cần đúng 192 giá trị). Giọng đã có ref codes thì không cần nữa.
    if (!voice_dir.empty()) {
        std::error_code remove_ec;
        fs::remove(voice_dir / "speaker.emb.txt", remove_ec);
    }

    g_last_error = "vieneu_tts_clone_voice: đã mã hoá giọng '" +
                   std::string(voice_id) + "' từ " +
                   std::to_string(used_files) + " mẫu WAV (" +
                   std::to_string(reference_rate) + " Hz, " +
                   std::to_string(reference.size()) +
                   " mẫu) → " + std::string(output_ref_codes_path) + skipped;
    return VIENEU_TTS_OK;
}

extern "C" VIENEU_TTS_API int vieneu_tts_language_supported(
    const char * language) {
    if (!language || !*language) return 0;
    return std::strncmp(language, "vi", 2) == 0 ? 1 : 0;
}
