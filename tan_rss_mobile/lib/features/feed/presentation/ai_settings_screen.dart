import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../data/feed_repository.dart';
import 'feed_providers.dart';
import 'package:url_launcher/url_launcher.dart';

class AISettingsScreen extends ConsumerStatefulWidget {
  const AISettingsScreen({super.key});

  @override
  ConsumerState<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends ConsumerState<AISettingsScreen> {
  bool _loading = true;
  AIConfig? _config;
  String? _error;
  bool _saving = false;
  List<Map<String, dynamic>> _prompts = [];
  Map<String, dynamic>? _membership;

  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _modelNameController;
  late TextEditingController _embeddingBaseUrlController;
  late TextEditingController _embeddingModelNameController;
  bool _obscureApiKey = true;
  String _selectedProvider = 'Qwen (Alibaba)';

  final List<String> _providers = [
    'Qwen (Alibaba)',
    'OpenAI',
    'Anthropic',
    'DeepSeek',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _baseUrlController = TextEditingController();
    _modelNameController = TextEditingController();
    _embeddingBaseUrlController = TextEditingController();
    _embeddingModelNameController = TextEditingController();

    _loadData();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelNameController.dispose();
    _embeddingBaseUrlController.dispose();
    _embeddingModelNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(feedRepositoryProvider);

      // 并行加载数据
      final results = await Future.wait([
        repository.getAIConfig(),
        repository.getAIPrompts(),
        repository.getMembershipStatus(),
      ]);

      _config = results[0] as AIConfig;
      _prompts = results[1] as List<Map<String, dynamic>>;
      _membership = results[2] as Map<String, dynamic>;

      _apiKeyController.text = _config!.summary.apiKey;
      _baseUrlController.text = _config!.summary.baseUrl;
      _modelNameController.text = _config!.summary.modelName;
      _embeddingBaseUrlController.text = _config!.embedding.baseUrl;
      _embeddingModelNameController.text = _config!.embedding.modelName;

      // 如果有 Qwen 的特征，设置 provider
      if (_config!.summary.modelName.toLowerCase().contains('qwen')) {
        _selectedProvider = 'Qwen (Alibaba)';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (_config == null) return;
    setState(() => _saving = true);
    try {
      final newServiceConfig = AIServiceConfig(
        apiKey: _apiKeyController.text,
        baseUrl: _baseUrlController.text,
        modelName: _modelNameController.text,
        hasApiKey:
            _apiKeyController.text.isNotEmpty || _config!.summary.hasApiKey,
      );
      final newEmbeddingConfig = AIServiceConfig(
        apiKey: _apiKeyController.text,
        baseUrl: _embeddingBaseUrlController.text,
        modelName: _embeddingModelNameController.text,
        hasApiKey:
            _apiKeyController.text.isNotEmpty || _config!.embedding.hasApiKey,
      );

      final newConfig = AIConfig(
        summary: newServiceConfig,
        translation: newServiceConfig,
        embedding: newEmbeddingConfig,
        features: _config!.features,
      );

      final repository = ref.read(feedRepositoryProvider);
      await repository.updateAIConfig(newConfig);
      _config = newConfig;
      ref.invalidate(aiConfigProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ignore: unused_element
  Future<void> _testService() async {
    final repository = ref.read(feedRepositoryProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('正在测试...')));

    final currentConfig = AIServiceConfig(
      apiKey: _apiKeyController.text,
      baseUrl: _baseUrlController.text,
      modelName: _modelNameController.text,
      hasApiKey: true,
    );

    final success = await repository.testAIService(
      'summary',
      currentConfig.toJson(),
    );
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('测试成功！'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('测试失败，请检查配置。'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI功能'),
        actions: [
          if (!_loading && _error == null)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              onPressed: _saving ? null : _saveConfig,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_config == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMembershipCard(),
        const SizedBox(height: 24),

        Text(
          'AI提供商',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildProviderDropdown(),
        const SizedBox(height: 24),

        Text(
          'LLM 配置',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildConfigInputs(),
        const SizedBox(height: 24),

        Text(
          'Embedding 配置',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildEmbeddingConfigInputs(),
        const SizedBox(height: 32),

        _buildPromptsSection(
          'AI指令管理',
          'summary',
          'AI Summary',
          'Based on the following...',
        ),
        const SizedBox(height: 24),

        _buildPromptsSection(
          '文章聚合提示词',
          'synthesis',
          'Article Aggregation',
          'Please generate a compreh...',
        ),
        const SizedBox(height: 24),

        _buildTipsCard(),
        const SizedBox(height: 48),

        Text(
          '高级功能开关',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('自动质量评分'),
          subtitle: const Text('使用 AI 评估文章质量并过滤低质内容'),
          value: _config!.features.autoQualityScoring,
          onChanged: (val) {
            setState(() {
              _config = AIConfig(
                summary: _config!.summary,
                translation: _config!.translation,
                embedding: _config!.embedding,
                features: AIFeatureConfig(
                  autoSummary: _config!.features.autoSummary,
                  autoTranslation: _config!.features.autoTranslation,
                  autoTitleTranslation: _config!.features.autoTitleTranslation,
                  autoQualityScoring: val,
                  translationLanguage: _config!.features.translationLanguage,
                ),
              );
            });
          },
        ),
        SwitchListTile(
          title: const Text('自动生成摘要'),
          subtitle: const Text('后台自动为新文章生成 AI 摘要'),
          value: _config!.features.autoSummary,
          onChanged: (val) {
            setState(() {
              _config = AIConfig(
                summary: _config!.summary,
                translation: _config!.translation,
                embedding: _config!.embedding,
                features: AIFeatureConfig(
                  autoSummary: val,
                  autoTranslation: _config!.features.autoTranslation,
                  autoTitleTranslation: _config!.features.autoTitleTranslation,
                  autoQualityScoring: _config!.features.autoQualityScoring,
                  translationLanguage: _config!.features.translationLanguage,
                ),
              );
            });
          },
        ),
        SwitchListTile(
          title: const Text('自动翻译标题'),
          subtitle: const Text('自动翻译外文标题'),
          value: _config!.features.autoTitleTranslation,
          onChanged: (val) {
            setState(() {
              _config = AIConfig(
                summary: _config!.summary,
                translation: _config!.translation,
                embedding: _config!.embedding,
                features: AIFeatureConfig(
                  autoSummary: _config!.features.autoSummary,
                  autoTranslation: _config!.features.autoTranslation,
                  autoTitleTranslation: val,
                  autoQualityScoring: _config!.features.autoQualityScoring,
                  translationLanguage: _config!.features.translationLanguage,
                ),
              );
            });
          },
        ),
        SwitchListTile(
          title: const Text('自动翻译全文'),
          subtitle: const Text('后台自动翻译未读文章'),
          value: _config!.features.autoTranslation,
          onChanged: (val) {
            setState(() {
              _config = AIConfig(
                summary: _config!.summary,
                translation: _config!.translation,
                embedding: _config!.embedding,
                features: AIFeatureConfig(
                  autoSummary: _config!.features.autoSummary,
                  autoTranslation: val,
                  autoTitleTranslation: _config!.features.autoTitleTranslation,
                  autoQualityScoring: _config!.features.autoQualityScoring,
                  translationLanguage: _config!.features.translationLanguage,
                ),
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildMembershipCard() {
    final bool isPlusOrPro =
        _membership != null &&
        (_membership!['tier'] == 'plus' || _membership!['tier'] == 'pro');
    final String tierName =
        _membership?['tier']?.toString().toUpperCase() ?? 'FREE';
    final int todayCalls = _membership?['today_ai_calls'] ?? 0;

    return Card(
      elevation: 0,
      color: isPlusOrPro
          ? Colors.orange.shade50
          : Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPlusOrPro ? Colors.orange.shade200 : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      color: isPlusOrPro ? Colors.orange : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$tierName 会员',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isPlusOrPro ? Colors.orange.shade900 : null,
                      ),
                    ),
                  ],
                ),
                if (!isPlusOrPro)
                  FilledButton.tonal(
                    onPressed: () {
                      // TODO: Navigate to membership subscription screen
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('升级', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isPlusOrPro
                  ? '您当前享有平台 AI 服务调用特权。今日已调用: $todayCalls 次。'
                  : 'Free 会员需要配置自己的 API 密钥才能使用 AI 功能。升级 Plus 享受免配置开箱即用的 AI 体验！',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedProvider,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: _providers.map((provider) {
            return DropdownMenuItem<String>(
              value: provider,
              child: Row(
                children: [
                  const Icon(
                    Icons.hub_outlined,
                    size: 20,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 12),
                  Text(provider),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedProvider = val;
                if (val == 'Qwen (Alibaba)') {
                  _modelNameController.text = 'qwen3';
                } else if (val == 'OpenAI') {
                  _modelNameController.text = 'gpt-4o-mini';
                }
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildConfigInputs() {
    return Column(
      children: [
        _buildTextField(
          label: 'API密钥',
          controller: _apiKeyController,
          obscureText: _obscureApiKey,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _obscureApiKey = !_obscureApiKey),
              ),
              IconButton(
                icon: const Icon(Icons.save_outlined),
                onPressed: _saveConfig,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          label: '基础URL（可选）',
          controller: _baseUrlController,
          suffixIcon: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _baseUrlController.clear(),
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          label: '模型（可选）',
          controller: _modelNameController,
          suffixIcon: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _modelNameController.clear(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final String url;
              if (_selectedProvider == 'OpenAI') {
                url = 'https://platform.openai.com/api-keys';
              } else if (_selectedProvider == 'Anthropic') {
                url = 'https://console.anthropic.com/';
              } else if (_selectedProvider == 'DeepSeek') {
                url = 'https://platform.deepseek.com/api_keys';
              } else {
                url = 'https://dashscope.console.aliyun.com/apiKey';
              }
              // TODO: url_launcher open url
              launchUrl(Uri.parse(url));
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('获取 $_selectedProvider API密钥'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '点击上方按钮获取$_selectedProvider 的API密钥',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildEmbeddingConfigInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '向量检索、我的专题、研究功能会单独使用这里的 embedding 服务配置。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          label: 'Embedding 基础URL',
          controller: _embeddingBaseUrlController,
          suffixIcon: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _embeddingBaseUrlController.clear(),
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          label: 'Embedding 模型',
          controller: _embeddingModelNameController,
          suffixIcon: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _embeddingModelNameController.clear(),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Future<void> _showPromptDialog({
    Map<String, dynamic>? prompt,
    required String defaultType,
  }) async {
    final nameController = TextEditingController(text: prompt?['name'] ?? '');
    final contentController = TextEditingController(
      text: prompt?['content'] ?? '',
    );
    final typeController = TextEditingController(
      text: prompt?['prompt_type'] ?? defaultType,
    );
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(prompt == null ? '添加自定义指令' : '编辑自定义指令'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '名称',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: typeController,
                      decoration: const InputDecoration(
                        labelText: '类型 (summary 或 synthesis)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: contentController,
                      decoration: const InputDecoration(
                        labelText: '指令内容',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameController.text.isEmpty ||
                              contentController.text.isEmpty)
                            return;
                          setDialogState(() => isSaving = true);
                          try {
                            final repo = ref.read(feedRepositoryProvider);
                            if (prompt == null) {
                              await repo.createAIPrompt({
                                'name': nameController.text,
                                'prompt_type': typeController.text,
                                'content': contentController.text,
                              });
                            } else {
                              await repo.updateAIPrompt(prompt['id'], {
                                'name': nameController.text,
                                'prompt_type': typeController.text,
                                'content': contentController.text,
                              });
                            }
                            if (mounted) {
                              Navigator.pop(context);
                              _loadData();
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('保存失败: $e')),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deletePrompt(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个自定义指令吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repo = ref.read(feedRepositoryProvider);
      await repo.deleteAIPrompt(id);
      _loadData();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  Widget _buildPromptsSection(
    String title,
    String type,
    String defaultName,
    String defaultDesc,
  ) {
    final typePrompts = _prompts
        .where((p) => p['prompt_type'] == type)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            OutlinedButton.icon(
              onPressed: () => _showPromptDialog(defaultType: type),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Default Prompt Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drag_indicator, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.star,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                ),
              ],
            ),
            title: Row(
              children: [
                Text(
                  defaultName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '默认',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              defaultDesc,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ),
        ),

        // Custom Prompts List
        ...typePrompts
            .map(
              (p) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(top: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.drag_indicator, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.article_outlined,
                          color: Colors.grey.shade700,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    p['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    p['content'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showPromptDialog(prompt: p, defaultType: type);
                      } else if (value == 'delete') {
                        _deletePrompt(p['id']);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('删除', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildTipsCard() {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '提示',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTipItem('使用 {title} 和 {content} 占位符来引用文章信息'),
            _buildTipItem('使用 {language} 占位符来引用AI生成语言（可在语言设置中配置）'),
            _buildTipItem('API密钥安全存储在您的本地设备上'),
            _buildTipItem('您可以配置自定义模型和端点以供高级使用'),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
