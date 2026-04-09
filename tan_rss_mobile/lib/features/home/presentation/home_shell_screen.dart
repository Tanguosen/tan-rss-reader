import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../feed/data/feed_repository.dart';
import '../../feed/presentation/common_app_bar.dart';
import '../../feed/presentation/feed_list_screen.dart';
import '../../feed/presentation/feed_providers.dart';
import '../../feed/presentation/channel_square_screen.dart';
import '../../feed/presentation/discovery_screen.dart';
import '../../feed/presentation/entry_detail_screen.dart';
import '../../feed/presentation/my_topics_screen.dart';
import '../../feed/presentation/reading_history_screen.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  Timer? _tokenCheckTimer;
  bool _hasWarnedExpiry = false;

  @override
  void initState() {
    super.initState();
    _checkTokenExpiry();
    _tokenCheckTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _checkTokenExpiry(),
    );
  }

  @override
  void dispose() {
    _tokenCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkTokenExpiry() async {
    final api = ApiClient();
    final expiry = await api.getTokenExpiry();
    if (expiry == null || !mounted) return;

    final remaining = expiry.difference(DateTime.now());
    if (remaining.isNegative) {
      // Token already expired — interceptor will handle 401
      return;
    }
    if (remaining.inHours < 24 && !_hasWarnedExpiry) {
      _hasWarnedExpiry = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('登录凭证即将过期（剩余${remaining.inHours}小时），请尽快重新登录'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget build(BuildContext context) {
    final currentTab = ref.watch(homeTabProvider);
    Widget body;
    if (currentTab == 0) {
      body = const FeedListScreen();
    } else if (currentTab == 1) {
      body = const SubscribedChannelsScreen();
    } else {
      body = const DiscoveryScreen();
    }

    return Scaffold(
      appBar: const CommonAppBar(title: 'TAN RSS'),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (index) {
          ref.read(homeTabProvider.notifier).change(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: '文章',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: '频道',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: '发现',
          ),
        ],
      ),
    );
  }
}

class SubscribedChannelsScreen extends ConsumerWidget {
  const SubscribedChannelsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(mySubscriptionsProvider);
  }

  bool _canManageChannel(WidgetRef ref, Channel channel) {
    final currentUserId = ref.watch(authProvider).user?.id;
    return currentUserId != null && channel.ownerId == currentUserId;
  }

  Future<void> _showChannelSheet(
    BuildContext context,
    WidgetRef ref, {
    Channel? channel,
  }) async {
    final isEditing = channel != null;
    final nameController = TextEditingController(text: channel?.name ?? '');
    final descriptionController = TextEditingController(
      text: channel?.description ?? '',
    );
    var isPublic = channel?.isPublic ?? true;
    var saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isEditing ? '编辑频道' : '创建频道',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEditing
                          ? '更新频道信息，调整频道对外展示方式。'
                          : '创建你自己的内容集合，后续可以继续添加订阅源。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: '频道名称',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: '频道简介',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('公开频道'),
                      subtitle: const Text('关闭后仅自己可见'),
                      value: isPublic,
                      onChanged: (value) {
                        setSheetState(() {
                          isPublic = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    final name = nameController.text.trim();
                                    if (name.isEmpty) return;
                                    setSheetState(() {
                                      saving = true;
                                    });
                                    try {
                                      final repo = ref.read(
                                        feedRepositoryProvider,
                                      );
                                      final description =
                                          descriptionController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : descriptionController.text.trim();
                                      if (isEditing) {
                                        await repo.updateChannel(
                                          channel.id,
                                          name: name,
                                          description: description,
                                          isPublic: isPublic,
                                        );
                                      } else {
                                        await repo.createChannel(
                                          name: name,
                                          description: description,
                                          isPublic: isPublic,
                                        );
                                      }
                                      ref.invalidate(mySubscriptionsProvider);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isEditing ? '频道更新成功' : '频道创建成功',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${isEditing ? '更新' : '创建'}失败: $e',
                                            ),
                                          ),
                                        );
                                      }
                                      setSheetState(() {
                                        saving = false;
                                      });
                                    }
                                  },
                            child: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(isEditing ? '保存' : '创建'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF3b82f6),
      const Color(0xFF10b981),
      const Color(0xFFf59e0b),
      const Color(0xFFef4444),
      const Color(0xFF8b5cf6),
      const Color(0xFFec4899),
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(mySubscriptionsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Text(
                '我的频道',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '最近阅读',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReadingHistoryScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.history),
              ),
              IconButton(
                tooltip: '我的专题',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyTopicsScreen()),
                  );
                },
                icon: const Icon(Icons.auto_awesome_outlined),
              ),
              IconButton(
                onPressed: () => _refresh(ref),
                icon: const Icon(Icons.refresh),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'create') {
                    _showChannelSheet(context, ref);
                  } else if (value == 'square') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChannelSquareScreen(),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'create', child: Text('创建频道')),
                  PopupMenuItem(value: 'square', child: Text('去频道广场')),
                ],
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: subscriptionsAsync.when(
            data: (channels) {
              if (channels.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.folder_off_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '暂无订阅的频道',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChannelSquareScreen(),
                            ),
                          );
                        },
                        child: const Text('去频道广场逛逛'),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: channels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    final unreadAsync = ref.watch(
                      channelUnreadCountProvider(channel.id),
                    );
                    final unreadCount = unreadAsync.asData?.value ?? -1;
                    final canManage = _canManageChannel(ref, channel);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getAvatarColor(channel.name),
                          backgroundImage: channel.coverUrl != null
                              ? NetworkImage(channel.coverUrl!)
                              : null,
                          child: channel.coverUrl == null
                              ? Text(
                                  channel.name.isNotEmpty
                                      ? channel.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: Text(
                          channel.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (channel.description != null &&
                                channel.description!.isNotEmpty)
                              Text(
                                channel.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (canManage)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '我创建的',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (canManage)
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _showChannelSheet(
                                      context,
                                      ref,
                                      channel: channel,
                                    );
                                  } else if (value == 'delete') {
                                    final repo = ref.read(
                                      feedRepositoryProvider,
                                    );
                                    await repo.deleteChannel(channel.id);
                                    ref.invalidate(mySubscriptionsProvider);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('编辑频道'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('删除频道'),
                                  ),
                                ],
                                icon: const Icon(Icons.settings_outlined),
                              )
                            else
                              const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChannelDetailScreen(
                                channel: channel,
                                canManage: canManage,
                              ),
                            ),
                          );
                        },
                      ),
                    );
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
                    onPressed: () => ref.invalidate(mySubscriptionsProvider),
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

class StarredScreen extends ConsumerWidget {
  const StarredScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(starredEntriesProvider);
    await ref.read(starredEntriesProvider.future);
  }

  Future<void> _toggleStar(WidgetRef ref, Entry entry) async {
    final repository = ref.read(feedRepositoryProvider);
    await repository.markEntryStarred(entry.id, starred: false);
    ref.invalidate(starredEntriesProvider);
    ref.invalidate(entriesProvider);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      return timeago.format(DateTime.parse(dateStr), locale: 'zh');
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starredAsync = ref.watch(starredEntriesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Text(
                '收藏',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _refresh(ref),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: starredAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return const Center(child: Text('还没有收藏的文章'));
              }
              return RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return ListTile(
                      title: Text(
                        entry.title ?? '无标题',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${entry.feedTitle ?? ''} · ${_formatDate(entry.publishedAt ?? entry.insertedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        onPressed: () => _toggleStar(ref, entry),
                        icon: const Icon(Icons.star),
                        color: Colors.amber,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EntryDetailScreen(entry: entry),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
          ),
        ),
      ],
    );
  }
}
