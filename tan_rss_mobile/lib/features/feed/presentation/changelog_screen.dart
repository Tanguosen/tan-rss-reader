import 'package:flutter/material.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  static const _entries = [
    _ChangelogEntry(
      version: '2026.03',
      title: '个性化推荐与专题系统',
      summary: '发现页加入更贴近日常阅读的个性化推荐入口，让内容发现更主动。',
      highlights: [
        '新增最近阅读记录，自动沉淀用户浏览历史',
        '新增我的专题，基于订阅与阅读兴趣生成推荐',
        '发现页重构为“全网趋势 / 我的专题”双入口',
      ],
      icon: Icons.auto_awesome_rounded,
    ),
    _ChangelogEntry(
      version: '2026.03',
      title: '深度搜索研究上线',
      summary: '新增研究型入口，适合围绕一个问题快速拉起背景信息和核心脉络。',
      highlights: [
        '支持输入问题发起深度搜索研究',
        '自动整理研究结论、关键发现与待观察问题',
        '结果页会附带证据文章，方便继续阅读',
      ],
      icon: Icons.manage_search_rounded,
    ),
    _ChangelogEntry(
      version: '2026.03',
      title: '阅读与收藏体验升级',
      summary: '阅读页和收藏页都做了更完整的体验优化，信息更清晰，操作更顺手。',
      highlights: [
        '阅读页补上发布时间，并优化深度解读展示',
        '收藏页升级为卡片布局，支持更清晰的信息预览',
        '最近阅读、收藏、专题页之间的跳转更顺畅',
      ],
      icon: Icons.chrome_reader_mode_rounded,
    ),
    _ChangelogEntry(
      version: '2026.03',
      title: '翻译与 AI 输出更稳定',
      summary: '翻译结果和 AI 生成内容更贴近你的语言设置，重复进入页面也更省等待。',
      highlights: [
        '深度解读会跟随 AI 生成语言输出对应内容',
        '标题、正文和趋势里的文本翻译都支持缓存',
        '重复进入页面时不再频繁触发同一段翻译',
      ],
      icon: Icons.translate_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('更新日志')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF2DE), Color(0xFFFFE2BF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFEBCB9F).withValues(alpha: 0.8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.new_releases_rounded,
                        color: Color(0xFF9A5B16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '最近大版本更新',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF5C3B1E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '这段时间的重点更新主要围绕内容发现、研究能力、阅读体验和翻译稳定性展开。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6A4B2D),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ..._entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ChangelogCard(entry: entry),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'TAN RSS 正在持续完善移动端的信息消费体验',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangelogCard extends StatelessWidget {
  final _ChangelogEntry entry;

  const _ChangelogCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    entry.icon,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          entry.version,
                          style: TextStyle(
                            color: colorScheme.onSecondaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        entry.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.summary,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            ...entry.highlights.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangelogEntry {
  final String version;
  final String title;
  final String summary;
  final List<String> highlights;
  final IconData icon;

  const _ChangelogEntry({
    required this.version,
    required this.title,
    required this.summary,
    required this.highlights,
    required this.icon,
  });
}
