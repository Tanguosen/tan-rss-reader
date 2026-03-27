import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feed_providers.dart';
import 'entry_detail_screen.dart';

// Dedicated Favorites (Starred) Page
class StarredPage extends ConsumerWidget {
  const StarredPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starredAsync = ref.watch(starredEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('收藏')),
      body: starredAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('暂无收藏'));
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (ctx, i) {
              final e = entries[i];
              return ListTile(
                title: Text(e.title ?? e.feedTitle ?? ''),
                subtitle: Text(e.feedTitle ?? ''),
                onTap: () {
                  final entry = e;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EntryDetailScreen(entry: entry),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载收藏失败: $err')),
      ),
    );
  }
}
