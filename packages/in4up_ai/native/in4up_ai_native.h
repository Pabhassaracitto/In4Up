#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef void * in4up_ai_handle;

in4up_ai_handle in4up_ai_create(const char * model_path, int n_ctx, int n_threads);
int in4up_ai_generate(in4up_ai_handle handle, const char * prompt, int max_tokens, float temperature, char ** output);
void in4up_ai_free_string(char * value);
void in4up_ai_destroy(in4up_ai_handle handle);

/* Compatibility aliases for the harvested I2U chat session. */
typedef in4up_ai_handle in2up_ai_handle;
in4up_ai_handle in2up_ai_create(const char * model_path, int n_ctx, int n_threads);
int in2up_ai_generate(in2up_ai_handle handle, const char * prompt, int max_tokens, float temperature, char ** output);
void in2up_ai_free_string(char * value);
void in2up_ai_destroy(in2up_ai_handle handle);

#ifdef __cplusplus
}
#endif
