import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/chatbot_repository.dart';
import '../repositories/document_repository.dart';
import '../repositories/conversation_repository.dart';
import '../repositories/message_repository.dart';
import '../models/chatbot.dart';
import 'documents/ingestion_service.dart';
import 'rag/rag_service.dart';

// Repository Providers
final chatbotRepositoryProvider = Provider<ChatbotRepository>((ref) {
  return ChatbotRepository();
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository();
});

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository();
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository();
});

final ingestionServiceProvider = Provider<IngestionService>((ref) {
  return IngestionService(
    documentRepository: ref.read(documentRepositoryProvider),
  );
});

final ragServiceProvider = Provider<RagService>((ref) {
  return RagService();
});

// Chatbots List State Notifier
class ChatbotsNotifier extends AsyncNotifier<List<Chatbot>> {
  @override
  Future<List<Chatbot>> build() async {
    final repo = ref.read(chatbotRepositoryProvider);
    return await repo.getAllChatbots();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(chatbotRepositoryProvider);
      return await repo.getAllChatbots();
    });
  }

  Future<Chatbot> createChatbot(String name, String description) async {
    final repo = ref.read(chatbotRepositoryProvider);
    final newChatbot = await repo.createChatbot(name, description);
    await refresh();
    return newChatbot;
  }

  Future<void> updateChatbot(int id, String name, String description) async {
    final repo = ref.read(chatbotRepositoryProvider);
    await repo.updateChatbot(id, name, description);
    await refresh();
  }

  Future<void> deleteChatbot(int id) async {
    final repo = ref.read(chatbotRepositoryProvider);
    await repo.deleteChatbot(id);
    await refresh();
  }
}

final chatbotsProvider = AsyncNotifierProvider<ChatbotsNotifier, List<Chatbot>>(() {
  return ChatbotsNotifier();
});
