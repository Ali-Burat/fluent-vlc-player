import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';

/// 设置页面
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        children: [
          // 外观设置
          _buildSection(
            context,
            title: '外观',
            icon: FluentIcons.paint_brush_24_regular,
            children: [
              _buildSwitchTile(
                context,
                title: 'Material You 动态颜色',
                subtitle: '根据壁纸自动生成主题颜色',
                value: context.watch<SettingsService>().useMaterialYou,
                onChanged: (value) {
                  context.read<SettingsService>().useMaterialYou = value;
                },
              ),
              _buildColorPickerTile(context),
              _buildThemeModeTile(context),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // 播放设置
          _buildSection(
            context,
            title: '播放',
            icon: FluentIcons.play_24_regular,
            children: [
              _buildSwitchTile(
                context,
                title: '自动循环播放',
                subtitle: '视频播放完毕后自动重新开始',
                value: context.watch<SettingsService>().autoLoop,
                onChanged: (value) {
                  context.read<SettingsService>().autoLoop = value;
                },
              ),
              _buildSwitchTile(
                context,
                title: '无感循环',
                subtitle: '视频循环时无黑屏闪烁',
                value: context.watch<SettingsService>().seamlessLoop,
                onChanged: (value) {
                  context.read<SettingsService>().seamlessLoop = value;
                },
              ),
              _buildSwitchTile(
                context,
                title: '记住播放位置',
                subtitle: '下次打开时从上次位置继续播放',
                value: context.watch<SettingsService>().rememberPosition,
                onChanged: (value) {
                  context.read<SettingsService>().rememberPosition = value;
                },
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // 关于
          _buildSection(
            context,
            title: '关于',
            icon: FluentIcons.info_24_regular,
            children: [
              _buildInfoTile(context, title: '版本', value: '1.0.0'),
              _buildInfoTile(context, title: '构建版本', value: '1'),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // 重置按钮
          FilledButton.icon(
            onPressed: () => _showResetDialog(context),
            icon: const Icon(FluentIcons.arrow_reset_24_regular),
            label: const Text('重置所有设置'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 20),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildColorPickerTile(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return ListTile(
      title: const Text('主题颜色'),
      subtitle: const Text('自定义应用主题颜色'),
      trailing: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: settings.accentColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
          ),
        ),
      ),
      onTap: () => _showColorPicker(context, settings),
    );
  }

  Widget _buildThemeModeTile(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    String getThemeName(ThemeMode mode) {
      switch (mode) {
        case ThemeMode.system:
          return '跟随系统';
        case ThemeMode.light:
          return '浅色模式';
        case ThemeMode.dark:
          return '深色模式';
      }
    }

    return ListTile(
      title: const Text('主题模式'),
      subtitle: Text(getThemeName(settings.themeMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeModeDialog(context, settings),
    );
  }

  Widget _buildInfoTile(BuildContext context, {required String title, required String value}) {
    return ListTile(
      title: Text(title),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, SettingsService settings) {
    final colors = [
      Colors.blue, Colors.teal, Colors.green, Colors.amber,
      Colors.orange, Colors.deepOrange, Colors.red, Colors.pink,
      Colors.purple, Colors.indigo, Colors.cyan, Colors.lime,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题颜色'),
        content: SizedBox(
          width: 280,
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: colors.map((color) {
              final isSelected = color.value == settings.accentColor.value;
              return GestureDetector(
                onTap: () {
                  settings.accentColor = color;
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: ThemeData.estimateBrightnessForColor(color) ==
                                  Brightness.light
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showThemeModeDialog(BuildContext context, SettingsService settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('跟随系统'),
              value: ThemeMode.system,
              groupValue: settings.themeMode,
              onChanged: (value) {
                settings.themeMode = value!;
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('浅色模式'),
              value: ThemeMode.light,
              groupValue: settings.themeMode,
              onChanged: (value) {
                settings.themeMode = value!;
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('深色模式'),
              value: ThemeMode.dark,
              groupValue: settings.themeMode,
              onChanged: (value) {
                settings.themeMode = value!;
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置设置'),
        content: const Text('确定要重置所有设置为默认值吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              context.read<SettingsService>().reset();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('设置已重置')),
              );
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }
}
