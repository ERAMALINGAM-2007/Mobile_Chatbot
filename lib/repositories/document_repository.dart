import 'dart:typed_data';
import '../core/database/app_database.dart';
import '../models/document.dart';
import '../models/chunk.dart';

class DocumentRepository {
  Future<List<DocumentModel>> getDocumentsForChatbot(int chatbotId) async {
    final db = await AppDatabase.instance;
    final results = await db.query(
      'documents',
      where: 'chatbot_id = ?',
      whereArgs: [chatbotId],
      orderBy: 'created_at DESC',
    );
    return results.map((m) => DocumentModel.fromMap(m)).toList();
  }

  Future<DocumentModel> insertDocument(DocumentModel doc) async {
    final db = await AppDatabase.instance;
    final id = await db.insert('documents', doc.toMap());
    return doc.copyWith(id: id);
  }

  Future<int> updateDocumentStatus(int documentId, String status, {int? pageCount}) async {
    final db = await AppDatabase.instance;
    final updateData = <String, dynamic>{'status': status};
    if (pageCount != null) {
      updateData['page_count'] = pageCount;
    }
    return await db.update(
      'documents',
      updateData,
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  Future<int> deleteDocument(int documentId) async {
    final db = await AppDatabase.instance;
    return await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  Future<void> insertChunksAndEmbeddings({
    required List<ChunkModel> chunks,
    required List<List<double>> embeddings,
  }) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final chunkId = await txn.insert('chunks', chunk.toMap());

        if (i < embeddings.length) {
          final embeddingList = embeddings[i];
          final byteData = Float32List.fromList(embeddingList).buffer.asUint8List();
          await txn.insert('embeddings', {
            'chunk_id': chunkId,
            'chatbot_id': chunk.chatbotId,
            'embedding': byteData,
          });
        }
      }
    });
  }

  Future<List<ChunkModel>> getChunksForDocument(int documentId) async {
    final db = await AppDatabase.instance;
    final results = await db.query(
      'chunks',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'chunk_index ASC',
    );
    return results.map((m) => ChunkModel.fromMap(m)).toList();
  }

  Future<int> getChunkCountForChatbot(int chatbotId) async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chunks WHERE chatbot_id = ?',
      [chatbotId],
    );
    return (result.first['count'] as int?) ?? 0;
  }
}
