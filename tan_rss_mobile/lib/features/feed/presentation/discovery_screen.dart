import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../data/feed_repository.dart';
import 'entry_detail_screen.dart';
import 'daily_digest_screen.dart';
import 'feed_providers.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  int _selectedDays = 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDailyDigestBanner(context),
        _buildActionCards(context),
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '话题趋势'),
              Tab(text: '语义搜索'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TrendsTab(
                selectedDays: _selectedDays,
                onDaysChanged: (days) {
                  setState(() {
                    _selectedDays = days;
                  });
                },
              ),
              _SearchTab(
                searchController: _searchController,
                isSearching: _isSearching,
                onSearch: _handleSearch,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          Icon(Icons.local_fire_department, size: 14, color: Colors.red[300]),
          const SizedBox(width: 4),
          Text('重大事件', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(width: 16),
          Icon(Icons.newspaper, size: 14, color: Colors.blue[300]),
          const SizedBox(width: 4),
          Text(
            '信息源高光',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(width: 16),
          Icon(Icons.manage_search, size: 14, color: Colors.purple[300]),
          const SizedBox(width: 4),
          Text('深度解读', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const Spacer(),
          Text(
            '已集成至每日简报',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyDigestBanner(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Fetch global unread entries for digest
        final repository = ref.read(feedRepositoryProvider);
        try {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
          final entries = await repository.getEntriesByQuery(
            const EntryQuery(unreadOnly: true, limit: 100),
          );
          if (!context.mounted) return;
          Navigator.pop(context); // close dialog

          if (entries.isEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('当前没有未读文章可供生成简报')));
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DailyDigestScreen(entries: entries),
            ),
          );
        } catch (e) {
          if (!context.mounted) return;
          Navigator.pop(context); // close dialog
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('获取文章失败: $e')));
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B6B56), Color(0xFFB08968)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B6B56).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI 每日简报',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '阅读所有频道的精华总结',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  void _handleSearch(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
    });
  }
}

class _TrendsTab extends ConsumerWidget {
  final int selectedDays;
  final ValueChanged<int> onDaysChanged;

