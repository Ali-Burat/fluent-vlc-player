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
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        elevation: 0,
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
              _buildColorPicker(context),
              _buildAutoColorSwitch(context),
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
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // 字幕设置
          _buildSection(
            context,
            title: '字幕',
            icon: FluentIcons.closed_caption_24_regular,
            children: [
              _buildSubtitleSettings(context),
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
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: FilledButton.icon(
              onPressed: () => _showResetDialog(context),
              icon: const Icon(FluentIcons.arrow_reset_24_regular),
              label: const Text('重置所有设置'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
                padding: const EdgeInsets.all(AppTheme.spacingM),
              ),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildColorPicker(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: settings.accentColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(FluentIcons.color_fill_24_regular, color: settings.accentColor),
      ),
      title: const Text('主题颜色'),
      subtitle: const Text('自定义应用主题颜色'),
      trailing: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: settings.accentColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: settings.accentColor.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
      onTap: () => _showColorPicker(context, settings),
    );
  }

  Widget _buildAutoColorSwitch(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final colorScheme = Theme.of(context).colorScheme;
    
    return SwitchListTile(
      title: const Text('自动取色'),
      subtitle: const Text('从视频中提取主题色'),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(FluentIcons.color_background_24_regular, color: colorScheme.primary),
      ),
      value: settings.autoColor,
      onChanged: (value) => settings.autoColor = value,
    );
  }

  Widget _buildThemeModeSelector(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final colorScheme = Theme.of(context).colorScheme;
    
    String getThemeName(ThemeMode mode) {
      switch (mode) {
        case ThemeMode.system: return '跟随系统';
        case ThemeMode.light: return '浅色模式';
        case ThemeMode.dark: return '深色模式';
      }
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(FluentIcons.dark_theme_24_regular, color: colorScheme.primary),
      ),
      title: const Text('主题模式'),
      subtitle: Text(getThemeName(settings.themeMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeModeDialog(context, settings),
    );
  }

  Widget _buildAmoledSwitch(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final colorScheme = Theme.of(context).colorScheme;
    
    return SwitchListTile(
      title: const Text('AMOLED 深色模式'),
      subtitle: const Text('使用纯黑背景节省电量'),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(FluentIcons.phone_24_regular, color: colorScheme.primary),
      ),
      value: settings.useAmoledDark,
      onChanged: (value) => settings.useAmoledDark = value,
    );
  }

  Widget _buildAutoLoopSwitch(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final colorScheme = Theme.of(context).colorScheme;
    
    return SwitchListTile(
      title: const Text('自动循环播放'),
      subtitle: const Text('视频播放完毕后自动重新开始'),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(FluentIcons.arrow_sync_24_filled, color: colorScheme.primary),
      ),
      value: settings.autoLoop,
      onChanged: (value) => settings.autoLoop = value,
    );
  }

  Widget _buildSeamlessLoopSwitch(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final colorScheme = Theme.of(context).colorScheme;
    
    return SwitchListTile(
      title: const Text('无感循环'),
      subtitle: const Text('视频循环时无黑屏闪烁，完美衔接'),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(FluentIcons.arrow_sync_24_regular, color: colorScheme.primary),
      ),
      value: settings.seamlessLoop,
      onChanged: (value) => settings.seamlessLoop = value,
    );
  }

  Widget _buildRememberPositionSwitch(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final colorScheme = Theme.of(context).colorScheme;
    
    return SwitchListTile(
      title: const Text('记住播放位置'),
      subtitle: const Text('下次打开时从上次位置继续播放'),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(FluentIcons.save_24_regular, color: colorScheme.primary),
      ),
      value: settings.rememberPosition,
      onChanged: (value) => settings.rememberPosition = value,
    );
  }

  Widget _buildPlaybackSpeedSelector(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(FluentIcons.top_speed_24_regular, color: colorScheme.primary),
      ),
      title: const Text('默认播放速度'),
      subtitle: Text('${settings.playbackSpeed}x'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '${settings.playbackSpeed}x',
          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
        ),
      ),
      onTap: () => _showSpeedDialog(context, settings),
    );
  }

  Widget _buildSubtitleSettings(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(FluentIcons.closed_caption_24_regular, color: colorScheme.primary),
      ),
      title: const Text('字幕设置'),
      subtitle: const Text('字体大小、颜色、位置'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showSubtitleSettingsDialog(context),
    );
  }

  Widget _buildInfoTile(BuildContext context, String title, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(FluentIcons.info_24_regular, color: colorScheme.primary),
      ),
      title: Text(title),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          value,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, SettingsService settings) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题颜色'),
        content: SizedBox(
          width: 300,
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
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
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: isSelected ? 2 : 0,
                        ),
                      ],
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
                            size: 20,
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
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeModeOption(context, settings, ThemeMode.system, '跟随系统', FluentIcons.brightness_auto_24_regular),
            _buildThemeModeOption(context, settings, ThemeMode.light, '浅色模式', FluentIcons.weather_sunny_24_regular),
            _buildThemeModeOption(context, settings, ThemeMode.dark, '深色模式', FluentIcons.weather_moon_24_regular),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModeOption(BuildContext context, SettingsService settings, ThemeMode mode, String label, IconData icon) {
    final isSelected = settings.themeMode == mode;
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
      ),
      title: Text(label),
      trailing: isSelected ? Icon(Icons.check_circle, color: colorScheme.primary) : null,
      onTap: () {
        settings.themeMode = mode;
        Navigator.pop(context);
      },
    );
  }

  void _showSpeedDialog(BuildContext context, SettingsService settings) {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final colorScheme = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '默认播放速度',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: speeds.map((speed) {
                final isSelected = speed == settings.playbackSpeed;
                return GestureDetector(
                  onTap: () {
                    settings.playbackSpeed = speed;
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected
                          ? [BoxShadow(color: colorScheme.primary.withOpacity(0.4), blurRadius: 8)]
                          : null,
                    ),
                    child: Text(
                      '${speed}x',
                      style: TextStyle(
                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSubtitleSettingsDialog(BuildContext context) {
    double fontSize = 18;
    double position = 0.85;
    Color fontColor = Colors.white;
    Color bgColor = Colors.black54;
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('字幕设置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 字体大小
                Row(
                  children: [
                    const Text('字体大小', style: TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${fontSize.toInt()}',
                        style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: fontSize,
                  min: 12,
                  max: 32,
                  onChanged: (value) => setState(() => fontSize = value),
                ),
                
                const SizedBox(height: 16),
                
                // 字幕位置
                Row(
                  children: [
                    const Text('字幕位置', style: TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text(
                      position < 0.4 ? '顶部' : position > 0.7 ? '底部' : '中间',
                      style: TextStyle(color: colorScheme.primary),
                    ),
                  ],
                ),
                Slider(
                  value: position,
                  min: 0.1,
                  max: 0.9,
                  onChanged: (value) => setState(() => position = value),
                ),
                
                const SizedBox(height: 16),
                
                // 字幕颜色
                const Text('字幕颜色', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Colors.white,
                    Colors.yellow,
                    Colors.cyan,
                    Colors.green,
                    Colors.pink,
                    Colors.orange,
                  ].map((color) => GestureDetector(
                    onTap: () => setState(() => fontColor = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: fontColor == color
                            ? Border.all(color: colorScheme.primary, width: 3)
                            : null,
                        boxShadow: [
                          BoxShadow(color: color.withOpacity(0.3), blurRadius: 6),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
                
                const SizedBox(height: 16),
                
                // 背景颜色
                const Text('背景颜色', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Colors.black54,
                    Colors.black87,
                    Colors.black,
                    Colors.white54,
                    Colors.transparent,
                  ].map((color) => GestureDetector(
                    onTap: () => setState(() => bgColor = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: bgColor == color
                            ? Border.all(color: colorScheme.primary, width: 3)
                            : Border.all(color: colorScheme.outline),
                      ),
                    ),
                  )).toList(),
                ),
                
                const SizedBox(height: 20),
                
                // 预览
                const Text('预览', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '字幕预览文本',
                        style: TextStyle(
                          color: fontColor,
                          fontSize: fontSize,
                          shadows: [
                            Shadow(color: Colors.black.withOpacity(0.5), offset: const Offset(1, 1), blurRadius: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('字幕设置已保存')),
                );
              },
              child: const Text('保存'),
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
