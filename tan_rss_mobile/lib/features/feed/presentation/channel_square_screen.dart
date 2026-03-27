import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/models/models.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/feed_repository.dart';
import '../presentation/feed_providers.dart';
import 'entry_detail_screen.dart';
import 'channel_synthesis_screen.dart';
import 'admin_management_screen.dart';

Color getAvatarColor(String name) {
  final colors = [const Color(0xFF3b82f6), const Color(0xFF10b981), const Color(0xFFf59e0b), const Color(0xFFef4444), const Color(0xFF8b5cf6), const Color(0xFFec4899)];
  int hash = 0;
  for (int i = 0; i < name.length; i++) hash = name.codeUnitAt(i) + ((hash << 5) - hash);
  return colors[hash.abs() % colors.length];
}

Widget buildLetterAvatar(String name, double size) {
  return CircleAvatar(
    radius: size / 2,
    backgroundColor: getAvatarColor(name),
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.4),
    ),
  );
}


Widget buildChannelAvatar(Channel channel, {double size = 48}) {
  if (channel.iconUrl != null && channel.iconUrl!.isNotEmpty) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: channel.iconUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => buildLetterAvatar(channel.name, size),
          errorWidget: (_, __, ___) => buildLetterAvatar(channel.name, size),
        ),
      ),
    );
  }
  return buildLetterAvatar(channel.name, size);
}

class ChannelSquareScreen extends ConsumerStatefulWidget {
  const ChannelSquareScreen({super.key});

  @override
  ConsumerState<ChannelSquareScreen> createState() => _ChannelSquareScreenState();
}

