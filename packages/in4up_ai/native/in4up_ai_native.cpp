#include "in4up_ai_native.h"
#include "llama.h"
#include "ggml.h"

#include <algorithm>
#include <chrono>
#include <cstdarg>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

// =============================================================================
// HYMT-006 (2026-11-06) — log llama.cpp được GIỮ LẠI.
//
// Trước bản này mọi chẩn đoán của llama/ggml ("unknown model architecture",
// "failed to load tensor", OOM) rơi vào stderr của tiến trình — trên Android
// logcat của app release không hiện, nên triệu chứng duy nhất người dùng thấy
// là "Hy-MT không load được" hoặc "trả về rỗng". Giờ mọi dòng log được gom vào
// một ring buffer trong native và Dart đọc lên bằng `in4up_ai_last_log()`.
// Root cause đầy đủ: docs/translation/hymt_root_cause_2026-11-06.md
// =============================================================================
namespace {

std::mutex g_log_mutex;
std::string g_log_buffer;
in4up_ai_log_fn g_log_cb = nullptr;
void * g_log_user_data = nullptr;

void log_append(const char * text, size_t len) {
    if (!text || len == 0) return;
    std::lock_guard<std::mutex> lock(g_log_mutex);
    g_log_buffer.append(text, len);
    // Giữ ~16KB cuối: đủ cho cả chuỗi lỗi load model, không phình RAM.
    constexpr size_t kMax = 16 * 1024;
    if (g_log_buffer.size() > kMax) {
        g_log_buffer.erase(0, g_log_buffer.size() - kMax);
    }
}

// ⚠ MSVC KHÔNG hiểu `__attribute__((format(printf,1,2)))` ⇒ build Windows
// (bản 1.24.0 đầu tiên) đỏ ở step "Build Windows Release". Chỉ bật
// attribute khi trình biên dịch là GCC/Clang.
#if defined(__GNUC__) || defined(__clang__)
void log_note(const char * fmt, ...) __attribute__((format(printf, 1, 2)));
#else
void log_note(const char * fmt, ...);
#endif

void log_note(const char * fmt, ...) {
    char buf[512];
    va_list args;
    va_start(args, fmt);
    const int n = std::vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    if (n > 0) log_append(buf, static_cast<size_t>(std::min<int>(n, sizeof(buf) - 1)));
}

void log_sink(enum ggml_log_level level, const char * text, void * user_data) {
    if (!text) return;
    if (g_log_cb == nullptr || user_data == nullptr) {
        log_append(text, std::strlen(text));
    }
    if (g_log_cb != nullptr) {
        g_log_cb(static_cast<int>(level), text, g_log_user_data);
    }
}

// llama_backend_init() chỉ được gọi 1 lần cho cả app (AI chat + Hy-MT dùng
// CHUNG libin4up_ai_native). Dispose 1 model không được làm chết backend của
// model còn lại → đếm tham chiếu thay vì init/free theo từng handle.
std::mutex g_backend_mutex;
int g_backend_refs = 0;
bool g_logger_installed = false;

void backend_acquire() {
    std::lock_guard<std::mutex> lock(g_backend_mutex);
    if (!g_logger_installed) {
        llama_log_set(log_sink, nullptr);
        g_logger_installed = true;
    }
    if (g_backend_refs == 0) {
        llama_backend_init();
    }
    ++g_backend_refs;
}

void backend_release() {
    std::lock_guard<std::mutex> lock(g_backend_mutex);
    if (g_backend_refs > 0) --g_backend_refs;
    if (g_backend_refs == 0) {
        llama_backend_free();
    }
}

}  // namespace

struct In4upAiContext {
    llama_model * model = nullptr;
    llama_context * context = nullptr;
    const llama_vocab * vocab = nullptr;
    int n_threads = 4;
    uint32_t n_ctx = 2048;
};

// =============================================================================
// Diag (HYMT-003): đọc thẳng GGUF header/KV, không cần llama backend.
// Định dạng: magic "GGUF", u32 version, u64 n_tensors, u64 n_kv, rồi
//   string key, u32 type, value…  (string = u64 len + utf8)
// =============================================================================
namespace {

struct GgufReader {
    const unsigned char * p = nullptr;
    size_t n = 0;
    size_t at = 0;

