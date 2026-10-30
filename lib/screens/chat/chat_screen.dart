import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../core/constants/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../models/chatbot.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../services/providers.dart';
import '../../services/llm_providers.dart';
import '../../services/rag/rag_service.dart';
import '../settings/model_manager_screen.dart';

// Provider for messages in this conversation
final conversationMessagesProvider = FutureProvider.family<List<MessageModel>, int>((ref, convId) async {
  final repo = ref.read(messageRepositoryProvider);
  return await repo.getMessagesForConversation(convId);
});

class ChatScreen extends ConsumerStatefulWidget {
  final Chatbot chatbot;
  final ConversationModel conversation;

  const ChatScreen({
    super.key,
    required this.chatbot,
    required this.conversation,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<RetrievedChunk> _currentQuerySources = [];
  bool _isRetrievingContext = false;

  @override
  void initState() {
    super.initState();
    // Eagerly trigger Gemini config check in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(llmNotifierProvider.notifier).loadModelIfNeeded();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// High-performance scroll with drift detection to prevent UI jank during rapid streaming
  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final isNearBottom = _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 240;
        if (force || isNearBottom) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final llmState = ref.read(llmNotifierProvider);
    if (!llmState.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gemini API Key is required. Please configure it in Settings.'),
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.amberAccent,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
              );
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (llmState.status == LlmStatus.generating) {
      return;
    }

    _inputController.clear();
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Fetch recent conversation history to provide multi-turn conversational context
    final msgRepo = ref.read(messageRepositoryProvider);
    final priorMessages = await msgRepo.getMessagesForConversation(widget.conversation.id!);
    final recentTurns = priorMessages.length > 8
        ? priorMessages.sublist(priorMessages.length - 8)
        : priorMessages;
    final conversationHistory = recentTurns.map((m) => {
      'role': m.role,
      'content': m.content,
    }).toList();

    // 2. Save and display User message
    await msgRepo.addMessage(
      MessageModel(
        conversationId: widget.conversation.id!,
        role: 'user',
        content: text,
        createdAt: now,
      ),
    );
    ref.invalidate(conversationMessagesProvider(widget.conversation.id!));
    _scrollToBottom(force: true);

    // 3. RAG Context Retrieval (Scaled topK=8 for Gemini's large context)
    setState(() {
      _isRetrievingContext = true;
      _currentQuerySources = [];
    });

    List<RetrievedChunk> retrievedChunks = [];
    try {
      final rag = ref.read(ragServiceProvider);
      retrievedChunks = await rag.retrieveContext(
        chatbotId: widget.chatbot.id!,
        query: text,
        topK: AppConstants.defaultTopK,
      );
      setState(() {
        _currentQuerySources = retrievedChunks;
        _isRetrievingContext = false;
      });
    } catch (e) {
      setState(() {
        _isRetrievingContext = false;
      });
    }

    // 4. Prepare Gemini system instruction and grounded prompt with multi-turn history
    final rag = ref.read(ragServiceProvider);
    final systemInstruction = rag.buildSystemInstruction(
      chatbotName: widget.chatbot.name,
      chatbotDescription: widget.chatbot.description,
    );
    final prompt = rag.buildUserPrompt(
      userQuery: text,
      contextChunks: retrievedChunks,
      conversationHistory: conversationHistory,
      maxChunkChars: AppConstants.defaultMaxChunkChars,
    );

    // 5. Generate with streaming tokens (scaled 4096 output token budget)
    final llmNotifier = ref.read(llmNotifierProvider.notifier);
    try {
      _scrollToBottom(force: true);
      final fullResponse = await llmNotifier.generate(
        prompt: prompt,
        systemInstruction: systemInstruction,
        maxTokens: AppConstants.defaultMaxOutputTokens,
        temperature: 0.7,
      );

      // 6. Save Assistant response with citations
      final citations = retrievedChunks.map((c) {
        return MessageCitation(
          fileName: c.fileName,
          pageNumber: c.pageNumber,
          excerpt: c.text,
          score: c.score,
        );
      }).toList();

      await msgRepo.addMessage(
        MessageModel(
          conversationId: widget.conversation.id!,
          role: 'assistant',
          content: fullResponse.trim(),
          citations: citations,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      setState(() {
        _currentQuerySources = [];
      });

      ref.invalidate(conversationMessagesProvider(widget.conversation.id!));
      _scrollToBottom(force: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gemini Generation error: $e')),
        );
      }
    }
  }

  void _stopGeneration() {
    ref.read(llmNotifierProvider.notifier).stopGeneration();
  }



  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(conversationMessagesProvider(widget.conversation.id!));
    final llmState = ref.watch(llmNotifierProvider);

    // Auto-scroll when new streaming tokens arrive
    if (llmState.status == LlmStatus.generating) {
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.conversation.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Text(
                  widget.chatbot.name,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                ),
                const SizedBox(width: 8),
                _buildModelStatusBadge(llmState),
              ],
            ),
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
        child: Column(
          children: [
            // Error / setup banner if any
            if (llmState.error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.red.withAlpha(40),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        llmState.error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (!llmState.isConfigured) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
                          );
                        } else {
                          ref.read(llmNotifierProvider.notifier).loadModelIfNeeded();
                        }
                      },
                      child: Text(
                        !llmState.isConfigured ? 'Configure' : 'Retry',
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // Messages List
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (llmState.status == LlmStatus.generating || _isRetrievingContext ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Live streaming bubble at the end
                      if (index == messages.length) {
                        return _buildStreamingBubble(llmState);
                      }

                      final msg = messages[index];
                      return _buildMessageBubble(msg);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading messages: $err')),
              ),
            ),

            // Input Bar
            _buildInputBar(llmState),
          ],
        ),
      ),
    );
  }

  Widget _buildModelStatusBadge(LlmState state) {
    Color color;
    String label;

    if (!state.isConfigured) {
      color = Colors.amberAccent;
      label = 'API Key Needed';
    } else {
      switch (state.status) {
        case LlmStatus.ready:
          color = Colors.greenAccent;
          label = state.selectedModel;
          break;
        case LlmStatus.loading:
          color = Colors.orangeAccent;
          label = 'Connecting...';
          break;
        case LlmStatus.generating:
          color = AppTheme.accentColor;
          label = 'Gemini Generating...';
          break;
        case LlmStatus.error:
          color = Colors.redAccent;
          label = 'Gemini Error';
          break;
        case LlmStatus.notLoaded:
          color = Colors.amberAccent;
          label = 'API Key Needed';
          break;
      }
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(80), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildMessageBubble(MessageModel message) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.psychology, size: 16, color: AppTheme.accentColor),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser ? AppTheme.primaryColor : AppTheme.surfaceDark,
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.accentColor],
                          )
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser ? null : Border.all(color: Colors.white.withAlpha(15)),
                  ),
                  child: isUser
                      ? SelectableText(
                          message.content,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        )
                      : MarkdownBody(
                          data: message.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(fontSize: 14, color: AppTheme.textPrimaryDark, height: 1.5),
                            h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            em: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70),
                            listBullet: const TextStyle(color: AppTheme.accentColor, fontSize: 14),
                            code: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12.5,
                              backgroundColor: Color(0x33000000),
                              color: Colors.greenAccent,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: const Color(0xFF141724),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withAlpha(20)),
                            ),
                            blockquoteDecoration: BoxDecoration(
                              color: AppTheme.accentColor.withAlpha(15),
                              border: const Border(left: BorderSide(color: AppTheme.accentColor, width: 3)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),

          // Source citations section (Milestone 14 requirement)
          if (!isUser && message.citations.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: _buildCitationsCard(message.citations),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamingBubble(LlmState llmState) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: AppTheme.accentColor.withAlpha(60)),
                  ),
                  child: llmState.streamingResponse.isEmpty
                      ? Text(
                          _isRetrievingContext
                              ? 'Searching isolated knowledge base...'
                              : 'Synthesizing with ${ref.read(llmNotifierProvider).selectedModel}...',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondaryDark,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : MarkdownBody(
                          data: '${llmState.streamingResponse} ▌',
                          selectable: false,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(fontSize: 14, color: AppTheme.textPrimaryDark, height: 1.5),
                            code: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12.5,
                              color: Colors.greenAccent,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: const Color(0xFF141724),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),

          // Live sources preview
          if (_currentQuerySources.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: _buildCitationsCard(
                _currentQuerySources.map((c) {
                  return MessageCitation(
                    fileName: c.fileName,
                    pageNumber: c.pageNumber,
                    excerpt: c.text,
                    score: c.score,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCitationsCard(List<MessageCitation> citations) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      dense: true,
      initiallyExpanded: false,
      leading: const Icon(Icons.bookmark_added_outlined, size: 18, color: AppTheme.accentColor),
      title: Text(
        '${citations.length} Source Document(s) Cited',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
      ),
      children: citations.map((c) {
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withAlpha(10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 14, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${c.fileName} (Page ${c.pageNumber})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                    ),
                  ),
                  if (c.score != null)
                    Text(
                      'Match ${(c.score! * 100).toInt()}%',
                      style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                c.excerpt,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputBar(LlmState llmState) {
    final isGenerating = llmState.status == LlmStatus.generating;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: Colors.white.withAlpha(15))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ask a question from your documents...',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryDark),
                filled: true,
                fillColor: AppTheme.backgroundDark,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isGenerating)
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 32),
              tooltip: 'Stop Generation',
              onPressed: _stopGeneration,
            )
          else
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                tooltip: 'Send',
                onPressed: _sendMessage,
              ),
            ),
        ],
      ),
    );
  }
}
