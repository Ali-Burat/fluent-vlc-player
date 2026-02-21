import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/models/app_settings.dart';
import '../player/player_page.dart';
import '../settings/settings_page.dart';
import '../vault/vault_page.dart';

/// 主页面
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  final List<VideoItem> _recentVideos = [];
  final List<VideoItem> _localVideos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentVideos();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
      
      // Android 13+ 需要请求媒体权限
      if (await Permission.videos.request().isGranted) {
        // 权限已授予
      }
    }
  }

  Future<void> _loadRecentVideos() async {
    // 从本地存储加载最近播放的视频
    setState(() {
      _isLoading = true;
    });

    // 模拟加载
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isLoading = false;
    });
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          videoPath: path,
          videoName: name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomePage(context, colorScheme),
          const VaultPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: _buildNavigationBar(context, colorScheme),
    );
  }

  Widget _buildHomePage(BuildContext context, ColorScheme colorScheme) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, colorScheme),
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildQuickActions(context, colorScheme),
              const SizedBox(height: AppTheme.spacingL),
              _buildRecentVideos(context, colorScheme),
              const SizedBox(height: AppTheme.spacingL),
              _buildLocalVideos(context, colorScheme),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Fluent VLC Player',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      ),
      actions: [
        IconButton(
          icon: Icon(
            FluentIcons.search_24_regular,
            color: colorScheme.onSurface,
          ),
          onPressed: () {
            // 搜索功能
          },
        ),
        IconButton(
          icon: Icon(
            FluentIcons.options_24_regular,
            color: colorScheme.onSurface,
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SettingsPage(),
              ),
            );
          },
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
                onTap: () => _showUrlDialog(context),
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: _QuickActionCard(
                icon: FluentIcons.history_24_filled,
                label: '最近播放',
                color: colorScheme.tertiaryContainer,
                onTap: () {
                  // 显示最近播放
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentVideos(BuildContext context, ColorScheme colorScheme) {
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
            TextButton(
              onPressed: () {
                // 查看全部
              },
              child: Text(
                '查看全部',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_recentVideos.isEmpty)
          _buildEmptyState(
            context,
            FluentIcons.video_24_regular,
            '暂无播放记录',
            '点击上方按钮打开视频文件开始播放',
          )
        else
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentVideos.length,
              itemBuilder: (context, index) {
                final video = _recentVideos[index];
                return _VideoCard(
                  video: video,
                  onTap: () => _playVideo(video.path, video.name),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLocalVideos(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '本地视频',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            TextButton(
              onPressed: () {
                // 扫描本地视频
              },
              child: Text(
                '扫描',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        if (_localVideos.isEmpty)
          _buildEmptyState(
            context,
            FluentIcons.folder_24_regular,
            '未找到本地视频',
            '点击扫描按钮搜索设备上的视频文件',
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _localVideos.length,
            itemBuilder: (context, index) {
              final video = _localVideos[index];
              return ListTile(
                leading: Container(
                  width: 80,
                  height: 45,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    FluentIcons.video_24_regular,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                title: Text(video.name),
                subtitle: Text(video.size ?? ''),
                onTap: () => _playVideo(video.path, video.name),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context, ColorScheme colorScheme) {
    return NavigationBar(
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
    );
  }

  void _showUrlDialog(BuildContext context) {
    final controller = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('打开网络链接'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '输入视频URL',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
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
              Icon(icon, size: 28),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 视频卡片
class _VideoCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback onTap;

  const _VideoCard({
    required this.video,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: AppTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Center(
                child: Icon(
                  FluentIcons.video_24_regular,
                  size: 32,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              video.name,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// 视频项模型
class VideoItem {
  final String path;
  final String name;
  final String? thumbnail;
  final String? size;
  final String? duration;

  const VideoItem({
    required this.path,
    required this.name,
    this.thumbnail,
    this.size,
    this.duration,
  });
}
