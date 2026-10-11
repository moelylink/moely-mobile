import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/image_item.dart';
import '../models/promo_item.dart';
import '../services/user_agent_service.dart';
import '../services/promo_service.dart';
import '../widgets/promo_card.dart';
import '../widgets/moely_image_card.dart';
import '../widgets/moely_waterfall_view.dart';

class RandomTab extends StatefulWidget {
  const RandomTab({super.key});

  @override
  State<RandomTab> createState() => _RandomTabState();
}

class _RandomTabState extends State<RandomTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final Dio _dio = UserAgentService.createDio();
  List<dynamic> _images = [];
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

        await PromoService.instance.fetchPromos();

        final List<dynamic> items = [];
        int imageCount = 0;
        for (final img in images) {
          items.add(img);
          imageCount++;
          if (imageCount % 20 == 0) {
            final promo = PromoService.instance.getRandomPromo();
            if (promo != null) {
              items.add(promo);
            }
          }
        }

        if (mounted) {
          setState(() {
            _images = items;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Invalid data structure');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '随机探索',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
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
      body: MoelyWaterfallView(
        isRootTab: true,
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final item = _images[index];
          if (item is PromoItem) {
            return PromoCard(promo: item);
          } else if (item is MoelyImage) {
            return MoelyImageCard(image: item, heroPrefix: 'random');
          }
          return const SizedBox.shrink();
        },
        currentPage: 1,
        totalPages: 1,
        isLoading: _isLoading,
        hasError: _hasError,
        onRefresh: _fetchRandomImages,
      ),
    );
  }
}
