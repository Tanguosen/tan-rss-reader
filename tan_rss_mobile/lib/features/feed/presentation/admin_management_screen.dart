import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/feed_repository.dart';
import 'feed_providers.dart';

class AdminManagementScreen extends ConsumerStatefulWidget {
  final bool isPlatformAdmin;

  const AdminManagementScreen({super.key, this.isPlatformAdmin = false});

  @override
  ConsumerState<AdminManagementScreen> createState() =>
      _AdminManagementScreenState();
}

class _AdminManagementScreenState extends ConsumerState<AdminManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isPlatformAdmin ? '平台管理中心' : '我的频道',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF8B6B4A),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF8B6B4A),
          tabs: const [
            Tab(text: '频道', icon: Icon(Icons.folder_outlined)),
            Tab(text: '订阅源', icon: Icon(Icons.rss_feed_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ChannelsTab(isPlatformAdmin: widget.isPlatformAdmin),
          _FeedsTab(isPlatformAdmin: widget.isPlatformAdmin),
        ],
      ),
    );
  }
}

class _ChannelsTab extends ConsumerWidget {
  final bool isPlatformAdmin;

  const _ChannelsTab({this.isPlatformAdmin = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(adminChannelsProvider);
    final authState = ref.watch(authProvider);
    final isAdmin = authState.isAdmin && isPlatformAdmin;

    return channelsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorView(ref, e),
      data: (channels) {
        final publicChannels = isAdmin
            ? channels.where((c) => c.isPublic).toList()
            : [];
        final personalChannels = channels.where((c) => !c.isPublic).toList();

        if (channels.isEmpty ||
            (publicChannels.isEmpty && personalChannels.isEmpty)) {
          return _buildEmptyView(
            icon: Icons.folder_open_outlined,
            title: '暂无频道',
            subtitle: isAdmin ? '点击下方按钮创建第一个频道' : '暂无个人频道',
            onAdd: () => _showChannelDialog(context, ref, null),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (publicChannels.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.public,
                      iconColor: Colors.blue,
                      title: '平台频道',
                      count: publicChannels.length,
                    ),
                    const SizedBox(height: 8),
                    ...publicChannels.map((c) => _ChannelCard(channel: c)),
                    const SizedBox(height: 24),
                  ],
                  if (personalChannels.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.person,
                      iconColor: Colors.purple,
                      title: isAdmin ? '个人频道' : '我的频道',
                      count: personalChannels.length,
                    ),
                    const SizedBox(height: 8),
                    ...personalChannels.map((c) => _ChannelCard(channel: c)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _AddButton(
                label: '创建频道',
                onPressed: () => _showChannelDialog(context, ref, null),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorView(WidgetRef ref, Object e) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('加载失败: $e', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(adminChannelsProvider),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onAdd,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (onAdd != null) _AddButton(label: '创建', onPressed: onAdd),
        ],
      ),
    );
  }

  Future<void> _showChannelDialog(
    BuildContext context,
    WidgetRef ref,
    Channel? channel,
  ) async {
    final nameController = TextEditingController(text: channel?.name ?? '');
    final descController = TextEditingController(
      text: channel?.description ?? '',
    );
    final iconUrlController = TextEditingController(
      text: channel?.iconUrl ?? '',
    );
    bool isPublic = channel?.isPublic ?? true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(channel == null ? '创建频道' : '编辑频道'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '频道名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '描述（可选）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: iconUrlController,
                  decoration: const InputDecoration(
                    labelText: '图标 URL（可选）',
                    hintText: 'https://example.com/icon.png',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('公开频道'),
                  subtitle: Text(
                    isPublic ? '其他用户可发现并订阅' : '仅自己可见',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  value: isPublic,
                  onChanged: (v) => setState(() => isPublic = v),
                  contentPadding: EdgeInsets.zero,
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
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final repo = ref.read(feedRepositoryProvider);
                try {
                  if (channel == null) {
                    await repo.createChannel(
                      name: name,
                      description: descController.text.trim().isEmpty
                          ? null
                          : descController.text.trim(),
                      isPublic: isPublic,
                      iconUrl: iconUrlController.text.trim().isEmpty
                          ? null
                          : iconUrlController.text.trim(),
                    );
                  } else {
                    await repo.updateChannel(
                      channel.id,
                      name: name,
                      description: descController.text.trim().isEmpty
                          ? null
                          : descController.text.trim(),
                      isPublic: isPublic,
                      iconUrl: iconUrlController.text.trim().isEmpty
                          ? null
                          : iconUrlController.text.trim(),
                    );
                  }
                  ref.invalidate(adminChannelsProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
                  }
                }
              },
              child: Text(channel == null ? '创建' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelCard extends ConsumerWidget {
  final Channel channel;

  const _ChannelCard({required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: () => _showSourcesSheet(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildChannelAvatar(channel),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (channel.description != null &&
                        channel.description!.isNotEmpty)
                      Text(
                        channel.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _showEditDialog(context, ref),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.red,
                ),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSourcesSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SourcesSheet(channel: channel),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController(text: channel.name);
    final descController = TextEditingController(
      text: channel.description ?? '',
    );
    final iconUrlController = TextEditingController(
      text: channel.iconUrl ?? '',
    );
    bool isPublic = channel.isPublic;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑频道'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '频道名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '描述（可选）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: iconUrlController,
                  decoration: const InputDecoration(
                    labelText: '图标 URL（可选）',
                    hintText: 'https://example.com/icon.png',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('公开频道'),
                  value: isPublic,
                  onChanged: (v) => setState(() => isPublic = v),
                  contentPadding: EdgeInsets.zero,
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
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                try {
                  final repo = ref.read(feedRepositoryProvider);
                  final iconUrlValue = iconUrlController.text.trim();
                  await repo.updateChannel(
                    channel.id,
                    name: name,
                    description: descController.text.trim().isEmpty
                        ? null
                        : descController.text.trim(),
                    isPublic: isPublic,
                    iconUrl: iconUrlValue.isEmpty ? null : iconUrlValue,
                  );
                  ref.invalidate(adminChannelsProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除频道'),
        content: Text('确定要删除 "${channel.name}" 吗？这不会删除其包含的信息源。'),
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

    if (confirm == true) {
      try {
        await ref.read(feedRepositoryProvider).deleteChannel(channel.id);
        ref.invalidate(adminChannelsProvider);
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('频道已删除')));
      } catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF3b82f6),
      const Color(0xFF10b981),
      const Color(0xFFf59e0b),
      const Color(0xFFef4444),
      const Color(0xFF8b5cf6),
      const Color(0xFFec4899),
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++)
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    return colors[hash.abs() % colors.length];
  }

  Widget _buildChannelAvatar(Channel channel, {double size = 40}) {
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
            placeholder: (_, __) => _buildLetterAvatar(channel.name, size),
            errorWidget: (_, __, ___) => _buildLetterAvatar(channel.name, size),
          ),
        ),
      );
    }
    return _buildLetterAvatar(channel.name, size);
  }

  Widget _buildLetterAvatar(String name, double size) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _avatarColor(name),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

class _SourcesSheet extends ConsumerStatefulWidget {
  final Channel channel;

  const _SourcesSheet({required this.channel});

  @override
  ConsumerState<_SourcesSheet> createState() => _SourcesSheetState();
}

class _SourcesSheetState extends ConsumerState<_SourcesSheet> {
  List<ChannelSourceItem> _sources = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(feedRepositoryProvider);
      final sources = await repo.getChannelSources(widget.channel.id);
      setState(() {
        _sources = sources;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addSource() async {
    final urlController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加订阅源'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: 'RSS/Atom URL',
            hintText: 'https://example.com/feed.xml',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, urlController.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final repo = ref.read(feedRepositoryProvider);
        await repo.addChannelSourceByUrl(widget.channel.id, result);
        _loadSources();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('添加失败: $e')));
      }
    }
  }

  Future<void> _removeSource(ChannelSourceItem source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除订阅源'),
        content: Text('确定要移除「${source.title ?? source.url}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(feedRepositoryProvider);
        await repo.removeChannelSource(widget.channel.id, source.feedId);
        _loadSources();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('移除失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFBF5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildChannelAvatar(widget.channel, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.channel.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '${_sources.length} 个订阅源',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFF8B6B4A),
                    ),
                    onPressed: _addSource,
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text('加载失败: $_error'))
                  : _sources.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.rss_feed,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '暂无订阅源，点击 + 添加',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _sources.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final source = _sources[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              child: source.faviconUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: source.faviconUrl!,
                                      placeholder: (_, __) =>
                                          const Icon(Icons.rss_feed, size: 20),
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.rss_feed, size: 20),
                                    )
                                  : const Icon(Icons.rss_feed, size: 20),
                            ),
                            title: Text(
                              source.title ?? source.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              source.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _removeSource(source),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF3b82f6),
      const Color(0xFF10b981),
      const Color(0xFFf59e0b),
      const Color(0xFFef4444),
      const Color(0xFF8b5cf6),
      const Color(0xFFec4899),
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++)
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    return colors[hash.abs() % colors.length];
  }

  Widget _buildChannelAvatar(Channel channel, {double size = 40}) {
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
            placeholder: (_, __) => _buildLetterAvatar(channel.name, size),
            errorWidget: (_, __, ___) => _buildLetterAvatar(channel.name, size),
          ),
        ),
      );
    }
    return _buildLetterAvatar(channel.name, size);
  }

  Widget _buildLetterAvatar(String name, double size) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _avatarColor(name),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

