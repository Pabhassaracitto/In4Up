// native/llama_cpp/llama_bridge.cpp
// Wrapper: C++ llama.cpp API → C API cho Dart FFI

#include "llama_bridge.h"
#include "vendor/llama.cpp/llama.h"
#include <string>
#include <vector>
#include <cstring>
#include <cstdio>
#include <algorithm>

// Internal context struct
struct LlamaBridgeCtx
{
    llama_model *model = nullptr;
    llama_context *ctx = nullptr;
    std::string model_info;
    bool valid = false;
};

extern "C"
{

    void *llama_bridge_create(const char *model_path, int n_ctx, int n_threads)
    {
        auto *bridge = new LlamaBridgeCtx();

        // ── Model params ──────────────────────────────────────
        llama_model_params model_params = llama_model_default_params();
        model_params.n_gpu_layers = 0; // CPU only cho mobile

        bridge->model = llama_load_model_from_file(model_path, model_params);
        if (!bridge->model)
        {
            delete bridge;
            return nullptr;
        }

        // ── Context params ────────────────────────────────────
        llama_context_params ctx_params = llama_context_default_params();
        ctx_params.n_ctx = n_ctx > 0 ? n_ctx : 2048;
        ctx_params.n_threads = n_threads > 0 ? n_threads : 4;
        ctx_params.n_batch = 512;

        bridge->ctx = llama_new_context_with_model(bridge->model, ctx_params);
        if (!bridge->ctx)
        {
            llama_free_model(bridge->model);
            delete bridge;
            return nullptr;
        }

        bridge->model_info = llama_model_desc(bridge->model);
        bridge->valid = true;

        return static_cast<void *>(bridge);
    }

    void llama_bridge_destroy(void *ctx)
    {
        if (!ctx)
            return;
        auto *bridge = static_cast<LlamaBridgeCtx *>(ctx);

        if (bridge->ctx)
            llama_free(bridge->ctx);
        if (bridge->model)
            llama_free_model(bridge->model);

        delete bridge;
    }

    int llama_bridge_infer(
        void *ctx,
        const char *prompt,
        char *output_buf,
        int buf_size,
        int max_tokens,
        float temperature)
    {
        if (!ctx || !prompt || !output_buf || buf_size <= 0)
            return -1;

        auto *bridge = static_cast<LlamaBridgeCtx *>(ctx);
        if (!bridge->valid)
            return -1;

        // ── Tokenize prompt ───────────────────────────────────
        std::vector<llama_token> tokens(4096);
        int n_tokens = llama_tokenize(
            bridge->model,
            prompt,
            strlen(prompt),
            tokens.data(),
            tokens.size(),
            true, // add_bos
            true  // special
        );

        if (n_tokens < 0 || n_tokens > (int)tokens.size())
            return -1;
        tokens.resize(n_tokens);

        // ── Reset context ─────────────────────────────────────
        llama_kv_cache_clear(bridge->ctx);

        // ── Decode prompt tokens ──────────────────────────────
        llama_batch batch = llama_batch_get_one(tokens.data(), n_tokens, 0, 0);
        if (llama_decode(bridge->ctx, batch) != 0)
            return -1;

        // ── Generate output tokens ────────────────────────────
        std::string output;
        output.reserve(1024);

        // Sampler setup
        auto sparams = llama_sampler_chain_default_params();
        llama_sampler *sampler = llama_sampler_chain_init(sparams);
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature));
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(42));

        llama_token eos_token = llama_token_eos(bridge->model);
        int n_generated = 0;

        while (n_generated < max_tokens)
        {
            llama_token new_token = llama_sampler_sample(sampler, bridge->ctx, -1);

            // Stop conditions
            if (new_token == eos_token)
                break;

            // Convert token → string
            char token_buf[256];
            int token_len = llama_token_to_piece(
                bridge->model, new_token, token_buf, sizeof(token_buf), 0, true);
            if (token_len < 0)
                break;

            output.append(token_buf, token_len);
            n_generated++;

            // Decode next token
            llama_batch next_batch = llama_batch_get_one(&new_token, 1, n_tokens + n_generated - 1, 0);
            if (llama_decode(bridge->ctx, next_batch) != 0)
                break;

            // Stop khi đã đóng JSON (tối ưu cho use case này)
            if (output.size() > 10 && output.back() == '}')
            {
                // Kiểm tra JSON cân bằng
                int depth = 0;
                for (char c : output)
                {
                    if (c == '{')
                        depth++;
                    else if (c == '}')
                        depth--;
                }
                if (depth == 0)
                    break; // JSON hoàn chỉnh
            }
        }

        llama_sampler_free(sampler);

        // Copy vào output buffer
        int out_len = std::min((int)output.size(), buf_size - 1);
        std::memcpy(output_buf, output.c_str(), out_len);
        output_buf[out_len] = '\0';

        return out_len;
    }

    int llama_bridge_is_valid(void *ctx)
    {
        if (!ctx)
            return 0;
        return static_cast<LlamaBridgeCtx *>(ctx)->valid ? 1 : 0;
    }

    const char *llama_bridge_model_info(void *ctx)
    {
        if (!ctx)
            return "invalid";
        return static_cast<LlamaBridgeCtx *>(ctx)->model_info.c_str();
    }

    void llama_bridge_reset(void *ctx)
    {
        if (!ctx)
            return;
        auto *bridge = static_cast<LlamaBridgeCtx *>(ctx);
        if (bridge->ctx)
            llama_kv_cache_clear(bridge->ctx);
    }

    const char *llama_bridge_version(void)
    {
        return "llama_bridge v1.0";
    }

} // extern "C"
