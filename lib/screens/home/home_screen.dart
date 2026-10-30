import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_theme.dart';
import '../../models/chatbot.dart';
import '../../services/providers.dart';
import '../chatbot/chatbot_detail_screen.dart';
import '../settings/model_manager_screen.dart';
import '../../services/llm_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatbotsAsync = ref.watch(chatbotsProvider);
    final llmState = ref.watch(llmNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('LocalRAG'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Gemini Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!llmState.isConfigured) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amberAccent.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key_outlined, color: Colors.amberAccent, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gemini API Key Required',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Configure your API key in Settings to activate AI responses.',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
                          );
                        },
                        child: const Text('Setup', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
              const Text(
                'Your Chatbots',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Each chatbot has an isolated knowledge base and conversations.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryDark),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: chatbotsAsync.when(
                  data: (chatbots) {
                    if (chatbots.isEmpty) {
                      return _buildEmptyState(context, ref);
                    }
                    return RefreshIndicator(
                      onRefresh: () => ref.read(chatbotsProvider.notifier).refresh(),
                      child: ListView.separated(
                        itemCount: chatbots.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final bot = chatbots[index];
                          return _buildChatbotCard(context, ref, bot);
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text('Error loading chatbots: $err', style: const TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateChatbotDialog(context, ref),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Chatbot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy_outlined, size: 64, color: AppTheme.textSecondaryDark.withAlpha(128)),
          const SizedBox(height: 16),
          const Text(
            'No Chatbots Created Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Create your first local chatbot to isolate documents and run RAG offline.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryDark),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateChatbotDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create First Chatbot'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatbotCard(BuildContext context, WidgetRef ref, Chatbot bot) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatbotDetailScreen(chatbotId: bot.id!),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withAlpha(38),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_stories_outlined, color: AppTheme.accentColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bot.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryDark,
                          ),
                        ),
                        if (bot.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            bot.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppTheme.textSecondaryDark),
                    onSelected: (action) {
                      if (action == 'delete') {
                        _confirmDeleteChatbot(context, ref, bot);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFF334155)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatBadge(Icons.description_outlined, '${bot.documentCount} documents'),
                  const SizedBox(width: 16),
                  _buildStatBadge(Icons.chat_bubble_outline, '${bot.conversationCount} conversations'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondaryDark),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark),
        ),
      ],
    );
  }

  void _showCreateChatbotDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Create Chatbot', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. GATE Preparation',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. Computer Networks & OS notes',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryDark)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                if (name.isEmpty) return;

                Navigator.of(dialogCtx).pop();
                await ref.read(chatbotsProvider.notifier).createChatbot(name, desc);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Chatbot "$name" created successfully.')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteChatbot(BuildContext context, WidgetRef ref, Chatbot bot) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Chatbot?'),
        content: Text('Are you sure you want to delete "${bot.name}" and all its documents and conversations?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref.read(chatbotsProvider.notifier).deleteChatbot(bot.id!);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