    bool take(void * dst, size_t len) {
        if (len > n - at) return false;
        if (dst) std::memcpy(dst, p + at, len);
        at += len;
        return true;
    }
    bool u32(uint32_t & v) { return take(&v, 4); }
    bool u64(uint64_t & v) { return take(&v, 8); }
    bool str(std::string & s) {
        uint64_t len = 0;
        if (!u64(len)) return false;
        if (len > 0x7fffffffULL || static_cast<size_t>(len) > n - at) return false;
        s.assign(reinterpret_cast<const char *>(p + at), static_cast<size_t>(len));
        at += static_cast<size_t>(len);
        return true;
    }

    // Kích thước value theo kiểu GGUF metadata (enum gguf_type).
    static bool value_size(uint32_t type, uint64_t & size) {
        switch (type) {
            case 0: case 1: case 7: size = 1; return true;    // u8 i8 bool
            case 2: case 3: size = 2; return true;            // u16 i16
            case 4: case 5: case 6: size = 4; return true;    // u32 i32 f32
            case 10: case 11: case 12: size = 8; return true;  // u64 i64 f64
            default: return false;                             // string/array
        }
    }
};

void copy_into(char * dst, size_t cap, const std::string & src) {
    if (cap == 0) return;
    const size_t len = std::min(cap - 1, src.size());
    std::memcpy(dst, src.data(), len);
    dst[len] = '\0';
}

/// Tên loại tensor GGML — chỉ để hiển thị/chẩn đoán.
void quant_name(uint32_t ttype, char * dst, size_t cap) {
    switch (ttype) {
        case 0:  std::strcpy(dst, "f32"); break;
        case 1:  std::strcpy(dst, "f16"); break;
        case 2:  std::strcpy(dst, "q4_0"); break;
        case 3:  std::strcpy(dst, "q4_1"); break;
        case 6:  std::strcpy(dst, "q5_0"); break;
        case 8:  std::strcpy(dst, "q8_0"); break;
        case 12: std::strcpy(dst, "q4_k"); break;
        case 13: std::strcpy(dst, "q5_k"); break;
        case 14: std::strcpy(dst, "q6_k"); break;
        case 15: std::strcpy(dst, "q8_k"); break;
        case 30: std::strcpy(dst, "bf16"); break;
        case 41: std::strcpy(dst, "q1_0"); break;
        case 42: std::strcpy(dst, "q2_0"); break;
        default: std::snprintf(dst, cap, "UNKNOWN:%u", ttype); break;
    }
}

}  // namespace

extern "C" IN4UP_AI_API int in4up_ai_inspect_gguf(
    const unsigned char * prefix, int prefix_len,
    char * arch_out, int arch_cap,
    char * quant_out, int quant_cap,
    int * supported, int * has_template, int * n_tensors) {
    if (!prefix || prefix_len < 24) return -1;
    if (arch_out && arch_cap > 0) arch_out[0] = '\0';
    if (quant_out && quant_cap > 0) quant_out[0] = '\0';
    if (supported) *supported = 0;
    if (has_template) *has_template = 0;
    if (n_tensors) *n_tensors = 0;

    GgufReader r{prefix, static_cast<size_t>(prefix_len), 0};
    char magic[4] = {0, 0, 0, 0};
    if (!r.take(magic, 4)) return -2;
    if (magic[0] != 'G' || magic[1] != 'G' || magic[2] != 'U' || magic[3] != 'F') return -3;

    uint32_t version = 0;
    uint64_t n_tensor_decl = 0, n_kv = 0;
    if (!r.u32(version) || !r.u64(n_tensor_decl) || !r.u64(n_kv)) return -4;
    if (version < 2 || version > 3) return -5;
    if (n_tensors) *n_tensors = static_cast<int>(std::min<uint64_t>(n_tensor_decl, 0x7fffffff));

    for (uint64_t i = 0; i < n_kv; ++i) {
        std::string key;
        uint32_t type = 0;
        if (!r.str(key) || !r.u32(type)) return -6;

        std::string sval;
        if (type == 8) {  // string
            if (!r.str(sval)) return -7;
        } else if (type == 9) {  // array
            uint32_t elem_type = 0;
            uint64_t count = 0;
            if (!r.u32(elem_type) || !r.u64(count)) return -8;
            if (elem_type == 8) {
                for (uint64_t k = 0; k < count; ++k) {
                    if (!r.str(sval)) return -9;
                }
            } else {
                uint64_t one = 0;
                if (!GgufReader::value_size(elem_type, one) || one == 0) return -10;
                if (count > (r.n - r.at) / one) return -11;
                if (!r.take(nullptr, static_cast<size_t>(count) * one)) return -11;
            }
        } else {
            uint64_t size = 0;
            if (!GgufReader::value_size(type, size) || !r.take(nullptr, static_cast<size_t>(size))) {
                return -12;
            }
            continue;  // bool/number: không cần cho chẩn đoán
        }

        if (key == "general.architecture") {
            if (arch_out && arch_cap > 0) {
                copy_into(arch_out, static_cast<size_t>(arch_cap), sval);
            }
        } else if (key == "tokenizer.chat_template") {
            if (has_template) *has_template = sval.empty() ? 0 : 1;
        }
    }

    // Tensor đầu tiên: name (string), n_dims (u32), dims (u64 × n_dims), type (u32).
    // Loại quant của nó quyết định llama.cpp có LOAD được file hay không.
    std::string tensor_name;
    if (!r.str(tensor_name)) return -13;
    uint32_t n_dims = 0;
    if (!r.u32(n_dims) || n_dims > 8) return -14;
    for (uint32_t d = 0; d < n_dims; ++d) {
        uint64_t dim = 0;
        if (!r.u64(dim)) return -15;
    }
    uint32_t ttype = 0;
    if (!r.u32(ttype)) return -16;

    if (quant_out && quant_cap > 0) {
        quant_name(ttype, quant_out, static_cast<size_t>(quant_cap));
    }
    // Trong llama.cpp đã pin (d7fa69b7) `q2_0` là block 64 phần tử; file 2-bit
    // của AngelSlim/tencent được quantize bằng PR #19357 (`q2_0c`, block 512,
    // kernel SME2) — KHÔNG có trong bản pinned. Đây là lý do số 1 khiến
    // llama_model_load_from_file() trả NULL dù file đủ 601MB.
    if (supported) *supported = (ttype != 42) ? 1 : 0;
    return 0;
}

