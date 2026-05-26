import 'package:flutter/material.dart';

class MineTab extends StatefulWidget {
  const MineTab({super.key});

  @override
  State<MineTab> createState() => _MineTabState();
}

class _MineTabState extends State<MineTab> {
  bool _isLoggedIn = false;
  String _userEmail = '';

  void _handleLogin() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.login_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('登录萌哩', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: '电子邮箱',
                  prefixIcon: const Icon(Icons.email_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  setState(() {
                    _isLoggedIn = true;
                    _userEmail = email;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('欢迎回来，$email！')),
                  );
                }
              },
              child: const Text('登录'),
            ),
          ],
        );
      },
    );
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _userEmail = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已成功退出登录')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Premium Profile Header
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.surface,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: theme.colorScheme.primary,
                      child: Icon(
                        _isLoggedIn ? Icons.face_retouching_natural_rounded : Icons.person_rounded,
                        size: 40,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isLoggedIn ? _userEmail : '未登录萌哩',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLoggedIn ? 'UID: 20260526' : '登录即可同步收藏夹及云端壁纸',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Profile Actions List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // Bottom padding for bar
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!_isLoggedIn) ...[
                  FilledButton.icon(
                    onPressed: _handleLogin,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('登录 / 注册萌哩', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Section: Collection & Sync
                _buildSectionHeader(theme, '收藏与云端服务'),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
                        title: const Text('我的收藏夹', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {},
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.cloud_done_rounded, color: Colors.blue),
                        title: const Text('云端备份壁纸', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section: Preference Settings
                _buildSectionHeader(theme, '个性偏好'),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.palette_rounded),
                        title: const Text('主题设置', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        trailing: const Text('深色/浅色自适应', style: TextStyle(fontSize: 12)),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                if (_isLoggedIn) ...[
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('退出当前账号'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
