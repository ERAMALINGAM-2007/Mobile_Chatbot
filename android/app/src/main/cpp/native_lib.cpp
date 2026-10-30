#include <jni.h>
#include <string>
#include <vector>
#include <thread>
#include <atomic>
#include <sstream>
#include <cstring>
#include <android/log.h>

#include "llama.cpp/include/llama.h"

#define LOG_TAG "LocalRAG"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// ─────────────────────────────────────────────
// Global state (single model at a time)
// ─────────────────────────────────────────────
static llama_model   *g_model   = nullptr;
static llama_context *g_context = nullptr;
static std::atomic<bool> g_generating{false};
static std::atomic<bool> g_stop_requested{false};

static JavaVM *g_jvm = nullptr;

// ─────────────────────────────────────────────
// JNI_OnLoad – store JavaVM for callbacks
// ─────────────────────────────────────────────
JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *) {
    g_jvm = vm;
    llama_backend_init();
    LOGI("llama.cpp backend initialized");
    return JNI_VERSION_1_6;
}

JNIEXPORT void JNI_OnUnload(JavaVM *, void *) {
    if (g_context) { llama_free(g_context); g_context = nullptr; }
    if (g_model)   { llama_model_free(g_model); g_model = nullptr; }
    llama_backend_free();
}

// ─────────────────────────────────────────────
// isModelLoaded
// ─────────────────────────────────────────────
extern "C" JNIEXPORT jboolean JNICALL
Java_com_localrag_local_1rag_LlmBridge_isModelLoaded(JNIEnv *, jobject) {
    return (g_model != nullptr && g_context != nullptr) ? JNI_TRUE : JNI_FALSE;
}

// ─────────────────────────────────────────────
// loadModel
// ─────────────────────────────────────────────
extern "C" JNIEXPORT jstring JNICALL
Java_com_localrag_local_1rag_LlmBridge_loadModel(
        JNIEnv *env,
        jobject,
        jstring jModelPath,
        jint    nCtx,
        jint    nThreads) {

    if (g_model != nullptr) {
        return env->NewStringUTF("already_loaded");
    }

    const char *modelPath = env->GetStringUTFChars(jModelPath, nullptr);

    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = 0; // CPU only on mobile

    g_model = llama_model_load_from_file(modelPath, mparams);
    env->ReleaseStringUTFChars(jModelPath, modelPath);

    if (!g_model) {
        LOGE("Failed to load model");
        return env->NewStringUTF("error:model_load_failed");
    }

    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx           = (uint32_t)nCtx;
    cparams.n_batch         = 512;
    cparams.n_threads       = (int32_t)nThreads;
    cparams.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_AUTO;

    g_context = llama_init_from_model(g_model, cparams);
    if (!g_context) {
        llama_model_free(g_model);
        g_model = nullptr;
        LOGE("Failed to create context");
        return env->NewStringUTF("error:context_create_failed");
    }

    LOGI("Model loaded successfully, n_ctx=%d, n_threads=%d", nCtx, nThreads);
    return env->NewStringUTF("ok");
}

// ─────────────────────────────────────────────
// unloadModel
// ─────────────────────────────────────────────
extern "C" JNIEXPORT void JNICALL
Java_com_localrag_local_1rag_LlmBridge_unloadModel(JNIEnv *, jobject) {
    if (g_context) { llama_free(g_context); g_context = nullptr; }
    if (g_model)   { llama_model_free(g_model); g_model = nullptr; }
    LOGI("Model unloaded");
}

// ─────────────────────────────────────────────
// stopGeneration
// ─────────────────────────────────────────────
extern "C" JNIEXPORT void JNICALL
Java_com_localrag_local_1rag_LlmBridge_stopGeneration(JNIEnv *, jobject) {
    g_stop_requested.store(true);
}

