import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_error.dart';
import 'llm/gemini_service.dart';

// ─────────────────────────────────────────────────────────────────
// Gemini Service Provider (singleton)
// ─────────────────────────────────────────────────────────────────
final geminiServiceProvider = Provider<GeminiService>((ref) {
  final service = GeminiService();
  ref.onDispose(service.dispose);
  return service;
});

// Alias for backwards compatibility if needed
final llmServiceProvider = geminiServiceProvider;

// ─────────────────────────────────────────────────────────────────
// LLM / Gemini State Notifier
// ─────────────────────────────────────────────────────────────────
enum LlmStatus { notLoaded, loading, ready, generating, error }

class LlmState {
  final LlmStatus status;
  final String? error;
  final String streamingResponse;
  final String apiKey;
  final String selectedModel;

  const LlmState({
    this.status = LlmStatus.notLoaded,
    this.error,
    this.streamingResponse = '',
    this.apiKey = '',
    this.selectedModel = AppConstants.defaultGeminiModel,
  });

  bool get isConfigured => apiKey.trim().isNotEmpty;

  LlmState copyWith({
    LlmStatus? status,
    String? error,
    String? streamingResponse,
    String? apiKey,
    String? selectedModel,
  }) {
    return LlmState(
      status: status ?? this.status,
      error: error,
      streamingResponse: streamingResponse ?? this.streamingResponse,
      apiKey: apiKey ?? this.apiKey,
      selectedModel: selectedModel ?? this.selectedModel,
    );
  }
}

class LlmNotifier extends Notifier<LlmState> {
  @override
  LlmState build() {
    // Eagerly initialize preferences in background
    _init();
    return const LlmState();
  }

  GeminiService get _gemini => ref.read(geminiServiceProvider);

  Future<void> _init() async {
    await _gemini.initialize();
    state = state.copyWith(
      apiKey: _gemini.apiKey,
      selectedModel: _gemini.modelName,
      status: _gemini.isConfigured ? LlmStatus.ready : LlmStatus.notLoaded,
    );
  }

  /// Ensures settings are loaded. If API key is present, state is marked [LlmStatus.ready].
  Future<void> loadModelIfNeeded() async {
    if (state.apiKey.isEmpty) {
      await _gemini.initialize();
    }

    if (!_gemini.isConfigured) {
      state = state.copyWith(
        status: LlmStatus.notLoaded,
        apiKey: _gemini.apiKey,
        selectedModel: _gemini.modelName,
        error: 'Gemini API key is not configured. Please enter your API key in Settings.',
      );
      return;
    }

    state = state.copyWith(
      status: LlmStatus.ready,
      apiKey: _gemini.apiKey,
      selectedModel: _gemini.modelName,
      error: null,
    );
  }

  /// Updates and stores the Gemini API key.
  Future<void> setApiKey(String key) async {
    await _gemini.setApiKey(key);
    state = state.copyWith(
      apiKey: _gemini.apiKey,
      status: _gemini.isConfigured ? LlmStatus.ready : LlmStatus.notLoaded,
      error: null,
    );
  }

  /// Updates and stores the active Gemini model.
  Future<void> setSelectedModel(String model) async {
    await _gemini.setModel(model);
    state = state.copyWith(
      selectedModel: _gemini.modelName,
    );
  }

  /// Tests connection with Gemini API.
  Future<String> testConnection({String? apiKey, String? model}) async {
    state = state.copyWith(status: LlmStatus.loading);
    try {
      final result = await _gemini.testConnection(
        testApiKey: apiKey,
        testModel: model,
      );
      state = state.copyWith(
        status: _gemini.isConfigured ? LlmStatus.ready : LlmStatus.notLoaded,
        error: null,
      );
      return result;
    } on InferenceError catch (e) {
      state = state.copyWith(
        status: LlmStatus.error,
        error: e.message,
      );
      rethrow;
    } catch (e) {
      final msg = 'Connection failed: $e';
      state = state.copyWith(
        status: LlmStatus.error,
        error: msg,
      );
      throw InferenceError(msg);
    }
  }

  /// Generates a response with real-time token streaming.
  Future<String> generate({
    required String prompt,
    String? systemInstruction,
    int maxTokens = AppConstants.defaultMaxOutputTokens,
    double temperature = 0.7,
  }) async {
    if (!state.isConfigured && !_gemini.isConfigured) {
      state = state.copyWith(
        status: LlmStatus.notLoaded,
        error: 'Please configure your Gemini API Key in Settings first.',
      );
      return '';
    }

    state = state.copyWith(status: LlmStatus.generating, streamingResponse: '');

    // Subscribe to streaming tokens
    final sub = _gemini.tokenStream.listen((piece) {
      state = state.copyWith(
        streamingResponse: state.streamingResponse + piece,
      );
    });

    try {
      final full = await _gemini.generate(
        prompt: prompt,
        systemInstruction: systemInstruction,
        maxTokens: maxTokens,
        temperature: temperature,
      );
      state = state.copyWith(status: LlmStatus.ready, streamingResponse: full);
      return full;
    } on InferenceError catch (e) {
      state = state.copyWith(status: LlmStatus.error, error: e.message);
      return '';
    } finally {
      await sub.cancel();
    }
  }

  void stopGeneration() {
    _gemini.stopGeneration();
    state = state.copyWith(status: LlmStatus.ready);
  }
}

final llmNotifierProvider = NotifierProvider<LlmNotifier, LlmState>(() {
  return LlmNotifier();
});

// Alias
final geminiNotifierProvider = llmNotifierProvider;
