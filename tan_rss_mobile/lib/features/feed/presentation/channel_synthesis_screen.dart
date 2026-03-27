import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/models/models.dart';
import '../data/feed_repository.dart';
import 'entry_detail_screen.dart';

class ChannelSynthesisScreen extends ConsumerStatefulWidget {
  final Channel channel;
  final List<Entry> entries;

  const ChannelSynthesisScreen({
    super.key,
    required this.channel,
    required this.entries,
  });

  @override
  ConsumerState<ChannelSynthesisScreen> createState() => _ChannelSynthesisScreenState();
}

class _ChannelSynthesisScreenState extends ConsumerState<ChannelSynthesisScreen> {
  String _markdown = '';
  List<SynthesisReference> _references = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSynthesis();
  }

  Future<void> _loadSynthesis() async {
    setState(() {
      _loading = true;
      _error = null;
      _markdown = '';
      _references = [];
    });
    try {
      final repository = ref.read(feedRepositoryProvider);
      final entryIds = widget.entries.take(25).map((e) => e.id).toList();
      if (entryIds.isEmpty) {
        throw Exception('没有可分析的文章');
      }
      
      final stream = repository.generateSynthesisStream(
        entryIds,
        onReferences: (refs) {
          if (mounted) {
            setState(() {
              _references = refs;
            });
          }
        },
      );

      await for (final chunk in stream) {
        if (!mounted) return;
        setState(() {
          if (_loading) _loading = false;
          _markdown += chunk;
        });
      }
      
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onTapReference(String refId) {
    if (_references.isEmpty) return;
    
    // refId might be "ref:1", extract the number
    final match = RegExp(r'ref:(\d+)').firstMatch(refId);
    if (match != null) {
      final index = int.tryParse(match.group(1)!);
      if (index != null) {
        // Find reference
        try {
          final reference = _references.firstWhere((r) => r.index == index);
          // Show bottom sheet with reference info
          _showReferenceBottomSheet(reference);
        } catch (_) {
          // reference not found
        }
      }
    }
  }

  void _showReferenceBottomSheet(SynthesisReference reference) {
    // Find corresponding entry from widget.entries
    final entry = widget.entries.firstWhere(
      (e) => e.id == reference.id,
      orElse: () => Entry(
        id: reference.id,
        feedId: '',
        title: reference.title,
        url: reference.url,
        read: true,
        starred: false,
      ),
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '引用 [${reference.index}]',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              reference.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            if (entry.summary != null && entry.summary!.isNotEmpty) ...[
              Text(
                entry.summary!.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EntryDetailScreen(entry: entry),
                    ),
                  );
                },
                icon: const Icon(Icons.menu_book),
                label: const Text('阅读原文'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7), // Cream background
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
        title: const Text(
          'AI 聚合',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('即将推出 TTS 朗读功能')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(
            color: const Color(0xFFE6DED5),
            height: 1,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFB08968)),
            const SizedBox(height: 24),
            Text(
              '正在阅读 ${widget.channel.name} 近期文章...\nAI 正在为您生成聚合分析报告',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                '生成失败\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loadSynthesis,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB08968)),
                child: const Text('重新生成'),
              ),
            ],
          ),
        ),
      );
    }

    if (_markdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Markdown(
      data: _markdown,
      padding: const EdgeInsets.all(24),
      onTapLink: (text, href, title) {
        if (href != null && href.startsWith('ref:')) {
          _onTapReference(href);
        }
      },
      styleSheet: MarkdownStyleSheet(
        h1: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: Colors.black87,
          height: 1.4,
        ),
        h2: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
          height: 1.5,
        ),
        h3: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        p: const TextStyle(
          fontSize: 16,
          color: Color(0xFF333333),
          height: 1.8,
          letterSpacing: 0.5,
        ),
        a: const TextStyle(
          color: Color(0xFFB08968),
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
        blockquote: const TextStyle(
          color: Color(0xFF666666),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: const Color(0xFFB08968), width: 4),
          ),
          color: const Color(0xFFF6F2EC),
        ),
        listBullet: const TextStyle(
          color: Color(0xFFB08968),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}