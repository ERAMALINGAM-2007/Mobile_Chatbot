class AppConstants {
  static const String appName = 'LocalRAG';
  static const String appVersion = '1.0.0';

  // Default RAG Settings (Scaled for Gemini's massive context window)
  static const int defaultChunkSize = 800; // characters approximation
  static const int defaultChunkOverlap = 150;
  static const int defaultTopK = 8; // Scaled up from 4 for comprehensive coverage
  static const double defaultSimilarityThreshold = 0.05;
  static const int defaultMaxOutputTokens = 4096; // Scaled up from 256 for rich responses
  static const int defaultMaxPromptChars = 64000; // ~16,000 tokens
  static const int defaultMaxChunkChars = 2500;

  // Model filenames and targets (legacy)
  static const String llmModelFileName = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const String embeddingModelFileName = 'bge-small-en-v1.5.bin';

  // Supported Mime Types
  static const List<String> supportedExtensions = ['pdf', 'txt'];

  // Gemini AI Settings — Updated to Gemini 3.x series (September 2026)
  static const String defaultGeminiModel = 'gemini-3.8-flash';

  /// Ordered fallback chain: primary -> reliable fallback -> last resort
  static const List<String> fallbackModelChain = [
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
  ];

  static const List<String> availableGeminiModels = [
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
  ];

  // Optional: Place your API key here to preconfigure without typing in UI
  static const String defaultGeminiApiKey = '';

  // SharedPreferences Keys
  static const String prefGeminiApiKey = 'gemini_api_key';
  static const String prefGeminiModel = 'gemini_model';
}

