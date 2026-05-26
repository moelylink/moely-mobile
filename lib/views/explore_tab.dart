import 'package:flutter/material.dart';
import 'category_grid_screen.dart';
import 'tags_list_screen.dart';
import 'search_grid_screen.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final TextEditingController _searchController = TextEditingController();

  void _handleSearch(String query) {
    if (query.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchGridScreen(query: query.trim()),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 120.0), // Room for bottom floating bar
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header title
              Text(
                '探索灵感',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                '搜你所想，探索更精彩的二次元世界',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onBackground.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24.0),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _handleSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '搜索插画、画师、标签...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 16.0,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 32.0),

              // Modules Header
              Text(
                '精选模块',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 16.0),

              // Pixiv Categories Card
              _buildCategoryCard(
                title: 'Pixiv 分类',
                subtitle: '浏览精心编排的 Pixiv 优质插画集',
                icon: Icons.art_track_rounded,
                startColor: const Color(0xFF0052D4),
                endColor: const Color(0xFF4364F7),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoryGridScreen(
                        categoryCode: 'pixiv',
                        title: 'Pixiv 精选分类',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16.0),

              // Twitter Categories Card
              _buildCategoryCard(
                title: 'Twitter 分类',
                subtitle: '跟随推特画师足迹，品味先锋画风',
                icon: Icons.flutter_dash_rounded,
                startColor: const Color(0xFF1c92d2),
                endColor: const Color(0xFF06B6D4),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoryGridScreen(
                        categoryCode: 'twitter',
                        title: 'Twitter 精选分类',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16.0),

              // Tag Cloud Card
              _buildCategoryCard(
                title: '热门标签云',
                subtitle: '从错综复杂的二次元属性云端发现美好',
                icon: Icons.cloud_circle_rounded,
                startColor: const Color(0xFF10B981),
                endColor: const Color(0xFF12FFF7),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TagsListScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color startColor,
    required Color endColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        gradient: LinearGradient(
          colors: [
            startColor.withOpacity(isDark ? 0.35 : 0.85),
            endColor.withOpacity(isDark ? 0.20 : 0.70),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: startColor.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(isDark ? 0.08 : 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24.0),
          splashColor: Colors.white.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Icon Section
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 18.0),
                
                // Text Section
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Arrow
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
