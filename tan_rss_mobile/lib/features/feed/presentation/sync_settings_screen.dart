import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../data/feed_repository.dart';

class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  bool _loading = true;
  String? _error;
  bool _saving = false;

  late TextEditingController _apiUrlController;
  late TextEditingController _rsshubUrlController;
  int _fetchIntervalMinutes = 15;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController();
    _rsshubUrlController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _rsshubUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      _apiUrlController.text = prefs.getString('api_base_url') ?? ApiClient().baseUrl;

      final repository = ref.read(feedRepositoryProvider);
      final settings = await repository.getSettings();
      
      _rsshubUrlController.text = settings.rsshubUrl;
      _fetchIntervalMinutes = settings.fetchIntervalMinutes;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      // 保存本地 API 地址
      final apiUrl = _apiUrlController.text.trim();
      if (apiUrl.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('api_base_url', apiUrl);
        ApiClient().setBaseUrl(apiUrl);
      }

      // 保存远程设置
      final repository = ref.read(feedRepositoryProvider);
      await repository.updateSettings({
        'fetch_interval_minutes': _fetchIntervalMinutes,
        'rsshub_url': _rsshubUrlController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('同步设置'),
        actions: [
          if (!_loading && _error == null)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              onPressed: _saving ? null : _saveSettings,
            ),
        ],
      ),
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
            FilledButton(onPressed: _loadSettings, child: const Text('重试')),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '本地连接配置',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _apiUrlController,
          decoration: const InputDecoration(
            labelText: '后端 API Base URL',
            hintText: 'http://192.168.1.1:8080',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          '服务器后台配置 (全局)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '自动刷新间隔 (分钟)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _fetchIntervalMinutes.toDouble(),
                        min: 5,
                        max: 1440,
                        divisions: 1435,
                        label: _fetchIntervalMinutes.toString(),
                        onChanged: (val) {
                          setState(() {
                            _fetchIntervalMinutes = val.round();
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '$_fetchIntervalMinutes 分钟',
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rsshubUrlController,
                  decoration: const InputDecoration(
                    labelText: 'RSSHub 实例地址',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}