import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'feed_providers.dart';

class InteractionSettingsScreen extends ConsumerStatefulWidget {
  const InteractionSettingsScreen({super.key});

  @override
  ConsumerState<InteractionSettingsScreen> createState() => _InteractionSettingsScreenState();
}

class _InteractionSettingsScreenState extends ConsumerState<InteractionSettingsScreen> {
  bool _hapticFeedback = true;
  bool _immersiveReading = false;
  bool _swipeToChange = true;
  bool _scrollMarkRead = false;
  bool _lazyLoadDetails = false;
  bool _useExternalBrowser = false;
  String _fabPosition = 'Right';
  int _pageSize = 50;
  int _startupTab = 0; // 0: 文章, 1: 频道, 2: 发现

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _hapticFeedback = prefs.getBool('interaction_haptic_feedback') ?? true;
        _immersiveReading = prefs.getBool('interaction_immersive_reading') ?? false;
        _swipeToChange = prefs.getBool('interaction_swipe_to_change') ?? true;
        _scrollMarkRead = prefs.getBool('interaction_scroll_mark_read') ?? false;
        _lazyLoadDetails = prefs.getBool('interaction_lazy_load_details') ?? false;
        _useExternalBrowser = prefs.getBool('interaction_use_external_browser') ?? false;
        _fabPosition = prefs.getString('interaction_fab_position') ?? 'Right';
        _pageSize = prefs.getInt('interaction_page_size') ?? 50;
        _startupTab = prefs.getInt('default_startup_tab') ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveBool(String key, bool value, void Function(bool) updateState) async {
    setState(() => updateState(value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
      ref.read(interactionSettingsProvider.notifier).reload();
    } catch (_) {}
  }

  Future<void> _saveString(String key, String value, void Function(String) updateState) async {
    setState(() => updateState(value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      ref.read(interactionSettingsProvider.notifier).reload();
    } catch (_) {}
  }

  Future<void> _saveInt(String key, int value, void Function(int) updateState) async {
    setState(() => updateState(value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
      ref.read(interactionSettingsProvider.notifier).reload();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('交互')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('交互'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              '手势操作',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _buildSwitchItem(
                  icon: Icons.touch_app_outlined,
                  title: '触感反馈',
                  subtitle: '点击和滑动时提供震动反馈',
                  value: _hapticFeedback,
                  onChanged: (v) => _saveBool('interaction_haptic_feedback', v, (val) => _hapticFeedback = val),
                ),
                const Divider(height: 1, indent: 56),
                _buildSwitchItem(
                  icon: Icons.fullscreen_outlined,
                  title: '自动沉浸式阅读',
                  subtitle: '阅读文章时自动隐藏顶部工具栏和底部操作栏',
                  value: _immersiveReading,
                  onChanged: (v) => _saveBool('interaction_immersive_reading', v, (val) => _immersiveReading = val),
                ),
                const Divider(height: 1, indent: 56),
                _buildSwitchItem(
                  icon: Icons.swipe_outlined,
                  title: '文章滑动切换',
                  subtitle: '在文章详情页面左右滑动切换文章',
                  value: _swipeToChange,
                  onChanged: (v) => _saveBool('interaction_swipe_to_change', v, (val) => _swipeToChange = val),
                ),
                const Divider(height: 1, indent: 56),
                _buildSwitchItem(
                  icon: Icons.arrow_downward_outlined,
                  title: '滚动自动标记已读',
                  subtitle: '滚动时文章变得可见时自动将其标记为已读',
                  value: _scrollMarkRead,
                  onChanged: (v) => _saveBool('interaction_scroll_mark_read', v, (val) => _scrollMarkRead = val),
                ),
                const Divider(height: 1, indent: 56),
                _buildSwitchItem(
                  icon: Icons.dashboard_customize_outlined,
                  title: '文章详情懒加载',
                  subtitle: '提升部分设备性能，但可能导致滚动条跳动',
                  value: _lazyLoadDetails,
                  onChanged: (v) => _saveBool('interaction_lazy_load_details', v, (val) => _lazyLoadDetails = val),
                ),
                const Divider(height: 1, indent: 56),
                _buildSwitchItem(
                  icon: Icons.open_in_browser_outlined,
                  title: '使用外部浏览器打开',
                  subtitle: '在外部浏览器中打开文章链接，而不是应用内浏览器',
                  value: _useExternalBrowser,
                  onChanged: (v) => _saveBool('interaction_use_external_browser', v, (val) => _useExternalBrowser = val),
                ),
                const Divider(height: 1, indent: 56),
                _buildDropdownItem<String>(
                  icon: Icons.done_all_outlined,
                  title: '标记已读悬浮按钮位置',
                  subtitle: '选择标记为已读悬浮按钮的位置',
                  value: _fabPosition,
                  items: const [
                    DropdownMenuItem(value: 'Right', child: Text('Right')),
                    DropdownMenuItem(value: 'Left', child: Text('Left')),
                    DropdownMenuItem(value: 'Hidden', child: Text('隐藏')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      _saveString('interaction_fab_position', v, (val) => _fabPosition = val);
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                _buildDropdownItem<int>(
                  icon: Icons.format_list_numbered_outlined,
                  title: '每页文章数量',
                  subtitle: '每次加载的文章数量。这也影响AI聚合读取时使用的文章数量。',
                  value: _pageSize,
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                    DropdownMenuItem(value: 100, child: Text('100')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      _saveInt('interaction_page_size', v, (val) => _pageSize = val);
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                _buildDropdownItem<int>(
                  icon: Icons.launch_outlined,
                  title: '启动页',
                  subtitle: '选择应用启动时显示的页面',
                  value: _startupTab,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('文章')),
                    DropdownMenuItem(value: 1, child: Text('频道')),
                    DropdownMenuItem(value: 2, child: Text('发现')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      _saveInt('default_startup_tab', v, (val) => _startupTab = val);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: const Color(0xFF8B6B4A)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: const Color(0xFF8B6B4A),
      ),
      onTap: () => onChanged(!value),
    );
  }

  Widget _buildDropdownItem<T>({
    required IconData icon,
    required String title,
    required String subtitle,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: const Color(0xFF8B6B4A)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE8C7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8B6B4A)),
            style: const TextStyle(color: Color(0xFF8B6B4A), fontWeight: FontWeight.bold, fontSize: 14),
            isDense: true,
          ),
        ),
      ),
    );
  }
}