import 'dart:io';
import '../../core/storage/storage_service.dart';
import '../../models/document.dart';
import '../../repositories/document_repository.dart';
import 'document_processor.dart';
import 'chunking_service.dart';

enum IngestionStep {
  readingFile,
  extractingText,
  creatingChunks,
  generatingVectors,
  savingDatabase,
  completed,
  error,
}

class IngestionProgress {
  final IngestionStep step;
  final String message;
  final double? progress;
  final String? errorMessage;

  const IngestionProgress({
    required this.step,
    required this.message,
    this.progress,
    this.errorMessage,
  });
}

class IngestionService {
  final DocumentRepository documentRepository;
  final DocumentProcessor documentProcessor;
  final ChunkingService chunkingService;

  IngestionService({
    required this.documentRepository,
    DocumentProcessor? processor,
    ChunkingService? chunker,
  })  : documentProcessor = processor ?? DocumentProcessor(),
        chunkingService = chunker ?? const ChunkingService();

  Stream<IngestionProgress> ingestDocument({
    required int chatbotId,
    required String sourceFilePath,
    required String fileName,
  }) async* {
    try {
      // 1. Reading file and storing locally in app-private storage
      yield const IngestionProgress(
        step: IngestionStep.readingFile,
        message: 'Copying file to isolated chatbot storage...',
      );

      final sourceFile = File(sourceFilePath);
      final fileSize = await sourceFile.length();
      final copiedFile = await StorageService.copyDocumentToChatbotStorage(
        chatbotId: chatbotId,
        sourcePath: sourceFilePath,
        fileName: fileName,
      );

      // 2. Extracting text per page
      yield const IngestionProgress(
        step: IngestionStep.extractingText,
        message: 'Extracting text and identifying pages...',
      );

      final extractedDoc = await documentProcessor.extractText(
        filePath: copiedFile.path,
        fileName: fileName,
      );

      // 3. Creating structured chunks
      yield const IngestionProgress(
        step: IngestionStep.creatingChunks,
        message: 'Creating semantic sentence/paragraph chunks...',
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      final docModel = await documentRepository.insertDocument(
        DocumentModel(
          chatbotId: chatbotId,
          fileName: fileName,
          filePath: copiedFile.path,
          mimeType: fileName.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'text/plain',
          fileSize: fileSize,
          pageCount: extractedDoc.totalPages,
          status: 'processing',
          createdAt: now,
        ),
      );

      final chunks = chunkingService.chunkDocument(
        documentId: docModel.id!,
        chatbotId: chatbotId,
        document: extractedDoc,
      );

      // 4. Generating Vectors (Will be connected in Milestone 8 & 9)
      yield IngestionProgress(
        step: IngestionStep.generatingVectors,
        message: 'Ready for embedding vector index (${chunks.length} chunks generated)...',
      );

      // 5. Saving database
      yield const IngestionProgress(
        step: IngestionStep.savingDatabase,
        message: 'Saving chunks into SQLite database...',
      );

      // Store chunks (embeddings will be populated in Milestone 8/9)
      await documentRepository.insertChunksAndEmbeddings(
        chunks: chunks,
        embeddings: [],
      );

      await documentRepository.updateDocumentStatus(
        docModel.id!,
        'completed',
        pageCount: extractedDoc.totalPages,
      );

      yield IngestionProgress(
        step: IngestionStep.completed,
        message: 'Document successfully ingested! Generated ${chunks.length} chunks across ${extractedDoc.totalPages} page(s).',
      );
    } catch (e) {
      yield IngestionProgress(
        step: IngestionStep.error,
        message: 'Ingestion failed',
        errorMessage: e.toString().replaceFirst('AppError: ', '').replaceFirst('IngestionError: ', ''),
      );
    }
  }
}
