import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../data/feed_repository.dart';
import 'feed_providers.dart';

class AddFeedScreen extends ConsumerStatefulWidget {
  const AddFeedScreen({super.key});

  @override
  ConsumerState<AddFeedScreen> createState() => _AddFeedScreenState();
}

class _AddFeedScreenState extends ConsumerState<AddFeedScreen> {
  final _urlController = TextEditingController();
  final _focusNode = FocusNode();
  bool _loading = false;
  String? _errorMessage;
  Feed? _addedFeed; // 成功添加的 feed，用于展示结果

  final List<Map<String, dynamic>> _platforms = [
    {'icon': Icons.rss_feed_rounded, 'name': '博客 / 网站', 'color': Color(0xFFFF6B35)},
    {'icon': Icons.article_outlined, 'name': 'Medium', 'color': Color(0xFF00AB6C)},
    {'icon': Icons.alternate_email, 'name': 'Mastodon', 'color': Color(0xFF6364FF)},
    {'icon': Icons.flutter_dash, 'name': 'Bluesky', 'color': Color(0xFF0085FF)},
    {'icon': Icons.mark_email_read_outlined, 'name': 'Substack', 'color': Color(0xFFFF6719)},
    {'icon': Icons.ondemand_video_rounded, 'name': 'YouTube', 'color': Color(0xFFFF0000)},
    {'icon': Icons.forum_outlined, 'name': 'Reddit', 'color': Color(0xFFFF4500)},
    {'icon': Icons.public_outlined, 'name': '其他', 'color': Color(0xFF8B6B4A)},
  ];

  final List<Map<String, String>> _examples = [
    {'name': 'BBC News', 'url': 'https://feeds.bbci.co.uk/news/rss.xml', 'icon': '🇬🇧'},
    {'name': 'TechCrunch', 'url': 'https://techcrunch.com/feed/', 'icon': '💻'},
    {'name': 'The Verge', 'url': 'https://www.theverge.com/rss/index.xml', 'icon': '⚡'},
    {'name': 'Ars Technica', 'url': 'https://feeds.arstechnica.com/arstechnica/index', 'icon': '🔬'},
    {'name': 'Hacker News', 'url': 'https://hnrss.org/frontpage', 'icon': '🔥'},
    {'name': 'Reuters', 'url': 'https://feeds.reuters.com/reuters/topNews', 'icon': '🌍'},
  ];

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _createFeed() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = '请输入订阅链接');
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _errorMessage = '链接必须以 http:// 或 https:// 开头');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _addedFeed = null;
    });
    try {
      final repository = ref.read(feedRepositoryProvider);
      final feed = await repository.createFeed(url: url, title: null);

      // 添加完成后立即刷新频道数据
      if (feed.channelId != null) {
        try {
          await repository.refreshChannel(feed.channelId!);
        } catch (_) {
          // 刷新失败不阻断流程
        }
      }

      ref.invalidate(feedsProvider);
      ref.invalidate(entriesProvider);
      ref.invalidate(channelEntriesProvider(feed.channelId ?? ''));

      setState(() {
        _addedFeed = feed;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加订阅源', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 成功添加结果卡片
            if (_addedFeed != null) _buildSuccessCard(_addedFeed!, colorScheme),

            // 输入区域标题
            Text(
              '订阅链接',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),

            // 链接输入框
            TextField(
              controller: _urlController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'https://example.com/feed.xml',
                prefixIcon: Icon(Icons.rss_feed, color: colorScheme.primary),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_urlController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _urlController.clear();
                          setState(() => _errorMessage = null);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.content_paste_rounded),
                      tooltip: '粘贴',
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          _urlController.text = data!.text!;
                          setState(() => _errorMessage = null);
                        }
                      },
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                errorText: _errorMessage,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _errorMessage = null),
              onSubmitted: (_) => _createFeed(),
            ),
            const SizedBox(height: 16),

            // 添加按钮
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _loading ? null : _createFeed,
                icon: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: Text(
                  _loading ? '正在添加并获取内容...' : '添加订阅源',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 支持的平台
            Text(
              '支持的内容来源',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _platforms.length,
              itemBuilder: (context, index) {
                final platform = _platforms[index];
                final color = platform['color'] as Color;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        platform['icon'] as IconData,
                        size: 26,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      platform['name'] as String,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // 快速示例
            Text(
              '快速添加示例',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            for (final example in _examples)
              InkWell(
                onTap: () {
                  _urlController.text = example['url']!;
                  setState(() => _errorMessage = null);
                  _focusNode.unfocus();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                    borderRadius: BorderRadius.circular(12),
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  child: Row(
                    children: [
                      Text(example['icon']!, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              example['name']!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              example['url']!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard(Feed feed, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('订阅源添加成功', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                Text(
                  feed.title ?? feed.url,
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text('正在后台获取最新内容...', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }
}