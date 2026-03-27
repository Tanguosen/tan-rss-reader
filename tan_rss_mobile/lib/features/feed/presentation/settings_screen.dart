import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import 'feed_providers.dart';
import 'ai_settings_screen.dart';
import 'language_settings_screen.dart';
import 'interaction_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'opml_settings_screen.dart';
import 'sync_settings_screen.dart';
import 'admin_management_screen.dart';
import 'user_management_screen.dart';
import 'about_screen.dart';
import 'membership_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('即将推出')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 更新日志 Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Material(
              color: const Color(0xFFFFE8C7),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _showComingSoon,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.new_releases_outlined, color: Color(0xFF6D4C41)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '更新日志',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF3E2F25),
                                  ),
                            ),
                            Text(
                              '查看最新版本的改进内容',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF6D4C41),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.open_in_new, color: Color(0xFF6D4C41)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          _buildSettingsItem(
            icon: Icons.workspace_premium_outlined,
            title: '会员中心',
            subtitle: '解锁高级 AI 功能与特权',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MembershipScreen()),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.person_outline,
            title: '账户',
            subtitle: '本地, 云端同步',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.palette_outlined,
            title: '颜色和样式',
            subtitle: '主题, 文章样式',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AppearanceSettingsScreen()),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.touch_app_outlined,
            title: '交互',
            subtitle: '手势操作, 启动页面',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InteractionSettingsScreen()),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.language_outlined,
            title: '语言',
            subtitle: '界面、AI、翻译',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.auto_awesome_outlined,
            title: 'AI功能',
            subtitle: 'AI 提供商, AI 指令',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AISettingsScreen()),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.highlight_outlined,
            title: '高亮设置',
            subtitle: '管理文章中的关键词高亮',
            onTap: _showComingSoon,
          ),
          _buildSettingsItem(
            icon: Icons.record_voice_over_outlined,
            title: 'TTS设置',
            subtitle: '语音、语言设置',
            onTap: _showComingSoon,
          ),
          _buildSettingsItem(
            icon: Icons.sync_outlined,
            title: '同步设置',
            subtitle: '自动刷新, API 地址配置',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SyncSettingsScreen()),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.import_export_outlined,
            title: '导入/导出',
            subtitle: '订阅源, App 设置',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OpmlSettingsScreen()),
            ),
          ),
          if (ref.watch(authProvider).user?.role == 'admin')
            _buildSettingsItem(
              icon: Icons.admin_panel_settings_outlined,
              title: '平台管理中心',
              subtitle: '全局频道、分组和信息源管理',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminManagementScreen(isPlatformAdmin: true)),
              ),
            ),
          if (ref.watch(authProvider).user?.role == 'admin')
            _buildSettingsItem(
              icon: Icons.people_outline,
              title: '用户管理',
              subtitle: '管理用户权限和会员等级',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserManagementScreen()),
              ),
            ),
          _buildSettingsItem(
            icon: Icons.info_outline,
            title: '关于',
            subtitle: '应用信息、版本',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, size: 28),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  // 登录/注册表单控制器
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  bool _registerMode = false;
  bool _obscurePassword = true;

  // 修改邮箱对话框控制器
  final _newEmailController = TextEditingController();

  // 修改密码对话框控制器
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _newEmailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 验证邮箱格式
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // 提交登录/注册
  Future<void> _submitAuth() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('用户名和密码不能为空', isError: true);
      return;
    }

    if (_registerMode) {
      if (username.length < 3) {
        _showSnackBar('用户名至少需要 3 个字符', isError: true);
        return;
      }
      if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(username)) {
        _showSnackBar('用户名只能包含字母、数字、_ 和 -', isError: true);
        return;
      }
      if (email.isNotEmpty && !_isValidEmail(email)) {
        _showSnackBar('请输入有效的邮箱地址', isError: true);
        return;
      }
      if (password.length < 6) {
        _showSnackBar('密码至少需要 6 个字符', isError: true);
        return;
      }
    }

    try {
      if (_registerMode) {
        await ref.read(authProvider.notifier).register(
              username,
              password,
              email.isEmpty ? null : email,
            );
        _showSnackBar('注册并登录成功');
      } else {
        await ref.read(authProvider.notifier).login(username, password);
        _showSnackBar('登录成功');
      }
      ref.invalidate(entriesProvider);
      ref.invalidate(feedsProvider);
      ref.invalidate(starredEntriesProvider);
      // 清空表单
      _usernameController.clear();
      _passwordController.clear();
      _emailController.clear();
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  // 退出登录
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 先清空Provider状态
      await ref.read(authProvider.notifier).logout();
      ref.invalidate(entriesProvider);
      ref.invalidate(feedsProvider);
      ref.invalidate(starredEntriesProvider);
      
      // 关闭设置页面，返回到主页
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  // 显示修改邮箱对话框
  void _showUpdateEmailDialog(String currentEmail) {
    _newEmailController.text = currentEmail;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改邮箱'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newEmailController,
              decoration: const InputDecoration(
                labelText: '新邮箱地址',
                hintText: '请输入新的邮箱地址',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final newEmail = _newEmailController.text.trim();
              if (newEmail.isEmpty) {
                _showSnackBar('邮箱不能为空', isError: true);
                return;
              }
              if (!_isValidEmail(newEmail)) {
                _showSnackBar('请输入有效的邮箱地址', isError: true);
                return;
              }
              Navigator.pop(context);
              try {
                await ref.read(authProvider.notifier).updateEmail(newEmail);
                _showSnackBar('邮箱修改成功');
              } catch (e) {
                _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 显示修改密码对话框
  void _showUpdatePasswordDialog() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('修改密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: '当前密码',
                  hintText: '请输入当前密码',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrentPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                  ),
                ),
                obscureText: _obscureCurrentPassword,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: '新密码',
                  hintText: '至少 6 个字符',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_person_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => _obscureNewPassword = !_obscureNewPassword),
                  ),
                ),
                obscureText: _obscureNewPassword,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: '确认新密码',
                  hintText: '再次输入新密码',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                obscureText: _obscureConfirmPassword,
                onSubmitted: (_) => _submitPasswordChange(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: _submitPasswordChange,
              child: const Text('修改'),
            ),
          ],
        ),
      ),
    );
  }

  // 提交密码修改
  Future<void> _submitPasswordChange() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('请填写所有密码字段', isError: true);
      return;
    }
    if (newPassword.length < 6) {
      _showSnackBar('新密码至少需要 6 个字符', isError: true);
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar('两次输入的新密码不一致', isError: true);
      return;
    }

    Navigator.pop(context);
    try {
      await ref.read(authProvider.notifier).updatePassword(currentPassword, newPassword);
      _showSnackBar('密码修改成功');
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  // 显示 SnackBar
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 格式化日期
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '未知';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}年${date.month}月${date.day}日';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户管理'),
        elevation: 0,
      ),
      body: auth.isLoggedIn
          ? _buildLoggedInView(auth, theme, colorScheme)
          : _buildLoginView(auth, theme, colorScheme),
    );
  }

  // 已登录状态视图
  Widget _buildLoggedInView(AuthState auth, ThemeData theme, ColorScheme colorScheme) {
    final user = auth.user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 用户信息卡片
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 头像和用户名
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    user.username.substring(0, 1).toUpperCase(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user.username,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.role == 'admin'
                        ? Colors.orange.withValues(alpha: 0.1)
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.role == 'admin' ? '管理员' : '普通用户',
                    style: TextStyle(
                      color: user.role == 'admin' ? Colors.orange : colorScheme.onPrimaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                // 详细信息
                _buildInfoRow(Icons.email_outlined, '邮箱', user.email ?? '未设置'),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.calendar_today_outlined, '注册时间', _formatDate(user.createdAt)),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.verified_user_outlined,
                  '账户状态',
                  user.isActive ? '正常' : '已禁用',
                  valueColor: user.isActive ? Colors.green : Colors.red,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 账户操作
        Text(
          '账户操作',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // 修改邮箱
        _buildActionTile(
          icon: Icons.email_outlined,
          title: '修改邮箱',
          subtitle: user.email ?? '未设置',
          onTap: () => _showUpdateEmailDialog(user.email ?? ''),
        ),

        // 修改密码
        _buildActionTile(
          icon: Icons.lock_outline,
          title: '修改密码',
          subtitle: '定期更换密码可提高账户安全',
          onTap: _showUpdatePasswordDialog,
        ),

        const SizedBox(height: 24),

        // 退出登录按钮
        FilledButton.tonalIcon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('退出登录'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.red.withValues(alpha: 0.1),
            foregroundColor: Colors.red,
          ),
        ),

        if (auth.loading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  // 构建信息行
  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text(
          '$label：',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // 构建操作项
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // 未登录状态视图
  Widget _buildLoginView(AuthState auth, ThemeData theme, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 图标和标题
        Icon(
          Icons.account_circle_outlined,
          size: 80,
          color: colorScheme.primary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 24),
        Text(
          _registerMode ? '创建新账户' : '欢迎回来',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _registerMode ? '注册后即可同步您的订阅数据' : '登录以同步您的订阅数据',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // 登录/注册切换
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('登录')),
            ButtonSegment(value: true, label: Text('注册')),
          ],
          selected: {_registerMode},
          onSelectionChanged: (value) {
            setState(() => _registerMode = value.first);
          },
        ),
        const SizedBox(height: 24),

        // 用户名输入
        TextFormField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: '用户名',
            hintText: '请输入用户名',
            prefixIcon: const Icon(Icons.person_outline),
            border: const OutlineInputBorder(),
            helperText: _registerMode ? '仅允许字母、数字、下划线(_)和连字符(-)，至少 3 个字符' : null,
          ),
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),

        // 密码输入
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: '密码',
            hintText: '请输入密码',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            helperText: _registerMode ? '至少 6 个字符' : null,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          textInputAction: _registerMode ? TextInputAction.next : TextInputAction.done,
          onFieldSubmitted: (_) {
            if (_registerMode) {
              FocusScope.of(context).nextFocus();
            } else {
              _submitAuth();
            }
          },
        ),

        // 邮箱输入（仅注册模式）
        if (_registerMode) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: '邮箱（可选）',
              hintText: '请输入邮箱地址',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitAuth(),
          ),
        ],

        const SizedBox(height: 24),

        // 提交按钮
        FilledButton.icon(
          onPressed: auth.loading ? null : _submitAuth,
          icon: auth.loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(_registerMode ? Icons.person_add : Icons.login),
          label: Text(_registerMode ? '注册并登录' : '登录'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),

        // 错误提示
        if (auth.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              auth.error!.replaceAll('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.error),
            ),
          ),
      ],
    );
  }
}
