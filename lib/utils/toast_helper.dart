import 'dart:async';
import 'package:flutter/material.dart';
import '../services/url_handler_service.dart';

enum ToastType { info, success, warning, error }

class ToastHelper {
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    OverlayState? overlay;
    try {
      overlay = UrlHandlerService.navigatorKey.currentState?.overlay;
    } catch (_) {}
    
    try {
      overlay ??= Overlay.of(context);
    } catch (_) {}

    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        duration: duration,
        actionLabel: actionLabel,
        onActionTap: onActionTap,
        onDismissed: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }

  static void showCustom(
    BuildContext context, {
    required Widget Function(VoidCallback dismiss) builder,
    Duration duration = const Duration(seconds: 3),
  }) {
    OverlayState? overlay;
    try {
      overlay = UrlHandlerService.navigatorKey.currentState?.overlay;
    } catch (_) {}

    try {
      overlay ??= Overlay.of(context);
    } catch (_) {}

    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        builder: builder,
        duration: duration,
        onDismissed: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String? message;
  final ToastType? type;
  final Widget Function(VoidCallback dismiss)? builder;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final VoidCallback onDismissed;

  const _ToastWidget({
    this.message,
    this.type,
    this.builder,
    required this.duration,
    this.actionLabel,
    this.onActionTap,
    required this.onDismissed,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 3.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    _controller.forward().then((_) {
      _dismissTimer = Timer(widget.duration, () {
        if (mounted) {
          _controller.reverse().then((_) {
            widget.onDismissed();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget content;
    if (widget.builder != null) {
      content = widget.builder!(() {
        if (mounted) {
          _dismissTimer?.cancel();
          _controller.reverse().then((_) {
            widget.onDismissed();
          });
        }
      });
    } else {
      IconData iconData = Icons.info_outline_rounded;
      Color iconColor = theme.colorScheme.primary;
      
      switch (widget.type) {
        case ToastType.success:
          iconData = Icons.check_circle_rounded;
          iconColor = Colors.green;
          break;
        case ToastType.warning:
          iconData = Icons.warning_amber_rounded;
          iconColor = Colors.amber;
          break;
        case ToastType.error:
          iconData = Icons.error_outline_rounded;
          iconColor = Colors.red;
          break;
        case ToastType.info:
        default:
          iconData = Icons.info_outline_rounded;
          iconColor = theme.colorScheme.primary;
          break;
      }
      
      content = Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(iconData, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.message ?? '',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (widget.actionLabel != null && widget.onActionTap != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                widget.onActionTap!();
                _controller.reverse().then((_) {
                  widget.onDismissed();
                });
              },
              child: Text(
                widget.actionLabel!,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ],
      );
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 50.0, left: 24.0, right: 24.0),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Dismissible(
                key: const ValueKey('toast_dismissible'),
                direction: DismissDirection.down,
                onDismissed: (direction) {
                  widget.onDismissed();
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withOpacity(0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