extern "C" IN4UP_AI_API void in4up_ai_set_logger(in4up_ai_log_fn cb, void * user_data) {
    std::lock_guard<std::mutex> lock(g_log_mutex);
    g_log_cb = cb;
    g_log_user_data = user_data;
}

extern "C" IN4UP_AI_API void in4up_ai_last_log(char * buf, int max_len) {
    if (!buf || max_len <= 0) return;
    std::lock_guard<std::mutex> lock(g_log_mutex);
    const size_t cap = static_cast<size_t>(max_len) - 1;
    const size_t len = std::min(cap, g_log_buffer.size());
    std::memcpy(buf, g_log_buffer.data() + (g_log_buffer.size() - len), len);
    buf[len] = '\0';
}

// =============================================================================
// Prompt framing — HYMT-004 (2026-11-06)
//
// HY-MT1.5 KHÔNG phải chat model thường: chat_template.jinja của Tencent là
//   <｜hy_begin▁of▁sentence｜><｜hy_User｜>{prompt}<｜hy_Assistant｜>
// (không có <|im_start|>, không có "user:\n", không có BOS/EOS khác).
// Bản cũ gửi chuỗi thô ⇒ model không thấy ranh giới lượt ⇒ nhả rỗng hoặc
// nhả lại nguyên prompt (dịch = "không có gì xảy ra").
// =============================================================================
namespace {

// U+FF5C (｜) = EF BD 9C, U+2581 (▁) = E2 96 81. Tách literal để tránh
// "\x9Chy" bị hiểu thành một hex escape duy nhất.
constexpr const char * kHunyuanBos =
    "<\xEF\xBD\x9C" "hy_begin\xE2\x96\x81of\xE2\x96\x81sentence\xEF\xBD\x9C" ">";
constexpr const char * kHunyuanUser = "<\xEF\xBD\x9C" "hy_User\xEF\xBD\x9C" ">";
constexpr const char * kHunyuanAssistant =
    "<\xEF\xBD\x9C" "hy_Assistant\xEF\xBD\x9C" ">";

/// Thêm khung lượt nếu prompt CHƯA có (idempotent — model chat thường không bị
/// đụng tới vì đã có template riêng ở phía Dart).
std::string frame_prompt(const std::string & prompt, bool hunyuan) {
    if (!hunyuan) return prompt;
    if (prompt.find(kHunyuanUser) != std::string::npos) return prompt;
    std::string out;
    out.reserve(prompt.size() + 96);
    out.append(kHunyuanBos);
    out.append(kHunyuanUser);
    out.append(prompt);
    out.append(kHunyuanAssistant);
    return out;
}

std::string model_arch(const llama_model * model) {
    char buf[64] = {0};
    if (model == nullptr) return {};
    llama_model_meta_val_str(model, "general.architecture", buf, sizeof(buf) - 1);
    return std::string(buf);
}

}  // namespace

