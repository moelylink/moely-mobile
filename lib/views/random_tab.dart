import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/image_item.dart';
import '../services/user_agent_service.dart';
import 'image_detail_screen.dart';

class RandomTab extends StatefulWidget {
  const RandomTab({super.key});

  @override
  State<RandomTab> createState() => _RandomTabState();
}

class _RandomTabState extends State<RandomTab> {
  final Dio _dio = UserAgentService.createDio();
  List<MoelyImage> _images = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchRandomImages();
  }

  Future<void> _fetchRandomImages() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await _dio.get('https://www.moely.link/index.json');
      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> listData = response.data;
        final images = listData.map((e) => MoelyImage.fromJson(e)).toList();
        images.shuffle(); // Randomize the list
        setState(() {
          _images = images;
          _isLoading = false;
        });
      } else {
        throw Exception('Invalid data structure');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          '随机探索',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(Icons.shuffle_rounded, color: theme.colorScheme.primary),
            onPressed: _fetchRandomImages,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRandomImages,
        color: theme.colorScheme.primary,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: theme.colorScheme.error.withOpacity(0.8),
              ),
              const SizedBox(height: 16),
              Text(
                '数据加载失败',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _fetchRandomImages,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新尝试'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_images.isEmpty) {
      return const Center(
        child: Text('没有找到插画文件'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: _images.length,
        padding: const EdgeInsets.only(bottom: 96.0), // Padding for the floating bottom bar
        itemBuilder: (context, index) {
          final image = _images[index];
          return _buildImageCard(theme, image);
        },
      ),
    );
  }

  Widget _buildImageCard(ThemeData theme, MoelyImage image) {
    final platformColor = theme.colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 3,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
      child: InkWell(
        onTap: () {
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
            // Image section
            Hero(
              tag: 'img_${image.id}',
              child: CachedNetworkImage(
                imageUrl: image.urls,
                httpHeaders: {'User-Agent': UserAgentService.userAgent},
                fit: BoxFit.fitWidth,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: theme.colorScheme.surfaceVariant,
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
                  height: 200,
                  color: theme.colorScheme.surfaceVariant,
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded),
                  ),
                ),
              ),
            ),
            
            // Metadata section
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row for Category Badge & Multi-image Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: platformColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: platformColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          image.category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: platformColor,
                          ),
                        ),
                      ),
                      if (image.total != null && image.total != '1')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.collections_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              image.total!,
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Image ID
                  Row(
                    children: [
                      Icon(
                        Icons.tag_rounded,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'ID: ${image.id}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Author Name
                  Row(
                    children: [
                      Icon(
                        Icons.alternate_email_rounded,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
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
  }
}
