import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// Floating glassmorphic pagination pill component used across grid pages.
class FloatingPaginationPill extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueNotifier<bool> isVisibleNotifier;
  final ValueChanged<int> onPageSelected;
  final double bottomOffset;
  final bool isLoading;
  final bool hasError;

  const FloatingPaginationPill({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.isVisibleNotifier,
    required this.onPageSelected,
    this.bottomOffset = 24.0,
    this.isLoading = false,
    this.hasError = false,
  });

  void _showPageJumpDialog(BuildContext context) {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: currentPage.toString());
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          title: Text(
            '跳转到指定页',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: MediaQuery.of(dialogContext).size.width * 0.85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '可输入范围：1 ~ $totalPages (当前第 $currentPage 页)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: errorMessage != null
                          ? Colors.redAccent
                          : theme.colorScheme.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: errorMessage != null ? Colors.redAccent : theme.colorScheme.primary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                '取消',
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(controller.text);
                if (val != null && val >= 1 && val <= totalPages) {
                  Navigator.pop(dialogContext);
                  if (val != currentPage) {
                    onPageSelected(val);
                  }
                } else {
                  setDialogState(() {
                    errorMessage = '页码范围错误，请输入 1 ~ $totalPages';
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('确认', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final enableInfinite = AppSettings.instance.enableInfiniteScroll;
        if (enableInfinite || isLoading || hasError || totalPages <= 1) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<bool>(
          valueListenable: isVisibleNotifier,
          builder: (context, isVisible, child) {
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: isVisible ? bottomOffset : -80.0,
              left: 24.0,
              right: 24.0,
              child: Center(
                child: Material(
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30.0),
                  color: theme.colorScheme.surface.withOpacity(0.85),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30.0),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: currentPage > 1
                              ? () => onPageSelected(currentPage - 1)
                              : null,
                        ),
                        InkWell(
                          onTap: () => _showPageJumpDialog(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Text(
                              '$currentPage / $totalPages',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: currentPage < totalPages
                              ? () => onPageSelected(currentPage + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
