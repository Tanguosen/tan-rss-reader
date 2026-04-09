import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/feed_repository.dart';

class PlatformSettingsScreen extends ConsumerStatefulWidget {
  const PlatformSettingsScreen({super.key});

  @override
  ConsumerState<PlatformSettingsScreen> createState() =>
      _PlatformSettingsScreenState();
}

class _PlatformSettingsScreenState
    extends ConsumerState<PlatformSettingsScreen> {
  bool _loading = true;
  String? _error;
  bool _saving = false;

  late TextEditingController _rsshubUrlController;
  int _fetchIntervalMinutes = 15;
  int _itemsPerPage = 50;
  String _defaultDateRange = '30d';
  String _timeField = 'inserted_at';
  bool _showEntrySummary = true;

  @override
  void initState() {
    super.initState();
    _rsshubUrlController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _rsshubUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(feedRepositoryProvider);
      final settings = await repository.getSettings();

      _rsshubUrlController.text = settings.rsshubUrl;
      _fetchIntervalMinutes = settings.fetchIntervalMinutes;
      _itemsPerPage = settings.itemsPerPage;
      _defaultDateRange = settings.defaultDateRange;
      _timeField = settings.timeField;
      _showEntrySummary = settings.showEntrySummary;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.updateSettings({
        'fetch_interval_minutes': _fetchIntervalMinutes,
        'items_per_page': _itemsPerPage,
        'default_date_range': _defaultDateRange,
        'time_field': _timeField,
        'show_entry_summary': _showEntrySummary,
        'rsshub_url': _rsshubUrlController.text.trim(),
      });

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
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('平台设置'),
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
              onPressed: _saving ? null : _saveSettings,
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
            FilledButton(onPressed: _loadSettings, child: const Text('重试')),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '平台级全局配置',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '这些设置会影响整个平台的默认内容展示、抓取节奏和 RSSHub 相关能力。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '自动刷新间隔 (分钟)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _fetchIntervalMinutes.toDouble(),
                        min: 5,
                        max: 1440,
                        divisions: 1435,
                        label: _fetchIntervalMinutes.toString(),
                        onChanged: (val) {
                          setState(() {
                            _fetchIntervalMinutes = val.round();
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 68,
                      child: Text(
                        '$_fetchIntervalMinutes 分钟',
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '每页文章数量',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [20, 50, 100, 150]
                      .map(
                        (value) => ChoiceChip(
                          label: Text('$value 篇'),
                          selected: _itemsPerPage == value,
                          onSelected: (_) {
                            setState(() {
                              _itemsPerPage = value;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  '默认文章时间范围',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      const [
                        ('1d', '24 小时'),
                        ('3d', '3 天'),
                        ('7d', '1 周'),
                        ('30d', '30 天'),
                        ('90d', '90 天'),
                        ('all', '全部'),
                      ].map((option) {
                        return ChoiceChip(
                          label: Text(option.$2),
                          selected: _defaultDateRange == option.$1,
                          onSelected: (_) {
                            setState(() {
                              _defaultDateRange = option.$1;
                            });
                          },
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  '文章时间依据',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'inserted_at',
                      label: Text('入库时间'),
                      icon: Icon(Icons.schedule_send_outlined),
                    ),
                    ButtonSegment(
                      value: 'published_at',
                      label: Text('发布时间'),
                      icon: Icon(Icons.event_outlined),
                    ),
                  ],
                  selected: {_timeField},
                  onSelectionChanged: (value) {
                    setState(() {
                      _timeField = value.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('默认显示文章摘要'),
                  subtitle: const Text('影响文章列表和内容页的默认信息密度'),
                  value: _showEntrySummary,
                  onChanged: (value) {
                    setState(() {
                      _showEntrySummary = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _rsshubUrlController,
                  decoration: const InputDecoration(
                    labelText: 'RSSHub 默认实例地址',
                    helperText: '用于通过 RSSHub 生成动态订阅源',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
