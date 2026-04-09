import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/feed_repository.dart';
import 'feed_providers.dart';

class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({super.key});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(feedRepositoryProvider);
      _status = await repository.getMembershipStatus();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _subscribe(String tier) async {
    setState(() => _loading = true);
    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.subscribeMembership(tier);
      await _loadStatus();
      ref.invalidate(aiConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已成功升级至 $tier 会员！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('升级失败: $e')));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('会员中心')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadStatus, child: const Text('重试')),
          ],
        ),
      );
    }

    final currentTier = _status?['tier'] ?? 'free';
    final isPlus = currentTier == 'plus';
    final isPro = currentTier == 'pro';
    final isActive = _status?['is_active'] == true;
    final expiresAt = _status?['expires_at'];
    final todayCalls = _status?['today_ai_calls'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 当前状态卡片
        Card(
          elevation: 0,
          color: (isPlus || isPro)
              ? Colors.orange.shade50
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  (isPlus || isPro)
                      ? Icons.workspace_premium
                      : Icons.person_outline,
                  size: 64,
                  color: (isPlus || isPro) ? Colors.orange : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  '当前等级: ${currentTier.toString().toUpperCase()}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isActive && expiresAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '到期时间: ${DateTime.parse(expiresAt).toLocal().toString().split('.')[0]}',
                  ),
                ],
                const SizedBox(height: 8),
                Text('今日平台AI调用次数: $todayCalls 次'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        Text(
          '订阅计划',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Free Plan
        _buildPlanCard(
          title: 'Free 基础版',
          price: '免费',
          features: ['基础 RSS 订阅管理', '支持自定义接入 AI 模型 (自带 Key)', '社区插件与精选包'],
          isCurrent: currentTier == 'free',
          onTap: currentTier == 'free' ? null : () => _subscribe('free'),
          buttonText: currentTier == 'free' ? '当前计划' : '降级',
        ),
        const SizedBox(height: 16),

        // Plus Plan
        _buildPlanCard(
          title: 'Plus 专业版',
          price: '￥15 / 月',
          features: [
            '包含所有 Free 版功能',
            '免配置直接使用平台高质量 AI 模型',
            '每日 50 次平台 AI 调用额度',
            '支持自定义 AI 指令管理',
          ],
          isCurrent: isPlus,
          color: Colors.orange.shade50,
          borderColor: Colors.orange,
          onTap: isPlus ? null : () => _subscribe('plus'),
          buttonText: isPlus ? '当前计划' : (isPro ? '降级' : '立即升级'),
        ),
        const SizedBox(height: 16),

        // Pro Plan
        _buildPlanCard(
          title: 'Pro 终极版',
          price: '￥45 / 月',
          features: [
            '包含所有 Plus 版功能',
            '每日 500 次平台高级 AI 调用额度',
            '高级主题定制 (即将推出)',
            '优先客服支持',
          ],
          isCurrent: isPro,
          color: Colors.purple.shade50,
          borderColor: Colors.purple,
          onTap: isPro ? null : () => _subscribe('pro'),
          buttonText: isPro ? '当前计划' : '立即升级',
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required List<String> features,
    required bool isCurrent,
    Color? color,
    Color? borderColor,
    VoidCallback? onTap,
    required String buttonText,
  }) {
    return Card(
      elevation: isCurrent ? 2 : 0,
      color: color ?? Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCurrent
              ? (borderColor ?? Theme.of(context).colorScheme.primary)
              : Colors.grey.shade300,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          borderColor ?? Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '当前',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: borderColor ?? Theme.of(context).colorScheme.primary,
              ),
            ),
            const Divider(height: 32),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color:
                          borderColor ?? Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: onTap == null
                      ? Colors.grey.shade300
                      : (borderColor ?? Theme.of(context).colorScheme.primary),
                  foregroundColor: onTap == null
                      ? Colors.grey.shade600
                      : Colors.white,
                ),
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
