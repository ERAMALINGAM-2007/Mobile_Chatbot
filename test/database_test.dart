import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:local_rag/core/database/app_database.dart';
import 'package:local_rag/repositories/chatbot_repository.dart';
import 'package:local_rag/repositories/document_repository.dart';
import 'package:local_rag/models/document.dart';
import 'package:local_rag/models/chunk.dart';

void main() {
  // Setup sqflite FFI for local host test execution
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await AppDatabase.close();
    final dbDir = await getDatabasesPath();
    final dbPath = '$dbDir/local_rag.db';
    await deleteDatabase(dbPath);
  });

  tearDown(() async {
    await AppDatabase.close();
  });

  test('Milestone 4: Chatbot creation, persistence across reopen, and isolation', () async {
    final chatbotRepo = ChatbotRepository();
    final docRepo = DocumentRepository();

    // 1. Create first chatbot
    final botA = await chatbotRepo.createChatbot(
      'GATE Preparation',
      'Computer Networks and OS notes',
    );
    expect(botA.id, isNotNull);
    expect(botA.name, equals('GATE Preparation'));

    // 2. Query all chatbots
    var allBots = await chatbotRepo.getAllChatbots();
    expect(allBots.length, equals(1));
    expect(allBots.first.name, equals('GATE Preparation'));

    // 3. Create second chatbot
    final botB = await chatbotRepo.createChatbot(
      'Java Learning',
      'Core Java and Spring Boot',
    );
    expect(botB.id, isNotNull);

    allBots = await chatbotRepo.getAllChatbots();
    expect(allBots.length, equals(2));

    // 4. Add isolated documents to each chatbot
    final now = DateTime.now().millisecondsSinceEpoch;
    final docA = await docRepo.insertDocument(DocumentModel(
      chatbotId: botA.id!,
      fileName: 'GATE_CN.pdf',
      filePath: '/dummy/GATE_CN.pdf',
      mimeType: 'application/pdf',
      fileSize: 1024,
      createdAt: now,
    ));

    await docRepo.insertDocument(DocumentModel(
      chatbotId: botB.id!,
      fileName: 'Java_OOP.pdf',
      filePath: '/dummy/Java_OOP.pdf',
      mimeType: 'application/pdf',
      fileSize: 2048,
      createdAt: now,
    ));

    // Add chunks to doc A
    await docRepo.insertChunksAndEmbeddings(
      chunks: [
        ChunkModel(
          documentId: docA.id!,
          chatbotId: botA.id!,
          chunkIndex: 0,
          text: 'TCP uses a three-way handshake.',
          pageNumber: 1,
          createdAt: now,
        ),
      ],
      embeddings: [
        [0.1, 0.2, 0.3],
      ],
    );

    // 5. Test strict Chatbot Isolation:
    // Documents for bot A should only contain GATE_CN.pdf
    final docsForA = await docRepo.getDocumentsForChatbot(botA.id!);
    expect(docsForA.length, equals(1));
    expect(docsForA.first.fileName, equals('GATE_CN.pdf'));

    // Documents for bot B should only contain Java_OOP.pdf
    final docsForB = await docRepo.getDocumentsForChatbot(botB.id!);
    expect(docsForB.length, equals(1));
    expect(docsForB.first.fileName, equals('Java_OOP.pdf'));

    // Chunks for bot A should be 1, for bot B should be 0
    final chunkCountA = await docRepo.getChunkCountForChatbot(botA.id!);
    final chunkCountB = await docRepo.getChunkCountForChatbot(botB.id!);
    expect(chunkCountA, equals(1));
    expect(chunkCountB, equals(0));

    // 6. Test App Reopen / Re-connection:
    // Close the database to simulate app close
    await AppDatabase.close();

    // Reopen database and assert data is still intact
    final reloadedBots = await chatbotRepo.getAllChatbots();
    expect(reloadedBots.length, equals(2));
    final reloadedBotA = reloadedBots.firstWhere((b) => b.id == botA.id);
    expect(reloadedBotA.name, equals('GATE Preparation'));
    expect(reloadedBotA.documentCount, equals(1));

    // 7. Test Cascade Delete:
    // Deleting bot A should delete docA and its chunks automatically
    await chatbotRepo.deleteChatbot(botA.id!);
    final remainingBots = await chatbotRepo.getAllChatbots();
    expect(remainingBots.length, equals(1));
    expect(remainingBots.first.id, equals(botB.id));

    final orphanedDocsA = await docRepo.getDocumentsForChatbot(botA.id!);
    expect(orphanedDocsA, isEmpty);
    final orphanedChunksA = await docRepo.getChunkCountForChatbot(botA.id!);
    expect(orphanedChunksA, equals(0));
  });
}
