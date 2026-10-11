import 'package:flutter/material.dart';

/// A widget that displays text and automatically performs a seamless marquee loop scroll
/// when the text width exceeds the available container width.
class AutoScrollingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool centerWhenNoScroll;
  final double velocity;
  final double blankSpacing;
  final bool forceScroll;

  const AutoScrollingText({
    super.key,
    required this.text,
    required this.style,
    this.centerWhenNoScroll = true,
    this.velocity = 30.0,
    this.blankSpacing = 48.0,
    this.forceScroll = false,
  });

  @override
  State<AutoScrollingText> createState() => _AutoScrollingTextState();
}

class _AutoScrollingTextState extends State<AutoScrollingText> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  double _unitWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this);
  }

  void _setupAnimation(bool shouldScroll, double unitWidth) {
    _unitWidth = unitWidth;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (shouldScroll && unitWidth > 0) {
        final durationSeconds = (unitWidth / widget.velocity).clamp(1.0, 60.0);
        final newDuration = Duration(milliseconds: (durationSeconds * 1000).toInt());
        if (_animController.duration != newDuration || !_animController.isAnimating) {
          _animController.duration = newDuration;
          _animController.stop();
          _animController.reset();
          _animController.repeat();
        }
      } else {
        if (_animController.isAnimating) {
          _animController.stop();
          _animController.reset();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant AutoScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.velocity != widget.velocity ||
        oldWidget.blankSpacing != widget.blankSpacing ||
        oldWidget.forceScroll != widget.forceScroll) {
      _animController.stop();
      _animController.reset();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        if (containerWidth <= 0 || containerWidth.isInfinite) {
          _setupAnimation(false, 0);
          return Align(
            alignment: widget.centerWhenNoScroll ? Alignment.center : Alignment.centerLeft,
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        // Measure exact text width using TextPainter with device textScaler
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();

        final textWidth = textPainter.width;
        // Trigger scrolling if forceScroll is enabled or text width (plus 2px buffer) exceeds container width
        final shouldScroll = widget.forceScroll || (textWidth + 2.0) > containerWidth;
        final unitWidth = textWidth + widget.blankSpacing;

        _setupAnimation(shouldScroll, unitWidth);

        if (!shouldScroll) {
          return Align(
            alignment: widget.centerWhenNoScroll ? Alignment.center : Alignment.centerLeft,
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final currentOffset = _unitWidth > 0 ? -_animController.value * _unitWidth : 0.0;
              return Transform.translate(
                offset: Offset(currentOffset, 0),
                child: child,
              );
            },
            child: OverflowBox(
              minWidth: 0,
              maxWidth: double.infinity,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.text,
                    style: widget.style,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                  SizedBox(width: widget.blankSpacing),
                  Text(
                    widget.text,
                    style: widget.style,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                  SizedBox(width: widget.blankSpacing),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
