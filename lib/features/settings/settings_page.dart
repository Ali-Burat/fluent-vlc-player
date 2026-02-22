import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('外观', [
            _colorPicker(context),
            _themeMode(context),
            _amoled(context),
          ]),
          const SizedBox(height: 20),
          _section('播放', [
            _seamlessLoop(context),
            _rememberPos(context),
            _playbackSpeed(context),
          ]),
          const SizedBox(height: 20),
          _section('字幕', [
            _subtitleSettings(context),
          ]),
          const SizedBox(height: 20),
          _section('关于', [
            _infoTile('版本', '1.0.0'),
            _infoTile('构建', 'Release'),
          ]),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _reset(context),
            icon: const Icon(FluentIcons.arrow_reset_24_regular),
            label: const Text('重置设置'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.errorContainer, foregroundColor: Theme.of(context).colorScheme.onErrorContainer),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Card(child: Column(children: children)),
    ]);
  }

  Widget _colorPicker(BuildContext context) {
    final s = context.watch<SettingsService>();
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: s.accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(FluentIcons.color_fill_24_regular, color: s.accentColor)),
      title: const Text('主题颜色'),
      trailing: Container(width: 28, height: 28, decoration: BoxDecoration(color: s.accentColor, shape: BoxShape.circle)),
      onTap: () => _showColors(context, s),
    );
  }

  void _showColors(BuildContext context, SettingsService s) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('选择颜色'),
      content: SizedBox(width: 260, child: GridView.count(crossAxisCount: 4, shrinkWrap: true, mainAxisSpacing: 10, crossAxisSpacing: 10,
        children: List.generate(ThemeColors.presetColors.length, (i) {
          final color = ThemeColors.presetColors[i];
          return GestureDetector(
            onTap: () { s.accentColor = color; Navigator.pop(c); },
            child: Container(decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: s.accentColor == color ? Border.all(color: Colors.white, width: 2) : null)),
          );
        }),
      )),
    ));
  }

  Widget _themeMode(BuildContext context) {
    final s = context.watch<SettingsService>();
    String name = {'system': '跟随系统', 'light': '浅色', 'dark': '深色'}[s.themeMode.name] ?? '跟随系统';
    return ListTile(
      leading: const Icon(FluentIcons.dark_theme_24_regular),
      title: const Text('主题模式'),
      subtitle: Text(name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog(context: context, builder: (c) => SimpleDialog(
        title: const Text('主题模式'),
        children: [ThemeMode.system, ThemeMode.light, ThemeMode.dark].map((m) => RadioListTile(
          title: Text({'system': '跟随系统', 'light': '浅色', 'dark': '深色'}[m.name]!),
          value: m, groupValue: s.themeMode,
          onChanged: (v) { s.themeMode = v!; Navigator.pop(c); },
        )).toList(),
      )),
    );
  }

  Widget _amoled(BuildContext context) {
    final s = context.watch<SettingsService>();
    return SwitchListTile(secondary: const Icon(FluentIcons.phone_24_regular), title: const Text('AMOLED深色'), subtitle: const Text('纯黑背景'), value: s.useAmoledDark, onChanged: (v) => s.useAmoledDark = v);
  }

  Widget _seamlessLoop(BuildContext context) {
    final s = context.watch<SettingsService>();
    return SwitchListTile(secondary: const Icon(FluentIcons.arrow_sync_24_regular), title: const Text('无感循环'), subtitle: const Text('循环时无黑屏'), value: s.seamlessLoop, onChanged: (v) => s.seamlessLoop = v);
  }

  Widget _rememberPos(BuildContext context) {
    final s = context.watch<SettingsService>();
    return SwitchListTile(secondary: const Icon(FluentIcons.save_24_regular), title: const Text('记住位置'), subtitle: const Text('继续上次播放'), value: s.rememberPosition, onChanged: (v) => s.rememberPosition = v);
  }

  Widget _playbackSpeed(BuildContext context) {
    final s = context.watch<SettingsService>();
    return ListTile(
      leading: const Icon(FluentIcons.top_speed_24_regular),
      title: const Text('默认速度'),
      subtitle: Text('${s.playbackSpeed}x'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet(context: context, builder: (c) => Container(
        padding: const EdgeInsets.all(20),
        child: Wrap(spacing: 10, children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((sp) => ChoiceChip(
          label: Text('${sp}x'), selected: s.playbackSpeed == sp,
          onSelected: (_) { s.playbackSpeed = sp; Navigator.pop(c); },
        )).toList()),
      )),
    );
  }

  Widget _subtitleSettings(BuildContext context) {
    return ListTile(
      leading: const Icon(FluentIcons.closed_caption_24_regular),
      title: const Text('字幕设置'),
      subtitle: const Text('大小、颜色'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showSubSettings(context),
    );
  }

  void _showSubSettings(BuildContext context) {
    double size = 16;
    Color color = Colors.white;
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      title: const Text('字幕设置'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [const Text('大小'), Expanded(child: Slider(value: size, min: 12, max: 28, onChanged: (v) => setSt(() => size = v))), Text('${size.toInt()}')]),
        const SizedBox(height: 12),
        const Text('颜色'),
        const SizedBox(height: 8),
        Wrap(spacing: 10, children: [Colors.white, Colors.yellow, Colors.cyan, Colors.green, Colors.pink].map((c) => GestureDetector(
          onTap: () => setSt(() => color = c),
          child: Container(width: 28, height: 28, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: color == c ? Border.all(color: Colors.blue, width: 2) : null)),
        )).toList()),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(c), child: const Text('保存'))],
    )));
  }

  Widget _infoTile(String title, String value) {
    return ListTile(leading: const Icon(FluentIcons.info_24_regular), title: Text(title), trailing: Text(value));
  }

  void _reset(BuildContext context) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('重置设置'),
      content: const Text('确定重置所有设置？'),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')), FilledButton(onPressed: () { context.read<SettingsService>().reset(); Navigator.pop(c); }, child: const Text('重置'))],
    ));
  }
}
