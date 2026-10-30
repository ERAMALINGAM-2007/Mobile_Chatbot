import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/errors/app_error.dart';

/// Dart-side interface for the native llama.cpp inference engine.
///
/// All heavy work runs on a background thread in Kotlin/C++.
/// Token streaming is delivered via [onToken] callbacks pushed back
/// through MethodChannel.invokeMethod("onToken", piece).
class LlmService {
  static const MethodChannel _channel = MethodChannel('com.localrag/llm');

  bool _modelLoaded = false;
  bool _generating = false;

  // Token streaming controller
  final StreamController<String> _tokenStreamController =
      StreamController<String>.broadcast();

  /// Stream of token pieces as they are generated.
  Stream<String> get tokenStream => _tokenStreamController.stream;

  LlmService() {
    // Listen for token callbacks pushed from Kotlin
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onToken') {
        final piece = call.arguments as String? ?? '';
        _tokenStreamController.add(piece);
      }
    });
  }

  bool get isModelLoaded => _modelLoaded;
  bool get isGenerating => _generating;

  /// Load the GGUF model from [modelPath].
  ///
  /// [nCtx] - context window size (default 2048)
  /// [nThreads] - CPU threads for inference (default 4)
  Future<void> loadModel({
    required String modelPath,
    int nCtx = 2048,
    int nThreads = 4,
  }) async {
    if (_modelLoaded) return;

    final result = await _channel.invokeMethod<String>('loadModel', {
      'modelPath': modelPath,
      'nCtx': nCtx,
      'nThreads': nThreads,
    });

    if (result == null || result.startsWith('error:')) {
      throw InferenceError('Failed to load LLM model: $result');
    }
    _modelLoaded = true;
  }

  /// Unload the model from memory.
  Future<void> unloadModel() async {
    await _channel.invokeMethod<void>('unloadModel');
    _modelLoaded = false;
  }

  /// Check if the model is currently loaded.
  Future<bool> checkIsModelLoaded() async {
    final result = await _channel.invokeMethod<bool>('isModelLoaded');
    _modelLoaded = result ?? false;
    return _modelLoaded;
  }

  /// Stop a running generation immediately.
  void stopGeneration() {
    _channel.invokeMethod<void>('stopGeneration');
    _generating = false;
  }

  /// Generate a response for [prompt].
  ///
  /// Tokens stream via [tokenStream] in real time.
  /// Returns the full completed response string.
  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async {
    if (!_modelLoaded) {
      throw const InferenceError('LLM model is not loaded.');
    }
    if (_generating) {
      throw const InferenceError('Already generating a response.');
    }

    _generating = true;
    try {
      final result = await _channel.invokeMethod<String>('generate', {
        'prompt': prompt,
        'maxTokens': maxTokens,
        'temperature': temperature,
      });

      if (result == null || result.startsWith('error:')) {
        throw InferenceError('Generation failed: $result');
      }

      return result;
    } finally {
      _generating = false;
    }
  }

  void dispose() {
    _tokenStreamController.close();
  }
}
