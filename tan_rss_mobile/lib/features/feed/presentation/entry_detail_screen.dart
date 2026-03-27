import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/models.dart';
import '../data/feed_repository.dart';
import 'feed_providers.dart';

class EntryDetailScreen extends ConsumerStatefulWidget {
  final Entry entry;
  final List<Entry>? siblingEntries; // For swipe to change

  const EntryDetailScreen({super.key, required this.entry, this.siblingEntries});

  @override
  ConsumerState<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends ConsumerState<EntryDetailScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  List<Entry> _entries = [];

  @override
  void initState() {
    super.initState();
    if (widget.siblingEntries != null && widget.siblingEntries!.isNotEmpty) {
      _entries = widget.siblingEntries!;
      _currentIndex = _entries.indexWhere((e) => e.id == widget.entry.id);
      if (_currentIndex == -1) _currentIndex = 0;
    } else {
      _entries = [widget.entry];
      _currentIndex = 0;
    }
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(interactionSettingsProvider);
    
    if (settings.swipeToChange && _entries.length > 1) {
      return PageView.builder(
        controller: _pageController,
        itemCount: _entries.length,
        onPageChanged: (index) {
          if (settings.hapticFeedback) {
            HapticFeedback.selectionClick();
          }
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          // Pass the specific entry down
          return _EntryDetailContent(
            key: ValueKey(_entries[index].id),
            entry: _entries[index],
            onEntryUpdated: (updatedEntry) {
              setState(() {
                _entries[index] = updatedEntry;
              });
            },
          );
        },
      );
    } else {
      return _EntryDetailContent(
        entry: _entries[_currentIndex],
        onEntryUpdated: (updatedEntry) {
          setState(() {
            _entries[_currentIndex] = updatedEntry;
          });
        },
      );
    }
  }
}

class _EntryDetailContent extends ConsumerStatefulWidget {
  final Entry entry;
  final ValueChanged<Entry> onEntryUpdated;

  const _EntryDetailContent({super.key, required this.entry, required this.onEntryUpdated});

  @override
  ConsumerState<_EntryDetailContent> createState() => _EntryDetailContentState();
}

