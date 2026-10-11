import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/artist_item.dart';
import '../services/html_parser_service.dart';
import '../services/user_agent_service.dart';
import 'artist_profile_screen.dart';
import '../widgets/platform_avatar_badge.dart';
import '../widgets/moely_error_widget.dart';

class ArtistsListScreen extends StatefulWidget {
  const ArtistsListScreen({super.key});

  @override
  State<ArtistsListScreen> createState() => _ArtistsListScreenState();
}

class _ArtistsListScreenState extends State<ArtistsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ArtistItem> _allArtists = [];
  List<ArtistItem> _filteredArtists = [];

  bool _isLoading = true;
  bool _hasError = false;

  String _selectedPlatform = 'all'; // 'all', 'pixiv', 'twitter'
  String _selectedSort = 'count'; // 'count', 'name'

  @override
  void initState() {
    super.initState();
    _fetchArtists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchArtists() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final artists = await HtmlParserService.fetchArtistsList();
      if (mounted) {
        setState(() {
          _allArtists = artists;
          _isLoading = false;
        });
        _applyFilterAndSort();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _applyFilterAndSort() {
    final query = _searchController.text.trim().toLowerCase();

    var list = _allArtists.where((artist) {
      final matchesQuery = query.isEmpty ||
          artist.name.toLowerCase().contains(query) ||
          artist.uid.toLowerCase().contains(query);

      final matchesPlatform = _selectedPlatform == 'all' ||
          (_selectedPlatform == 'pixiv' && artist.hasPixiv) ||
          (_selectedPlatform == 'twitter' && artist.hasTwitter);

      return matchesQuery && matchesPlatform;
    }).toList();

    if (_selectedSort == 'name') {
      list.sort((a, b) {
        final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (cmp != 0) return cmp;
        return b.count.compareTo(a.count);
      });
    } else {
      list.sort((a, b) {
        final cmp = b.count.compareTo(a.count);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }

    setState(() {
      _filteredArtists = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text(
          '画师库',
          style: TextStyle(fontWeight: FontWeight.bold),
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
            onPressed: _fetchArtists,
          ),
        ],
      ),
      body: _buildBody(theme, primaryColor),
    );
  }

  Widget _buildBody(ThemeData theme, Color primaryColor) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (_hasError) {
      return MoelyErrorWidget(
        message: '画师库加载失败，请检查网络',
        icon: Icons.palette_outlined,
        onRetry: _fetchArtists,
      );
    }

    final isFiltered = _searchController.text.trim().isNotEmpty || _selectedPlatform != 'all';
    final countText = isFiltered
        ? '${_filteredArtists.length} / ${_allArtists.length}'
        : '${_allArtists.length}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applyFilterAndSort(),
              decoration: InputDecoration(
                hintText: '搜索画师名称、UID...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: primaryColor,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilterAndSort();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
              ),
            ),
          ),
        ),

        // Filter and Sort Chips Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              // Platform Filter
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPlatformChip('全部', 'all', theme),
                      const SizedBox(width: 8),
                      _buildPlatformChip('Pixiv', 'pixiv', theme),
                      const SizedBox(width: 8),
                      _buildPlatformChip('Twitter', 'twitter', theme),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort Mode Dropdown Button
              PopupMenuButton<String>(
                initialValue: _selectedSort,
                onSelected: (val) {
                  setState(() {
                    _selectedSort = val;
                  });
                  _applyFilterAndSort();
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'count',
                    child: Row(
                      children: [
                        Icon(Icons.sort_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('作品数排序'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'name',
                    child: Row(
                      children: [
                        Icon(Icons.sort_by_alpha_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('名称排序'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedSort == 'count' ? Icons.sort_rounded : Icons.sort_by_alpha_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedSort == 'count' ? '作品数' : '名称',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Stats summary
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '共 $countText 位画师',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Grid of Artist Cards
        Expanded(
          child: _filteredArtists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search_rounded,
                        size: 56,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '未找到匹配的画师',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchArtists,
                  color: primaryColor,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 134,
                    ),
                    itemCount: _filteredArtists.length,
                    itemBuilder: (context, index) {
                      final artist = _filteredArtists[index];
                      return _buildArtistCard(artist, theme);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPlatformChip(String label, String value, ThemeData theme) {
    final isSelected = _selectedPlatform == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPlatform = value;
          });
          _applyFilterAndSort();
        }
      },
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  Widget _buildArtistCard(ArtistItem artist, ThemeData theme) {
    final bool hasPixiv = artist.hasPixiv;
    final bool hasTwitter = artist.hasTwitter;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArtistProfileScreen(
                artistUid: artist.uid,
                artistName: artist.name,
                initialAvatar: artist.avatar,
                initialCount: artist.count,
                hasPixiv: artist.hasPixiv,
                hasTwitter: artist.hasTwitter,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.onSurface.withOpacity(0.08),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with platform badge in center
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surfaceVariant,
                    ),
                    child: ClipOval(
                      child: artist.avatar.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: artist.avatar,
                              httpHeaders: {'User-Agent': UserAgentService.userAgent},
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Icon(
                                Icons.person_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 28,
                              ),
                              placeholder: (context, url) => Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 28,
                            ),
                    ),
                  ),
                  // Platform mini-badge
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: PlatformAvatarBadge(
                      hasPixiv: hasPixiv,
                      hasTwitter: hasTwitter,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Name centered
              Text(
                artist.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),

              // Metadata centered (UID & Works Count)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'UID: ${artist.uid}',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: theme.colorScheme.onSurface.withOpacity(0.45),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${artist.count} 幅',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
