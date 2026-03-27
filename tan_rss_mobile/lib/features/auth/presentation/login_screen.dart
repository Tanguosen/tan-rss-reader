import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_providers.dart';
import '../../../core/api/api_client.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _serverController = TextEditingController();

  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _showServerConfig = false;

  @override
  void initState() {
    super.initState();
    _serverController.text = ApiClient().baseUrl;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _saveServerAddress() async {
    final url = _serverController.text.trim();
    if (url.isNotEmpty) {
      ApiClient().setBaseUrl(url);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base_url', url);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    await _saveServerAddress();

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (_isLoginMode) {
      ref.read(authProvider.notifier).login(username, password);
    } else {
      final email = _emailController.text.trim();
      ref.read(authProvider.notifier).register(username, password, email.isEmpty ? null : email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      // 错误提示
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!.replaceAll('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      // 登录/注册成功提示
      if (next.isLoggedIn && !(previous?.isLoggedIn ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isLoginMode ? '登录成功，欢迎回来！' : '注册成功，欢迎加入！'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo/Title
                  Icon(
                    Icons.rss_feed_rounded,
                    size: 72,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TAN RSS',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoginMode ? '欢迎回来，请登录' : '创建新账号',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 48),

                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '用户名',
                      prefixIcon: const Icon(Icons.person_outline),
                      helperText: _isLoginMode ? null : '仅允许字母、数字、下划线(_)和连字符(-)，至少 3 个字符',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入用户名';
                      }
                      if (!_isLoginMode) {
                        if (value.trim().length < 3) return '用户名至少需要 3 个字符';
                        if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value.trim())) {
                          return '用户名只能包含字母、数字、_ 和 -';
                        }
                      }
                      return null;
                    },
                  ),
                  
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Column(
                      children: [
                        if (!_isLoginMode) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: '邮箱 (可选)',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            ),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                                  return '邮箱格式不正确';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      helperText: _isLoginMode ? null : '密码长度至少 6 个字符',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      if (!_isLoginMode && value.length < 6) {
                        return '密码长度不能少于 6 位';
                      }
                      return null;
                    },
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Column(
                      children: [
                        if (_showServerConfig) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _serverController,
                            decoration: InputDecoration(
                              labelText: '服务器地址',
                              prefixIcon: const Icon(Icons.dns_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '请输入服务器地址';
                              }
                              if (!value.startsWith('http')) {
                                return '地址必须以 http 或 https 开头';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showServerConfig = !_showServerConfig;
                        });
                      },
                      icon: Icon(
                        _showServerConfig ? Icons.expand_less : Icons.settings_outlined,
                        size: 16,
                      ),
                      label: Text(
                        _showServerConfig ? '收起配置' : '服务器配置',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  FilledButton(
                    onPressed: authState.loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: authState.loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isLoginMode ? '登录' : '注册',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Toggle Mode
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                        _formKey.currentState?.reset();
                      });
                    },
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                        children: [
                          TextSpan(text: _isLoginMode ? '没有账号？ ' : '已有账号？ '),
                          TextSpan(
                            text: _isLoginMode ? '点击注册' : '点击登录',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}