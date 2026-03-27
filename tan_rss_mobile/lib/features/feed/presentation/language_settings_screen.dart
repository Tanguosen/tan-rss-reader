import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';

class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() =>
      _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState
    extends ConsumerState<LanguageSettingsScreen> {
  String _aiGenLang = 'follow_app';
  String _translateLang = 'zh';

  @override
  void initState() {
    super.initState();
    _loadAiLangPrefs();
  }

  Future<void> _loadAiLangPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _aiGenLang = prefs.getString('ai_gen_language') ?? 'follow_app';
      _translateLang = prefs.getString('translate_language') ?? 'zh';
    });
  }

  Future<void> _setAiGenLang(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_gen_language', value);
    if (!mounted) return;
    setState(() => _aiGenLang = value);
  }

  Future<void> _setTranslateLang(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('translate_language', value);
    if (!mounted) return;
    setState(() => _translateLang = value);
  }

  static const _languages = [
    {'code': 'zh', 'label': '简体中文', 'labelEn': 'Chinese (Simplified)'},
    {'code': 'en', 'label': 'English', 'labelEn': 'English'},
    {'code': 'ja', 'label': '日本語', 'labelEn': 'Japanese'},
    {'code': 'ko', 'label': '한국어', 'labelEn': 'Korean'},
    {'code': 'fr', 'label': 'Français', 'labelEn': 'French'},
    {'code': 'de', 'label': 'Deutsch', 'labelEn': 'German'},
    {'code': 'es', 'label': 'Español', 'labelEn': 'Spanish'},
  ];

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(localeProvider);
    final localeNotifier = ref.read(localeProvider.notifier);

    final currentLangLabel = currentLocale == null
        ? '跟随系统'
        : currentLocale.languageCode == 'zh'
        ? '简体中文'
        : 'English';

    return Scaffold(
      appBar: AppBar(title: const Text('语言设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('应用语言', '应用界面使用的语言'),
          _buildLanguageSelector(
            currentLabel: currentLangLabel,
            onTap: () =>
                _showAppLanguageDialog(context, localeNotifier, currentLocale),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('AI 生成语言', 'AI生成内容（摘要等）使用的语言'),
          _buildLanguageSelector(
            currentLabel: _getLangLabel(_aiGenLang),
            onTap: () => _showAiLanguageDialog(
              context,
              title: 'AI 生成语言',
              current: _aiGenLang,
              onChanged: _setAiGenLang,
              includeFollowApp: true,
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('翻译语言', '文章翻译的目标语言'),
          _buildLanguageSelector(
            currentLabel: _getLangLabel(_translateLang),
            onTap: () => _showAiLanguageDialog(
              context,
              title: '翻译语言',
              current: _translateLang,
              onChanged: _setTranslateLang,
              includeFollowApp: false,
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF5E6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6D5C3), width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF8B6B4A),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '语言支持取决于大模型和翻译引擎的能力',
                    style: TextStyle(
                      color: const Color(0xFF8B6B4A).withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getLangLabel(String code) {
    if (code == 'follow_app') return '跟随应用语言';
    final lang = _languages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => {'label': code},
    );
    return lang['label']!;
  }

  void _showAppLanguageDialog(
    BuildContext context,
    LocaleNotifier notifier,
    Locale? current,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('应用语言'),
        children: [
          _buildDialogOption(
            ctx,
            label: '跟随系统',
            isSelected: current == null,
            onTap: () {
              notifier.setLocale(null);
              Navigator.pop(ctx);
            },
          ),
          _buildDialogOption(
            ctx,
            label: '简体中文',
            isSelected: current?.languageCode == 'zh',
            onTap: () {
              notifier.setLocale(const Locale('zh'));
              Navigator.pop(ctx);
            },
          ),
          _buildDialogOption(
            ctx,
            label: 'English',
            isSelected: current?.languageCode == 'en',
            onTap: () {
              notifier.setLocale(const Locale('en'));
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showAiLanguageDialog(
    BuildContext context, {
    required String title,
    required String current,
    required ValueChanged<String> onChanged,
    required bool includeFollowApp,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          if (includeFollowApp)
            _buildDialogOption(
              ctx,
              label: '跟随应用语言',
              isSelected: current == 'follow_app',
              onTap: () {
                onChanged('follow_app');
                Navigator.pop(ctx);
              },
            ),
          ..._languages.map(
            (lang) => _buildDialogOption(
              ctx,
              label: lang['label']!,
              isSelected: current == lang['code'],
              onTap: () {
                onChanged(lang['code']!);
                Navigator.pop(ctx);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogOption(
    BuildContext ctx, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF8B6B4A))
          : null,
      onTap: onTap,
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector({
    required String currentLabel,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      color: Colors.white,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.language, color: Color(0xFF8B6B4A)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  currentLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5A4A3A),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