static std::string generate_text(
    In4upAiContext * ai,
    const char * prompt,
    int max_tokens,
    float temperature) {
    // Each turn must start with an empty KV cache. Reusing the context without
    // clearing it causes later prompts to inherit old tokens and eventually
    // exhaust n_ctx (especially in multi-turn chat).
    llama_memory_clear(llama_get_memory(ai->context), true);

    // Arch quyết định khung lượt: Hy-MT/Hunyuan cần <｜hy_User｜>…<｜hy_Assistant｜>;
    // model chat khác tự có template ở phía Dart nên giữ nguyên prompt.
    const std::string arch = model_arch(ai->model);
    const bool hunyuan = arch.find("hunyuan") != std::string::npos;

    const std::string framed = frame_prompt(std::string(prompt), hunyuan);
    const int prompt_len = static_cast<int>(framed.size());
    if (prompt_len <= 0) return {};

    // add_special = true: để llama tự thêm BOS theo metadata file.
    const int n_prompt = -llama_tokenize(ai->vocab, framed.c_str(), prompt_len, nullptr, 0, true, true);
    if (n_prompt <= 0) {
        log_note("[in4up-ai] tokenize trả 0 token (prompt rỗng?)\n");
        return {};
    }
    log_note("[in4up-ai] prompt %d ký tự → %d token (arch=%s, framed=%d)\n",
             prompt_len, n_prompt, arch.empty() ? "?" : arch.c_str(), hunyuan ? 1 : 0);
    if (n_prompt + 8 > static_cast<int>(ai->n_ctx)) {
        log_note("[in4up-ai] CẢNH BÁO: prompt %d token gần/vượt n_ctx=%u\n",
                 n_prompt, ai->n_ctx);
    }

    std::vector<llama_token> tokens(static_cast<size_t>(n_prompt));
    if (llama_tokenize(ai->vocab, framed.c_str(), prompt_len, tokens.data(), n_prompt, true, true) < 0) return {};

    llama_batch batch = llama_batch_get_one(tokens.data(), static_cast<int32_t>(tokens.size()));
    if (llama_decode(ai->context, batch) != 0) {
        log_note("[in4up-ai] llama_decode(prompt) FAILED — hết n_ctx hoặc thiếu RAM\n");
        return {};
    }

    auto sampler_params = llama_sampler_chain_default_params();
    llama_sampler * sampler = llama_sampler_chain_init(sampler_params);
    if (!sampler) return {};

    const float safe_temperature = std::isfinite(temperature)
        ? std::clamp(temperature, 0.0f, 2.0f)
        : 0.2f;
    if (safe_temperature <= 0.0001f) {
        llama_sampler_chain_add(sampler, llama_sampler_init_greedy());
    } else if (hunyuan) {
        // ── Hy-MT / Hunyuan: tham số Tencent khuyến nghị (model card)
        //   --temp 0.7 --top-k 20 --top-p 0.6 --repeat-penalty 1.05
        // Chỉ áp cho dòng model dịch: `in4up_ai_generate` là API DÙNG CHUNG
        // với AI chat (Gemma/GGUF), mà top-k 20 + top-p 0.6 làm câu trả lời
        // chat cụt/đơn điệu nếu áp toàn cục.
        llama_sampler_chain_add(sampler, llama_sampler_init_penalties(
            llama_vocab_n_tokens(ai->vocab), 64, 1.05f, 0.0f, 0.0f));
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(20));
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.6f, 1));
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(safe_temperature));
        const auto ticks = std::chrono::steady_clock::now().time_since_epoch().count();
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(static_cast<uint32_t>(ticks)));
    } else {
        // ── Model chat (Gemma, Qwen…) — GIỮ NGUYÊN sampler trước HYMT-004:
        // chỉ temp + dist. Không thêm top-k/top-p/penalty để hành vi AI chat
        // local không đổi so với v1.23.0.
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(safe_temperature));
        const auto ticks = std::chrono::steady_clock::now().time_since_epoch().count();
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(static_cast<uint32_t>(ticks)));
    }

    std::string result;
    int produced = 0;
    for (int i = 0; i < max_tokens; ++i) {
        const llama_token token = llama_sampler_sample(sampler, ai->context, -1);
        if (llama_vocab_is_eog(ai->vocab, token)) break;

        char piece[256];
        const int n = llama_token_to_piece(ai->vocab, token, piece, static_cast<int32_t>(sizeof(piece)), 0, true);
        if (n > 0) result.append(piece, static_cast<size_t>(n));
        ++produced;
        batch = llama_batch_get_one(const_cast<llama_token *>(&token), 1);
        if (llama_decode(ai->context, batch) != 0) break;
    }
    llama_sampler_free(sampler);

    if (produced == 0) {
        // Nguyên nhân đã xác minh: thiếu/khác chat template của Hy-MT1.5.
        log_note("[in4up-ai] model sinh 0 token trong %d bước (n_ctx=%u, arch=%s):\n"
                 "  token đầu tiên là EOG ⇒ model không nhận ra khung lượt\n"
                 "  <｜hy_User｜>…<｜hy_Assistant｜> (hoặc prompt không hợp lệ).\n",
                 max_tokens, ai->n_ctx, arch.empty() ? "?" : arch.c_str());
    } else {
        log_note("[in4up-ai] sinh %d token, %zu byte\n", produced, result.size());
    }
    return result;
}

