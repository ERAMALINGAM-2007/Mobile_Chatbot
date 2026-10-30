import '../core/database/app_database.dart';
import '../models/chatbot.dart';

class ChatbotRepository {
  Future<List<Chatbot>> getAllChatbots() async {
    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        c.id, 
        c.name, 
        c.description, 
        c.created_at, 
        c.updated_at,
        COUNT(DISTINCT d.id) AS document_count,
        COUNT(DISTINCT conv.id) AS conversation_count
      FROM chatbots c
      LEFT JOIN documents d ON d.chatbot_id = c.id
      LEFT JOIN conversations conv ON conv.chatbot_id = c.id
      GROUP BY c.id
      ORDER BY c.updated_at DESC
    ''');

    return results.map((m) => Chatbot.fromMap(m)).toList();
  }

  Future<Chatbot?> getChatbotById(int id) async {
    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        c.id, 
        c.name, 
        c.description, 
        c.created_at, 
        c.updated_at,
        COUNT(DISTINCT d.id) AS document_count,
        COUNT(DISTINCT conv.id) AS conversation_count
      FROM chatbots c
      LEFT JOIN documents d ON d.chatbot_id = c.id
      LEFT JOIN conversations conv ON conv.chatbot_id = c.id
      WHERE c.id = ?
      GROUP BY c.id
    ''', [id]);

    if (results.isEmpty) return null;
    return Chatbot.fromMap(results.first);
  }

  Future<Chatbot> createChatbot(String name, String description) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('chatbots', {
      'name': name,
      'description': description,
      'created_at': now,
      'updated_at': now,
    });

    return Chatbot(
      id: id,
      name: name,
      description: description,
      createdAt: now,
      updatedAt: now,
      documentCount: 0,
      conversationCount: 0,
    );
  }

  Future<int> updateChatbot(int id, String name, String description) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      'chatbots',
      {
        'name': name,
        'description': description,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteChatbot(int id) async {
    final db = await AppDatabase.instance;
    // With PRAGMA foreign_keys = ON, deleting a chatbot automatically deletes
    // all documents, chunks, embeddings, conversations, and messages.
    return await db.delete(
      'chatbots',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
