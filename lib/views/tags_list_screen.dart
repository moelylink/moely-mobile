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

    final int chunkSize = 30;
    final int itemCount = (_filteredTags.length / chunkSize).ceil();

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

        // Tags Scroll View (Virtualized)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 40.0),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final int startIndex = index * chunkSize;
              final int endIndex = (startIndex + chunkSize < _filteredTags.length)
                  ? startIndex + chunkSize
                  : _filteredTags.length;
              final List<Map<String, dynamic>> chunk = _filteredTags.sublist(startIndex, endIndex);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Wrap(
                  spacing: 10.0,
                  runSpacing: 12.0,
                  children: chunk.map((tag) {
                    final String name = tag['name'];
                    final String urlName = tag['urlName'] ?? name;
                    final int count = tag['count'];
                    
                    const double fontSize = 13.0;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TagGridScreen(tag: urlName, displayName: name),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.12),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '#$name',
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.primary,
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
              );
            },
          ),
        ),
      ],
    );
  }
}
