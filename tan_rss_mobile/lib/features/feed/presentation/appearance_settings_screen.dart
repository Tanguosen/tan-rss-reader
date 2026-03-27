import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'feed_providers.dart';

class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends ConsumerState<AppearanceSettingsScreen> {
  Future<void> _updateSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    }
    ref.read(appearanceSettingsProvider.notifier).reload();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appearanceSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('颜色和样式'),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () {},
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildSectionHeader('文章显示模式'),
          _buildRadioCard(
            icon: Icons.list,
            title: '列表',
            subtitle: '简单列表，显示标题和订阅源信息',
            value: 'list',
            groupValue: settings.viewMode,
            onChanged: (v) => _updateSetting('appearance_view_mode', v),
          ),
          const SizedBox(height: 8),
          _buildRadioCard(
            icon: Icons.view_agenda_outlined,
            title: '杂志',
            subtitle: '丰富布局，包含内容预览',
            value: 'magazine',
            groupValue: settings.viewMode,
            onChanged: (v) => _updateSetting('appearance_view_mode', v),
          ),
          const SizedBox(height: 8),
          _buildRadioCard(
            icon: Icons.dashboard_outlined,
            title: '卡片',
            subtitle: '基于图片的卡片布局',
            value: 'card',
            groupValue: settings.viewMode,
            onChanged: (v) => _updateSetting('appearance_view_mode', v),
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader('主题模式'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildRadioListTile(
                  icon: Icons.auto_mode,
                  title: '跟随系统',
                  subtitle: 'Automatically switch based on system settings',
                  value: 'system',
                  groupValue: settings.themeMode,
                  onChanged: (v) => _updateSetting('appearance_theme_mode', v),
                ),
                const Divider(height: 1, indent: 56),
                _buildRadioListTile(
                  icon: Icons.light_mode_outlined,
                  title: '浅色模式',
                  subtitle: 'Use light theme',
                  value: 'light',
                  groupValue: settings.themeMode,
                  onChanged: (v) => _updateSetting('appearance_theme_mode', v),
                ),
                const Divider(height: 1, indent: 56),
                _buildRadioListTile(
                  icon: Icons.dark_mode_outlined,
                  title: '深色模式',
                  subtitle: 'Use dark theme',
                  value: 'dark',
                  groupValue: settings.themeMode,
                  onChanged: (v) => _updateSetting('appearance_theme_mode', v),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: const Icon(Icons.brightness_3_outlined, color: Color(0xFF6D4C41)),
                  title: const Text('AMOLED纯黑模式', style: TextStyle(fontWeight: FontWeight.w600)),
                  value: settings.amoledBlack,
                  onChanged: settings.themeMode == 'light' ? null : (v) => _updateSetting('appearance_amoled_black', v),
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF8B6B4A),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('主题颜色'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildColorItem('dynamic', 'Dynamic', null, settings.themeColor),
              _buildColorItem('blue', 'Blue', Colors.blue, settings.themeColor),
              _buildColorItem('indigo', 'Indigo', Colors.indigo, settings.themeColor),
              _buildColorItem('purple', 'Purple', Colors.purple, settings.themeColor),
              _buildColorItem('pink', 'Pink', Colors.pink, settings.themeColor),
              _buildColorItem('red', 'Red', Colors.red, settings.themeColor),
              _buildColorItem('orange', 'Orange', Colors.orange, settings.themeColor),
              _buildColorItem('yellow', 'Yellow', Colors.yellow, settings.themeColor),
              _buildColorItem('lime', 'Lime', Colors.lime, settings.themeColor),
              _buildColorItem('green', 'Green', Colors.green, settings.themeColor),
              _buildColorItem('teal', 'Teal', Colors.teal, settings.themeColor),
              _buildColorItem('cyan', 'Cyan', Colors.cyan, settings.themeColor),
            ],
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('配色方案风格'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildRadioListTileWithSquareIcon(
                  icon: Icons.lens_outlined,
                  title: '色调斑点',
                  subtitle: '默认柔和调色板，低饱和度',
                  value: 'tonal_spot',
                  groupValue: settings.colorSchemeStyle,
                  onChanged: (v) => _updateSetting('appearance_color_scheme_style', v),
                  color: Colors.blue,
                ),
                const Divider(height: 1, indent: 72),
                _buildRadioListTileWithSquareIcon(
                  icon: Icons.adjust,
                  title: '保真度',
                  subtitle: '匹配主题颜色，即使很亮',
                  value: 'fidelity',
                  groupValue: settings.colorSchemeStyle,
                  onChanged: (v) => _updateSetting('appearance_color_scheme_style', v),
                  color: Colors.blue,
                ),
                const Divider(height: 1, indent: 72),
                _buildRadioListTileWithSquareIcon(
                  icon: Icons.balance,
                  title: '中性',
                  subtitle: '接近灰度，带一点色彩',
                  value: 'neutral',
                  groupValue: settings.colorSchemeStyle,
                  onChanged: (v) => _updateSetting('appearance_color_scheme_style', v),
                  color: Colors.blueGrey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRadioCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    final isSelected = value == groupValue;
    return Card(
      elevation: 0,
      color: isSelected ? const Color(0xFFFDF5E6) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? const Color(0xFF8B6B4A) : Colors.grey.withValues(alpha: 0.2),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF8B6B4A)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Color(0xFF8B6B4A)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF8B6B4A)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF8B6B4A)),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioListTileWithSquareIcon({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String> onChanged,
    required Color color,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF8B6B4A)),
          ],
        ),
      ),
    );
  }

  Widget _buildColorItem(String value, String label, Color? color, String groupValue) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => _updateSetting('appearance_theme_color', value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B6B4A) : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (color == null)
              const Icon(Icons.auto_awesome, color: Color(0xFF8B6B4A), size: 32)
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF8B6B4A) : Colors.black87,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}