class _FeedsTab extends ConsumerStatefulWidget {
  final bool isPlatformAdmin;

  // ignore: unused_element_parameter
  const _FeedsTab({super.key, this.isPlatformAdmin = false});

  @override
  ConsumerState<_FeedsTab> createState() => _FeedsTabState();
}

class _FeedsTabState extends ConsumerState<_FeedsTab> {
  List<Feed> _feeds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFeeds();
  }

  Future<void> _loadFeeds() async {
    setState(() => _loading = true);
    try {
      final feedsAsync = ref.read(feedsProvider);
      feedsAsync.whenData((feeds) {
        setState(() {
          _feeds = feeds;
          _loading = false;
        });
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addFeed() async {
    final urlController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加订阅源'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'RSS/Atom URL',
                  hintText: 'https://example.com/feed.xml',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
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
            onPressed: () => Navigator.pop(context, urlController.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final repo = ref.read(feedRepositoryProvider);
        await repo.createFeed(url: result);
        ref.invalidate(feedsProvider);
        _loadFeeds();
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('订阅源添加成功')));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('添加失败: $e')));
      }
    }
  }

  Future<void> _deleteFeed(Feed feed) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除订阅源'),
        content: Text('确定要删除订阅源「${feed.title ?? feed.url}」吗？'),
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

    if (confirmed == true) {
      try {
        final repo = ref.read(feedRepositoryProvider);
        await repo.deleteFeed(feed.id);
        ref.invalidate(feedsProvider);
        _loadFeeds();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final displayFeeds = _feeds;

    return Column(
      children: [
        Expanded(
          child: displayFeeds.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rss_feed, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '暂无订阅源',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      _AddButton(label: '添加订阅源', onPressed: _addFeed),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayFeeds.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final feed = displayFeeds[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          child: feed.favicon != null
                              ? CachedNetworkImage(
                                  imageUrl: feed.favicon!,
                                  placeholder: (_, __) =>
                                      const Icon(Icons.rss_feed, size: 20),
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.rss_feed, size: 20),
                                )
                              : const Icon(Icons.rss_feed, size: 20),
                        ),
                        title: Text(
                          feed.title ?? feed.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          feed.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if ((feed.unreadCount ?? 0) > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE8C7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${feed.unreadCount}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8B6B4A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _deleteFeed(feed),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _AddButton(label: '添加订阅源', onPressed: _addFeed),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: iconColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _AddButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFFE8C7),
          foregroundColor: const Color(0xFF3E2F25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
