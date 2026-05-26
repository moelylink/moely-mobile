import 'package:flutter/material.dart';
import '../services/html_parser_service.dart';
import 'tag_grid_screen.dart';

class TagsListScreen extends StatefulWidget {
  const TagsListScreen({super.key});

  @override
  State<TagsListScreen> createState() => _TagsListScreenState();
}

class _TagsListScreenState extends State<TagsListScreen> {
  List<Map<String, dynamic>> _allTags = [];
  List<Map<String, dynamic>> _filteredTags = [];
  
  bool _isLoading = true;
  bool _hasError = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchTags();
  }

  Future<void> _fetchTags() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final tags = await HtmlParserService.fetchTagsList();
      setState(() {
        _allTags = tags;
        _filteredTags = tags;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _filterTags(String query) {
    setState(() {
      _searchQuery = query;
      if (query.trim().isEmpty) {
        _filteredTags = _allTags;
      } else {
        _filteredTags = _allTags
            .where((tag) => tag['name']
                .toString()
                .toLowerCase()
                .contains(query.trim().toLowerCase()))
            .toList();
      }
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
          '热门标签云',
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
            onPressed: _fetchTags,
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '标签云加载失败',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _fetchTags,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新加载'),
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

    if (_allTags.isEmpty) {
      return const Center(
        child: Text('未找到任何标签'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tag Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
              onChanged: _filterTags,
              decoration: InputDecoration(
                hintText: '搜索标签...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.colorScheme.primary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 14.0,
                ),
              ),
            ),
          ),
        ),

        // Tags Scroll View
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 40.0),
            child: Wrap(
              spacing: 10.0,
              runSpacing: 12.0,
              children: _filteredTags.map((tag) {
                final String name = tag['name'];
                final int count = tag['count'];
                
                // Dynamically calculate tag size based on popularity
                double fontSize = 12.0;
                if (count > 1000) {
                  fontSize = 16.0;
                } else if (count > 500) {
                  fontSize = 14.5;
                } else if (count > 200) {
                  fontSize = 13.5;
                }

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TagGridScreen(tag: name),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(count > 500 ? 0.08 : 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(count > 500 ? 0.25 : 0.1),
                          width: count > 500 ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#$name',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: count > 500 ? FontWeight.bold : FontWeight.w500,
                              color: count > 500 
                                  ? theme.colorScheme.primary 
                                  : theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
