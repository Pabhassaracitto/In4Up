#include "in4up_ai_native.h"
#include "llama.h"

#include <algorithm>
#include <atomic>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

struct In4upAiContext {
    llama_model * model = nullptr;
    llama_context * context = nullptr;
    llama_sampler * sampler = nullptr;
    const llama_vocab * vocab = nullptr;
    int n_threads = 4;
};

// Process-wide abort: Dart main isolate can call in4up_ai_abort() while the
// worker isolate is blocked inside llama_decode / the generate loop.
static std::atomic<int> g_abort{0};

static bool in4up_abort_cb(void * /*data*/) {
    return g_abort.load() != 0;
}

static void clear_memory(llama_context * ctx) {
    if (!ctx) return;
    llama_memory_t mem = llama_get_memory(ctx);
    if (mem) llama_memory_clear(mem, true);
}

static bool contains_stop(const std::string & text, std::string * cut_at) {
    static const char * kStops[] = {
        "<end_of_turn>",
        "<start_of_turn>",
        "<|eot_id|>",
        "<|im_end|>",
        "</s>",
        "<eos>",
    };
    for (const char * stop : kStops) {
        const auto pos = text.find(stop);
        if (pos != std::string::npos) {
            if (cut_at) *cut_at = text.substr(0, pos);
            return true;
        }
    }
    return false;
}

static std::string generate_text(In4upAiContext * ai, const char * prompt, int max_tokens) {
    g_abort.store(0);
    llama_set_abort_callback(ai->context, in4up_abort_cb, nullptr);
    clear_memory(ai->context);

    const int prompt_len = static_cast<int>(std::strlen(prompt));
    const int n_prompt = -llama_tokenize(ai->vocab, prompt, prompt_len, nullptr, 0, true, true);
    if (n_prompt <= 0) return {};

    std::vector<llama_token> tokens(static_cast<size_t>(n_prompt));
    if (llama_tokenize(ai->vocab, prompt, prompt_len, tokens.data(), n_prompt, true, true) < 0) {
        return {};
    }

    const int n_ctx = static_cast<int>(llama_n_ctx(ai->context));
    const int n_batch = std::max(1, static_cast<int>(llama_n_batch(ai->context)));
    const int max_new = std::max(1, max_tokens);
    int n_use = static_cast<int>(tokens.size());
    int offset = 0;
    // Leave room for the completion; keep the TAIL (latest user turn).
    const int max_prompt = std::max(32, n_ctx - max_new);
    if (n_use > max_prompt) {
        offset = n_use - max_prompt;
        n_use = max_prompt;
    }

    for (int i = 0; i < n_use; ) {
        if (g_abort.load() != 0) return {};
        const int n = std::min(n_batch, n_use - i);
        llama_batch batch = llama_batch_get_one(tokens.data() + offset + i, n);
        const int rc = llama_decode(ai->context, batch);
        if (rc != 0) return {};
        i += n;
    }

    std::string result;
    result.reserve(static_cast<size_t>(max_new) * 4);
    for (int i = 0; i < max_new; ++i) {
        if (g_abort.load() != 0) break;
        const llama_token token = llama_sampler_sample(ai->sampler, ai->context, -1);
        if (llama_vocab_is_eog(ai->vocab, token)) break;

        char piece[256];
        const int n = llama_token_to_piece(ai->vocab, token, piece, static_cast<int32_t>(sizeof(piece)), 0, true);
        if (n > 0) result.append(piece, static_cast<size_t>(n));

        std::string trimmed;
        if (contains_stop(result, &trimmed)) {
            result.swap(trimmed);
            break;
        }

        llama_batch batch = llama_batch_get_one(const_cast<llama_token *>(&token), 1);
        if (llama_decode(ai->context, batch) != 0) break;
    }
    return result;
}

extern "C" in4up_ai_handle in4up_ai_create(const char * model_path, int n_ctx, int n_threads) {
    if (!model_path || !*model_path) return nullptr;
    llama_backend_init();

    auto * ai = new In4upAiContext();
    ai->n_threads = std::max(1, std::min(n_threads, 4));
    auto model_params = llama_model_default_params();
    ai->model = llama_model_load_from_file(model_path, model_params);
    if (!ai->model) {
        delete ai;
        llama_backend_free();
        return nullptr;
    }

    auto context_params = llama_context_default_params();
    // Small n_batch: a 2048-token one-shot prefill on a weak tablet is what
    // made chat hit the 3-minute Dart timeout before a single token appeared.
    context_params.n_ctx = static_cast<uint32_t>(std::max(512, n_ctx));
    context_params.n_batch = 128;
    context_params.n_ubatch = 128;
    context_params.n_threads = ai->n_threads;
    context_params.n_threads_batch = ai->n_threads;
    ai->context = llama_init_from_model(ai->model, context_params);
    ai->vocab = llama_model_get_vocab(ai->model);
    if (!ai->context || !ai->vocab) {
        in4up_ai_destroy(ai);
        return nullptr;
    }

    auto sampler_params = llama_sampler_chain_default_params();
    ai->sampler = llama_sampler_chain_init(sampler_params);
    llama_sampler_chain_add(ai->sampler, llama_sampler_init_temp(0.3f));
    llama_sampler_chain_add(ai->sampler, llama_sampler_init_greedy());
    llama_set_abort_callback(ai->context, in4up_abort_cb, nullptr);
    return ai;
}

extern "C" int in4up_ai_generate(in4up_ai_handle handle, const char * prompt, int max_tokens, float temperature, char ** output) {
    if (!handle || !prompt || !output) return -1;
    auto * ai = static_cast<In4upAiContext *>(handle);
    if (ai->sampler) llama_sampler_reset(ai->sampler);
    (void) temperature;
    const auto result = generate_text(ai, prompt, std::max(1, max_tokens));
    *output = static_cast<char *>(std::malloc(result.size() + 1));
    if (!*output) return -2;
    std::memcpy(*output, result.data(), result.size());
    (*output)[result.size()] = '\0';
    return static_cast<int>(result.size());
}

extern "C" void in4up_ai_abort(void) { g_abort.store(1); }

extern "C" void in4up_ai_free_string(char * value) { std::free(value); }

extern "C" void in4up_ai_destroy(in4up_ai_handle handle) {
    auto * ai = static_cast<In4upAiContext *>(handle);
    if (!ai) return;
    g_abort.store(1);
    if (ai->sampler) llama_sampler_free(ai->sampler);
    if (ai->context) llama_free(ai->context);
    if (ai->model) llama_model_free(ai->model);
    delete ai;
    llama_backend_free();
}

extern "C" in4up_ai_handle in2up_ai_create(const char * model_path, int n_ctx, int n_threads) {
    return in4up_ai_create(model_path, n_ctx, n_threads);
}

extern "C" int in2up_ai_generate(in2up_ai_handle handle, const char * prompt, int max_tokens, float temperature, char ** output) {
    return in4up_ai_generate(handle, prompt, max_tokens, temperature, output);
}

extern "C" void in2up_ai_free_string(char * value) { in4up_ai_free_string(value); }

extern "C" void in2up_ai_destroy(in2up_ai_handle handle) { in4up_ai_destroy(handle); }

extern "C" void in2up_ai_abort(void) { in4up_ai_abort(); }
