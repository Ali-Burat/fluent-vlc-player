import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';
import '../player/player_page.dart';
import '../settings/settings_page.dart';
import '../vault/vault_page.dart';
import '../media_library/media_library_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showPermissionDialog = false;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // 检查存储权限
    final storageStatus = await Permission.storage.status;
    final manageStatus = await Permission.manageExternalStorage.status;
    
    if (storageStatus.isGranted || manageStatus.isGranted) {
      setState(() {
        _permissionsGranted = true;
      });
    } else {
      setState(() {
        _showPermissionDialog = true;
      });
    }
  }

  Future<void> _requestPermissions() async {
    // 请求存储权限
    final statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.videos,
      Permission.photos,
    ].request();
    
    bool granted = statuses.values.any((status) => status.isGranted);
    
    if (!granted) {
      // 尝试打开设置页面
      await openAppSettings();
    }
    
    setState(() {
      _permissionsGranted = granted;
      _showPermissionDialog = !granted;
    });
  }

  Future<void> _pickVideoFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        if (file.path != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => PlayerPage(videoPath: file.path!, videoName: file.name, videoId: const Uuid().v4()),
          ));
        }
      }
    }
  }

  void _showUrlDialog() {
    final controller = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('打开网络链接'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: '输入视频URL', prefixIcon: Icon(FluentIcons.link_24_regular))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        FilledButton(onPressed: () {
          Navigator.pop(c);
          final url = controller.text.trim();
          if (url.isNotEmpty) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => PlayerPage(videoPath: url, videoName: url.split('/').last, videoId: const Uuid().v4()),
            ));
          }
        }, child: const Text('播放')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildHomeContent(),
              const MediaLibraryPage(),
              const VaultPage(),
              const SettingsPage(),
            ],
          ),
          // 权限引导对话框
          if (_showPermissionDialog) _buildPermissionDialog(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(FluentIcons.home_24_regular), selectedIcon: Icon(FluentIcons.home_24_filled), label: '首页'),
          NavigationDestination(icon: Icon(FluentIcons.video_24_regular), selectedIcon: Icon(FluentIcons.video_24_filled), label: '媒体库'),
          NavigationDestination(icon: Icon(FluentIcons.lock_closed_24_regular), selectedIcon: Icon(FluentIcons.lock_closed_24_filled), label: '保险箱'),
          NavigationDestination(icon: Icon(FluentIcons.settings_24_regular), selectedIcon: Icon(FluentIcons.settings_24_filled), label: '设置'),
        ],
      ),
    );
  }

  Widget _buildPermissionDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(FluentIcons.folder_open_24_filled, color: Theme.of(context).colorScheme.primary, size: 32),
              ),
              const SizedBox(height: 20),
              const Text('需要存储权限', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('为了扫描和管理您的视频文件，请授予存储权限', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _requestPermissions,
                  child: const Padding(padding: EdgeInsets.all(12), child: Text('授予权限')),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _showPermissionDialog = false),
                child: const Text('稍后再说'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    final cs = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 100,
          floating: true,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text('Fluent Player', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // 快速操作
              Row(
                children: [
                  Expanded(child: _QuickCard(icon: FluentIcons.folder_open_24_filled, label: '打开文件', color: cs.primaryContainer, onTap: _pickVideoFile)),
                  const SizedBox(width: 12),
                  Expanded(child: _QuickCard(icon: FluentIcons.link_24_filled, label: '打开链接', color: cs.secondaryContainer, onTap: _showUrlDialog)),
                ],
              ),
              const SizedBox(height: 24),
              
              // 功能入口
              const Text('功能', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _FeatureCard(
                icon: FluentIcons.video_24_filled,
                title: '媒体库',
                subtitle: '自动扫描手机中的视频文件',
                color: cs.tertiaryContainer,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              const SizedBox(height: 8),
              _FeatureCard(
                icon: FluentIcons.lock_closed_24_filled,
                title: '私密保险箱',
                subtitle: '加密存储私密文件',
                color: cs.errorContainer,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              const SizedBox(height: 24),
              
              // 使用提示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(FluentIcons.lightbulb_24_regular, color: cs.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('使用提示', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('• 双击屏幕播放/暂停', style: TextStyle(fontSize: 13)),
                    const Text('• 左右滑动调整进度', style: TextStyle(fontSize: 13)),
                    const Text('• 左侧上下滑动调整亮度', style: TextStyle(fontSize: 13)),
                    const Text('• 右侧上下滑动调整音量', style: TextStyle(fontSize: 13)),
                    const Text('• 自动加载同名字幕文件', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  
  const _QuickCard({required this.icon, required this.label, required this.color, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  
  const _FeatureCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
