import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/models.dart';
import '../data/feed_repository.dart';
import 'feed_providers.dart';

class FeedsScreen extends ConsumerStatefulWidget {
  const FeedsScreen({super.key});

  @override
  ConsumerState<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends ConsumerState<FeedsScreen> {
  final Set<String> _expandedGroups = <String>{};
  List<Channel>? _channels;
  final Map<String, List<ChannelSourceItem>> _channelSources = {};
  bool _loadingChannels = false;

  Future<void> _refreshAll(WidgetRef ref) async {
    ref.invalidate(feedsProvider);
    await ref.read(feedsProvider.future);
    await _loadChannels();
  }

  Future<void> _refreshSingle(WidgetRef ref, String feedId) async {
    final repository = ref.read(feedRepositoryProvider);
    await repository.refreshFeed(feedId);
    ref.invalidate(feedsProvider);
    ref.invalidate(entriesProvider);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadChannels);
  }

  Future<void> _loadChannels() async {
    setState(() {
      _loadingChannels = true;
    });
    try {
      final repository = ref.read(feedRepositoryProvider);
      final data = await repository.getAdminChannels();
      if (!mounted) return;
      setState(() {
        _channels = data;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingChannels = false;
        });
      }
    }
  }

  Future<void> _ensureChannelSources(String channelId) async {
    if (_channelSources[channelId] != null) return;
    final repository = ref.read(feedRepositoryProvider);
    final items = await repository.getChannelSources(channelId);
    if (!mounted) return;
    setState(() {
      _channelSources[channelId] = items;
    });
  }

  Future<void> _renameChannel(
    BuildContext context,
    String channelId,
    String oldName,
  ) async {
    final controller = TextEditingController(text: oldName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名频道'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '新名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final repository = ref.read(feedRepositoryProvider);
      await repository.updateChannel(channelId, name: controller.text.trim());
      await _loadChannels();
    }
  }

  Future<void> _deleteChannel(BuildContext context, String channelId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除频道'),
        content: const Text('确定删除该频道？只移除频道与订阅关系，不会删除订阅源。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final repository = ref.read(feedRepositoryProvider);
      await repository.deleteChannel(channelId);
      setState(() {
        _channelSources.remove(channelId);
      });
      await _loadChannels();
    }
  }

  Future<void> _addFeedToChannel(BuildContext context, String channelId) async {
    final urlController = TextEditingController();
    final titleController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('添加订阅到频道'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'RSS/Atom URL'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '标题（可选）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final repository = ref.read(feedRepositoryProvider);
      final feed = await repository.createFeed(
        url: urlController.text.trim(),
        title: titleController.text.trim().isEmpty
            ? null
            : titleController.text.trim(),
      );
      await repository.addChannelSource(channelId, feed.id);
      _channelSources.remove(channelId);
      await _ensureChannelSources(channelId);
      ref.invalidate(feedsProvider);
      ref.invalidate(entriesProvider);
    }
  }

  // ignore: unused_element
  Future<void> _showCreateFeedDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final urlController = TextEditingController();
    final titleController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增订阅源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '标题（可选）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final repository = ref.read(feedRepositoryProvider);
    await repository.createFeed(
      url: urlController.text.trim(),
      title: titleController.text.trim().isEmpty
          ? null
          : titleController.text.trim(),
    );
    ref.invalidate(feedsProvider);
    ref.invalidate(entriesProvider);
  }

  Future<void> _showEditFeedDialog(
    BuildContext context,
    WidgetRef ref,
    Feed feed,
  ) async {
    final titleController = TextEditingController(text: feed.title ?? '');
    int? updateInterval;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑订阅源'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(feed.url, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: updateInterval,
                decoration: const InputDecoration(
                  labelText: '更新间隔（分钟）',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<int?>(value: null, child: Text('默认（15分钟）')),
                  DropdownMenuItem<int?>(value: 5, child: Text('5分钟')),
                  DropdownMenuItem<int?>(value: 10, child: Text('10分钟')),
                  DropdownMenuItem<int?>(value: 15, child: Text('15分钟')),
                  DropdownMenuItem<int?>(value: 30, child: Text('30分钟')),
                  DropdownMenuItem<int?>(value: 60, child: Text('1小时')),
                  DropdownMenuItem<int?>(value: 120, child: Text('2小时')),
                  DropdownMenuItem<int?>(value: 360, child: Text('6小时')),
                  DropdownMenuItem<int?>(value: 720, child: Text('12小时')),
                  DropdownMenuItem<int?>(value: 1440, child: Text('24小时')),
                ],
                onChanged: (value) {
                  setState(() {
                    updateInterval = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    final repository = ref.read(feedRepositoryProvider);
    await repository.updateFeed(
      id: feed.id,
      title: titleController.text.trim().isEmpty
          ? null
          : titleController.text.trim(),
      updateInterval: updateInterval,
    );
    ref.invalidate(feedsProvider);
    ref.invalidate(entriesProvider);
  }

  Future<void> _confirmDeleteFeed(
    BuildContext context,
    WidgetRef ref,
    Feed feed,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消订阅'),
        content: Text('确定取消订阅「${feed.title ?? feed.url}」？\n取消后将不再收到该订阅源的更新。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定取消'),
          ),
        ],
      ),
    );
    if (result != true) return;
    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.deleteFeed(feed.id);
      ref.invalidate(feedsProvider);
      ref.invalidate(entriesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已取消订阅'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '操作失败: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedsAsync = ref.watch(feedsProvider);
    return feedsAsync.when(
      data: (feeds) {
        final totalUnread = feeds.fold<int>(
          0,
          (sum, item) => sum + (item.unreadCount ?? 0),
        );

        // If channels are available，优先显示"频道折叠列表"
        if (_channels != null && _channels!.isNotEmpty)
          return RefreshIndicator(
            onRefresh: () async {
              await _loadChannels();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                ..._channels!.map((ch) {
                  final expanded = _expandedGroups.contains('ch:${ch.id}');
                  final sources = _channelSources[ch.id];
                  final unread = 0; // 服务端暂无直接统计，后续可汇总 sources 的 unreadCount
                  return Column(
                    children: [
                      InkWell(
                        onTap: () async {
                          setState(() {
                            if (expanded) {
                              _expandedGroups.remove('ch:${ch.id}');
                            } else {
                              _expandedGroups.add('ch:${ch.id}');
                            }
                          });
                          if (!expanded) {
                            await _ensureChannelSources(ch.id);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFFF6F2EC),
                                child: Icon(
                                  expanded
                                      ? Icons.keyboard_arrow_down
                                      : Icons.chevron_right,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.folder_open, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${ch.name}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              _CountBadge(count: unread),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'add') {
                                    await _addFeedToChannel(context, ch.id);
                                  } else if (value == 'rename') {
                                    await _renameChannel(
                                      context,
                                      ch.id,
                                      ch.name,
                                    );
                                  } else if (value == 'delete') {
                                    await _deleteChannel(context, ch.id);
                                  }
                                },
                                itemBuilder: (context) {
                                  return const [
                                    PopupMenuItem(
                                      value: 'add',
                                      child: Text('在此频道添加订阅'),
                                    ),
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Text('重命名频道'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('删除频道'),
                                    ),
                                  ];
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (expanded)
                        if (sources == null && _loadingChannels)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (sources != null)
                          ...sources.map(
                            (src) => InkWell(
                              onTap: () {
                                ref
                                    .read(selectedFeedIdProvider.notifier)
                                    .select(src.feedId);
                                ref.read(homeTabProvider.notifier).change(0);
                                ref.invalidate(entriesProvider);
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  36,
                                  10,
                                  0,
                                  10,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: const Color(0xFFFFF0F4),
                                      child:
                                          src.faviconUrl != null &&
                                              src.faviconUrl!.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: CachedNetworkImage(
                                                imageUrl: src.faviconUrl!,
                                                width: 28,
                                                height: 28,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    Icon(
                                                      Icons.rss_feed,
                                                      size: 16,
                                                      color:
                                                          Colors.red.shade400,
                                                    ),
                                              ),
                                            )
                                          : Icon(
                                              Icons.rss_feed,
                                              size: 16,
                                              color: Colors.red.shade400,
                                            ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        src.title ?? src.url,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ],
                  );
                }).toList(),
              ],
            ),
          );

        // 否则显示简单的 Feed 列表
        return RefreshIndicator(
          onRefresh: () => _refreshAll(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  ref.read(selectedFeedIdProvider.notifier).select(null);
                  ref.read(homeTabProvider.notifier).change(0);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8C7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.transparent,
                        child: Icon(
                          Icons.radio_button_unchecked,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '所有未读',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '$totalUnread 未读',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...feeds.map(
                (feed) => InkWell(
                  onTap: () {
                    ref.read(selectedFeedIdProvider.notifier).select(feed.id);
                    ref.read(homeTabProvider.notifier).change(0);
                    ref.invalidate(entriesProvider);
                  },
                  onLongPress: () async {
                    final action = await showMenu<String>(
                      context: context,
                      position: const RelativeRect.fromLTRB(1000, 200, 12, 0),
                      items: const [
                        PopupMenuItem(value: 'refresh', child: Text('刷新')),
                        PopupMenuItem(value: 'edit', child: Text('编辑')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    );
                    if (!context.mounted) return;
                    if (action == 'refresh') {
                      await _refreshSingle(ref, feed.id);
                    } else if (action == 'edit') {
                      await _showEditFeedDialog(context, ref, feed);
                    } else if (action == 'delete') {
                      await _confirmDeleteFeed(context, ref, feed);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFFFF0F4),
                          child:
                              feed.favicon != null && feed.favicon!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: CachedNetworkImage(
                                    imageUrl: feed.favicon!,
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Icon(
                                      Icons.rss_feed,
                                      size: 16,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.rss_feed,
                                  size: 16,
                                  color: Colors.red.shade400,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            feed.title ?? feed.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _CountBadge(count: feed.unreadCount ?? 0),
                      ],
                    ),
                  ),
                ),
              ),
              if (feeds.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: Text('暂无订阅源，点击右上角 + 添加')),
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('错误: ${error.toString()}', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8C7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
