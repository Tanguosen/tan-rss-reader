import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const SizedBox(height: 32),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: 96,
                height: 96,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'TAN RSS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'v1.0.0',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 48),
          const Text(
            '一个现代化的AI-RSS阅读器，支持AI摘要、智能翻译和优雅的阅读体验。',
            style: TextStyle(fontSize: 16, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Text(
            'TAN 致力于为你的信息流带来清爽高效的阅读体验。',
            style: TextStyle(fontSize: 16, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TAN = Trend · Awareness · Network',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  '（趋势 · 认知 · 网络）',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
                SizedBox(height: 16),
                Text(
                  'Trend：前沿趋势、最新研究、技术动向',
                  style: TextStyle(fontSize: 15, height: 1.7),
                ),
                SizedBox(height: 10),
                Text(
                  'Awareness：认知觉察、理解、判断',
                  style: TextStyle(fontSize: 15, height: 1.7),
                ),
                SizedBox(height: 10),
                Text(
                  'Network：信息网络、知识网络、专家网络',
                  style: TextStyle(fontSize: 15, height: 1.7),
                ),
                SizedBox(height: 14),
                Text(
                  '整体含义：面向未来的趋势感知与认知网络',
                  style: TextStyle(fontSize: 15, height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('核心特性'),
            subtitle: const Text('RSS订阅 · AI摘要 · 智能翻译 · 收藏管理'),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('技术架构'),
            subtitle: const Text('Flutter 前端 | Python FastAPI 后端 | SQLite 数据库'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
