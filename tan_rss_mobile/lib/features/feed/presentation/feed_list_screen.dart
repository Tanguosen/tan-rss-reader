import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter/services.dart';
import '../../../core/models/models.dart';
import '../data/feed_repository.dart';
import 'entry_detail_screen.dart';
import 'feed_providers.dart';
import 'daily_digest_screen.dart';
import 'starred_page.dart';

class FeedListScreen extends ConsumerStatefulWidget {
  const FeedListScreen({super.key});

  @override
  ConsumerState<FeedListScreen> createState() => _FeedListScreenState();
}

class _FeedListScreenState extends ConsumerState<FeedListScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Entry> _items = [];
  final Set<String> _selectedIds = {};
  String? _feedId;
  final String _orderBy = 'created_at';
  final String _order = 'desc';
  final String _searchText = '';
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorText;
  int _offset = 0;
  int get _pageSize {
    return ref.read(interactionSettingsProvider).pageSize;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _reload();
    // Listen for changes in selectedFeedId to reload deterministically
    ref.listen<String?>(selectedFeedIdProvider, (prev, next) {
      if (prev != next) {
        _feedId = next;
        Future.microtask(_reload);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;

    // Auto mark as read on scroll
    final settings = ref.read(interactionSettingsProvider);
    if (settings.scrollMarkRead && _items.isNotEmpty) {
      // 简单估算：每篇文章大约占据 120 逻辑像素，划过时标记
      final index = (position.pixels / 120).floor();
      if (index >= 0 && index < _items.length) {
        final entry = _items[index];
        if (!entry.read) {
          _markRead(entry, true);
        }
      }
    }

    if (position.pixels > position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _isInitialLoading = true;
      _errorText = null;
      _offset = 0;
      _hasMore = true;
      _items = [];
      _selectedIds.clear();
    });
    try {
      final repository = ref.read(feedRepositoryProvider);
      final unreadOnly = ref.read(unreadOnlyProvider);
      final highQualityOnly = ref.read(highQualityOnlyProvider);
      final rows = await repository.getEntriesByQuery(
        EntryQuery(
          feedId: _feedId,
          unreadOnly: unreadOnly,
          highQualityOnly: highQualityOnly,
          limit: _pageSize,
          offset: 0,
          orderBy: _orderBy,
          order: _order,
          searchText: _searchText,
        ),
      );
      if (!mounted) return;
      setState(() {
        _items = rows;
        _offset = rows.length;
        _hasMore = rows.length >= _pageSize;
        _isInitialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.toString();
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isInitialLoading) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final repository = ref.read(feedRepositoryProvider);
      final unreadOnly = ref.read(unreadOnlyProvider);
      final highQualityOnly = ref.read(highQualityOnlyProvider);
      final rows = await repository.getEntriesByQuery(
        EntryQuery(
          feedId: _feedId,
          unreadOnly: unreadOnly,
          highQualityOnly: highQualityOnly,
          limit: _pageSize,
          offset: _offset,
          orderBy: _orderBy,
          order: _order,
          searchText: _searchText,
        ),
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...rows];
        _offset += rows.length;
        _hasMore = rows.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _markRead(Entry entry, bool read) async {
    final settings = ref.read(interactionSettingsProvider);
    if (settings.hapticFeedback) {
      HapticFeedback.selectionClick();
    }
    final repository = ref.read(feedRepositoryProvider);
    await repository.markEntryRead(entry.id, read: read);
    setState(() {
      _items = _items.map((e) {
        if (e.id == entry.id) {
          return e.copyWith(read: read);
        }
        return e;
      }).toList();
    });
  }

  Future<void> _toggleStar(Entry entry) async {
    final settings = ref.read(interactionSettingsProvider);
    if (settings.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    final repository = ref.read(feedRepositoryProvider);
    final nextStarred = !entry.starred;
    await repository.markEntryStarred(entry.id, starred: nextStarred);
    setState(() {
      _items = _items.map((e) {
        if (e.id == entry.id) {
          return e.copyWith(starred: nextStarred);
        }
        return e;
      }).toList();
    });
  }

  Future<void> _openDetail(Entry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntryDetailScreen(entry: entry, siblingEntries: _items),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  Widget _buildDailyDigestFab() {
    return FloatingActionButton.extended(
      onPressed: () {
        if (_items.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('当前没有文章可供生成简报')));
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DailyDigestScreen(entries: _items)),
        );
      },
      icon: const Icon(Icons.auto_awesome, color: Colors.black87),
      label: const Text(
        'AI 简报',
        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
      ),
      backgroundColor: const Color(0xFFFFE8C7),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reload is driven by provider listener above; avoid duplication here
    final inBatchMode = _selectedIds.isNotEmpty;
    final settings = ref.watch(interactionSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Text(
                  '文章',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (!inBatchMode)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_items.isNotEmpty) {
                          _selectedIds.add(_items.first.id);
                        }
                      });
                    },
                    icon: const Icon(Icons.checklist),
                    label: const Text('批量操作'),
                  ),
                IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            color: Colors.transparent,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('未读'),
                  selected: ref.watch(unreadOnlyProvider),
                  onSelected: (val) {
                    ref.read(unreadOnlyProvider.notifier).setValue(val);
                    _reload();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text(
                    '精选',
                    style: TextStyle(color: Colors.orange),
                  ),
                  selected: ref.watch(highQualityOnlyProvider),
                  selectedColor: Colors.orange.withValues(alpha: 0.2),
                  onSelected: (val) {
                    ref.read(highQualityOnlyProvider.notifier).setValue(val);
                    _reload();
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: const Text(
                    '收藏',
                    style: TextStyle(color: Colors.amber),
                  ),
                  avatar: const Icon(Icons.star, color: Colors.amber, size: 18),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StarredPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          if (inBatchMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text('已选 ${_selectedIds.length} 项'),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final repository = ref.read(feedRepositoryProvider);
                      await repository.bulkMarkStarred(
                        _selectedIds.toList(),
                        starred: true,
                      );
                      await _reload();
                    },
                    child: const Text('批量收藏'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final repository = ref.read(feedRepositoryProvider);
                      await repository.bulkMarkStarred(
                        _selectedIds.toList(),
                        starred: false,
                      );
                      await _reload();
                    },
                    child: const Text('批量取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedIds.clear();
                      });
                    },
                    child: const Text('取消选择'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorText != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '加载失败',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorText!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: _reload,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _items.isEmpty
                ? const Center(child: Text('当前条件下没有文章'))
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.separated(
                      controller: _scrollController,
                      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final entry = _items[index];
                        final subtitle =
                            '${entry.feedTitle ?? ''} · ${_formatDate(entry.publishedAt ?? entry.insertedAt)}';
                        final selected = _selectedIds.contains(entry.id);
                        final thumbnail = entry.thumbnail;
                        return _EntryCard(
                          entry: entry,
                          subtitle: subtitle,
                          selected: selected,
                          inBatchMode: inBatchMode,
                          thumbnail: thumbnail,
                          onTap: () {
                            if (inBatchMode) {
                              setState(() {
                                if (selected) {
                                  _selectedIds.remove(entry.id);
                                } else {
                                  _selectedIds.add(entry.id);
                                }
                              });
                              return;
                            }
                            _openDetail(entry);
                          },
                          onLongPress: () {
                            setState(() {
                              _selectedIds.add(entry.id);
                            });
                          },
                          onCheckboxChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedIds.add(entry.id);
                              } else {
                                _selectedIds.remove(entry.id);
                              }
                            });
                          },
                          onMarkRead: () => _markRead(entry, true),
                          onMarkUnread: () => _markRead(entry, false),
                          onToggleStar: () => _toggleStar(entry),
                          onSelect: () {
                            setState(() {
                              _selectedIds.add(entry.id);
                            });
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: settings.fabPosition == 'Hidden'
          ? null
          : Padding(
              padding: settings.fabPosition == 'Left'
                  ? const EdgeInsets.only(left: 32)
                  : EdgeInsets.zero,
              child: Align(
                alignment: settings.fabPosition == 'Left'
                    ? Alignment.bottomLeft
                    : Alignment.bottomRight,
                child: _buildDailyDigestFab(),
              ),
            ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return timeago.format(date, locale: 'zh');
    } catch (_) {
      return '';
    }
  }
}

class _EntryCard extends ConsumerStatefulWidget {
  final Entry entry;
  final String subtitle;
  final bool selected;
  final bool inBatchMode;
  final String? thumbnail;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool?> onCheckboxChanged;
  final VoidCallback onMarkRead;
  final VoidCallback onMarkUnread;
  final VoidCallback onToggleStar;
  final VoidCallback onSelect;

  const _EntryCard({
    required this.entry,
    required this.subtitle,
    required this.selected,
    required this.inBatchMode,
    this.thumbnail,
    required this.onTap,
    required this.onLongPress,
    required this.onCheckboxChanged,
    required this.onMarkRead,
    required this.onMarkUnread,
    required this.onToggleStar,
    required this.onSelect,
  });

  @override
  ConsumerState<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends ConsumerState<_EntryCard> {
  String? _translatedTitle;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _translatedTitle = widget.entry.translatedTitle;
  }

  @override
  void didUpdateWidget(_EntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.id != oldWidget.entry.id) {
      _translatedTitle = widget.entry.translatedTitle;
      _isTranslating = false;
    }
  }

  void _checkAutoTranslate() {
    if (_translatedTitle != null ||
        _isTranslating ||
        (widget.entry.title == null))
      return;

    final aiConfigAsync = ref.read(aiConfigProvider);
    if (aiConfigAsync.hasValue) {
      final aiConfig = aiConfigAsync.value!;
      if (aiConfig.features.autoTitleTranslation) {
        _doTranslate();
      }
    }
  }

  Future<void> _doTranslate() async {
    setState(() {
      _isTranslating = true;
    });
    try {
      final repository = ref.read(feedRepositoryProvider);
      final aiConfig = ref.read(aiConfigProvider).value;
      final targetLang = aiConfig?.features.translationLanguage ?? 'zh';
      final res = await repository.translateTitle(
        entryId: widget.entry.id,
        language: targetLang,
      );
      if (mounted) {
        setState(() {
          _translatedTitle = res;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check auto translate in build so it reacts to config changes if needed
    // But we need to watch aiConfigProvider to trigger rebuild
    final aiConfigAsync = ref.watch(aiConfigProvider);
    if (aiConfigAsync.hasValue &&
        aiConfigAsync.value!.features.autoTitleTranslation) {
      Future.microtask(_checkAutoTranslate);
    }

    final appearance = ref.watch(appearanceSettingsProvider);
    final hasThumbnail =
        widget.thumbnail != null && widget.thumbnail!.isNotEmpty;
    final displayTitle = _translatedTitle ?? widget.entry.title ?? '无标题';

    if (appearance.viewMode == 'card') {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: widget.selected
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasThumbnail)
                CachedNetworkImage(
                  imageUrl: widget.thumbnail!,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  placeholder: (_, __) => Container(
                    height: 160,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.inBatchMode) ...[
                          Checkbox(
                            value: widget.selected,
                            onChanged: widget.onCheckboxChanged,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            displayTitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: widget.entry.read
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_isTranslating)
                          const Padding(
                            padding: EdgeInsets.only(left: 8, top: 4),
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (widget.entry.starred)
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        _buildPopupMenu(context),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (appearance.viewMode == 'magazine' && hasThumbnail) {
      return InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: widget.selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.inBatchMode)
                Checkbox(
                  value: widget.selected,
                  onChanged: widget.onCheckboxChanged,
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: widget.thumbnail!,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: widget.entry.read
                            ? FontWeight.w500
                            : FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (widget.entry.starred)
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                        if (_isTranslating)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        const Spacer(),
                        _buildPopupMenu(context),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListTile(
      selected: widget.selected,
      selectedTileColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.08),
      leading: widget.inBatchMode
          ? Checkbox(
              value: widget.selected,
              onChanged: widget.onCheckboxChanged,
            )
          : null,
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: widget.entry.read
                    ? FontWeight.w500
                    : FontWeight.w700,
              ),
            ),
          ),
          if (_isTranslating)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 4),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      subtitle: Text(
        widget.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _buildPopupMenu(context),
      onLongPress: widget.onLongPress,
      onTap: widget.onTap,
    );
  }

  Widget _buildPopupMenu(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'read') {
          widget.onMarkRead();
        } else if (value == 'unread') {
          widget.onMarkUnread();
        } else if (value == 'star') {
          widget.onToggleStar();
        } else if (value == 'select') {
          widget.onSelect();
        } else if (value == 'translate') {
          _doTranslate();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: widget.entry.read ? 'unread' : 'read',
          child: Text(widget.entry.read ? '标记未读' : '标记已读'),
        ),
        PopupMenuItem<String>(
          value: 'star',
          child: Text(widget.entry.starred ? '取消收藏' : '收藏'),
        ),
        const PopupMenuItem<String>(value: 'select', child: Text('加入批量')),
        if (_translatedTitle == null && !_isTranslating)
          const PopupMenuItem<String>(value: 'translate', child: Text('翻译标题')),
      ],
    );
  }
}
