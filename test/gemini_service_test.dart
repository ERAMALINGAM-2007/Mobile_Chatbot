import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_rag/services/llm/gemini_service.dart';
import 'package:local_rag/services/rag/rag_service.dart';
import 'package:local_rag/core/constants/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gemini RAG Prompt Formatting Tests', () {
    final ragService = RagService();

    test('buildSystemInstruction generates proper assistant persona and grounding rules', () {
      final sys = ragService.buildSystemInstruction(
        chatbotName: 'GATE Exam Tutor',
        chatbotDescription: 'Assists with computer science GATE preparation',
      );

      expect(sys, contains('You are "GATE Exam Tutor"'));
      expect(sys, contains('Assists with computer science GATE preparation'));
      expect(sys, contains('cite the document name and page number'));
    });

    test('buildUserPrompt formats reference documents and multi-turn conversation context', () {
      final chunks = [
        const RetrievedChunk(
          chunkId: 1,
          documentId: 10,
          fileName: 'Algorithms.pdf',
          pageNumber: 3,
          text: 'Dijkstra algorithm has time complexity O(E + V log V).',
          score: 1.5,
        ),
      ];

      final history = [
        {'role': 'user', 'content': 'What graph algorithms are covered?'},
        {'role': 'assistant', 'content': 'Graph algorithms include BFS, DFS, and Dijkstra.'},
      ];

      final prompt = ragService.buildUserPrompt(
        userQuery: 'What is Dijkstra time complexity?',
        contextChunks: chunks,
        conversationHistory: history,
      );

      expect(prompt, contains('=== REFERENCE DOCUMENTS ==='));
      expect(prompt, contains('Document: Algorithms.pdf (Page 3)'));
      expect(prompt, contains('Dijkstra algorithm has time complexity'));
      expect(prompt, contains('=== PREVIOUS CONVERSATION CONTEXT ==='));
      expect(prompt, contains('User: What graph algorithms are covered?'));
      expect(prompt, contains('Assistant: Graph algorithms include BFS, DFS, and Dijkstra.'));
      expect(prompt, contains('What is Dijkstra time complexity?'));
    });
  });

  group('GeminiService Initialization & State Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'gemini_api_key': 'AIzaSyFakeKeyForTest_12345',
        'gemini_model': AppConstants.defaultGeminiModel,
      });
    });

    test('GeminiService defaults to gemini-1.5-flash and handles model changes', () async {
      final service = GeminiService();
      await service.initialize();

      expect(service.isConfigured, isTrue);
      expect(service.apiKey, equals('AIzaSyFakeKeyForTest_12345'));
      expect(service.modelName, equals('gemini-1.5-flash'));

      await service.setModel('gemini-2.0-flash');
      expect(service.modelName, equals('gemini-2.0-flash'));

      await service.setApiKey('');
      expect(service.isConfigured, isFalse);

      service.dispose();
    });

    test('GeminiService automatically migrates obsolete model names', () async {
      SharedPreferences.setMockInitialValues({
        'gemini_api_key': 'AIzaSyFakeKeyForTest_12345',
        'gemini_model': 'gemini-2.5-flash',
      });

      final service = GeminiService();
      await service.initialize();

      expect(service.modelName, equals('gemini-1.5-flash'));
      service.dispose();
    });
  });
}