class _ChannelSquareScreenState extends ConsumerState<ChannelSquareScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    ref.invalidate(channelSquareProvider);
    ref.invalidate(publicCategoriesProvider);
    ref.invalidate(mySubscriptionsProvider);
    ref.invalidate(publicPacksProvider);
  }

  Future<void> _onSearch() async {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _isSearching = true;
    });
    ref.invalidate(channelSquareProvider);
    setState(() {
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('频道广场'),
        actions: [
          if (authState.isLoggedIn)
            IconButton(
              icon: const Icon(Icons.folder_shared_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminManagementScreen()),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '发现'),
            Tab(text: '我的订阅'),
            Tab(text: '精选包'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoveryTab(),
          _buildMySubscriptionsTab(),
          _buildPacksTab(),
        ],
      ),
    );
  }

  Widget _buildDiscoveryTab() {
    final channelsAsync = ref.watch(channelSquareProvider);
    final categoriesAsync = ref.watch(publicCategoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 搜索栏
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(Icons.search_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索频道',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.close_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _onSearch,
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text('搜索', style: TextStyle(color: colorScheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // 分类筛选
        SizedBox(
          height: 40,
          child: categoriesAsync.when(
            data: (categories) {
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildCategoryChip('全部', null),
                  ...categories.map((cat) => _buildCategoryChip(cat.name, cat.id)),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: channelsAsync.when(
            data: (channels) {
              final filtered = channels.where((ch) {
                if (_searchQuery.isNotEmpty) {
                  return ch.name.toLowerCase().contains(_searchQuery.toLowerCase());
                }
                if (_selectedCategoryId != null) {
                  return ch.categoryId == _selectedCategoryId;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.explore_outlined, size: 40, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Text('暂无频道', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15)),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final channel = filtered[index];
                    return _ChannelCard(
                      channel: channel,
                      avatarColor: getAvatarColor(channel.name),
                      onSubscribe: () => _subscribeChannel(channel),
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
                    onPressed: _loadData,
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

  Widget _buildCategoryChip(String label, String? categoryId) {
    final isSelected = _selectedCategoryId == categoryId;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategoryId = categoryId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : colorScheme.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? null : Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMySubscriptionsTab() {
    final subscriptionsAsync = ref.watch(mySubscriptionsProvider);

    return subscriptionsAsync.when(
      data: (channels) {
        if (channels.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_border, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('暂无订阅', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    _tabController.animateTo(0);
                  },
                  child: const Text('去频道广场逛逛'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mySubscriptionsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return _SubscriptionCard(
                channel: channel,
                avatarColor: getAvatarColor(channel.name),
                onTap: () => _openChannelDetail(channel),
                onUnsubscribe: () => _unsubscribeChannel(channel),
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
    );
  }

  Future<void> _subscribeChannel(Channel channel) async {
    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.subscribeChannel(channel.id);
      ref.invalidate(mySubscriptionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已订阅 ${channel.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('订阅失败: $e')),
        );
      }
    }
  }

  Future<void> _unsubscribeChannel(Channel channel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('取消订阅'),
        content: Text('确定取消订阅 "${channel.name}" 吗？'),
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
    if (ok != true) return;

    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.unsubscribeChannel(channel.id);
      ref.invalidate(mySubscriptionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已取消订阅 ${channel.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消订阅失败: $e')),
        );
      }
    }
  }

  void _openChannelDetail(Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelDetailScreen(channel: channel),
      ),
    );
  }

  Widget _buildPacksTab() {
    final packsAsync = ref.watch(publicPacksProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _CreatePackScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: packsAsync.when(
        data: (packs) {
          if (packs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('暂无精选包', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角创建属于你的频道合集',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(publicPacksProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: packs.length,
            itemBuilder: (context, index) {
              final pack = packs[index];
              return _PackCard(
                pack: pack,
                onInstall: () => _installPack(pack),
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
                onPressed: () => ref.invalidate(publicPacksProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _installPack(SourcePack pack) async {
    try {
      final repository = ref.read(feedRepositoryProvider);
      final result = await repository.installPack(pack.slug!);
      final added = result['added'] ?? 0;
      final skipped = result['skipped'] ?? 0;
      ref.invalidate(mySubscriptionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已安装 "${pack.name}"，新增 $added 个频道订阅${skipped > 0 ? '，跳过 $skipped 个已订阅' : ''}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('安装失败: $e')),
        );
      }
    }
  }
}

class _CreatePackScreen extends ConsumerStatefulWidget {
  const _CreatePackScreen();

  @override
  ConsumerState<_CreatePackScreen> createState() => _CreatePackScreenState();
}

class _CreatePackScreenState extends ConsumerState<_CreatePackScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final List<Channel> _selectedChannels = [];
  bool _loading = false;

  void _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入包名称')));
      return;
    }
    if (_selectedChannels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请至少选择一个频道')));
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = ref.read(feedRepositoryProvider);
      
      // Convert selected channels to JSON structure required by backend
      final List<Map<String, dynamic>> sourcesJson = _selectedChannels.map((c) => {
        'name': c.name,
        'type': 'channel',
        'config': {}
      }).toList();
      
      await repo.createPack(
        name: name,
        description: _descController.text.trim(),
        sourcesJson: jsonEncode(sourcesJson),
      );
      
      ref.invalidate(publicPacksProvider);
      ref.invalidate(myPacksProvider);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('创建成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
        setState(() => _loading = false);
      }
    }
  }

  void _selectChannels() async {
    // We fetch user's subscriptions so they can add them to the pack
    final channels = await ref.read(feedRepositoryProvider).getMySubscriptions();
    
    if (!mounted) return;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('选择要加入的频道', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: channels.isEmpty
                        ? const Center(child: Text('暂无订阅的频道，请先去订阅一些吧'))
                        : ListView.builder(
                            itemCount: channels.length,
                            itemBuilder: (context, index) {
                              final c = channels[index];
                              final isSelected = _selectedChannels.any((selected) => selected.id == c.id);
                              return CheckboxListTile(
                                value: isSelected,
                                title: Text(c.name),
                                secondary: buildChannelAvatar(c, size: 32),
                                onChanged: (val) {
                                  setStateSheet(() {
                                    if (val == true) {
                                      _selectedChannels.add(c);
                                    } else {
                                      _selectedChannels.removeWhere((selected) => selected.id == c.id);
                                    }
                                  });
                                  setState(() {}); // Update parent screen
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('确定'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建精选包'),
        actions: [
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
          if (!_loading)
            TextButton(
              onPressed: _create,
              child: const Text('完成'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '精选包名称 *',
              hintText: '例如：AI 资讯合集',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: '描述（可选）',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('包含的频道', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _selectChannels,
                icon: const Icon(Icons.add),
                label: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedChannels.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('暂未选择任何频道', style: TextStyle(color: Colors.grey)),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedChannels.length,
              itemBuilder: (context, index) {
                final c = _selectedChannels[index];
                return ListTile(
                  leading: buildChannelAvatar(c, size: 32),
                  title: Text(c.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _selectedChannels.removeAt(index);
                      });
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final Channel channel;
  final Color avatarColor;
  final VoidCallback onSubscribe;

  const _ChannelCard({
    required this.channel,
    required this.avatarColor,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.08),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：头像 + 名称/标签 + 订阅按钮
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 头像（带光晕效果）
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: avatarColor.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: buildChannelAvatar(channel, size: 52),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channel.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (channel.tags.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 5,
                              runSpacing: 3,
                              children: channel.tags.take(3).map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tag.name,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 订阅按钮
                    _SubscribeButton(onSubscribe: onSubscribe, avatarColor: avatarColor),
                  ],
                ),
                // 描述
                if (channel.description != null && channel.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    channel.description!.trim(),
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.45,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // 预览文章列表
                if (channel.previewEntries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withValues(alpha: isDark ? 0.3 : 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: channel.previewEntries.take(3).toList().asMap().entries.map((e) {
                        final isLast = e.key == channel.previewEntries.take(3).length - 1;
                        return Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: avatarColor.withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.value.title ?? '无标题',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colorScheme.onSurface.withValues(alpha: 0.75),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubscribeButton extends StatefulWidget {
  final VoidCallback onSubscribe;
  final Color avatarColor;
  const _SubscribeButton({required this.onSubscribe, required this.avatarColor});

  @override
  State<_SubscribeButton> createState() => _SubscribeButtonState();
}

class _SubscribeButtonState extends State<_SubscribeButton> {
  bool _subscribed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_subscribed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 14, color: Colors.green),
            SizedBox(width: 4),
            Text('已订阅', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() => _subscribed = true);
        widget.onSubscribe();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '订阅',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final Channel channel;
  final Color avatarColor;
  final VoidCallback onTap;
  final VoidCallback onUnsubscribe;

  const _SubscriptionCard({
    required this.channel,
    required this.avatarColor,
    required this.onTap,
    required this.onUnsubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.07),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // 带光晕头像
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: buildChannelAvatar(channel, size: 46),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (channel.description != null && channel.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          channel.description!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12.5),
                        ),
                      ],
                      if (channel.tags.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: channel.tags.take(2).map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              tag.name,
                              style: TextStyle(fontSize: 10, color: colorScheme.onPrimaryContainer),
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                // 进入箭头 + 取消订阅
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    GestureDetector(
                      onTap: onUnsubscribe,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.star_rounded, size: 20, color: Colors.amber[600]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final SourcePack pack;
  final VoidCallback onInstall;

  const _PackCard({
    required this.pack,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF8b5cf6),
                  child: const Icon(Icons.inventory_2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            '${pack.sources.length} 个频道',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.download, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            '${pack.installCount} 次安装',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onInstall,
                  child: const Text('一键订阅'),
                ),
              ],
            ),
            if (pack.description != null && pack.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                pack.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (pack.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '包含频道:',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: pack.sources.take(5).map((source) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      source.name,
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
              if (pack.sources.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '等 ${pack.sources.length} 个频道',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChannelSourcesSheet extends ConsumerStatefulWidget {
  final Channel channel;
  const _ChannelSourcesSheet({required this.channel});

  @override
  ConsumerState<_ChannelSourcesSheet> createState() => _ChannelSourcesSheetState();
}

class _ChannelSourcesSheetState extends ConsumerState<_ChannelSourcesSheet> {
  List<ChannelSourceItem> _sources = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    try {
      final repo = ref.read(feedRepositoryProvider);
      final sources = await repo.getChannelSources(widget.channel.id);
      if (mounted) {
        setState(() {
          _sources = sources;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                buildChannelAvatar(widget.channel, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.channel.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${_sources.length} 个信息源', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('加载失败: $_error', style: const TextStyle(color: Colors.red)))
                    : _sources.isEmpty
                        ? const Center(child: Text('暂无信息源'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _sources.length,
                            itemBuilder: (context, index) {
                              final source = _sources[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: source.faviconUrl != null ? NetworkImage(source.faviconUrl!) : null,
                                    child: source.faviconUrl == null ? const Icon(Icons.rss_feed, color: Colors.grey) : null,
                                  ),
                                  title: Text(source.title ?? source.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(source.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class ChannelDetailScreen extends ConsumerStatefulWidget {
  final Channel channel;

  const ChannelDetailScreen({super.key, required this.channel});

  @override
  ConsumerState<ChannelDetailScreen> createState() => _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends ConsumerState<ChannelDetailScreen> {
  bool _refreshing = false;

  void _showSourcesSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChannelSourcesSheet(channel: widget.channel),
    );
  }

  Future<void> _refreshChannel() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final repo = ref.read(feedRepositoryProvider);
      final result = await repo.refreshChannel(widget.channel.id);
      ref.invalidate(channelEntriesProvider(widget.channel.id));
      if (mounted) {
        final newCount = result['new_entries'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newCount > 0 ? '获取到 $newCount 条新内容' : '已是最新内容'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刷新失败: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      final repo = ref.read(feedRepositoryProvider);
      final count = await repo.markChannelAllRead(widget.channel.id);
      ref.invalidate(channelEntriesProvider(widget.channel.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0 ? '已将 $count 篇文章设为已读' : '没有未读文章'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(channelEntriesProvider(widget.channel.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channel.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          entriesAsync.maybeWhen(
            data: (entries) => IconButton(
              icon: const Icon(Icons.chrome_reader_mode_outlined),
              onPressed: () {
                if (entries.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('暂无文章可供分析')),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChannelSynthesisScreen(
                      channel: widget.channel,
                      entries: entries,
                    ),
                  ),
                );
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          PopupMenuButton<String>(
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _refreshChannel();
                  break;
                case 'mark_all_read':
                  _markAllRead();
                  break;
                case 'view_sources':
                  _showSourcesSheet(context);
                  break;
                case 'share':
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('频道链接已复制')));
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.sync, size: 20),
                    SizedBox(width: 8),
                    Text('获取最新内容'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 20),
                    SizedBox(width: 8),
                    Text('全部设为已读'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'view_sources',
                child: Row(
                  children: [
                    Icon(Icons.list_alt, size: 20),
                    SizedBox(width: 8),
                    Text('查看信息源'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 8),
                    Text('分享频道'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: entriesAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('暂无文章', style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _refreshChannel,
                    icon: const Icon(Icons.sync),
                    label: const Text('获取最新内容'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await _refreshChannel();
            },
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.transparent),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _buildEntryItem(entry, entries);
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
                onPressed: () => ref.invalidate(channelEntriesProvider(widget.channel.id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryItem(Entry entry, List<Entry> entries) {
    final thumbnail = entry.thumbnail;
    final hasThumbnail = thumbnail != null && thumbnail.isNotEmpty;

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EntryDetailScreen(entry: entry, siblingEntries: entries),
          ),
        );
        // Refresh data after returning
        ref.invalidate(channelEntriesProvider(widget.channel.id));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rss_feed, size: 14, color: Colors.redAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.feedTitle ?? widget.channel.name,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDate(entry.publishedAt ?? entry.insertedAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AutoTranslatedTitleText(
                        entry: entry,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: entry.read ? FontWeight.normal : FontWeight.bold,
                          color: entry.read ? Colors.grey[600] : Colors.black87,
                          height: 1.3,
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getSubtitle(entry),
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hasThumbnail) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: thumbnail,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      placeholder: (_, __) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getSubtitle(Entry entry) {
    if (entry.author != null && entry.author!.isNotEmpty) {
      return 'submitted by ${entry.author}';
    }
    if (entry.summary != null && entry.summary!.isNotEmpty) {
      final text = entry.summary!.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
      return text;
    }
    return '';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      return timeago.format(DateTime.parse(dateStr), locale: 'zh');
    } catch (_) {
      return '';
    }
  }
}

class _AutoTranslatedTitleText extends ConsumerStatefulWidget {
  final Entry entry;
  final TextStyle style;
  final int maxLines;

  const _AutoTranslatedTitleText({
    required this.entry,
    required this.style,
    required this.maxLines,
  });

  @override
  ConsumerState<_AutoTranslatedTitleText> createState() => _AutoTranslatedTitleTextState();
}

class _AutoTranslatedTitleTextState extends ConsumerState<_AutoTranslatedTitleText> {
  String? _translatedTitle;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _translatedTitle = widget.entry.translatedTitle;
  }

  @override
  void didUpdateWidget(_AutoTranslatedTitleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.id != oldWidget.entry.id) {
      _translatedTitle = widget.entry.translatedTitle;
      _isTranslating = false;
      return;
    }
    if (_translatedTitle == null && widget.entry.translatedTitle != null) {
      _translatedTitle = widget.entry.translatedTitle;
    }
  }

  void _checkAutoTranslate() {
    if (_translatedTitle != null || widget.entry.translatedTitle != null) return;
    if (_isTranslating) return;
    final sourceTitle = widget.entry.title;
    if (sourceTitle == null || sourceTitle.isEmpty) return;

    final aiConfigAsync = ref.read(aiConfigProvider);
    if (!aiConfigAsync.hasValue) return;
    final config = aiConfigAsync.value!;
    if (!config.features.autoTitleTranslation) return;

    _doTranslate(config.features.translationLanguage);
  }

  Future<void> _doTranslate(String language) async {
    setState(() {
      _isTranslating = true;
    });
    try {
      final repository = ref.read(feedRepositoryProvider);
      final title = await repository.translateTitle(entryId: widget.entry.id, language: language);
      if (!mounted) return;
      setState(() {
        _translatedTitle = title;
        _isTranslating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiConfigAsync = ref.watch(aiConfigProvider);
    if (aiConfigAsync.hasValue && aiConfigAsync.value!.features.autoTitleTranslation) {
      Future.microtask(_checkAutoTranslate);
    }

    final displayTitle = _translatedTitle ?? widget.entry.translatedTitle ?? widget.entry.title ?? '无标题';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            displayTitle,
            style: widget.style,
            maxLines: widget.maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_isTranslating)
          const Padding(
            padding: EdgeInsets.only(left: 8, top: 2),
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}
