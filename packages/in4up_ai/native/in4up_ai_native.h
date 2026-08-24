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

/* Compatibility aliases for the harvested I2U chat session. */
typedef in4up_ai_handle in2up_ai_handle;
IN4UP_AI_API in4up_ai_handle in2up_ai_create(const char * model_path, int n_ctx, int n_threads);
IN4UP_AI_API int in2up_ai_generate(in2up_ai_handle handle, const char * prompt, int max_tokens, float temperature, char ** output);
IN4UP_AI_API void in2up_ai_free_string(char * value);
IN4UP_AI_API void in2up_ai_destroy(in2up_ai_handle handle);

#ifdef __cplusplus
}
#endif
