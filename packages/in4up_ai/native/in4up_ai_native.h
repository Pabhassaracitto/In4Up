#pragma once

// Export macro: bắt buộc trên Windows — không có __declspec(dllexport) thì DLL
// không export symbol nào và Dart FFI sẽ lookup thất bại (âm thầm rơi về mock).
#ifdef _WIN32
#define IN4UP_AI_API __declspec(dllexport)
#else
#define IN4UP_AI_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void * in4up_ai_handle;

IN4UP_AI_API in4up_ai_handle in4up_ai_create(const char * model_path, int n_ctx, int n_threads);
IN4UP_AI_API int in4up_ai_generate(in4up_ai_handle handle, const char * prompt, int max_tokens, float temperature, char ** output);
IN4UP_AI_API void in4up_ai_free_string(char * value);
IN4UP_AI_API void in4up_ai_destroy(in4up_ai_handle handle);

// =============================================================================
// HYMT-003 (2026-11-06) — raw GGUF inspection + "why did it fail" log.
//
// Dart cần biết SỰ THẬT về file model TRƯỚC khi hứa hẹn với người dùng:
//   * `general.architecture` (hunyuan-dense?)
//   * loại quant của tensor đầu (`q2_0`, `q1_0`, `STQ1_0`…)
//   * file có `tokenizer.chat_template` (Jinja) hay không
// xem `docs/translation/hymt_root_cause_2026-11-06.md`.
// =============================================================================

/// Số byte Dart phải đọc từ đầu file để gọi được `in4up_ai_inspect_gguf`
/// (GGUF header + KV metadata: tokenizer 120k token + template thường < 8MB).
#define IN4UP_AI_GGUF_PREFIX_BYTES (8u * 1024u * 1024u)

/// Đọc header GGUF từ `prefix` (N byte đầu của file, xem
/// IN4UP_AI_GGUF_PREFIX_BYTES). Trả 0 nếu OK, âm nếu lỗi.
/// Thuần parse — không cấp phát model, không cần llama_backend_init().
///
/// Mọi output đi qua buffer do phía gọi cấp phát (không dùng struct) để
/// layout FFI không phụ thuộc compiler/ABI:
///   arch_out     "hunyuan-dense" | "llama" | ""      (NUL-terminated)
///   quant_out    "q2_0" | "q1_0" | "f16" | "UNKNOWN:41"
///   supported    1 = pinned llama.cpp LOAD được; 0 = chắc chắn KHÔNG
///   has_template 1 = GGUF có `tokenizer.chat_template`
///   n_tensors    số tensor khai báo trong header
IN4UP_AI_API int in4up_ai_inspect_gguf(const unsigned char * prefix, int prefix_len,
                                       char * arch_out, int arch_cap,
                                       char * quant_out, int quant_cap,
                                       int * supported, int * has_template,
                                       int * n_tensors);

/// Đăng ký callback nhận log của llama.cpp/ggml (vd "unknown model
/// architecture", "failed to load tensor", OOM). `cb` = NULL ⇒ bỏ đăng ký
/// (vẫn giữ ring buffer nội bộ để `in4up_ai_last_log` đọc được).
typedef void (*in4up_ai_log_fn)(int level, const char * text, void * user_data);
IN4UP_AI_API void in4up_ai_set_logger(in4up_ai_log_fn cb, void * user_data);

/// Lấy log llama.cpp gần nhất (tối đa `max_len` byte, luôn NUL-terminated).
/// Toàn bộ stderr của llama được gom vào đây — trên Android release logcat
/// không hiện, nên đây là nguồn DUY NHẤT giải thích được lỗi load/generate.
IN4UP_AI_API void in4up_ai_last_log(char * buf, int max_len);

/* Compatibility aliases for the harvested I2U chat session. */
typedef in4up_ai_handle in2up_ai_handle;
IN4UP_AI_API in4up_ai_handle in2up_ai_create(const char * model_path, int n_ctx, int n_threads);
IN4UP_AI_API int in2up_ai_generate(in2up_ai_handle handle, const char * prompt, int max_tokens, float temperature, char ** output);
IN4UP_AI_API void in2up_ai_free_string(char * value);
IN4UP_AI_API void in2up_ai_destroy(in2up_ai_handle handle);

#ifdef __cplusplus
}
#endif