// ─────────────────────────────────────────────
// generate  (blocking – called from a Kotlin coroutine thread)
// Streams tokens back via callback object
// ─────────────────────────────────────────────
extern "C" JNIEXPORT jstring JNICALL
Java_com_localrag_local_1rag_LlmBridge_generate(
        JNIEnv  *env,
        jobject  thiz,
        jstring  jPrompt,
        jint     maxTokens,
        jfloat   temperature,
        jobject  tokenCallback) {

    if (!g_model || !g_context) {
        return env->NewStringUTF("error:model_not_loaded");
    }
    if (g_generating.exchange(true)) {
        return env->NewStringUTF("error:already_generating");
    }
    g_stop_requested.store(false);

    const struct llama_vocab *vocab = llama_model_get_vocab(g_model);
    if (!vocab) {
        g_generating.store(false);
        return env->NewStringUTF("error:vocab_unavailable");
    }

    const char *prompt = env->GetStringUTFChars(jPrompt, nullptr);

    // ── tokenise ──
    const int n_prompt_tokens = -llama_tokenize(
        vocab, prompt, (int32_t)strlen(prompt),
        nullptr, 0, /*add_special=*/true, /*parse_special=*/true);

    std::vector<llama_token> tokens_list(n_prompt_tokens > 0 ? n_prompt_tokens : 1);
    llama_tokenize(
        vocab, prompt, (int32_t)strlen(prompt),
        tokens_list.data(), tokens_list.size(),
        /*add_special=*/true, /*parse_special=*/true);

    env->ReleaseStringUTFChars(jPrompt, prompt);

    // ── guard: truncate prompt if it exceeds context window ──
    const int32_t n_ctx = (int32_t)llama_n_ctx(g_context);
    const int32_t max_prompt_tokens = n_ctx - (int32_t)maxTokens - 16; // reserve space for generation
    if (max_prompt_tokens <= 0) {
        g_generating.store(false);
        return env->NewStringUTF("error:context_too_small");
    }
    if ((int32_t)tokens_list.size() > max_prompt_tokens) {
        LOGI("Truncating prompt from %d to %d tokens to fit n_ctx=%d", (int)tokens_list.size(), max_prompt_tokens, n_ctx);
        tokens_list.resize(max_prompt_tokens);
    }

    // ── memory / KV-cache reset ──
    llama_memory_clear(llama_get_memory(g_context), true);

    // ── batch decode prompt ──
    llama_batch batch = llama_batch_get_one(tokens_list.data(), (int32_t)tokens_list.size());
    if (llama_decode(g_context, batch) != 0) {
        g_generating.store(false);
        return env->NewStringUTF("error:decode_failed");
    }

    // ── find callback method ──
    jclass  cbClass  = env->GetObjectClass(tokenCallback);
    jmethodID cbMethod = env->GetMethodID(cbClass, "onToken", "(Ljava/lang/String;)V");

    // ── sampler ──
    llama_sampler *smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(temperature));
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    std::string fullResponse;
    int n_generated = 0;

    while (n_generated < maxTokens && !g_stop_requested.load()) {
        llama_token new_token = llama_sampler_sample(smpl, g_context, -1);
        llama_sampler_accept(smpl, new_token);

        if (llama_vocab_is_eog(vocab, new_token)) break;

        // ── de-tokenise ──
        char piece[256] = {};
        int32_t piece_len = llama_token_to_piece(vocab, new_token, piece, sizeof(piece) - 1, 0, true);
        if (piece_len < 0) piece_len = 0;
        piece[piece_len] = '\0';
        fullResponse += piece;

        // ── stream token to Java ──
        jstring jPiece = env->NewStringUTF(piece);
        env->CallVoidMethod(tokenCallback, cbMethod, jPiece);
        env->DeleteLocalRef(jPiece);

        // ── next batch (single token) ──
        llama_batch next = llama_batch_get_one(&new_token, 1);
        if (llama_decode(g_context, next) != 0) break;

        ++n_generated;
    }

    llama_sampler_free(smpl);
    g_generating.store(false);

    return env->NewStringUTF(fullResponse.c_str());
}