extern "C" IN4UP_AI_API in4up_ai_handle in4up_ai_create(const char * model_path, int n_ctx, int n_threads) {
    if (!model_path || !*model_path) return nullptr;
    backend_acquire();

    auto * ai = new In4upAiContext();
    ai->n_threads = std::max(1, n_threads);
    auto model_params = llama_model_default_params();
    ai->model = llama_model_load_from_file(model_path, model_params);
    if (!ai->model) {
        // Log thật của llama.cpp ("unknown model architecture", "wrong tensor
        // type"…) đã nằm trong ring buffer ⇒ Dart đọc lên bằng
        // in4up_ai_last_log() thay vì chỉ nói "load failed".
        log_note("[in4up-ai] llama_model_load_from_file trả NULL cho %s\n", model_path);
        delete ai;
        backend_release();
        return nullptr;
    }

    auto context_params = llama_context_default_params();
    context_params.n_ctx = static_cast<uint32_t>(std::max(512, n_ctx));
    context_params.n_batch = context_params.n_ctx;
    context_params.n_threads = ai->n_threads;
    context_params.n_threads_batch = ai->n_threads;
    ai->n_ctx = context_params.n_ctx;
    ai->context = llama_init_from_model(ai->model, context_params);
    ai->vocab = llama_model_get_vocab(ai->model);
    if (!ai->context || !ai->vocab) {
        in4up_ai_destroy(ai);
        return nullptr;
    }

    const std::string arch = model_arch(ai->model);
    log_note("[in4up-ai] loaded arch=%s n_ctx=%u threads=%d\n",
             arch.empty() ? "?" : arch.c_str(), ai->n_ctx, ai->n_threads);
    return ai;
}

extern "C" IN4UP_AI_API int in4up_ai_generate(in4up_ai_handle handle, const char * prompt, int max_tokens, float temperature, char ** output) {
    if (!handle || !prompt || !output) return -1;
    auto * ai = static_cast<In4upAiContext *>(handle);
    const auto result = generate_text(
        ai,
        prompt,
        std::max(1, max_tokens),
        temperature);
    *output = static_cast<char *>(std::malloc(result.size() + 1));
    if (!*output) return -2;
    std::memcpy(*output, result.data(), result.size());
    (*output)[result.size()] = '\0';
    return static_cast<int>(result.size());
}

extern "C" IN4UP_AI_API void in4up_ai_free_string(char * value) { std::free(value); }

extern "C" IN4UP_AI_API void in4up_ai_destroy(in4up_ai_handle handle) {
    auto * ai = static_cast<In4upAiContext *>(handle);
    if (!ai) return;
    if (ai->context) llama_free(ai->context);
    if (ai->model) llama_model_free(ai->model);
    delete ai;
    backend_release();
}

extern "C" IN4UP_AI_API in4up_ai_handle in2up_ai_create(const char * model_path, int n_ctx, int n_threads) {
    return in4up_ai_create(model_path, n_ctx, n_threads);
}

extern "C" IN4UP_AI_API int in2up_ai_generate(in2up_ai_handle handle, const char * prompt, int max_tokens, float temperature, char ** output) {
    return in4up_ai_generate(handle, prompt, max_tokens, temperature, output);
}

extern "C" IN4UP_AI_API void in2up_ai_free_string(char * value) { in4up_ai_free_string(value); }

extern "C" IN4UP_AI_API void in2up_ai_destroy(in2up_ai_handle handle) { in4up_ai_destroy(handle); }
