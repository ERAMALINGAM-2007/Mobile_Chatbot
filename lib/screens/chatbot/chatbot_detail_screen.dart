import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_theme.dart';
import '../../models/chatbot.dart';
import '../../models/document.dart';
import '../../models/conversation.dart';
import '../../services/providers.dart';
import '../../services/documents/ingestion_service.dart';
import '../chat/chat_screen.dart';

// Providers for this specific chatbot
final chatbotDetailProvider = FutureProvider.family<Chatbot?, int>((ref, chatbotId) async {
  final repo = ref.read(chatbotRepositoryProvider);
  return await repo.getChatbotById(chatbotId);
});

final chatbotDocumentsProvider = FutureProvider.family<List<DocumentModel>, int>((ref, chatbotId) async {
  final repo = ref.read(documentRepositoryProvider);
  return await repo.getDocumentsForChatbot(chatbotId);
});

final chatbotConversationsProvider = FutureProvider.family<List<ConversationModel>, int>((ref, chatbotId) async {
  final repo = ref.read(conversationRepositoryProvider);
  return await repo.getConversationsForChatbot(chatbotId);
});

class ChatbotDetailScreen extends ConsumerStatefulWidget {
  final int chatbotId;

  const ChatbotDetailScreen({super.key, required this.chatbotId});

  @override
  ConsumerState<ChatbotDetailScreen> createState() => _ChatbotDetailScreenState();
}

