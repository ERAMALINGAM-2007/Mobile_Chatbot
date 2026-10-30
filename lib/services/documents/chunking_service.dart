import '../../core/constants/app_constants.dart';
import '../../models/chunk.dart';
import 'document_processor.dart';

class ChunkingService {
  final int chunkSize;
  final int chunkOverlap;

  const ChunkingService({
    this.chunkSize = AppConstants.defaultChunkSize,
    this.chunkOverlap = AppConstants.defaultChunkOverlap,
  });

  /// Chunks an extracted document into structured ChunkModel instances
  List<ChunkModel> chunkDocument({
    required int documentId,
    required int chatbotId,
    required ExtractedDocument document,
  }) {
    final List<ChunkModel> allChunks = [];
    int globalChunkIndex = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final page in document.pages) {
      final pageChunks = _chunkPageText(
        text: page.text,
        pageNumber: page.pageNumber,
        documentId: documentId,
        chatbotId: chatbotId,
        sourceFileName: document.fileName,
        startIndex: globalChunkIndex,
        createdAt: now,
      );

      allChunks.addAll(pageChunks);
      globalChunkIndex += pageChunks.length;
    }

    return allChunks;
  }

  List<ChunkModel> _chunkPageText({
    required String text,
    required int pageNumber,
    required int documentId,
    required int chatbotId,
    required String sourceFileName,
    required int startIndex,
    required int createdAt,
  }) {
    if (text.isEmpty) return [];

    final List<ChunkModel> chunks = [];
    int currentIndex = startIndex;

    // Split text into paragraphs first
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final List<String> segments = [];

    for (final p in paragraphs) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.length <= chunkSize) {
        segments.add(trimmed);
      } else {
        // Break large paragraphs by sentences
        final sentences = _splitIntoSentences(trimmed);
        segments.addAll(sentences);
      }
    }

    String currentBuffer = '';

    for (final segment in segments) {
      if (currentBuffer.isEmpty) {
        currentBuffer = segment;
      } else if (currentBuffer.length + segment.length + 1 <= chunkSize) {
        currentBuffer = '$currentBuffer $segment';
      } else {
        // Current buffer is full, emit chunk
        chunks.add(ChunkModel(
          documentId: documentId,
          chatbotId: chatbotId,
          chunkIndex: currentIndex++,
          text: currentBuffer.trim(),
          pageNumber: pageNumber,
          createdAt: createdAt,
          sourceFileName: sourceFileName,
        ));

        // Create overlap from the end of currentBuffer
        final overlapText = _extractOverlap(currentBuffer, chunkOverlap);
        currentBuffer = overlapText.isNotEmpty ? '$overlapText $segment' : segment;
      }
    }

    if (currentBuffer.trim().isNotEmpty) {
      chunks.add(ChunkModel(
        documentId: documentId,
        chatbotId: chatbotId,
        chunkIndex: currentIndex++,
        text: currentBuffer.trim(),
        pageNumber: pageNumber,
        createdAt: createdAt,
        sourceFileName: sourceFileName,
      ));
    }

    return chunks;
  }

  List<String> _splitIntoSentences(String text) {
    // Regex for sentence boundaries (period, exclamation, question mark followed by space or end)
    final sentencePattern = RegExp(r'(?<=[.!?])\s+');
    final rawSentences = text.split(sentencePattern);
    final List<String> result = [];

    for (final s in rawSentences) {
      final trimmed = s.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.length > chunkSize) {
        // Fallback for extremely long run-on text with no punctuation: split by words
        final words = trimmed.split(RegExp(r'\s+'));
        String wordBuffer = '';
        for (final w in words) {
          if (wordBuffer.length + w.length + 1 <= chunkSize) {
            wordBuffer = wordBuffer.isEmpty ? w : '$wordBuffer $w';
          } else {
            if (wordBuffer.isNotEmpty) result.add(wordBuffer);
            wordBuffer = w;
          }
        }
        if (wordBuffer.isNotEmpty) result.add(wordBuffer);
      } else {
        result.add(trimmed);
      }
    }

    return result;
  }

  String _extractOverlap(String text, int overlapSize) {
    if (overlapSize <= 0 || text.length <= overlapSize) return '';
    final rawOverlap = text.substring(text.length - overlapSize);
    // Find first whitespace to avoid breaking a word in half
    final firstSpace = rawOverlap.indexOf(' ');
    if (firstSpace != -1 && firstSpace < rawOverlap.length - 1) {
      return rawOverlap.substring(firstSpace + 1).trim();
    }
    return rawOverlap.trim();
  }
}
