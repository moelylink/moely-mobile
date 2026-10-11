import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PlatformAvatarBadge extends StatelessWidget {
  final bool hasPixiv;
  final bool hasTwitter;
  final double size;

  static const Color pixivBlue = Color(0xFF0096FA);

  const PlatformAvatarBadge({
    super.key,
    required this.hasPixiv,
    required this.hasTwitter,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasPixiv && !hasTwitter) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.surface;

    // Single Platform: Pixiv (Blue background container + White inner counter underlay + Pixiv Blue FA Icon)
    if (hasPixiv && !hasTwitter) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: pixivBlue,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: pixivBlue.withOpacity(0.35),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: size * 0.85,
            height: size * 0.85,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Solid pure white underlay circle to fill the inner 'P' counter
                Container(
                  width: size * 0.48,
                  height: size * 0.48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                // 2. Native FontAwesome Pixiv Icon in Pixiv Blue
                FaIcon(
                  FontAwesomeIcons.pixiv,
                  size: size * 0.78,
                  color: pixivBlue,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Single Platform: Twitter (X)
    if (!hasPixiv && hasTwitter) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: FaIcon(
            FontAwesomeIcons.xTwitter,
            size: size * 0.5,
            color: Colors.white,
          ),
        ),
      );
    }

    // Dual Platform (hasPixiv && hasTwitter): Moesource Dual Stacked Badge
    // Pixiv in front (Left/Z-2), Twitter X behind (Right/Z-1, offset by ~45%)
    final overlapOffset = size * 0.45;

    return SizedBox(
      width: size + (size - overlapOffset),
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Rear Layer: Twitter (X)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: FaIcon(
                  FontAwesomeIcons.xTwitter,
                  size: size * 0.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Front Layer: Pixiv (Blue background container + White inner counter underlay)
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: pixivBlue,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: pixivBlue.withOpacity(0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: size * 0.85,
                  height: size * 0.85,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. Solid pure white underlay circle to fill the inner 'P' counter
                      Container(
                        width: size * 0.48,
                        height: size * 0.48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      // 2. Native FontAwesome Pixiv Icon in Pixiv Blue
                      FaIcon(
                        FontAwesomeIcons.pixiv,
                        size: size * 0.78,
                        color: pixivBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
