import '../core/database/app_database.dart';
import '../models/conversation.dart';

class ConversationRepository {
  Future<List<ConversationModel>> getConversationsForChatbot(int chatbotId) async {
    final db = await AppDatabase.instance;
    final results = await db.query(
      'conversations',
      where: 'chatbot_id = ?',
      whereArgs: [chatbotId],
      orderBy: 'updated_at DESC',
    );
    return results.map((m) => ConversationModel.fromMap(m)).toList();
  }

  Future<ConversationModel> createConversation(int chatbotId, String title) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('conversations', {
      'chatbot_id': chatbotId,
      'title': title,
      'created_at': now,
      'updated_at': now,
    });

    return ConversationModel(
      id: id,
      chatbotId: chatbotId,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<int> updateConversationTitle(int conversationId, String newTitle) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      'conversations',
      {
        'title': newTitle,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<int> touchConversation(int conversationId) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      'conversations',
      {'updated_at': now},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<int> deleteConversation(int conversationId) async {
    final db = await AppDatabase.instance;
    return await db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }
}
