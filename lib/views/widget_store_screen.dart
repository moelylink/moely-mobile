import 'package:flutter/material.dart';
import '../utils/toast_helper.dart';
import '../services/url_handler_service.dart';

class WidgetStoreScreen extends StatelessWidget {
  const WidgetStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mockWidgets = [
      {
        'title': '萌哩每日一图',
        'desc': '在桌面上展示每日精心挑选的二次元神级美图，支持自动更新与点击跳转。',
        'size': '4 × 2',
        'downloads': '1.2 万',
        'price': '免费',
        'color': const Color(0xFFAB47BC),
        'icon': Icons.image_rounded,
      },
      {
        'title': '随机探索看板娘',
        'desc': '随机展示最受好评的精选画师代表作，让你的桌面瞬间充满朝气与灵动！',
        'size': '2 × 2',
        'downloads': '8,500',
        'price': '免费',
        'color': const Color(0xFFFF7043),
        'icon': Icons.assistant_rounded,
      },
      {
        'title': '色彩灵感卡',
        'desc': '聚合当日最火二次元插画的配色色卡方案，一键复制十六进制灵感配色。',
        'size': '4 × 1',
        'downloads': '4,300',
        'price': '10 萌豆',
        'color': const Color(0xFF66BB6A),
        'icon': Icons.color_lens_rounded,
      },
      {
        'title': '画师动态订阅',
        'desc': '在您的手机桌面上实时接收订阅画师的最新发布作品，不错过任何心动瞬间。',
        'size': '2 × 2',
        'downloads': '6,200',
        'price': '免费',
        'color': const Color(0xFF29B6F6),
        'icon': Icons.rss_feed_rounded,
      },
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('小部件商城', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // Banner Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      Icons.widgets_rounded,
                      size: 160,
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '让桌面跃然指尖',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '下载并设置 iOS & Android 原生桌面小部件，精美二次元插图一触即达。',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '精选小部件',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Widgets list
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final widgetItem = mockWidgets[index];
                  final title = widgetItem['title'].toString();
                  final desc = widgetItem['desc'].toString();
                  final size = widgetItem['size'].toString();
                  final downloads = widgetItem['downloads'].toString();
                  final price = widgetItem['price'].toString();
                  final color = widgetItem['color'] as Color;
                  final icon = widgetItem['icon'] as IconData;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Widget Icon Placeholder
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(icon, color: color, size: 28),
                          ),
                          const SizedBox(width: 16),
                          
                          // Widget Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.onSurface.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        size,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.download_rounded, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$downloads 下载',
                                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                    ),
                                    const Spacer(),
                                    FilledButton(
                                      onPressed: () {
                                        final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
                                        ToastHelper.show(rootContext, '$title 小部件正在开发中，敬请期待！', type: ToastType.warning);
                                      },
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      child: Text(price),
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
                childCount: mockWidgets.length,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
