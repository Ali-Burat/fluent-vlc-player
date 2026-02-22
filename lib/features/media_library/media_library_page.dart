import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
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
  Map<String, List<VideoItemData>> _folderVideos = {};
  Map<String, String> _thumbnails = {};
  bool _scanning = false;
  String? _selectedFolder;
  final List<String> _videoExtensions = ['.mp4', '.avi', '.mkv', '.mov', '.webm', '.flv', '.wmv', '.3gp', '.m4v', '.ts'];

  @override
  void initState() { super.initState(); _scanVideos(); }

  Future<void> _scanVideos() async {
    setState(() => _scanning = true);
    
    try {
      final Map<String, List<VideoItemData>> folders = {};
      final cacheDir = await getTemporaryDirectory();
      
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
          await _scanDirectory(dir, folders, cacheDir.path);
        }
      }
      
      final extDir = Directory('/storage/emulated/0');
      if (await extDir.exists()) {
        await for (final entity in extDir.list()) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            if (!name.startsWith('.') && !['Android', 'LOST.DIR', 'System', 'system'].contains(name)) {
              await _scanDirectory(entity, folders, cacheDir.path, maxDepth: 2);
            }
          }
        }
      }
      
      for (final folder in folders.keys) {
        final videos = folders[folder]!;
        if (videos.isNotEmpty) {
          final firstVideo = videos.first;
          if (firstVideo.thumbnail == null) {
            try {
              final thumb = await VideoThumbnail.thumbnailFile(
                video: firstVideo.path,
                thumbnailPath: '${cacheDir.path}/${firstVideo.id}.jpg',
                imageFormat: ImageFormat.JPEG,
                maxWidth: 200,
                quality: 75,
              );
              if (thumb != null) {
                _thumbnails[folder] = thumb;
              }
            } catch (e) {
              debugPrint('生成缩略图失败: $e');
            }
          }
        }
      }
      
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

  Future<void> _scanDirectory(Directory dir, Map<String, List<VideoItemData>> folders, String cachePath, {int maxDepth = 3, int currentDepth = 0}) async {
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
            
            final id = entity.path.hashCode.toString();
            final thumbPath = '$cachePath/$id.jpg';
            final hasThumb = await File(thumbPath).exists();
            final size = await entity.length();
            
            folders[folderName]!.add(VideoItemData(
              id: id,
              path: entity.path,
              name: p.basename(entity.path),
              size: size,
              thumbnail: hasThumb ? thumbPath : null,
            ));
          }
        } else if (entity is Directory) {
          await _scanDirectory(entity, folders, cachePath, maxDepth: maxDepth, currentDepth: currentDepth + 1);
        }
      }
    } catch (e) {}
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
          IconButton(icon: const Icon(FluentIcons.arrow_sync_24_regular), onPressed: _scanning ? null : _scanVideos),
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
        final thumbnail = _thumbnails[folder];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _selectedFolder = folder),
            child: Row(
              children: [
                Container(
                  width: 80, height: 80,
                  color: colorScheme.surfaceVariant,
                  child: thumbnail != null
                      ? Image.file(File(thumbnail), fit: BoxFit.cover)
                      : Icon(FluentIcons.folder_24_filled, color: colorScheme.primary, size: 32),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(folder, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('${videos.length} 个视频 · ${_formatSize(totalSize)}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoList(ColorScheme colorScheme) {
    final videos = _folderVideos[_selectedFolder]!;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedFolder = null)),
              Text(_selectedFolder!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${videos.length} 个视频', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PlayerPage(
                        videoPath: video.path, 
                        videoName: video.name,
                        videoId: video.id,
                        playlist: videos.map((v) => VideoItem(id: v.id, path: v.path, name: v.name, thumbnail: v.thumbnail)).toList(),
                        currentIndex: index,
                      ),
                    ));
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 100, height: 60,
                        color: colorScheme.surfaceVariant,
                        child: video.thumbnail != null
                            ? Image.file(File(video.thumbnail!), fit: BoxFit.cover)
                            : const Icon(FluentIcons.video_24_filled),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(video.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text(_formatSize(video.size), style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                            ],
                          ),
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
