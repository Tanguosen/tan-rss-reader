import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../data/feed_repository.dart';
import 'feed_providers.dart';
import 'add_feeds_to_channel_dialog.dart';

class AdminChannelsScreen extends ConsumerStatefulWidget {
  const AdminChannelsScreen({super.key});

  @override
  ConsumerState<AdminChannelsScreen> createState() =>
      _AdminChannelsScreenState();
}

class _AdminChannelsScreenState extends ConsumerState<AdminChannelsScreen> {
  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(adminChannelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('频道管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: channelsAsync.when(
        data: (channels) {
          if (channels.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无频道', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text(
                    '点击右下角 + 创建新频道',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          final grouped = <String?, List<Channel>>{};
          for (final ch in channels) {
            grouped.putIfAbsent(ch.categoryId, () => []).add(ch);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminChannelsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: grouped.entries.map((entry) {
                final categoryId = entry.key;
                final categoryChannels = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (categoryId != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          categoryId,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ),
                    ...categoryChannels.map(
                      (ch) => _ChannelListItem(
                        channel: ch,
                        onEdit: () => _showEditDialog(ch),
                        onDelete: () => _deleteChannel(ch),
                        onManageSources: () => _manageSources(ch),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }).toList(),
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
                onPressed: () => ref.invalidate(adminChannelsProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('创建频道'),
        content: Column(
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
              maxLines: 3,
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
    if (nameController.text.trim().isEmpty) return;

    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.createChannel(
        name: nameController.text.trim(),
        description: descController.text.trim().isEmpty
            ? null
            : descController.text.trim(),
      );
      ref.invalidate(adminChannelsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('频道创建成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('创建失败: $e')));
      }
    }
  }

  Future<void> _showEditDialog(Channel channel) async {
    final nameController = TextEditingController(text: channel.name);
    final descController = TextEditingController(
      text: channel.description ?? '',
    );
    final iconUrlController = TextEditingController(
      text: channel.iconUrl ?? '',
    );
    final coverUrlController = TextEditingController(
      text: channel.coverUrl ?? '',
    );
    bool isPublic = channel.isPublic;
    String? selectedCategoryId = channel.categoryId;

    // Load categories
    List<Category> categories = [];
    try {
      final repository = ref.read(feedRepositoryProvider);
      categories = await repository.getPublicCategories();
    } catch (e) {
      // Ignore error, just show empty categories
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
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
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: iconUrlController,
                  decoration: const InputDecoration(
                    labelText: '图标URL（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: coverUrlController,
                  decoration: const InputDecoration(
                    labelText: '封面URL（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (categories.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: '分类（可选）',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('无分类'),
                      ),
                      ...categories.map(
                        (cat) => DropdownMenuItem<String>(
                          value: cat.id,
                          child: Text(cat.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedCategoryId = value;
                      });
                    },
                  ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('公开频道'),
                  subtitle: Text(isPublic ? '所有用户可见' : '仅自己可见'),
                  value: isPublic,
                  onChanged: (value) {
                    setState(() {
                      isPublic = value;
                    });
                  },
                ),
              ],
            ),
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
    if (nameController.text.trim().isEmpty) return;

    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.updateChannel(
        channel.id,
        name: nameController.text.trim(),
        description: descController.text.trim().isEmpty
            ? null
            : descController.text.trim(),
        iconUrl: iconUrlController.text.trim().isEmpty
            ? null
            : iconUrlController.text.trim(),
        coverUrl: coverUrlController.text.trim().isEmpty
            ? null
            : coverUrlController.text.trim(),
        isPublic: isPublic,
        categoryId: selectedCategoryId,
      );
      ref.invalidate(adminChannelsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('频道更新成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    }
  }

  Future<void> _deleteChannel(Channel channel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除频道'),
        content: Text('确定删除频道 "${channel.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.deleteChannel(channel.id);
      ref.invalidate(adminChannelsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('频道已删除')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  Future<void> _manageSources(Channel channel) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChannelSourcesScreen(channel: channel),
      ),
    );
  }
}

class _ChannelListItem extends StatelessWidget {
  final Channel channel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onManageSources;

  const _ChannelListItem({
    required this.channel,
    required this.onEdit,
    required this.onDelete,
    required this.onManageSources,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          backgroundImage: channel.coverUrl != null
              ? NetworkImage(channel.coverUrl!)
              : null,
          child: channel.coverUrl == null
              ? Text(
                  channel.name.isNotEmpty ? channel.name[0].toUpperCase() : '?',
                )
              : null,
        ),
        title: Text(channel.name),
        subtitle: Text(
          channel.description ?? '暂无描述',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'sources') onManageSources();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(value: 'sources', child: Text('管理订阅源')),
            PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
      ),
    );
  }
}

class _ChannelSourcesScreen extends ConsumerStatefulWidget {
  final Channel channel;

  const _ChannelSourcesScreen({required this.channel});

  @override
  ConsumerState<_ChannelSourcesScreen> createState() =>
      _ChannelSourcesScreenState();
}

class _ChannelSourcesScreenState extends ConsumerState<_ChannelSourcesScreen> {
  List<ChannelSourceItem>? _sources;
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
      final repository = ref.read(feedRepositoryProvider);
      final sources = await repository.getChannelSources(widget.channel.id);
      if (!mounted) return;
      setState(() {
        _sources = sources;
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
      appBar: AppBar(title: Text('${widget.channel.name} - 订阅源')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('加载失败: $_error'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadSources,
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : _sources == null || _sources!.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rss_feed_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无订阅源', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text(
                    '点击右下角 + 添加订阅源',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSources,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sources!.length,
                itemBuilder: (context, index) {
                  final source = _sources![index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade100,
                        child: Icon(Icons.rss_feed, color: Colors.red.shade400),
                      ),
                      title: Text(source.title ?? '无标题'),
                      subtitle: Text(
                        source.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSourceDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddSourceDialog() async {
    // Phase 3: Use dedicated dialog to load user subscriptions and channel sources
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddFeedsToChannelDialog(channelId: widget.channel.id),
    );
    if (added == true) {
      await _loadSources();
    }
  }

  Future<void> _removeSource(ChannelSourceItem source) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('移除订阅源'),
        content: Text('确定从频道中移除 "${source.title ?? source.url}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.removeChannelSource(widget.channel.id, source.feedId);
      await _loadSources();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('订阅源已移除')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('移除失败: $e')));
      }
    }
  }
}
