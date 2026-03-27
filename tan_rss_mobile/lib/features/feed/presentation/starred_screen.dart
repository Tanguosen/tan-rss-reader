import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/models/models.dart';
import '../data/feed_repository.dart';
import 'entry_detail_screen.dart';
import 'feed_providers.dart';

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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
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
                  separatorBuilder: (context, index) => const Divider(height: 1),
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
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EntryDetailScreen(entry: entry, siblingEntries: entries),
                          ),
                        );
                        // Refresh when returning in case starred status changed
                        ref.invalidate(starredEntriesProvider);
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(error.toString(), textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
