import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsService>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _section('外观', [ListTile(leading: const Icon(FluentIcons.color_fill_24_regular), title: const Text('主题颜色'), trailing: CircleAvatar(backgroundColor: s.accentColor, radius: 14), onTap: () => _colorPicker(context, s)), SwitchListTile(secondary: const Icon(FluentIcons.dark_theme_24_regular), title: const Text('深色模式'), value: s.themeMode == ThemeMode.dark, onChanged: (v) => s.themeMode = v ? ThemeMode.dark : ThemeMode.light), SwitchListTile(secondary: const Icon(FluentIcons.phone_24_regular), title: const Text('AMOLED深色'), value: s.useAmoledDark, onChanged: (v) => s.useAmoledDark = v)]),
        const SizedBox(height: 16),
        _section('播放', [SwitchListTile(secondary: const Icon(FluentIcons.arrow_sync_24_filled), title: const Text('无感循环'), subtitle: const Text('视频循环时无黑屏闪烁'), value: s.seamlessLoop, onChanged: (v) => s.seamlessLoop = v), SwitchListTile(secondary: const Icon(FluentIcons.save_24_regular), title: const Text('记住播放位置'), value: s.rememberPosition, onChanged: (v) => s.rememberPosition = v), ListTile(leading: const Icon(FluentIcons.top_speed_24_regular), title: const Text('默认播放速度'), trailing: Text('${s.playbackSpeed}x'), onTap: () => _speedSheet(context, s))]),
        const SizedBox(height: 16),
        _section('关于', [ListTile(leading: const Icon(FluentIcons.info_24_regular), title: const Text('版本'), trailing: const Text('1.0.0'))]),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 8), Card(child: Column(children: children))]);

  void _colorPicker(BuildContext context, SettingsService s) => showDialog(context: context, builder: (c) => AlertDialog(
    title: const Text('选择主题颜色'),
    content: SizedBox(width: 280, child: GridView.count(crossAxisCount: 4, shrinkWrap: true, mainAxisSpacing: 8, crossAxisSpacing: 8,
      children: List.generate(ThemeColors.presetColors.length, (i) => GestureDetector(onTap: () { s.accentColor = ThemeColors.presetColors[i]; Navigator.pop(c); },
        child: Container(decoration: BoxDecoration(color: ThemeColors.presetColors[i], shape: BoxShape.circle)))))),
  ));

  void _speedSheet(BuildContext context, SettingsService s) => showModalBottomSheet(context: context, builder: (c) => Container(padding: const EdgeInsets.all(16), child: Wrap(spacing: 8, children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((sp) => ChoiceChip(label: Text('${sp}x'), selected: s.playbackSpeed == sp, onSelected: (_) { s.playbackSpeed = sp; Navigator.pop(c); })).toList())));
}
