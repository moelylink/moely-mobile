import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/image_item.dart';
import '../services/user_agent_service.dart';
import '../services/settings_service.dart';
import '../views/image_detail_screen.dart';
import 'smooth_aspect_ratio_image.dart';

class MoelyImageCard extends StatelessWidget {
  final MoelyImage image;
  final VoidCallback? onTap;
  final String? heroPrefix;

  const MoelyImageCard({
    super.key,
    required this.image,
    this.onTap,
    this.heroPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heroTag = heroPrefix != null ? '${heroPrefix}_${image.id}' : 'img_${image.id}';

    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final showInfo = AppSettings.instance.showGridImageInfo;

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.surface,
          elevation: 2,
          shadowColor: theme.colorScheme.shadow.withOpacity(0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.onSurface.withOpacity(0.06),
            ),
          ),
          child: InkWell(
            onTap: onTap ??
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageDetailScreen(image: image),
                    ),
                  );
                },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image section with floating total badge
                Stack(
                  children: [
                    Hero(
                      tag: heroTag,
                      child: SmoothAspectRatioImage(
                        imageUrl: image.urls,
                        httpHeaders: {'User-Agent': UserAgentService.userAgent},
                        builder: (context, isLoading) => CachedNetworkImage(
                          imageUrl: image.urls,
                          httpHeaders: {'User-Agent': UserAgentService.userAgent},
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: theme.colorScheme.surface,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: theme.colorScheme.surface,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (image.total != null && image.total != '1')
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.collections_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                image.total!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // Metadata section (conditional based on AppSettings.instance.showGridImageInfo)
                if (showInfo)
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image ID
                        Text(
                          'ID: ${image.id}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Author Name with Platform Icon
                        Row(
                          children: [
                            _buildPlatformIcon(theme),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                image.cleanUser,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlatformIcon(ThemeData theme) {
    final category = image.category.toLowerCase();
    if (category == 'pixiv') {
      return FaIcon(
        FontAwesomeIcons.pixiv,
        size: 12,
        color: theme.colorScheme.primary,
      );
    } else if (category == 'twitter') {
      return FaIcon(
        FontAwesomeIcons.squareTwitter,
        size: 12,
        color: theme.colorScheme.primary,
      );
    } else {
      return Icon(
        Icons.alternate_email_rounded,
        size: 12,
        color: theme.colorScheme.primary,
      );
    }
  }
}
