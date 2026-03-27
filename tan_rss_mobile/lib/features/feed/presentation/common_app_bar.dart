import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_screen.dart';
import 'channel_square_screen.dart';
import 'add_feed_screen.dart';

class CommonAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final bool showFolderIcon;
  final bool showAddIcon;
  final List<Widget>? actions;

  const CommonAppBar({
    super.key,
    this.title = 'TAN RSS',
    this.showFolderIcon = true,
    this.showAddIcon = true,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _openChannelSquare(BuildContext context, WidgetRef ref) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChannelSquareScreen()));
  }

  void _openAddFeed(BuildContext context, WidgetRef ref) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddFeedScreen()));
  }

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      leading: IconButton(
        onPressed: () => _openSettings(context),
        icon: const Icon(Icons.settings_outlined),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      centerTitle: true,
      actions: [
        if (showFolderIcon)
          IconButton(
            onPressed: () => _openChannelSquare(context, ref),
            icon: const Icon(Icons.folder_open_outlined),
          ),
        if (showAddIcon)
          IconButton(
            onPressed: () => _openAddFeed(context, ref),
            icon: const Icon(Icons.add),
          ),
        if (actions != null) ...actions!,
      ],
    );
  }
}
