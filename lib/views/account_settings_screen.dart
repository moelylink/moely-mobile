import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../utils/toast_helper.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _MineBindingRow extends StatelessWidget {
  final IconData icon;
  final String providerName;
  final bool isBound;
  final Color activeColor;

  const _MineBindingRow({
    required this.icon,
    required this.providerName,
    required this.isBound,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isBound ? activeColor.withOpacity(0.12) : theme.colorScheme.onSurface.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isBound ? activeColor : theme.colorScheme.onSurface.withOpacity(0.4),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              providerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isBound ? activeColor.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isBound ? activeColor.withOpacity(0.3) : theme.colorScheme.onSurface.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              isBound ? '已绑定' : '未绑定',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isBound ? activeColor : theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PasswordUpdateAttributes extends UserAttributes {
  final String currentPassword;

  PasswordUpdateAttributes({
    required super.password,
    required this.currentPassword,
  });

  @override
  Map<String, dynamic> toJson() {
    final map = super.toJson();
    map['current_password'] = currentPassword;
    return map;
  }
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  void _showChangePasswordDialog(ThemeData theme) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final repeatPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          title: const Text('修改登录密码', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '输入当前原密码',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '输入新密码',
                      hintText: '不少于 8 位数',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: repeatPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '再次输入新密码确认',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
            ),
            FilledButton(
              onPressed: () async {
                final oldPwd = oldPasswordController.text.trim();
                final newPwd = newPasswordController.text.trim();
                final repeatPwd = repeatPasswordController.text.trim();

                if (oldPwd.isEmpty) {
                  _showNotification('请输入当前原密码', type: ToastType.warning);
                  return;
                }
                if (newPwd.length < 8) {
                  _showNotification('新密码需大于 8 位', type: ToastType.warning);
                  return;
                }
                if (newPwd != repeatPwd) {
                  _showNotification('两次新密码输入不一致', type: ToastType.warning);
                  return;
                }

                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await _supabase.auth.updateUser(
                    PasswordUpdateAttributes(
                      password: newPwd,
                      currentPassword: oldPwd,
                    ),
                  );
                  if (mounted) {
                    _showNotification('密码修改成功！', type: ToastType.success);
                  }
                } catch (e) {
                  if (mounted) {
                    _showNotification('修改失败: $e', type: ToastType.error);
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('确认修改'),
            ),
          ],
        );
      },
    );
  }

  void _showChangeEmailDialog(ThemeData theme) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          title: const Text('修改登录邮箱', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '输入新登录邮箱',
                hintText: 'example@moely.link',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
            ),
            FilledButton(
              onPressed: () async {
                final email = controller.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  _showNotification('请输入合法的邮箱地址', type: ToastType.warning);
                  return;
                }
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await _supabase.auth.updateUser(UserAttributes(email: email));
                  if (mounted) {
                    _showNotification('已向新邮箱发送确认验证邮件，请查收完成绑定。', type: ToastType.success);
                  }
                } catch (e) {
                  if (mounted) {
                    _showNotification('修改失败: $e', type: ToastType.error);
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('确认修改'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final currentUser = _supabase.auth.currentUser;
    final email = currentUser?.email ?? '未知邮箱';
    final uuid = currentUser?.id ?? '';
    final createdAtStr = currentUser?.createdAt ?? '';
    final parsedDate = createdAtStr.isNotEmpty
        ? DateTime.parse(createdAtStr).toLocal().toString().split(' ')[0]
        : '未知';

    // Fetch active identities
    final identities = currentUser?.identities ?? [];
    final hasGoogle = identities.any((id) => id.provider == 'google');
    final hasGithub = identities.any((id) => id.provider == 'github');
    final hasMicrosoft = identities.any((id) => id.provider == 'azure' || id.provider == 'microsoft');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('账号设置', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Account details Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.badge_rounded, color: theme.colorScheme.primary, size: 24),
                          const SizedBox(width: 10),
                          const Text('账号信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow('登录邮箱', email),
                      const Divider(height: 24),
                      _buildDetailRow('注册时间', parsedDate),
                      const Divider(height: 24),
                      _buildDetailRow('账号 ID', uuid, isCopyable: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Bindings details Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(Icons.link_rounded, color: theme.colorScheme.primary, size: 24),
                            const SizedBox(width: 10),
                            const Text('绑定信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MineBindingRow(
                        icon: Icons.g_mobiledata_rounded,
                        providerName: 'Google 账号',
                        isBound: hasGoogle,
                        activeColor: const Color(0xFFEA4335),
                      ),
                      const Divider(height: 1, indent: 56),
                      _MineBindingRow(
                        icon: Icons.code_rounded,
                        providerName: 'GitHub 账号',
                        isBound: hasGithub,
                        activeColor: const Color(0xFF24292E),
                      ),
                      const Divider(height: 1, indent: 56),
                      _MineBindingRow(
                        icon: Icons.window_rounded,
                        providerName: 'Microsoft 账号',
                        isBound: hasMicrosoft,
                        activeColor: const Color(0xFF00A4EF),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          '*如需绑定第三方账号，请前往“萌哩用户中心”网页操作',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withOpacity(0.45),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Operations details Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.lock_reset_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: const Text('修改密码', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () => _showChangePasswordDialog(theme),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: Icon(Icons.alternate_email_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: const Text('修改登录邮箱', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () => _showChangeEmailDialog(theme),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isCopyable = false}) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        if (isCopyable)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              _showNotification('已复制到剪切板', type: ToastType.success);
            },
            child: Icon(
              Icons.copy_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
      ],
    );
  }

  void _showNotification(String message, {ToastType type = ToastType.info}) {
    if (mounted) {
      ToastHelper.show(context, message, type: type);
    }
  }
}
