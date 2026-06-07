import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'latest_tab.dart';
import 'random_tab.dart';
import 'explore_tab.dart';
import 'settings_tab.dart';
import 'mine_tab.dart';
import '../services/update_service.dart';
import '../services/url_handler_service.dart';

class HomeScreen extends StatefulWidget {
  static final GlobalKey<HomeScreenState> homeKey = GlobalKey<HomeScreenState>();

  HomeScreen() : super(key: homeKey);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late PageController _pageController;
  bool _isAnimating = false;
  List<Widget>? _displayTabs;

  final List<GlobalKey> _tabKeys = List.generate(5, (_) => GlobalKey());

  late final List<Widget> _tabs = [
    LatestTab(), // Latest Tab (internally uses LatestTab.latestTabKey)
    ExploreTab(key: _tabKeys[1]), // Explore Category / Search
    RandomTab(key: _tabKeys[2]), // Native Random Staggered Grid
    SettingsTab(key: _tabKeys[3]), // Native Settings Tab
    MineTab(key: _tabKeys[4]), // Native Mine/Profile Tab
  ];

  void switchTab(int index) {
    if (!mounted || _isAnimating || index == _currentIndex) return;

    FocusScope.of(context).unfocus();

    final int fromIndex = _currentIndex;
    final int toIndex = index;
    final int distance = (toIndex - fromIndex).abs();

    if (!_pageController.hasClients) {
      setState(() {
        _currentIndex = toIndex;
      });
      return;
    }

    if (distance == 1) {
      setState(() {
        _currentIndex = toIndex;
        _isAnimating = true;
      });
      _pageController.animateToPage(
        toIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
          });
        }
      });
    } else {
      final tempTabs = List<Widget>.from(_tabs);
      final int tempTargetIndex = toIndex > fromIndex ? fromIndex + 1 : fromIndex - 1;

      // Place the target tab at the adjacent index
      tempTabs[tempTargetIndex] = _tabs[toIndex];

      // Put placeholders at all other indices to prevent duplicate widgets in the tree
      for (int i = 0; i < tempTabs.length; i++) {
        if (i != fromIndex && i != tempTargetIndex) {
          tempTabs[i] = const SizedBox();
        }
      }

      setState(() {
        _currentIndex = toIndex;
        _displayTabs = tempTabs;
        _isAnimating = true;
      });

      _pageController.animateToPage(
        tempTargetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) {
        if (mounted) {
          _pageController.jumpToPage(toIndex);
          setState(() {
            _displayTabs = null;
            _isAnimating = false;
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkUpdate();
      UrlHandlerService.handlePendingUrl(context);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await Permission.storage.request();
        await Permission.photos.request();
      }
    } catch (e) {
      debugPrint('Failed to request permissions: $e');
    }
  }

  // Fully Native refactored tabs
  // (We use _tabs defined above)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBody: true, // Allow body content to flow under the floating bottom bar
      body: Stack(
        children: [
          // Content Tab Layer
          PageView(
            controller: _pageController,
            physics: _isAnimating ? const NeverScrollableScrollPhysics() : null,
            onPageChanged: (index) {
              if (!_isAnimating) {
                setState(() {
                  _currentIndex = index;
                });
                FocusScope.of(context).unfocus();
              }
            },
            children: _displayTabs ?? _tabs,
          ),
          
          // Telegram-Style Floating Glassmorphic Navigation Bar
          Positioned(
            left: 18.0,
            right: 18.0,
            bottom: 24.0,
            child: _buildFloatingBottomBar(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.72),
        borderRadius: BorderRadius.circular(30.0),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.auto_awesome_rounded, '最新', theme),
                _buildNavItem(1, Icons.explore_rounded, '探索', theme),
                _buildNavItem(2, Icons.shuffle_rounded, '随机', theme),
                _buildNavItem(3, Icons.settings_rounded, '设置', theme),
                _buildNavItem(4, Icons.person_rounded, '我的', theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, ThemeData theme) {
    final isSelected = _currentIndex == index;
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurface.withOpacity(0.5);

    return Expanded(
      child: InkWell(
        onTap: () {
          switchTab(index);
        },
        borderRadius: BorderRadius.circular(20.0),
        splashColor: activeColor.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with capsule backdrop if selected
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? activeColor.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4.0),
              
              // Text label
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


