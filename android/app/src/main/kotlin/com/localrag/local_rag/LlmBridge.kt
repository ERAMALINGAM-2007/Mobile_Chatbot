package com.localrag.local_rag

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Java/Kotlin interface around the native llama.cpp JNI functions.
 * Loaded once per process; all methods call through to C++.
 */
class LlmBridge {
    companion object {
        private const val TAG = "LlmBridge"
        init {
            System.loadLibrary("localrag")
        }
    }

    // ── native declarations ──────────────────────────────────
    external fun loadModel(modelPath: String, nCtx: Int, nThreads: Int): String
    external fun unloadModel()
    external fun isModelLoaded(): Boolean
    external fun stopGeneration()

    /**
     * Blocking call – must be invoked from a background thread.
     * [tokenCallback] receives each token piece as it is generated.
     * Returns the full generated string.
     */
    external fun generate(
        prompt: String,
        maxTokens: Int,
        temperature: Float,
        tokenCallback: TokenCallback,
    ): String

    fun interface TokenCallback {
        fun onToken(piece: String)
    }
}

/**
 * Flutter MethodChannel plugin that exposes LlmBridge to Dart.
 *
 * Methods:
 *   loadModel   { modelPath, nCtx, nThreads } → "ok" or "error:..."
 *   unloadModel {} → null
 *   isModelLoaded {} → Boolean
 *   stopGeneration {} → null
 *   generate { prompt, maxTokens, temperature } → full string
 *             (streams tokens via EventChannel "com.localrag/llm_tokens")
 */
class LlmPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private val bridge = LlmBridge()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var genJob: Job? = null

    // We use a simple Dart-side event callback via method channel for tokens
    private var flutterApi: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "com.localrag/llm")
        methodChannel.setMethodCallHandler(this)
        flutterApi = methodChannel
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        scope.cancel()
        bridge.unloadModel()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {

            "loadModel" -> {
                val modelPath = call.argument<String>("modelPath") ?: run {
                    result.error("INVALID_ARG", "modelPath is required", null)
                    return
                }
                val nCtx     = call.argument<Int>("nCtx") ?: 2048
                val nThreads = call.argument<Int>("nThreads") ?: 4

                scope.launch {
                    val res = bridge.loadModel(modelPath, nCtx, nThreads)
                    launch(Dispatchers.Main) { result.success(res) }
                }
            }

            "unloadModel" -> {
                scope.launch {
                    bridge.unloadModel()
                    launch(Dispatchers.Main) { result.success(null) }
                }
            }

            "isModelLoaded" -> {
                result.success(bridge.isModelLoaded())
            }

            "stopGeneration" -> {
                bridge.stopGeneration()
                result.success(null)
            }

            "generate" -> {
                val prompt      = call.argument<String>("prompt") ?: ""
                val maxTokens   = call.argument<Int>("maxTokens") ?: 512
                val temperature = (call.argument<Double>("temperature") ?: 0.7).toFloat()

                genJob = scope.launch {
                    val full = bridge.generate(
                        prompt      = prompt,
                        maxTokens   = maxTokens,
                        temperature = temperature,
                        tokenCallback = { piece ->
                            // Send each token to Flutter on main thread
                            launch(Dispatchers.Main) {
                                flutterApi?.invokeMethod("onToken", piece)
                            }
                        }
                    )
                    launch(Dispatchers.Main) { result.success(full) }
                }
            }

            else -> result.notImplemented()
        }
    }
}