class _ChatbotDetailScreenState extends ConsumerState<ChatbotDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatbotAsync = ref.watch(chatbotDetailProvider(widget.chatbotId));

    return chatbotAsync.when(
      data: (bot) {
        if (bot == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Chatbot not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bot.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (bot.description.isNotEmpty)
                  Text(
                    bot.description,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                  ),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.textPrimaryDark,
              unselectedLabelColor: AppTheme.textSecondaryDark,
              tabs: const [
                Tab(icon: Icon(Icons.description_outlined), text: 'Documents'),
                Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Conversations'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildDocumentsTab(context),
              _buildConversationsTab(context, bot),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildDocumentsTab(BuildContext context) {
    final docsAsync = ref.watch(chatbotDocumentsProvider(widget.chatbotId));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Knowledge Base', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _pickAndIngestDocument(context),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Add Document'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: docsAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_outlined, size: 56, color: AppTheme.textSecondaryDark.withAlpha(102)),
                        const SizedBox(height: 12),
                        const Text('No documents added to this chatbot yet', style: TextStyle(color: AppTheme.textSecondaryDark)),
                        const SizedBox(height: 4),
                        const Text('Supported: PDF, TXT', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final doc = docs[idx];
                    final isPdf = doc.fileName.toLowerCase().endsWith('.pdf');
                    return Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isPdf ? Colors.red.withAlpha(30) : Colors.blue.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf : Icons.description,
                            color: isPdf ? Colors.redAccent : Colors.lightBlueAccent,
                            size: 22,
                          ),
                        ),
                        title: Text(doc.fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${doc.pageCount} page(s) • ${(doc.fileSize / 1024).toStringAsFixed(1)} KB • ${doc.status}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteDocument(doc.id!),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading documents: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsTab(BuildContext context, Chatbot bot) {
    final convsAsync = ref.watch(chatbotConversationsProvider(widget.chatbotId));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Chat History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _createConversationDialog(context),
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                label: const Text('New Chat'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: convsAsync.when(
              data: (convs) {
                if (convs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 56, color: AppTheme.textSecondaryDark.withAlpha(102)),
                        const SizedBox(height: 12),
                        const Text('No conversations started yet', style: TextStyle(color: AppTheme.textSecondaryDark)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: convs.length,
                  itemBuilder: (ctx, idx) {
                    final conv = convs[idx];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.chat_bubble_outline, color: AppTheme.accentColor),
                        title: Text(conv.title),
                        subtitle: Text(DateTime.fromMillisecondsSinceEpoch(conv.updatedAt).toString().split('.').first),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatbot: bot,
                                conversation: conv,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading conversations: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndIngestDocument(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (files.isEmpty || files.first.path == null) {
        return;
      }

      final file = files.first;
      if (!context.mounted) return;

      _showIngestionModal(context, file.path!, file.name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection error: $e')),
        );
      }
    }
  }

  void _showIngestionModal(BuildContext context, String filePath, String fileName) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        final ingestionService = ref.read(ingestionServiceProvider);
        final stream = ingestionService.ingestDocument(
          chatbotId: widget.chatbotId,
          sourceFilePath: filePath,
          fileName: fileName,
        );

        return StreamBuilder<IngestionProgress>(
          stream: stream,
          builder: (context, snapshot) {
            final progress = snapshot.data;
            final isDone = progress?.step == IngestionStep.completed;
            final isError = progress?.step == IngestionStep.error;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isError ? Colors.red.withAlpha(40) : AppTheme.primaryColor.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isError ? Icons.error_outline : Icons.auto_stories,
                          color: isError ? Colors.redAccent : AppTheme.accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isDone
                              ? 'Ingestion Complete'
                              : isError
                                  ? 'Ingestion Failed'
                                  : 'Ingesting Document...',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fileName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryDark),
                  ),
                  const SizedBox(height: 16),
                  _buildStepRow('1. Reading file & storing locally', progress?.step.index ?? 0, 0),
                  _buildStepRow('2. Extracting text & identifying pages', progress?.step.index ?? 0, 1),
                  _buildStepRow('3. Creating sentence/paragraph chunks', progress?.step.index ?? 0, 2),
                  _buildStepRow('4. Generating vectors', progress?.step.index ?? 0, 3),
                  _buildStepRow('5. Saving database', progress?.step.index ?? 0, 4),
                  const SizedBox(height: 20),
                  if (progress?.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withAlpha(60)),
                      ),
                      child: Text(
                        progress!.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    )
                  else if (progress?.message != null)
                    Text(
                      progress!.message,
                      style: const TextStyle(fontSize: 13, color: AppTheme.accentColor),
                    ),
                  const SizedBox(height: 20),
                  if (isDone || isError)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(modalCtx).pop();
                        },
                        child: Text(isDone ? 'Done' : 'Close'),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      ref.invalidate(chatbotDocumentsProvider(widget.chatbotId));
      ref.read(chatbotsProvider.notifier).refresh();
    });
  }

  Widget _buildStepRow(String title, int currentStepIndex, int thisStepIndex) {
    Widget icon;
    Color textColor;

    if (currentStepIndex > thisStepIndex) {
      icon = const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18);
      textColor = AppTheme.textPrimaryDark;
    } else if (currentStepIndex == thisStepIndex) {
      icon = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor),
      );
      textColor = AppTheme.accentColor;
    } else {
      icon = const Icon(Icons.radio_button_unchecked, color: AppTheme.textSecondaryDark, size: 18);
      textColor = AppTheme.textSecondaryDark;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 13, color: textColor)),
        ],
      ),
    );
  }

  Future<void> _deleteDocument(int docId) async {
    final repo = ref.read(documentRepositoryProvider);
    await repo.deleteDocument(docId);
    ref.invalidate(chatbotDocumentsProvider(widget.chatbotId));
    ref.read(chatbotsProvider.notifier).refresh();
  }

  void _createConversationDialog(BuildContext context) {
    final titleController = TextEditingController(text: 'New Conversation');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Conversation'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx);
              final repo = ref.read(conversationRepositoryProvider);
              final newConv = await repo.createConversation(widget.chatbotId, title);
              ref.invalidate(chatbotConversationsProvider(widget.chatbotId));
              ref.read(chatbotsProvider.notifier).refresh();
              final bot = await ref.read(chatbotRepositoryProvider).getChatbotById(widget.chatbotId);
              if (bot != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(chatbot: bot, conversation: newConv),
                  ),
                );
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
