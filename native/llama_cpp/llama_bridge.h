// native/llama_cpp/llama_bridge.h
// C API - Dart FFI chỉ đọc file này
// Không dùng C++ types ở đây để Dart parse được

#ifndef LLAMA_BRIDGE_H
#define LLAMA_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

// ── Context ───────────────────────────────────────────────

/// Tạo context từ model file
/// Trả về NULL nếu thất bại
void* llama_bridge_create(const char* model_path, int n_ctx, int n_threads);

/// Giải phóng context
void llama_bridge_destroy(void* ctx);

// ── Inference ─────────────────────────────────────────────

/// Chạy inference đồng bộ
/// output_buf: buffer để ghi kết quả
/// max_tokens: giới hạn output
/// Trả về số bytes đã ghi, -1 nếu lỗi
int llama_bridge_infer(
  void* ctx,
  const char* prompt,
  char* output_buf,
  int buf_size,
  int max_tokens,
  float temperature
);

/// Kiểm tra context hợp lệ
int llama_bridge_is_valid(void* ctx);

/// Lấy thông tin model
const char* llama_bridge_model_info(void* ctx);

/// Reset KV cache (dùng giữa các inference)
void llama_bridge_reset(void* ctx);

// ── Version ───────────────────────────────────────────────

const char* llama_bridge_version(void);

#ifdef __cplusplus
}
#endif

#endif // LLAMA_BRIDGE_H
