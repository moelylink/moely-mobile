import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'account_settings_screen.dart';
import 'favorites_screen.dart';
import 'browsing_history_screen.dart';
import 'storage_management_screen.dart';
import 'messages_screen.dart';
import 'widget_store_screen.dart';
import 'my_widgets_screen.dart';
import 'kanban_screen.dart';
import '../utils/toast_helper.dart';
import '../services/url_handler_service.dart';

class MineTab extends StatefulWidget {
  const MineTab({super.key});

  @override
  State<MineTab> createState() => _MineTabState();
}

class _MineTabState extends State<MineTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  void _handleLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          title: const Text('退出登录', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: const Text('确认要退出当前萌哩账号吗？'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await AuthService.instance.signOut();
                  if (mounted) {
                    final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
                    ToastHelper.show(rootContext, '已成功退出登录', type: ToastType.success);
                  }
                } catch (e) {
                  if (mounted) {
                    final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
                    ToastHelper.show(rootContext, '退出登录失败: $e', type: ToastType.error);
                  }
                }
              },
              child: const Text('退出'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileHeader(ThemeData theme, bool isLoggedIn, String userEmail) {
    final avatarLetter = isLoggedIn && userEmail.isNotEmpty ? userEmail[0].toUpperCase() : '';
    
    return InkWell(
      onTap: isLoggedIn 
          ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountSettingsScreen()))
          : _handleLogin,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer.withOpacity(0.25),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.primaryContainer.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left avatar
            Hero(
              tag: 'avatar_profile',
              child: CircleAvatar(
                radius: 36,
                backgroundColor: isLoggedIn 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurface.withOpacity(0.06),
                child: isLoggedIn
                    ? Text(
                        avatarLetter,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Icon(
                        Icons.person_rounded,
                        size: 38,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
              ),
            ),
            const SizedBox(width: 20),
            // Right account email details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoggedIn ? userEmail : '未登录萌哩',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isLoggedIn ? '安全云端同步服务已就绪' : '点击登录以使用云端同步与私信',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        final isLoggedIn = AuthService.instance.isLoggedIn;
        final userEmail = AuthService.instance.userEmail;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('我的', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              // Premium left-aligned Profile Header
              _buildProfileHeader(theme, isLoggedIn, userEmail),
              const SizedBox(height: 24),

              // Button actions grid / unified card
              _buildSectionHeader(theme, '个人云端与收藏'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    // (1) 账号设置
                    ListTile(
                      leading: Icon(Icons.manage_accounts_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: const Text('账号设置', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('账号安全、修改密码、绑定社交账号', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        if (isLoggedIn) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AccountSettingsScreen()),
                          );
                        } else {
                          _handleLogin();
                        }
                      },
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),

                    // (2) 私信消息 (移动至云端分组)
                    ListTile(
                      leading: const Icon(Icons.forum_rounded, color: Colors.purpleAccent),
                      title: const Text('私信消息', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('接收系统广播、与其他小伙伴私信对话', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MessagesScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),

                    // (3) 美图收藏
                    ListTile(
                      leading: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
                      title: const Text('美图收藏', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('查看与同步已收藏的精美插图', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const FavoritesScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),

                    // (4) 浏览历史
                    ListTile(
                      leading: const Icon(Icons.history_rounded, color: Colors.blueAccent),
                      title: const Text('浏览历史', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('查看与清空本地浏览过的图片纪录', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BrowsingHistoryScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildSectionHeader(theme, '本地管理与服务'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    // (4) 下载管理
                    ListTile(
                      leading: Icon(Icons.download_for_offline_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: const Text('下载管理', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('查看与清理已下载成功的原画图片', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DownloadManagementScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),

                    // (5) 小部件商城
                    ListTile(
                      leading: Icon(Icons.widgets_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: const Text('小部件商城', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('获取精美的桌面大/中/小原生插件小工具', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const WidgetStoreScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),

                    // (6) 我的小组件
                    ListTile(
                      leading: Icon(Icons.palette_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: const Text('我的小组件', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('独立管理已放置和预设的桌面小部件', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MyWidgetsScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),

                    // (7) 萌哩小屋
                    ListTile(
                      leading: Icon(Icons.cabin_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: const Text('萌哩小屋', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('开启桌面萌宠，互动体验萌哩小屋', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const KanbanScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              if (isLoggedIn) ...[
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('退出登录', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
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
