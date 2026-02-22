import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';
import '../player/player_page.dart';

/// 媒体库页面 - 自动扫描视频文件
class MediaLibraryPage extends StatefulWidget {
  const MediaLibraryPage({super.key});
  @override
  State<MediaLibraryPage> createState() => _MediaLibraryPageState();
}

class _MediaLibraryPageState extends State<MediaLibraryPage> {
  Map<String, List<VideoFile>> _folderVideos = {};
  bool _scanning = false;
  String? _selectedFolder;
  final List<String> _videoExtensions = ['.mp4', '.avi', '.mkv', '.mov', '.webm', '.flv', '.wmv', '.3gp', '.m4v', '.ts'];

  @override
  void initState() {
    super.initState();
    _scanVideos();
  }

  Future<void> _scanVideos() async {
    setState(() => _scanning = true);
    
    try {
      final Map<String, List<VideoFile>> folders = {};
      
      // 扫描常见视频目录
      final dirs = [
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/Video',
        '/storage/emulated/0/Videos',
      ];
      
      for (final dirPath in dirs) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          await _scanDirectory(dir, folders);
        }
      }
      
      // 扫描外部存储
      final extDir = Directory('/storage/emulated/0');
      if (await extDir.exists()) {
        await for (final entity in extDir.list()) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            // 跳过系统目录
            if (!name.startsWith('.') && !['Android', 'LOST.DIR', 'System', 'system'].contains(name)) {
              await _scanDirectory(entity, folders, maxDepth: 2);
            }
          }
        }
      }
      
      // 排序文件夹
      final sortedKeys = folders.keys.toList()..sort();
      final sortedFolders = Map.fromEntries(
        sortedKeys.map((k) => MapEntry(k, folders[k]!..sort((a, b) => a.name.compareTo(b.name))))
      );
      
      setState(() {
        _folderVideos = sortedFolders;
        _scanning = false;
      });
    } catch (e) {
      debugPrint('扫描失败: $e');
      setState(() => _scanning = false);
    }
  }

  Future<void> _scanDirectory(Directory dir, Map<String, List<VideoFile>> folders, {int maxDepth = 3, int currentDepth = 0}) async {
    if (currentDepth >= maxDepth) return;
    
    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (_videoExtensions.contains(ext)) {
            final folderPath = p.dirname(entity.path);
            final folderName = p.basename(folderPath);
            
            if (!folders.containsKey(folderName)) {
              folders[folderName] = [];
            }
            
            folders[folderName]!.add(VideoFile(
              path: entity.path,
              name: p.basename(entity.path),
              folder: folderName,
              size: await entity.length(),
            ));
          }
        } else if (entity is Directory) {
          await _scanDirectory(entity, folders, maxDepth: maxDepth, currentDepth: currentDepth + 1);
        }
      }
    } catch (e) {
      // 忽略权限错误
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体库'),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.arrow_sync_24_regular),
            onPressed: _scanning ? null : _scanVideos,
          ),
        ],
      ),
      body: _scanning
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在扫描视频文件...'),
            ]))
          : _folderVideos.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(FluentIcons.folder_open_24_regular, size: 64, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  const Text('未找到视频文件'),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _scanVideos, child: const Text('重新扫描')),
                ]))
              : _selectedFolder == null
                  ? _buildFolderList(colorScheme)
                  : _buildVideoList(colorScheme),
    );
  }

  Widget _buildFolderList(ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _folderVideos.length,
      itemBuilder: (context, index) {
        final folder = _folderVideos.keys.elementAt(index);
        final videos = _folderVideos[folder]!;
        final totalSize = videos.fold<int>(0, (sum, v) => sum + v.size);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(FluentIcons.folder_24_filled, color: colorScheme.primary),
            ),
            title: Text(folder, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('${videos.length} 个视频 · ${_formatSize(totalSize)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _selectedFolder = folder),
          ),
        );
      },
    );
  }

  Widget _buildVideoList(ColorScheme colorScheme) {
    final videos = _folderVideos[_selectedFolder]!;
    
    return Column(
      children: [
        // 返回按钮
        Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedFolder = null),
              ),
              Text(_selectedFolder!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${videos.length} 个视频', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        const Divider(height: 1),
        // 视频列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(FluentIcons.video_24_filled),
                  ),
                  title: Text(video.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_formatSize(video.size)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PlayerPage(videoPath: video.path, videoName: video.name),
                    ));
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class VideoFile {
  final String path;
  final String name;
  final String folder;
  final int size;
  
  const VideoFile({
    required this.path,
    required this.name,
    required this.folder,
    required this.size,
  });
}
