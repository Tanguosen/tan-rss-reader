import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/models/models.dart';
import '../data/feed_repository.dart';
import 'entry_detail_screen.dart';
import 'feed_providers.dart';

class StarredScreen extends ConsumerWidget {
  final bool showHeader;

  const StarredScreen({super.key, this.showHeader = true});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starredAsync = ref.watch(starredEntriesProvider);

    return Column(
      children: [
        if (showHeader)
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
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: starredAsync.maybeWhen(
                    data: (entries) => Text(
                      '${entries.length} 篇',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    orElse: () => const Text(
                      '...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                return const _EmptyState(
                  icon: Icons.star_border_rounded,
                  title: '还没有收藏的文章',
                  subtitle: '点击文章右上角星标后，会出现在这里',
                );
              }
              return RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _StarredCard(
                    entry: entries[index],
                    onToggleStar: () => _toggleStar(ref, entries[index]),
                    siblingEntries: entries,
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message: '加载收藏失败: $error',
              onRetry: () => ref.invalidate(starredEntriesProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _StarredCard extends StatelessWidget {
  final Entry entry;
  final VoidCallback onToggleStar;
  final List<Entry> siblingEntries;

  const _StarredCard({
    required this.entry,
    required this.onToggleStar,
    required this.siblingEntries,
  });

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      return timeago.format(DateTime.parse(dateStr), locale: 'zh_CN');
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = entry.translatedTitle ?? entry.title ?? '无标题';
    final summary = (entry.summary ?? '').trim();
    final dateLabel = _formatDate(entry.publishedAt ?? entry.insertedAt);
    final hasSummary = summary.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                EntryDetailScreen(entry: entry, siblingEntries: siblingEntries),
          ),
        );
      },
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: onToggleStar,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF2E2),
                    foregroundColor: const Color(0xFFD48806),
                  ),
                  icon: const Icon(Icons.star_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.rss_feed_rounded,
                  label: entry.feedTitle ?? '未知来源',
                  color: Theme.of(context).colorScheme.primary,
                ),
                if (dateLabel.isNotEmpty)
                  _MetaChip(
                    icon: Icons.schedule_rounded,
                    label: dateLabel,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                _MetaChip(
                  icon: entry.read
                      ? Icons.mark_email_read_rounded
                      : Icons.mark_email_unread_rounded,
                  label: entry.read ? '已读' : '未读',
                  color: entry.read
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            if (hasSummary) ...[
              const SizedBox(height: 12),
              Text(
                summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: Colors.grey),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
