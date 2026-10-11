import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/artist_item.dart';
import '../models/image_item.dart';
import '../services/html_parser_service.dart';
import '../services/user_agent_service.dart';
import 'denoised_web_screen.dart';
import '../widgets/auto_scrolling_text.dart';
import '../widgets/moely_waterfall_view.dart';
import '../widgets/platform_avatar_badge.dart';
import '../widgets/moely_error_widget.dart';

class ArtistProfileScreen extends StatefulWidget {
  final String artistUid;
  final String artistName;
  final String? initialAvatar;
  final int? initialCount;
  final bool hasPixiv;
  final bool hasTwitter;

  const ArtistProfileScreen({
    super.key,
    required this.artistUid,
    required this.artistName,
    this.initialAvatar,
    this.initialCount,
    this.hasPixiv = false,
    this.hasTwitter = false,
  });

  @override
  State<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends State<ArtistProfileScreen> {
  final List<MoelyImage> _images = [];
  ArtistProfile? _profile;

  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingInitial = true;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _hasError = false;

  String get _displayArtistTitle {
    final name = (_profile?.name.isNotEmpty == true ? _profile!.name : widget.artistName).trim();
    if (name.startsWith('画师：') || name.startsWith('画师:')) {
      return name;
    }
    return '画师：$name';
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoadingInitial = true;
      _hasError = false;
    });

    try {
      final profile = await HtmlParserService.fetchArtistProfile(
        widget.artistUid,
        _currentPage,
        fallbackName: widget.artistName,
      );

      if (mounted) {
        if (profile.images.isEmpty && profile.count <= 0) {
          setState(() {
            _isLoadingInitial = false;
            _hasError = true;
          });
          return;
        }

        setState(() {
          _profile = profile;
          _images.clear();
          _images.addAll(profile.images);
          _totalPages = profile.totalPages;
          _isLoadingInitial = false;
          _hasMore = _currentPage < _totalPages;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _fetchNextPage() async {
    if (_isLoadingMore || !_hasMore || _currentPage >= _totalPages) return;
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final profile = await HtmlParserService.fetchArtistProfile(
        widget.artistUid,
        nextPage,
        fallbackName: widget.artistName,
      );

      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _images.addAll(profile.images);
          _totalPages = profile.totalPages;
          _hasMore = _currentPage < _totalPages;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = theme.colorScheme.primary;

    final avatarUrl = _profile?.avatar.isNotEmpty == true
        ? _profile!.avatar
        : (widget.initialAvatar ?? '');
    final artistName = _profile?.name.isNotEmpty == true
        ? _profile!.name
        : widget.artistName;
    final worksCount = _profile?.count ?? widget.initialCount ?? _images.length;
    final hasPixiv = _profile?.hasPixiv ?? widget.hasPixiv;
    final hasTwitter = _profile?.hasTwitter ?? widget.hasTwitter;
    final pixivUrl = _profile?.pixivUrl;
    final twitterUrl = _profile?.twitterUrl;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: SizedBox(
          height: 28,
          child: AutoScrollingText(
            text: _displayArtistTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: theme.colorScheme.onSurface,
            ),
            centerWhenNoScroll: true,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchProfile,
          ),
        ],
      ),
      body: (_hasError && _images.isEmpty && _profile == null)
          ? MoelyErrorWidget(
              message: '画师主页加载失败，请检查网络',
              icon: Icons.palette_outlined,
              onRetry: _fetchProfile,
            )
          : MoelyWaterfallView(
        images: _images,
        currentPage: _currentPage,
        totalPages: _totalPages,
        isLoading: _isLoadingInitial,
        isLoadingMore: _isLoadingMore,
        hasError: _hasError,
        onRefresh: _fetchProfile,
        onPageSelected: (page) {
          setState(() {
            _currentPage = page;
          });
          _fetchProfile();
        },
        onLoadMore: _fetchNextPage,
        heroPrefix: 'artist_${widget.artistUid}',
        headerSlivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withOpacity(0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Avatar
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.surfaceContainerHighest,
                              ),
                              child: ClipOval(
                                child: avatarUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: avatarUrl,
                                        httpHeaders: {'User-Agent': UserAgentService.userAgent},
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: brandColor,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Icon(
                                          Icons.person_rounded,
                                          color: theme.colorScheme.onSurfaceVariant,
                                          size: 36,
                                        ),
                                      )
                                    : Icon(
                                        Icons.person_rounded,
                                        color: theme.colorScheme.onSurfaceVariant,
                                        size: 36,
                                      ),
                              ),
                            ),
                            // Platform badge
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: PlatformAvatarBadge(
                                hasPixiv: hasPixiv,
                                hasTwitter: hasTwitter,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),

                        // Name and Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                artistName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.photo_library_rounded,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '收录作品：$worksCount 幅',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'UID: ${widget.artistUid}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withOpacity(0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // External Profile Action Buttons (if available)
                    if (pixivUrl != null || twitterUrl != null) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (pixivUrl != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DenoisedWebScreen(
                                        url: pixivUrl,
                                        title: '$artistName 的 Pixiv 主页',
                                      ),
                                    ),
                                  );
                                },
                                icon: const FaIcon(FontAwesomeIcons.pixiv, size: 15),
                                label: const Text('Pixiv 主页', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0096FA),
                                  side: const BorderSide(color: Color(0xFF0096FA)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          if (pixivUrl != null && twitterUrl != null)
                            const SizedBox(width: 10),
                          if (twitterUrl != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DenoisedWebScreen(
                                        url: twitterUrl,
                                        title: '$artistName 的 Twitter 主页',
                                      ),
                                    ),
                                  );
                                },
                                icon: FaIcon(FontAwesomeIcons.twitter, size: 14),
                                label: const Text('Twitter 主页', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary,
                                  side: BorderSide(color: theme.colorScheme.primary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
