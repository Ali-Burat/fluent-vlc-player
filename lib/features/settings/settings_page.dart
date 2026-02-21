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
              _buildMaterialYouSwitch(context),
              _buildColorPicker(context),
              _buildThemeModeSelector(context),
              _buildAmoledSwitch(context),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // 播放设置
          _buildSection(
            context,
            title: '播放',
            icon: FluentIcons.play_24_regular,
            children: [
              _buildAutoLoopSwitch(context),
              _buildSeamlessLoopSwitch(context),
              _buildRememberPositionSwitch(context),
              _buildPlaybackSpeedSelector(context),
              _buildThumbnailsSwitch(context),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // 关于
          _buildSection(
            context,
            title: '关于',
            icon: FluentIcons.info_24_regular,
            children: [
              _buildInfoTile(context, '版本', '1.0.0'),
              _buildInfoTile(context, '构建', 'Release'),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // 重置
          FilledButton.icon(
            onPressed: () => _showResetDialog(context),
            icon: const Icon(FluentIcons.arrow_reset_24_regular),
            label: const Text('重置所有设置'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
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

  Widget _buildMaterialYouSwitch(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return SwitchListTile(
      title: const Text('Material You 动态颜色'),
      subtitle: const Text('根据壁纸自动生成主题颜色'),
      secondary: const Icon(FluentIcons.color_24_regular),
      value: settings.useMaterialYou,
      onChanged: (value) => settings.useMaterialYou = value,
    );
  }

  Widget _buildColorPicker(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return ListTile(
      leading: const Icon(FluentIcons.color_fill_24_regular),
      title: const Text('主题颜色'),
      subtitle: const Text('自定义应用主题颜色'),
      trailing: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: settings.accentColor,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
        ),
      ),
      onTap: () => _showColorPicker(context, settings),
    );
  }

  Widget _buildThemeModeSelector(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    String getThemeName(ThemeMode mode) {
      switch (mode) {
        case ThemeMode.system: return '跟随系统';
        case ThemeMode.light: return '浅色模式';
        case ThemeMode.dark: return '深色模式';
      }
    }

    return ListTile(
      leading: const Icon(FluentIcons.dark_theme_24_regular),
      title: const Text('主题模式'),
      subtitle: Text(getThemeName(settings.themeMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeModeDialog(context, settings),
    );
  }

  Widget _buildAmoledSwitch(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return SwitchListTile(
      title: const Text('AMOLED 深色模式'),
      subtitle: const Text('使用纯黑背景节省电量'),
      secondary: const Icon(FluentIcons.phone_24_regular),
      value: settings.useAmoledDark,
      onChanged: (value) => settings.useAmoledDark = value,
    );
  }

  Widget _buildAutoLoopSwitch(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return SwitchListTile(
      title: const Text('自动循环播放'),
      subtitle: const Text('视频播放完毕后自动重新开始'),
      secondary: const Icon(FluentIcons.repeat_all_24_filled),
      value: settings.autoLoop,
      onChanged: (value) => settings.autoLoop = value,
    );
  }

  Widget _buildSeamlessLoopSwitch(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return SwitchListTile(
      title: const Text('无感循环'),
      subtitle: const Text('视频循环时无黑屏闪烁，完美衔接'),
      secondary: const Icon(FluentIcons.arrow_sync_24_regular),
      value: settings.seamlessLoop,
      onChanged: (value) => settings.seamlessLoop = value,
    );
  }

  Widget _buildRememberPositionSwitch(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return SwitchListTile(
      title: const Text('记住播放位置'),
      subtitle: const Text('下次打开时从上次位置继续播放'),
      secondary: const Icon(FluentIcons.save_24_regular),
      value: settings.rememberPosition,
      onChanged: (value) => settings.rememberPosition = value,
    );
  }

  Widget _buildPlaybackSpeedSelector(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return ListTile(
      leading: const Icon(FluentIcons.top_speed_24_regular),
      title: const Text('默认播放速度'),
      subtitle: Text('${settings.playbackSpeed}x'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showSpeedDialog(context, settings),
    );
  }

  Widget _buildThumbnailsSwitch(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return SwitchListTile(
      title: const Text('显示缩略图'),
      subtitle: const Text('显示视频预览缩略图'),
      secondary: const Icon(FluentIcons.image_24_regular),
      value: settings.showThumbnails,
      onChanged: (value) => settings.showThumbnails = value,
    );
  }

  Widget _buildInfoTile(BuildContext context, String title, String value) {
    return ListTile(
      leading: const Icon(FluentIcons.info_24_regular),
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
            children: List.generate(ThemeColors.presetColors.length, (index) {
              final color = ThemeColors.presetColors[index];
              final name = ThemeColors.colorNames[index];
              final isSelected = color.value == settings.accentColor.value;
              
              return GestureDetector(
                onTap: () {
                  settings.accentColor = color;
                  Navigator.pop(context);
                },
                child: Tooltip(
                  message: name,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: ThemeData.estimateBrightnessForColor(color) == Brightness.light
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                ),
              );
            }),
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

  void _showSpeedDialog(BuildContext context, SettingsService settings) {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '默认播放速度',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Wrap(
              spacing: AppTheme.spacingS,
              children: speeds.map((speed) {
                final isSelected = speed == settings.playbackSpeed;
                return ChoiceChip(
                  label: Text('${speed}x'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      settings.playbackSpeed = speed;
                      Navigator.pop(context);
                    }
                  },
                );
              }).toList(),
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
        content: const Text('确定要重置所有设置为默认值吗？此操作无法撤销。'),
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
