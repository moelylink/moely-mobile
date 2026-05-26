import 'dart:ui';
import 'package:flutter/material.dart';
import 'latest_tab.dart';
import 'random_tab.dart';
import 'explore_tab.dart';
import 'settings_tab.dart';
import 'mine_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Fully Native refactored tabs
  final List<Widget> _tabs = [
    const LatestTab(), // Latest WebView
    const ExploreTab(), // Explore Category / Search
    const RandomTab(), // Native Random Staggered Grid
    const SettingsTab(), // Native Settings Tab
    const MineTab(), // Native Mine/Profile Tab
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBody: true, // Allow body content to flow under the floating bottom bar
      body: Stack(
        children: [
          // Content Tab Layer
          IndexedStack(
            index: _currentIndex,
            children: _tabs,
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
          setState(() {
            _currentIndex = index;
          });
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


