import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/promo_item.dart';
import '../services/url_handler_service.dart';
import '../services/user_agent_service.dart';

class PromoCard extends StatelessWidget {
  final PromoItem promo;

  const PromoCard({super.key, required this.promo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 3,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.1),
      child: InkWell(
        onTap: () {
          UrlHandlerService.handleUrl(context, promo.url);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section with Badge
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: promo.fullImgUrl,
                  httpHeaders: {'User-Agent': UserAgentService.userAgent},
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 140,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 140,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.ads_click_rounded, size: 32),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '广告',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Details Section
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          theme.colorScheme.surface,
                          theme.colorScheme.surfaceDim,
                        ]
                      : [
                          theme.colorScheme.surface,
                          theme.colorScheme.surfaceContainerLow,
                        ],
                ),
              ),
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promo.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    promo.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '了解更多',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 8,
                        color: theme.colorScheme.secondary,
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
  }
}
