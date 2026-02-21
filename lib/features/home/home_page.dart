import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';
import '../player/player_page.dart';
import '../settings/settings_page.dart';
import '../vault/vault_page.dart';

/// 主页面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<RecentVideo> _recentVideos = [];

  @override
  void initState() {
    super.initState();
    _loadRecentVideos();
  }

  void _loadRecentVideos() {
    // 从设置加载最近播放
  }

  Future<void> _pickVideoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            _playVideo(file.path!, file.name);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  void _playVideo(String path, String name) {
    final videoId = const Uuid().v4();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          videoPath: path,
          videoName: name,
          videoId: videoId,
        ),
      ),
    );
  }

  void _showUrlDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('打开网络链接'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入视频URL',
            prefixIcon: Icon(FluentIcons.link_24_regular),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(context);
                _playVideo(url, url.split('/').last);
              }
            },
            child: const Text('播放'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeContent(context, colorScheme),
          const VaultPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(FluentIcons.home_24_regular),
            selectedIcon: Icon(FluentIcons.home_24_filled),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(FluentIcons.lock_closed_24_regular),
            selectedIcon: Icon(FluentIcons.lock_closed_24_filled),
            label: '保险箱',
          ),
          NavigationDestination(
            icon: Icon(FluentIcons.settings_24_regular),
            selectedIcon: Icon(FluentIcons.settings_24_filled),
            label: '设置',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context, ColorScheme colorScheme) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 120,
          floating: true,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              'Fluent Player',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
          ),
          actions: [
            IconButton(
              icon: Icon(FluentIcons.settings_24_regular, color: colorScheme.onSurface),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildQuickActions(context, colorScheme),
              const SizedBox(height: AppTheme.spacingL),
              _buildRecentSection(context, colorScheme),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '快速操作',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: FluentIcons.folder_open_24_filled,
                label: '打开文件',
                color: colorScheme.primaryContainer,
                onTap: _pickVideoFile,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: _QuickActionCard(
                icon: FluentIcons.link_24_filled,
                label: '打开链接',
                color: colorScheme.secondaryContainer,
                onTap: _showUrlDialog,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '最近播放',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            if (_recentVideos.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _recentVideos.clear();
                  });
                },
                child: const Text('清空'),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        if (_recentVideos.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Column(
              children: [
                Icon(
                  FluentIcons.video_24_regular,
                  size: 48,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  '暂无播放记录',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  '点击上方按钮打开视频文件开始播放',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentVideos.length,
              itemBuilder: (context, index) {
                final video = _recentVideos[index];
                return GestureDetector(
                  onTap: () => _playVideo(video.path, video.name),
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.video_24_regular,
                          size: 40,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            video.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// 快速操作卡片
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 最近播放视频
class RecentVideo {
  final String path;
  final String name;
  final DateTime playedAt;

  const RecentVideo({
    required this.path,
    required this.name,
    required this.playedAt,
  });
}
