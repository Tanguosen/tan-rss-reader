import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import 'package:timeago/timeago.dart' as timeago;

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiClient().dio.get('/admin/users');
      setState(() {
        _users = List<Map<String, dynamic>>.from(response.data);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _updateUser(String id, Map<String, dynamic> payload) async {
    try {
      await ApiClient().dio.patch('/admin/users/$id', data: payload);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('用户更新成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> user) {
    String role = user['role'] ?? 'user';
    bool isActive = user['is_active'] ?? true;
    String tier = user['tier'] ?? 'free';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('编辑用户: ${user['username']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: '角色'),
                      items: const [
                        DropdownMenuItem(
                          value: 'user',
                          child: Text('普通用户 (user)'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('管理员 (admin)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => role = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: tier,
                      decoration: const InputDecoration(labelText: '会员等级'),
                      items: const [
                        DropdownMenuItem(value: 'free', child: Text('Free')),
                        DropdownMenuItem(value: 'plus', child: Text('Plus')),
                        DropdownMenuItem(value: 'pro', child: Text('Pro')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => tier = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('激活状态'),
                      value: isActive,
                      onChanged: (val) {
                        setDialogState(() => isActive = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateUser(user['id'], {
                      'role': role,
                      'tier': tier,
                      'is_active': isActive,
                    });
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除用户 ${user['username']} 吗？此操作不可逆。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiClient().dio.delete('/admin/users/${user['id']}');
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('用户已删除')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户管理'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
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
            FilledButton(onPressed: _loadUsers, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_users.isEmpty) {
      return const Center(child: Text('没有用户数据'));
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final isActive = user['is_active'] ?? true;
        final tier = user['tier'] ?? 'free';
        final role = user['role'] ?? 'user';
        final createdAt = user['created_at'] != null
            ? DateTime.tryParse(user['created_at'])
            : null;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isActive
                  ? Colors.blue.shade100
                  : Colors.grey.shade300,
              child: Icon(
                role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                color: isActive ? Colors.blue.shade700 : Colors.grey.shade600,
              ),
            ),
            title: Text(
              user['username'] ?? 'Unknown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: isActive ? null : TextDecoration.lineThrough,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: role == 'admin'
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: role == 'admin'
                              ? Colors.red.shade900
                              : Colors.green.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tier == 'free'
                            ? Colors.grey.shade200
                            : (tier == 'pro'
                                  ? Colors.purple.shade100
                                  : Colors.orange.shade100),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tier.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: tier == 'free'
                              ? Colors.grey.shade700
                              : (tier == 'pro'
                                    ? Colors.purple.shade900
                                    : Colors.orange.shade900),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  createdAt != null
                      ? '注册于: ${timeago.format(createdAt, locale: 'zh')}'
                      : '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditDialog(user);
                } else if (value == 'delete') {
                  _deleteUser(user);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('删除', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
