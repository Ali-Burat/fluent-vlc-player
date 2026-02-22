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

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<RecentVideo> _recentVideos = [];

  Future<void> _pickVideoFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        if (file.path != null) _playVideo(file.path!, file.name);
      }
    }
  }

  void _playVideo(String path, String name) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(videoPath: path, videoName: name, videoId: const Uuid().v4())));
  }

  void _showUrlDialog() {
    final controller = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('打开网络链接'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: '输入视频URL', prefixIcon: Icon(FluentIcons.link_24_regular))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        FilledButton(onPressed: () { Navigator.pop(c); _playVideo(controller.text.trim(), controller.text.split('/').last); }, child: const Text('播放')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: [_buildHomeContent(), const VaultPage(), const SettingsPage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(FluentIcons.home_24_regular), selectedIcon: Icon(FluentIcons.home_24_filled), label: '首页'),
          NavigationDestination(icon: Icon(FluentIcons.lock_closed_24_regular), selectedIcon: Icon(FluentIcons.lock_closed_24_filled), label: '保险箱'),
          NavigationDestination(icon: Icon(FluentIcons.settings_24_regular), selectedIcon: Icon(FluentIcons.settings_24_filled), label: '设置'),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    final cs = Theme.of(context).colorScheme;
    return CustomScrollView(slivers: [
      SliverAppBar(expandedHeight: 120, floating: true, pinned: true, flexibleSpace: FlexibleSpaceBar(title: Text('Fluent Player', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)))),
      SliverPadding(padding: const EdgeInsets.all(16), sliver: SliverList(delegate: SliverChildListDelegate([
        Row(children: [
          Expanded(child: _QuickCard(icon: FluentIcons.folder_open_24_filled, label: '打开文件', color: cs.primaryContainer, onTap: _pickVideoFile)),
          const SizedBox(width: 8),
          Expanded(child: _QuickCard(icon: FluentIcons.link_24_filled, label: '打开链接', color: cs.secondaryContainer, onTap: _showUrlDialog)),
        ]),
        const SizedBox(height: 24),
        Text('最近播放', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Icon(FluentIcons.video_24_regular, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text('暂无播放记录', style: TextStyle(color: cs.onSurfaceVariant)),
          ])),
      ]))),
    ]);
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _QuickCard({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(color: color, borderRadius: BorderRadius.circular(12), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
    child: Container(padding: const EdgeInsets.all(16), child: Column(children: [Icon(icon, size: 32), const SizedBox(height: 4), Text(label)]))));
}

class RecentVideo { final String path; final String name; final DateTime playedAt; const RecentVideo({required this.path, required this.name, required this.playedAt}); }
