import 'dart:math';
import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';

class RetrievedChunk {
  final int chunkId;
  final int documentId;
  final String fileName;
  final int pageNumber;
  final String text;
  final double score;

  const RetrievedChunk({
    required this.chunkId,
    required this.documentId,
    required this.fileName,
    required this.pageNumber,
    required this.text,
    required this.score,
  });
}

class RagService {
  /// Stopwords list to enhance keyword matching relevance
  static const Set<String> _stopwords = {
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'for', 'from',
    'has', 'he', 'in', 'is', 'it', 'its', 'of', 'on', 'that', 'the',
    'to', 'was', 'were', 'will', 'with', 'what', 'where', 'when', 'who',
    'how', 'why', 'can', 'could', 'should', 'would', 'do', 'does', 'did'
  };

  /// Tokenizes text into normalized query terms
  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !_stopwords.contains(t))
        .toList();
  }

  /// Retrieves relevant chunks strictly for the given [chatbotId], scaled for Gemini context
  Future<List<RetrievedChunk>> retrieveContext({
    required int chatbotId,
    required String query,
    int topK = AppConstants.defaultTopK,
    double minScore = AppConstants.defaultSimilarityThreshold,
  }) async {
    final queryTokens = _tokenize(query);
    if (queryTokens.isEmpty) return [];

    final db = await AppDatabase.instance;

    // Strict multi-chatbot isolation: JOIN with documents WHERE chunks.chatbot_id = ?
    final results = await db.rawQuery('''
      SELECT 
        c.id as chunk_id,
        c.document_id,
        c.text,
        c.page_number,
        d.file_name
      FROM chunks c
      JOIN documents d ON c.document_id = d.id
      WHERE c.chatbot_id = ?
    ''', [chatbotId]);

    if (results.isEmpty) return [];

    final scoredChunks = <RetrievedChunk>[];

    for (final row in results) {
      final chunkText = row['text'] as String;
      final chunkLower = chunkText.toLowerCase();

      // Multi-term frequency & coverage scoring
      double termMatches = 0;
      double exactPhraseBonus = 0;

      if (chunkLower.contains(query.toLowerCase().trim())) {
        exactPhraseBonus = 2.0; // High bonus for exact phrase match
      }

      for (final token in queryTokens) {
        if (chunkLower.contains(token)) {
          // Count occurrences
          final matches = RegExp(r'\b' + RegExp.escape(token) + r'\b').allMatches(chunkLower).length;
          termMatches += (matches > 0 ? 1.0 + log(matches.toDouble() + 1) : 0.5);
        }
      }

      // Coverage ratio: what fraction of query terms were found
      final coverage = termMatches / queryTokens.length;
      final totalScore = coverage + exactPhraseBonus;

      if (totalScore >= minScore) {
        scoredChunks.add(
          RetrievedChunk(
            chunkId: row['chunk_id'] as int,
            documentId: row['document_id'] as int,
            fileName: row['file_name'] as String,
            pageNumber: row['page_number'] as int,
            text: chunkText,
            score: totalScore,
          ),
        );
      }
    }

    // Sort by score descending
    scoredChunks.sort((a, b) => b.score.compareTo(a.score));

    return scoredChunks.take(topK).toList();
  }

  /// Builds a clean system instruction for Gemini specifying persona and grounding rules
  String buildSystemInstruction({
    required String chatbotName,
    required String chatbotDescription,
  }) {
    final buffer = StringBuffer();
    buffer.write('You are "$chatbotName".');
    if (chatbotDescription.isNotEmpty) {
      buffer.write(' $chatbotDescription.');
    }
    buffer.writeln();
    buffer.writeln(
      'You are an intelligent, articulate AI assistant powered by Google Gemini. '
      'When reference documents are provided, answer comprehensively and accurately based on them. '
      'Format your output using clear Markdown (e.g. bold headings, bullet points, clean tables, and code snippets when appropriate). '
      'Always cite the document name and page number for facts and quotes. '
      'If the answer is not contained in the provided reference documents, politely explain that '
      'the information is not available in the uploaded documents.',
    );
    return buffer.toString().trim();
  }

  /// Builds a grounded user prompt for Gemini with retrieved document excerpts & multi-turn history
  String buildUserPrompt({
    required String userQuery,
    required List<RetrievedChunk> contextChunks,
    List<Map<String, String>> conversationHistory = const [],
    int maxChunkChars = AppConstants.defaultMaxChunkChars,
  }) {
    final buffer = StringBuffer();

    // 1. Context Documents (scaled for large context)
    if (contextChunks.isNotEmpty) {
      buffer.writeln('=== REFERENCE DOCUMENTS ===');
      for (final c in contextChunks) {
        String excerpt = c.text.trim();
        if (excerpt.length > maxChunkChars) {
          excerpt = '${excerpt.substring(0, maxChunkChars)}...';
        }
        buffer.writeln('Document: ${c.fileName} (Page ${c.pageNumber})');
        buffer.writeln(excerpt);
        buffer.writeln('---');
      }
      buffer.writeln('===========================');
      buffer.writeln();
    }

    // 2. Multi-turn conversation context
    if (conversationHistory.isNotEmpty) {
      buffer.writeln('=== PREVIOUS CONVERSATION CONTEXT ===');
      for (final turn in conversationHistory) {
        final role = turn['role'] == 'user' ? 'User' : 'Assistant';
        final content = turn['content'] ?? '';
        buffer.writeln('$role: $content');
      }
      buffer.writeln('=====================================');
      buffer.writeln();
    }

    if (contextChunks.isNotEmpty) {
      buffer.writeln('Based on the reference documents and conversation context above, please answer the user query:');
    }

    buffer.writeln(userQuery);
    return buffer.toString();
  }

  /// Builds a combined prompt for Gemini (including system guidelines, history, and context)
  String buildPrompt({
    required String chatbotName,
    required String chatbotDescription,
    required String userQuery,
    required List<RetrievedChunk> contextChunks,
    List<Map<String, String>> conversationHistory = const [],
    int maxPromptChars = AppConstants.defaultMaxPromptChars,
    int maxChunkChars = AppConstants.defaultMaxChunkChars,
  }) {
    final sys = buildSystemInstruction(
      chatbotName: chatbotName,
      chatbotDescription: chatbotDescription,
    );
    final user = buildUserPrompt(
      userQuery: userQuery,
      contextChunks: contextChunks,
      conversationHistory: conversationHistory,
      maxChunkChars: maxChunkChars,
    );

    return '$sys\n\n$user';
  }
}