  const _TrendsTab({required this.selectedDays, required this.onDaysChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clustersAsync = ref.watch(_clustersProvider(selectedDays));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                '时间范围: ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: selectedDays,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('最近 24 小时')),
                  DropdownMenuItem(value: 3, child: Text('最近 3 天')),
                  DropdownMenuItem(value: 7, child: Text('最近一周')),
                  DropdownMenuItem(value: 30, child: Text('最近 1 个月')),
                  DropdownMenuItem(value: 90, child: Text('最近 3 个月')),
                ],
                onChanged: (value) {
                  if (value != null) onDaysChanged(value);
                },
              ),
              const Spacer(),
              IconButton(
                onPressed: () =>
                    ref.invalidate(_clustersProvider(selectedDays)),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: clustersAsync.when(
            data: (clusters) {
              if (clusters.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '该时间段内未发现趋势话题',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(_clustersProvider(selectedDays));
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: clusters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final cluster = clusters[index];
                    return _ClusterCard(cluster: cluster);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('加载失败: $e'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(_clustersProvider(selectedDays)),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final _clustersProvider = FutureProvider.family<List<ClusterItem>, int>((
  ref,
  days,
) async {
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getClusters(days: days);
});

class _ClusterCard extends ConsumerStatefulWidget {
  final ClusterItem cluster;

  const _ClusterCard({required this.cluster});

  @override
  ConsumerState<_ClusterCard> createState() => _ClusterCardState();
}

class _ClusterCardState extends ConsumerState<_ClusterCard> {
  String? _translatedTopic;
  bool _translatingTopic = false;

  bool _isEnglish(String text) {
    // 简单判断：超过50%字符是ASCII字母则认为是英文
    if (text.isEmpty) return false;
    final letters = text.runes
        .where((r) => (r >= 65 && r <= 90) || (r >= 97 && r <= 122))
        .length;
    return letters / text.length > 0.5;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkAutoTranslateTopic);
  }

  Future<void> _checkAutoTranslateTopic() async {
    if (_translatedTopic != null || _translatingTopic) return;
    if (!_isEnglish(widget.cluster.topic)) return;
    final aiConfigAsync = ref.read(aiConfigProvider);
    if (!aiConfigAsync.hasValue) return;
    final aiConfig = aiConfigAsync.value!;
    if (!aiConfig.features.autoTitleTranslation) return;
    setState(() => _translatingTopic = true);
    try {
      final repository = ref.read(feedRepositoryProvider);
      final translated = await repository.translateText(
        text: widget.cluster.topic,
        language: aiConfig.features.translationLanguage,
      );
      if (mounted)
        setState(() {
          _translatedTopic = translated;
          _translatingTopic = false;
        });
    } catch (_) {
      if (mounted) setState(() => _translatingTopic = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiConfigAsync = ref.watch(aiConfigProvider);
    if (aiConfigAsync.hasValue &&
        aiConfigAsync.value!.features.autoTitleTranslation) {
      Future.microtask(_checkAutoTranslateTopic);
    }
    final displayTopic = _translatedTopic ?? widget.cluster.topic;

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnalysisReportScreen(
                clusterId: widget.cluster.clusterId,
                topic: displayTopic,
                entryIds: widget.cluster.items.map((e) => e.entryId).toList(),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayTopic,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_translatingTopic)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.cluster.size} 篇',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...widget.cluster.items
                  .take(3)
                  .map((item) => _ClusterItemRow(item: item)),
              if (widget.cluster.items.length > 3) ...[
                const SizedBox(height: 4),
                Text(
                  '+ ${widget.cluster.items.length - 3} 篇更多',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnalysisReportScreen(
                            clusterId: widget.cluster.clusterId,
                            topic: displayTopic,
                            entryIds: widget.cluster.items
                                .map((e) => e.entryId)
                                .toList(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('智能分析'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单条话题文章行，自动翻译英文标题
class _ClusterItemRow extends ConsumerStatefulWidget {
  final ClusterEntryItem item;
  const _ClusterItemRow({required this.item});

  @override
  ConsumerState<_ClusterItemRow> createState() => _ClusterItemRowState();
}

class _ClusterItemRowState extends ConsumerState<_ClusterItemRow> {
  String? _translatedTitle;
  bool _translating = false;

  bool _isEnglish(String text) {
    if (text.isEmpty) return false;
    final letters = text.runes
        .where((r) => (r >= 65 && r <= 90) || (r >= 97 && r <= 122))
        .length;
    return letters / text.length > 0.5;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkAutoTranslate);
  }

  Future<void> _checkAutoTranslate() async {
    if (_translatedTitle != null || _translating) return;
    if (!_isEnglish(widget.item.title)) return;
    final aiConfigAsync = ref.read(aiConfigProvider);
    if (!aiConfigAsync.hasValue ||
        !aiConfigAsync.value!.features.autoTitleTranslation)
      return;
    setState(() => _translating = true);
    try {
      final repo = ref.read(feedRepositoryProvider);
      final lang = aiConfigAsync.value!.features.translationLanguage;
      final translated = await repo.translateText(
        text: widget.item.title,
        language: lang,
      );
      if (mounted)
        setState(() {
          _translatedTitle = translated;
          _translating = false;
        });
    } catch (_) {
      if (mounted) setState(() => _translating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiConfigAsync = ref.watch(aiConfigProvider);
    if (aiConfigAsync.hasValue &&
        aiConfigAsync.value!.features.autoTitleTranslation) {
      Future.microtask(_checkAutoTranslate);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.article_outlined, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _translatedTitle ?? widget.item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (_translating)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
        ],
      ),
    );
  }
}

class _SearchTab extends ConsumerStatefulWidget {
  final TextEditingController searchController;
  final bool isSearching;
  final ValueChanged<String> onSearch;

  const _SearchTab({
    required this.searchController,
    required this.isSearching,
    required this.onSearch,
  });

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  List<SearchResult>? _results;
  String? _error;
  bool _hasSearched = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _hasSearched = true;
      _error = null;
    });
    try {
      final repository = ref.read(feedRepositoryProvider);
      final results = await repository.semanticSearch(query);
      if (!mounted) return;
      setState(() {
        _results = results;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.searchController,
                  decoration: InputDecoration(
                    hintText: '输入问题或描述...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (value) {
                    widget.onSearch(value);
                    _performSearch(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  widget.onSearch(widget.searchController.text);
                  _performSearch(widget.searchController.text);
                },
                icon: widget.isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
              ),
            ],
          ),
        ),
        Expanded(
          child: _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text('搜索失败: $_error'),
                    ],
                  ),
                )
              : _results == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _hasSearched ? '未找到相关结果' : '输入关键词开始搜索',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : _results!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('未找到相关结果'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final result = _results![index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Text(
                            '${(result.score * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(
                          result.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '发布时间: ${_formatDate(result.publishedAt)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () async {
                          try {
                            final repository = ref.read(feedRepositoryProvider);
                            final entry = await repository.getEntry(result.id);
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EntryDetailScreen(entry: entry),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('打开文章失败: $e')),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class AnalysisReportScreen extends ConsumerStatefulWidget {
  final int clusterId;
  final String topic;
  final List<String> entryIds;

  const AnalysisReportScreen({
    super.key,
    required this.clusterId,
    required this.topic,
    required this.entryIds,
  });

  @override
  ConsumerState<AnalysisReportScreen> createState() =>
      _AnalysisReportScreenState();
}

class _AnalysisReportScreenState extends ConsumerState<AnalysisReportScreen> {
  ClusterAnalysis? _analysis;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(feedRepositoryProvider);
      final analysis = await repository.analyzeCluster(widget.entryIds);
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.topic)),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在生成智能分析报告...'),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('分析失败: $_error'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadAnalysis,
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : _analysis == null
          ? const Center(child: Text('暂无分析数据'))
          : _buildAnalysisContent(),
    );
  }

  Widget _buildAnalysisContent() {
    final analysis = _analysis!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '智能趋势分析',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (analysis.analysis.trendPrediction != null) ...[
                    _buildSection('趋势预测', analysis.analysis.trendPrediction!),
                    const SizedBox(height: 12),
                  ],
                  if (analysis.analysis.keywords.isNotEmpty) ...[
                    const Text(
                      '关键词:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: analysis.analysis.keywords
                          .map(
                            (kw) => Chip(
                              label: Text(kw),
                              backgroundColor: Colors.blue.shade50,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildSentimentSection(analysis.analysis.sentimentScore),
                  const SizedBox(height: 12),
                  if (analysis.analysis.summary != null) ...[
                    _buildSection('摘要', analysis.analysis.summary!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (analysis.timeline.isNotEmpty) ...[
            Text(
              '事件脉络',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            // 用 IntrinsicHeight + Stack 实现连续贯通的时间线
            _TimelineList(items: analysis.timeline),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(content),
      ],
    );
  }

  Widget _buildSentimentSection(double score) {
    final normalizedScore = (score + 1) / 2;
    final color = score > 0.3
        ? Colors.green
        : (score < -0.3 ? Colors.red : Colors.orange);
    final label = score > 0.3 ? '正面' : (score < -0.3 ? '负面' : '中性');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('情感倾向:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: normalizedScore,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

/// 连续时间线列表 — 线条贯穿所有卡片
class _TimelineList extends StatelessWidget {
  final List<TimelineItem> items;
  const _TimelineList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          _TimelineCard(
            item: items[i],
            isFirst: i == 0,
            isLast: i == items.length - 1,
          ),
      ],
    );
  }
}

class _TimelineCard extends ConsumerStatefulWidget {
  final TimelineItem item;
  final bool isFirst;
  final bool isLast;

  const _TimelineCard({
    required this.item,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  ConsumerState<_TimelineCard> createState() => _TimelineCardState();
}

class _TimelineCardState extends ConsumerState<_TimelineCard> {
  String? _translatedTitle;
  bool _translating = false;

  static const _dotSize = 14.0;
  static const _lineWidth = 2.0;
  static const _dotOffset = 20.0; // 卡片内垂直方向上圆点的位置

  bool _isEnglish(String text) {
    if (text.isEmpty) return false;
    final letters = text.runes
        .where((r) => (r >= 65 && r <= 90) || (r >= 97 && r <= 122))
        .length;
    return letters / text.length > 0.5;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_checkAutoTranslate);
  }

  Future<void> _checkAutoTranslate() async {
    if (_translatedTitle != null || _translating) return;
    if (!_isEnglish(widget.item.title)) return;
    final aiConfigAsync = ref.read(aiConfigProvider);
    if (!aiConfigAsync.hasValue ||
        !aiConfigAsync.value!.features.autoTitleTranslation)
      return;
    setState(() => _translating = true);
    try {
      final repo = ref.read(feedRepositoryProvider);
      final lang = aiConfigAsync.value!.features.translationLanguage;
      final translated = await repo.translateText(
        text: widget.item.title,
        language: lang,
      );
      if (mounted)
        setState(() {
          _translatedTitle = translated;
          _translating = false;
        });
    } catch (_) {
      if (mounted) setState(() => _translating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiConfigAsync = ref.watch(aiConfigProvider);
    if (aiConfigAsync.hasValue &&
        aiConfigAsync.value!.features.autoTitleTranslation) {
      Future.microtask(_checkAutoTranslate);
    }
    final displayTitle = _translatedTitle ?? widget.item.title;
    final summary = widget.item.summary
        .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ')
        .trim();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时间线立柱：点 + 上下线条连续
          SizedBox(
            width: 30,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // 上半线条（非第一个才显示）
                if (!widget.isFirst)
                  Positioned(
                    top: 0,
                    bottom: _dotOffset + _dotSize / 2,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: _lineWidth,
                        color: const Color(0xFFD0C8C0),
                      ),
                    ),
                  ),
                // 下半线条（非最后一个才显示）
                if (!widget.isLast)
                  Positioned(
                    top: _dotOffset + _dotSize / 2,
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: _lineWidth,
                        color: const Color(0xFFD0C8C0),
                      ),
                    ),
                  ),
                // 圆点
                Positioned(
                  top: _dotOffset,
                  child: Container(
                    width: _dotSize,
                    height: _dotSize,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B6B56),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 右侧卡片
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFBF7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6DED5), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTime(widget.item.publishedAt),
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (_translating)
                          const Padding(
                            padding: EdgeInsets.only(left: 8, top: 2),
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      widget.item.source,
                      style: const TextStyle(
                        color: Color(0xFFAAA095),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
