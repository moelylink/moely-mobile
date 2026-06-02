import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../utils/toast_helper.dart';
import '../services/url_handler_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _chats = [];
  Timer? _refreshTimer;

  // System bot representation
  static const String systemBotId = 'system_notification_bot';

  @override
  void initState() {
    super.initState();
    if (AuthService.instance.isLoggedIn) {
      _loadChats();
      // Periodically refresh chat previews to sync with the web
      _refreshTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        _loadChats(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChats({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return;

      // 1. Fetch system notifications for preview & unread counts
      final sysNotifs = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', myId)
          .order('created_at', ascending: false);

      final sysNotifsList = sysNotifs as List;
      final lastSysMsg = sysNotifsList.isNotEmpty ? sysNotifsList.first : null;
      final sysUnread = sysNotifsList.where((n) => n['is_read'] == false).length;

      // 2. Fetch direct messages
      final directMessages = await _supabase
          .from('private_messages')
          .select('*')
          .or('sender_id.eq.$myId,receiver_id.eq.$myId')
          .order('created_at', ascending: false);

      final messagesList = directMessages as List;

      // Extract unique contact IDs
      final contactIds = <String>{};
      final unreadCounts = <String, int>{};
      final lastMessages = <String, Map<String, dynamic>>{};

      for (final msg in messagesList) {
        final sender = msg['sender_id'].toString();
        final receiver = msg['receiver_id'].toString();
        final partnerId = sender == myId ? receiver : sender;

        contactIds.add(partnerId);

        // Record last message for preview
        if (!lastMessages.containsKey(partnerId)) {
          lastMessages[partnerId] = msg as Map<String, dynamic>;
        }

        // Count unreads
        if (receiver == myId && msg['is_read'] == false) {
          unreadCounts[partnerId] = (unreadCounts[partnerId] ?? 0) + 1;
        }
      }

      // Fetch user profile emails
      final profilesMap = <String, String>{};
      if (contactIds.isNotEmpty) {
        final profilesRes = await _supabase
            .from('profiles')
            .select('id, email')
            .inFilter('id', contactIds.toList());

        for (final p in profilesRes as List) {
          profilesMap[p['id'].toString()] = p['email'].toString();
        }
      }

      // 3. Assemble active chat lists
      final List<Map<String, dynamic>> assembledChats = [];

      // A. Standard system notification bot
      assembledChats.add({
        'id': systemBotId,
        'email': '站内通知',
        'isSystem': true,
        'preview': lastSysMsg != null ? (lastSysMsg['title'] ?? lastSysMsg['content']) : '暂无系统通知',
        'unread': sysUnread,
        'timestamp': lastSysMsg != null ? DateTime.parse(lastSysMsg['created_at'].toString()) : null,
      });

      // B. User contacts
      for (final partnerId in contactIds) {
        final email = profilesMap[partnerId] ?? 'Unknown';
        final lastMsg = lastMessages[partnerId];
        final unread = unreadCounts[partnerId] ?? 0;

        assembledChats.add({
          'id': partnerId,
          'email': email,
          'isSystem': false,
          'preview': lastMsg != null ? lastMsg['content'] : '',
          'unread': unread,
          'timestamp': lastMsg != null ? DateTime.parse(lastMsg['created_at'].toString()) : null,
        });
      }

      // Sort chats: System notification bot is always pinned to the top, others are sorted by last message timestamp
      assembledChats.sort((a, b) {
        final isSystemA = a['isSystem'] as bool? ?? false;
        final isSystemB = b['isSystem'] as bool? ?? false;
        if (isSystemA && !isSystemB) return -1;
        if (!isSystemA && isSystemB) return 1;

        final tA = a['timestamp'] as DateTime?;
        final tB = b['timestamp'] as DateTime?;
        if (tA == null) return 1;
        if (tB == null) return -1;
        return tB.compareTo(tA);
      });

      if (mounted) {
        setState(() {
          _chats = assembledChats;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint('Load chats error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNewChatDialog(ThemeData theme) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          title: const Text('发起新私信', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '输入对方邮箱',
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
                  final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
                  ToastHelper.show(rootContext, '请输入合法的邮箱地址', type: ToastType.warning);
                  return;
                }
                Navigator.pop(context);

                setState(() => _isLoading = true);
                try {
                  final myEmail = _supabase.auth.currentUser?.email;
                  if (myEmail == email) {
                    final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
                    ToastHelper.show(rootContext, '不能给自己发送私信哦', type: ToastType.warning);
                    return;
                  }

                  final userRes = await _supabase
                      .from('profiles')
                      .select('id, email')
                      .eq('email', email)
                      .single();

                  if (userRes == null) {
                    final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
                    ToastHelper.show(rootContext, '未找到该用户，请检查邮箱拼写', type: ToastType.error);
                    return;
                  }

                  // Open chat view directly
                  if (mounted) {
                    _openChatRoom({
                      'id': userRes['id'].toString(),
                      'email': userRes['email'].toString(),
                      'isSystem': false,
                    });
                  }

                } catch (e) {
                  final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
                  ToastHelper.show(rootContext, '查找失败，用户可能不存在', type: ToastType.error);
                } finally {
                  _loadChats(silent: true);
                }
              },
              child: const Text('查找并对话'),
            ),
          ],
        );
      },
    );
  }

  void _openChatRoom(Map<String, dynamic> chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ChatRoomPage(chat: chat),
      ),
    ).then((_) => _loadChats());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLoggedIn = AuthService.instance.isLoggedIn;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('私信消息', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (isLoggedIn)
            IconButton(
              icon: const Icon(Icons.rate_review_rounded),
              tooltip: '发起聊天',
              onPressed: () => _showNewChatDialog(theme),
            ),
        ],
      ),
      body: !isLoggedIn
          ? _buildNotLoggedInState(theme)
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _chats.isEmpty
                  ? _buildEmptyState(theme)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _chats.length,
                      itemBuilder: (context, index) {
                        final chat = _chats[index];
                        final isSystem = chat['isSystem'] as bool;
                        final name = isSystem ? chat['email'] : chat['email'].toString().split('@')[0];
                        final preview = chat['preview'] ?? '';
                        final unread = chat['unread'] as int;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: isSystem 
                                  ? theme.colorScheme.primaryContainer 
                                  : theme.colorScheme.secondaryContainer,
                              child: Icon(
                                isSystem ? Icons.campaign_rounded : Icons.person_rounded,
                                color: isSystem ? theme.colorScheme.primary : theme.colorScheme.secondary,
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            trailing: unread > 0
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      unread > 99 ? '99+' : unread.toString(),
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : const Icon(Icons.chevron_right_rounded),
                            onTap: () => _openChatRoom(chat),
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildNotLoggedInState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            '未登录账号',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '需要登录萌哩账号后，才可以使用站内私信及接收最新的系统广播通知。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无消息记录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角，向小伙伴们发送你的第一条私信吧！',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatRoomPage extends StatefulWidget {
  final Map<String, dynamic> chat;
  const _ChatRoomPage({required this.chat});

  @override
  State<_ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<_ChatRoomPage> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = true;
  List<dynamic> _messages = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAsRead();
    
    // Auto-refresh chat thread every 3 seconds to ensure real-time responsiveness
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    if (widget.chat['isSystem'] == true) {
      await _supabase.from('notifications').update({ 'is_read': true }).eq('user_id', myId).eq('is_read', false);
    } else {
      await _supabase.from('private_messages')
          .update({ 'is_read': true })
          .eq('receiver_id', myId)
          .eq('sender_id', widget.chat['id'])
          .eq('is_read', false);
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return;

      if (widget.chat['isSystem'] == true) {
        final res = await _supabase
            .from('notifications')
            .select('*')
            .eq('user_id', myId)
            .order('created_at', ascending: true);
        
        if (mounted) {
          setState(() {
            _messages = res as List;
            _isLoading = false;
          });
          _scrollToBottom();
        }
      } else {
        final partnerId = widget.chat['id'].toString();
        final res = await _supabase
            .from('private_messages')
            .select('*')
            .or('and(sender_id.eq.$myId,receiver_id.eq.$partnerId),and(sender_id.eq.$partnerId,receiver_id.eq.$myId)')
            .order('created_at', ascending: true);

        if (mounted) {
          setState(() {
            _messages = res as List;
            _isLoading = false;
          });
          _scrollToBottom();
        }
      }

    } catch (e) {
      debugPrint('Load message thread error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    _controller.clear();

    // Locally inject temporary message for instant responsiveness
    final tempMsg = {
      'sender_id': myId,
      'content': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() {
      _messages.add(tempMsg);
    });
    _scrollToBottom();

    try {
      await _supabase.from('private_messages').insert({
        'sender_id': myId,
        'receiver_id': widget.chat['id'].toString(),
        'content': text,
        'is_read': false,
      });

      _loadMessages(silent: true);
    } catch (e) {
      final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
      ToastHelper.show(rootContext, '消息发送失败，请检查网络', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSystem = widget.chat['isSystem'] == true;
    final name = isSystem ? widget.chat['email'] : widget.chat['email'].toString().split('@')[0];
    final myId = _supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMine = msg['sender_id'] == myId;
                      final isSystemMsg = isSystem;
                      final content = msg['content'] ?? '';

                      if (isSystemMsg) {
                        final title = msg['title'] ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.colorScheme.primaryContainer.withOpacity(0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (title.isNotEmpty)
                                Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              const SizedBox(height: 6),
                              Text(content, style: const TextStyle(fontSize: 13, height: 1.4)),
                            ],
                          ),
                        );
                      }

                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                          decoration: BoxDecoration(
                            color: isMine 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isMine ? Radius.zero : const Radius.circular(16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            content,
                            style: TextStyle(
                              fontSize: 13,
                              color: isMine ? Colors.white : theme.colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Private messages input room
          if (!isSystem)
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: '发送私信...',
                          hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
