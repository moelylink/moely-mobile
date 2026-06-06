import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SmoothAspectRatioImage extends StatefulWidget {
  final String? imageUrl;
  final File? localFile;
  final Map<String, String>? httpHeaders;
  final Widget Function(BuildContext context, bool isLoading) builder;
  final double defaultAspectRatio;

  const SmoothAspectRatioImage({
    super.key,
    this.imageUrl,
    this.localFile,
    this.httpHeaders,
    required this.builder,
    this.defaultAspectRatio = 1.3,
  });

  @override
  State<SmoothAspectRatioImage> createState() => _SmoothAspectRatioImageState();
}

class _SmoothAspectRatioImageState extends State<SmoothAspectRatioImage> {
  double? _aspectRatio;
  bool _shouldAnimate = true;

  // Global static cache to record resolved image aspect ratios, preventing layout shift on scroll
  static final Map<String, double> _aspectRatioCache = {};

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant SmoothAspectRatioImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl || oldWidget.localFile?.path != widget.localFile?.path) {
      _resolveAspectRatio();
    }
  }

  void _resolveAspectRatio() {
    final cacheKey = widget.localFile != null ? widget.localFile!.path : widget.imageUrl;
    if (cacheKey == null) return;

    // 1. Try memory cache first
    if (_aspectRatioCache.containsKey(cacheKey)) {
      _aspectRatio = _aspectRatioCache[cacheKey];
      _shouldAnimate = false;
      return;
    }

    _shouldAnimate = true;

    // 2. Fetch using ImageStream to get size dimensions
    try {
      final ImageProvider provider = widget.localFile != null
          ? FileImage(widget.localFile!)
          : CachedNetworkImageProvider(
              widget.imageUrl!,
              headers: widget.httpHeaders,
            ) as ImageProvider;

      final ImageStream stream = provider.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;

      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          final double ratio = info.image.width / info.image.height;
          _aspectRatioCache[cacheKey] = ratio; // Write to cache
          if (mounted) {
            setState(() {
              _aspectRatio = ratio;
              _shouldAnimate = !synchronousCall;
            });
          }
          // Remove listener after we resolve the ratio
          stream.removeListener(listener);
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
    } catch (_) {
      // Graceful fallback to default aspect ratio
    }
  }

  @override
  Widget build(BuildContext context) {
    final double targetRatio = _aspectRatio ?? widget.defaultAspectRatio;

    if (!_shouldAnimate) {
      return AspectRatio(
        aspectRatio: targetRatio,
        child: widget.builder(context, false),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: widget.defaultAspectRatio, end: targetRatio),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      builder: (context, ratio, child) {
        return AspectRatio(
          aspectRatio: ratio,
          child: widget.builder(context, _aspectRatio == null),
        );
      },
    );
  }
}
