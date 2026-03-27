import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/models/models.dart';
import '../data/feed_repository.dart';
import 'entry_detail_screen.dart';

class DailyDigestScreen extends ConsumerStatefulWidget {
  final List<Entry> entries;

  const DailyDigestScreen({
    super.key,
    required this.entries,
  });

  @override
  ConsumerState<DailyDigestScreen> createState() => _DailyDigestScreenState();
}

class _DailyDigestScreenState extends ConsumerState<DailyDigestScreen> {
  String _markdown = '';
  List<SynthesisReference> _references = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDigest();
  }

  Future<void> _loadDigest({bool forceRegenerate = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (forceRegenerate) {
        _markdown = '';
        _references = [];
      }
    });
    try {
      final repository = ref.read(feedRepositoryProvider);
      
      if (!forceRegenerate) {
        try {
          final digest = await repository.getTodayDigest();
          if (digest.exists && digest.content != null && digest.content!.isNotEmpty) {
            if (mounted) {
              setState(() {
                _markdown = digest.content!;
                _references = digest.references;
                _loading = false;
              });
            }
            return;
          }
        } catch (e) {
          // ignore error and fallback to generate
        }
      }

      final entryIds = widget.entries.take(50).map((e) => e.id).toList();
      if (entryIds.isEmpty) {
        throw Exception('暂无最新文章可供生成简报');
      }
      
      if (forceRegenerate && mounted) {
        setState(() {
          _markdown = '';
          _references = [];
        });
      }
      
      final stream = repository.generateDailyDigestStream(
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
    
    final match = RegExp(r'ref:(\d+)').firstMatch(refId);
    if (match != null) {
      final index = int.tryParse(match.group(1)!);
      if (index != null) {
        try {
          final reference = _references.firstWhere((r) => r.index == index);
          _showReferenceBottomSheet(reference);
        } catch (_) {
          // not found
        }
      }
    }
  }

  void _showReferenceBottomSheet(SynthesisReference reference) {
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
                    '来源 [${reference.index}]',
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
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
        title: const Text(
          'AI 每日简报',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重新生成',
              onPressed: () => _loadDigest(forceRegenerate: true),
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
              '正在阅读所有未读文章...\nAI 编辑部正在为您撰写今日简报',
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
                onPressed: () => _loadDigest(forceRegenerate: true),
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
        listBullet: const TextStyle(
          color: Color(0xFFB08968),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}