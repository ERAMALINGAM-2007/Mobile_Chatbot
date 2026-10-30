import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_theme.dart';
import '../../services/llm_providers.dart';

class ModelManagerScreen extends ConsumerStatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  ConsumerState<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends ConsumerState<ModelManagerScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _isSaving = false;
  bool _isTesting = false;
  String _testPromptOutput = '';
  int? _lastLatencyMs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(llmNotifierProvider);
      if (state.apiKey.isNotEmpty) {
        _apiKeyController.text = state.apiKey;
      }
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Gemini API key.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final notifier = ref.read(llmNotifierProvider.notifier);
      await notifier.setApiKey(key);

      // Validate key with a quick ping
      final stopwatch = Stopwatch()..start();
      await notifier.testConnection(apiKey: key);
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _lastLatencyMs = stopwatch.elapsedMilliseconds;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text('Gemini API connected successfully! (${stopwatch.elapsedMilliseconds} ms)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: Text('Validation failed: $e'),
          ),
        );
      }
    }
  }

  Future<void> _runDiagnosticsTest() async {
    setState(() {
      _isTesting = true;
      _testPromptOutput = 'Testing Gemini API connection...\nPrompt: "Explain RAG in one sentence."\n';
    });

    final stopwatch = Stopwatch()..start();
    try {
      final notifier = ref.read(llmNotifierProvider.notifier);
      final result = await notifier.generate(
        prompt: 'Explain RAG (Retrieval-Augmented Generation) in one short sentence.',
        maxTokens: 64,
        temperature: 0.2,
      );
      stopwatch.stop();

      setState(() {
        _lastLatencyMs = stopwatch.elapsedMilliseconds;
        _testPromptOutput += '\nGemini Response (${stopwatch.elapsedMilliseconds} ms):\n"$result"\n\n✓ Diagnostics passed!';
        _isTesting = false;
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _testPromptOutput += '\nDiagnostic failed with error: $e';
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final llmState = ref.watch(llmNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini AI Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Card
            _buildStatusCard(llmState),

            const SizedBox(height: 16),

            // API Key Configuration Card
            _buildApiKeyCard(llmState),

            const SizedBox(height: 16),

            // Model Selection Card
            _buildModelSelectionCard(llmState),

            const SizedBox(height: 16),

            // Live Diagnostics Test Card
            _buildDiagnosticsCard(llmState),

            const SizedBox(height: 16),

            // Google AI Studio Info Card
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(LlmState state) {
    final isConfigured = state.isConfigured;

    return Card(
      elevation: 0,
      color: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isConfigured ? Colors.greenAccent.withAlpha(60) : Colors.amberAccent.withAlpha(60),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isConfigured
                        ? Colors.greenAccent.withAlpha(30)
                        : Colors.amberAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isConfigured ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    color: isConfigured ? Colors.greenAccent : Colors.amberAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConfigured ? 'Gemini AI Connected' : 'API Key Required',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isConfigured
                            ? 'Active model: ${state.selectedModel}'
                            : 'Enter your Gemini API key below to enable chat & RAG',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Engine', 'Google Generative AI (Cloud)'),
            _buildInfoRow('Active Model', state.selectedModel),
            _buildInfoRow('Context Window', 'Up to 1,000,000+ tokens'),
            if (_lastLatencyMs != null)
              _buildInfoRow('Last Latency', '$_lastLatencyMs ms'),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyCard(LlmState state) {
    return Card(
      elevation: 0,
      color: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key_rounded, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Gemini API Key',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (state.isConfigured)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    label: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    onPressed: () async {
                      _apiKeyController.clear();
                      await ref.read(llmNotifierProvider.notifier).setApiKey('');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('API key removed.')),
                        );
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your API key is securely stored in local app storage and used directly to communicate with Google Gemini API.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter AIzaSy...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: AppTheme.backgroundDark,
                prefixIcon: const Icon(Icons.key, size: 18, color: AppTheme.textSecondaryDark),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureKey ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: AppTheme.textSecondaryDark,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureKey = !_obscureKey;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(_isSaving ? 'Validating Key...' : 'Save & Validate Key'),
                onPressed: _isSaving ? null : _saveApiKey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelectionCard(LlmState state) {
    final models = [
      {
        'id': 'gemini-3.8-flash',
        'title': 'Gemini 3.8 Flash',
        'tag': '✦ Latest & Recommended',
        'desc': 'Google\'s latest flagship Flash model (September 2026). Best speed, quality, and context window for RAG workloads.',
      },
      {
        'id': 'gemini-3.5-flash-lite',
        'title': 'Gemini 3.5 Flash Lite',
        'tag': 'Ultra-Efficient',
        'desc': 'Highly cost-efficient and fast — used as the automatic fallback when the primary model is under peak demand.',
      },
    ];

    return Card(
      elevation: 0,
      color: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppTheme.accentColor, size: 20),
                SizedBox(width: 8),
                Text('Gemini Model Selection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select which Gemini model to use for answering questions and synthesizing document citations.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
            ),
            const SizedBox(height: 12),
            ...models.map((m) {
              final isSelected = state.selectedModel == m['id'];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor.withAlpha(25) : AppTheme.backgroundDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : Colors.white.withAlpha(15),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  title: Row(
                    children: [
                      Text(
                        m['title']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSelected ? Colors.white : AppTheme.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.accentColor.withAlpha(40)
                              : Colors.white.withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          m['tag']!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppTheme.accentColor : AppTheme.textSecondaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      m['desc']!,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark),
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: AppTheme.accentColor, size: 22)
                      : const Icon(Icons.circle_outlined, color: AppTheme.textSecondaryDark, size: 22),
                  onTap: () {
                    ref.read(llmNotifierProvider.notifier).setSelectedModel(m['id']!);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsCard(LlmState state) {
    return Card(
      elevation: 0,
      color: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.science_outlined, color: AppTheme.accentColor, size: 20),
                SizedBox(width: 8),
                Text('Diagnostics & Connection Test', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Sends a test prompt ("Explain RAG in one sentence") to verify API key validity, latency, and streaming connectivity.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_isTesting ? 'Sending test prompt...' : 'Run Diagnostics Test'),
                onPressed: _isTesting || !state.isConfigured ? null : _runDiagnosticsTest,
              ),
            ),
            if (_testPromptOutput.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                ),
                child: Text(
                  _testPromptOutput,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.greenAccent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 0,
      color: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 8),
                Text('How to get a Gemini API Key', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '1. Visit Google AI Studio at aistudio.google.com\n'
              '2. Sign in with your Google Account\n'
              '3. Click "Get API key" and create a new key\n'
              '4. Paste the key above and tap "Save & Validate Key"',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark, height: 1.5),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: 'https://aistudio.google.com/app/apikey'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied link: https://aistudio.google.com/app/apikey')),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy, size: 14, color: AppTheme.accentColor),
                    SizedBox(width: 6),
                    Text(
                      'Copy aistudio.google.com link',
                      style: TextStyle(fontSize: 11, color: AppTheme.accentColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryDark)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