class _EntryDetailContentState extends ConsumerState<_EntryDetailContent> {
  late Entry _entry;
  bool _saving = false;
  bool _loadingSummary = false;
  bool _loadingTitleTranslation = false;
  bool _loadingContentTranslation = false;
  bool _loadingDeepDive = false;
  AiSummaryData? _aiSummary;
  String? _translatedTitle;
  String? _translatedContent;
  String? _deepDiveMarkdown;
  bool _useTranslatedTitle = true;
  bool _useTranslatedContent = true;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _markRead();
    if (_entry.starred) {
      // 自动触发收藏文章的 AI 深度研报
      Future.microtask(_generateDeepDive);
    }
  }

  Future<void> _markRead() async {
    if (_entry.read) return;
    final repository = ref.read(feedRepositoryProvider);
    await repository.markEntryRead(_entry.id, read: true);
    if (!mounted) return;
    setState(() {
      _entry = _entry.copyWith(read: true);
    });
    widget.onEntryUpdated(_entry);
  }

  Future<void> _toggleStar() async {
    if (_saving) return;

    final settings = ref.read(interactionSettingsProvider);
    if (settings.hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    final repository = ref.read(feedRepositoryProvider);
    setState(() {
      _saving = true;
    });
    final next = !_entry.starred;
    try {
      await repository.markEntryStarred(_entry.id, starred: next);
      if (!mounted) return;
      setState(() {
        _entry = _entry.copyWith(starred: next);
      });
      widget.onEntryUpdated(_entry);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _openOriginal() async {
    final settings = ref.read(interactionSettingsProvider);
    if (settings.hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    final url = _entry.url;
    if (url == null || url.isEmpty) return;
    
    if (settings.useExternalBrowser) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    }
  }

  Future<void> _generateSummary() async {
    if (_loadingSummary) return;
    setState(() {
      _loadingSummary = true;
      _aiError = null;
    });
    final repository = ref.read(feedRepositoryProvider);
    try {
      final result = await repository.summarizeEntry(entryId: _entry.id, language: 'zh');
      if (!mounted) return;
      setState(() {
        _aiSummary = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = 'AI 摘要失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSummary = false;
        });
      }
    }
  }

  Future<void> _translateTitle() async {
    if (_loadingTitleTranslation) return;
    setState(() {
      _loadingTitleTranslation = true;
      _aiError = null;
    });
    final repository = ref.read(feedRepositoryProvider);
    try {
      final title = await repository.translateTitle(entryId: _entry.id, language: 'zh');
      if (!mounted) return;
      setState(() {
        _translatedTitle = title;
        _useTranslatedTitle = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = '标题翻译失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingTitleTranslation = false;
        });
      }
    }
  }

  Future<void> _translateContent() async {
    if (_loadingContentTranslation) return;
    setState(() {
      _loadingContentTranslation = true;
      _aiError = null;
    });
    final repository = ref.read(feedRepositoryProvider);
    try {
      final content = await repository.translateContent(entryId: _entry.id, language: 'zh');
      if (!mounted) return;
      setState(() {
        _translatedContent = content;
        _useTranslatedContent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = '正文翻译失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingContentTranslation = false;
        });
      }
    }
  }

  Future<void> _generateDeepDive() async {
    if (_loadingDeepDive) return;
    setState(() {
      _loadingDeepDive = true;
      _aiError = null;
      _deepDiveMarkdown = '';
    });
    try {
      final repository = ref.read(feedRepositoryProvider);
      final stream = repository.generateDeepDiveStream(_entry.id);
      
      await for (final chunk in stream) {
        if (!mounted) return;
        setState(() {
          _deepDiveMarkdown = (_deepDiveMarkdown ?? '') + chunk;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = 'AI 深度解读失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDeepDive = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(interactionSettingsProvider);
    final rawContent = _entry.content ?? _entry.summary ?? '';
    final content = (_useTranslatedContent && (_translatedContent?.isNotEmpty ?? false))
        ? _translatedContent!
        : rawContent;
    final displayTitle = (_useTranslatedTitle && (_translatedTitle?.isNotEmpty ?? false))
        ? _translatedTitle!
        : (_entry.title ?? '无标题');

    final bool isImmersive = settings.immersiveReading;

    return Scaffold(
      appBar: isImmersive ? null : AppBar(
        title: const Text('阅读'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _toggleStar,
            icon: Icon(_entry.starred ? Icons.star : Icons.star_border),
          ),
          IconButton(
            onPressed: _openOriginal,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: SafeArea(
        top: isImmersive,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (isImmersive) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _saving ? null : _toggleStar,
                        icon: Icon(_entry.starred ? Icons.star : Icons.star_border),
                      ),
                      IconButton(
                        onPressed: _openOriginal,
                        icon: const Icon(Icons.open_in_new),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              displayTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          const SizedBox(height: 10),
          Text(
            '${_entry.feedTitle ?? ''}  ${_entry.author ?? ''}'.trim(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _loadingSummary ? null : _generateSummary,
                icon: _loadingSummary
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('AI 摘要'),
              ),
              FilledButton.tonalIcon(
                onPressed: _loadingTitleTranslation ? null : _translateTitle,
                icon: _loadingTitleTranslation
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.translate),
                label: const Text('翻译标题'),
              ),
              FilledButton.tonalIcon(
                onPressed: _loadingContentTranslation ? null : _translateContent,
                icon: _loadingContentTranslation
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.g_translate),
                label: const Text('翻译正文'),
              ),
              FilledButton.tonalIcon(
                onPressed: _loadingDeepDive ? null : _generateDeepDive,
                icon: _loadingDeepDive
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.manage_search),
                label: const Text('深度解读'),
              ),
            ],
          ),
          if (_translatedTitle != null) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              value: _useTranslatedTitle,
              contentPadding: EdgeInsets.zero,
              title: const Text('显示翻译标题'),
              onChanged: (value) {
                setState(() {
                  _useTranslatedTitle = value;
                });
              },
            ),
          ],
          if (_translatedContent != null)
            SwitchListTile(
              value: _useTranslatedContent,
              contentPadding: EdgeInsets.zero,
              title: const Text('显示翻译正文'),
              onChanged: (value) {
                setState(() {
                  _useTranslatedContent = value;
                });
              },
            ),
          if (_aiSummary != null) ...[
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 摘要',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(_aiSummary!.summary),
                    if (_aiSummary!.keyPoints.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._aiSummary!.keyPoints.map((point) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $point'),
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (_deepDiveMarkdown != null && _deepDiveMarkdown!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: const Color(0xFFF6F2EC),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.psychology, color: Color(0xFFB08968)),
                        const SizedBox(width: 8),
                        Text(
                          'AI 深度解读',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFB08968),
                              ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFFE6DED5)),
                    MarkdownBody(
                      data: _deepDiveMarkdown!,
                      styleSheet: MarkdownStyleSheet(
                        h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.5),
                        p: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.6),
                        listBullet: const TextStyle(color: Color(0xFFB08968)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_aiError != null) ...[
            const SizedBox(height: 8),
            Text(
              _aiError!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 20),
          if (content.isEmpty)
            const Text('暂无内容')
          else
            Html(
              data: content,
              style: {
                'body': Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                  lineHeight: const LineHeight(1.7),
                  fontSize: FontSize(16),
                ),
                'p': Style(
                  margin: Margins.only(bottom: 16),
                ),
                'img': Style(
                  display: Display.block,
                  width: Width.auto(),
                  margin: Margins.symmetric(vertical: 10),
                  border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
                ),
                'blockquote': Style(
                  padding: HtmlPaddings.all(12),
                  margin: Margins.only(bottom: 16),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(
                    left: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
                'pre': Style(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  padding: HtmlPaddings.all(12),
                ),
                'code': Style(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  padding: HtmlPaddings.symmetric(horizontal: 6, vertical: 3),
                ),
                'a': Style(
                  color: Theme.of(context).colorScheme.primary,
                  textDecoration: TextDecoration.underline,
                ),
              },
              onLinkTap: (url, attributes, element) async {
                if (url == null || url.isEmpty) return;
                if (settings.useExternalBrowser) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
                }
              },
            ),
        ],
      ),
      ),
    );
  }
}
