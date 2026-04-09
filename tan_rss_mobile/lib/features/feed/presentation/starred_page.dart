import 'package:flutter/material.dart';

import 'starred_screen.dart';

class StarredPage extends StatelessWidget {
  const StarredPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('收藏')),
      body: const SafeArea(child: StarredScreen(showHeader: false)),
    );
  }
}
