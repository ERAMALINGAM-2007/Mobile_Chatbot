import '../core/database/app_database.dart';
import '../models/message.dart';

class MessageRepository {
  Future<List<MessageModel>> getMessagesForConversation(int conversationId) async {
    final db = await AppDatabase.instance;
    final results = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return results.map((m) => MessageModel.fromMap(m)).toList();
  }

  Future<MessageModel> addMessage(MessageModel message) async {
    final db = await AppDatabase.instance;
    final id = await db.insert('messages', message.toMap());

    // Update parent conversation updated_at timestamp
    await db.update(
      'conversations',
      {'updated_at': message.createdAt},
      where: 'id = ?',
      whereArgs: [message.conversationId],
    );

    return message.copyWith(id: id);
  }

  Future<int> deleteMessage(int messageId) async {
    final db = await AppDatabase.instance;
    return await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }
}
