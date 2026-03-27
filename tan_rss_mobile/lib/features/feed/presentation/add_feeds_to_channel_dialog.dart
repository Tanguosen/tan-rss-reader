import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../data/feed_repository.dart';

class AddFeedsToChannelDialog extends ConsumerStatefulWidget {
  final String channelId;
  const AddFeedsToChannelDialog({Key? key, required this.channelId})
    : super(key: key);

  @override
  _AddFeedsToChannelDialogState createState() =>
      _AddFeedsToChannelDialogState();
}

class _AddFeedsToChannelDialogState
    extends ConsumerState<AddFeedsToChannelDialog> {
  late Future<List<Feed>> _channelFeedsFuture;
  late Future<List<Feed>> _userFeedsFuture;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final repo = ref.read(feedRepositoryProvider);
    _channelFeedsFuture = repo.getChannelFeeds(widget.channelId);
    _userFeedsFuture = repo.getUserSubscribedFeeds();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<Feed>>>(
      future: Future.wait([_channelFeedsFuture, _userFeedsFuture]),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return AlertDialog(
            title: Text('添加订阅源到频道'),
            content: Center(child: CircularProgressIndicator()),
          );
        }
        final channelFeeds = snapshot.data![0];
        final userFeeds = snapshot.data![1];
        final addable = userFeeds
            .where((f) => !channelFeeds.any((cf) => cf.id == f.id))
            .toList();
        if (addable.isEmpty) {
          return AlertDialog(
            title: const Text('添加订阅源到频道'),
            content: const Text('暂无可添加的订阅源'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('关闭'),
              ),
            ],
          );
        }
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('添加订阅源'),
              content: Container(
                width: double.maxFinite,
                height: 320,
                child: ListView.builder(
                  itemCount: addable.length,
                  itemBuilder: (context, i) {
                    final f = addable[i];
                    final checked = _selected.contains(f.id);
                    return CheckboxListTile(
                      value: checked,
                      title: Text(f.title ?? f.url),
                      subtitle: Text(f.url),
                      onChanged: (v) {
                        setState(() {
                          if (v == true)
                            _selected.add(f.id);
                          else
                            _selected.remove(f.id);
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () async {
                          final repo = ref.read(feedRepositoryProvider);
                          await repo.addFeedsToChannel(
                            widget.channelId,
                            _selected.toList(),
                          );
                          Navigator.pop(context, true);
                        },
                  child: const Text('添加选中源'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
