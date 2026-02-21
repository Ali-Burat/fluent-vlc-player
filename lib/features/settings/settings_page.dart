import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/models/app_settings.dart';

/// 设置页面
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

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
                value: settings.useMaterialYou,
                onChanged: (value) => settingsNotifier.setMaterialYou(value),
              ),
              _buildColorPickerTile(
                context,
                title: '主题颜色',
                subtitle: '自定义应用主题颜色',
                currentColor: settings.accentColor,
                onColorSelected: (color) => settingsNotifier.setAccentColor(color),
              ),
              _buildThemeModeTile(
                context,
                title: '主题模式',
                currentMode: settings.themeMode,
                onModeChanged: (mode) => settingsNotifier.setThemeMode(mode),
              ),
              _buildSwitchTile(
                context,
                title: 'AMOLED 深色模式',
                subtitle: '使用纯黑背景节省电量',
                value: settings.useAmoledDark,
                onChanged: (value) => settingsNotifier.setAmoledDark(value),
              ),
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
                value: settings.autoLoop,
                onChanged: (value) => settingsNotifier.setAutoLoop(value),
              ),
              _buildSwitchTile(
                context,
                title: '无感循环',
                subtitle: '视频循环时无黑屏闪烁',
                value: settings.seamlessLoop,
                onChanged: (value) => settingsNotifier.setSeamlessLoop(value),
              ),
              _buildSwitchTile(
                context,
                title: '记住播放位置',
                subtitle: '下次打开时从上次位置继续播放',
                value: settings.rememberPosition,
                onChanged: (value) => settingsNotifier.setRememberPosition(value),
              ),
              _buildSwitchTile(
                context,
                title: '硬件加速',
                subtitle: '使用GPU解码视频（推荐开启）',
                value: settings.hardwareAcceleration,
                onChanged: (value) => settingsNotifier.setHardwareAcceleration(value),
              ),
              _buildSliderTile(
                context,
                title: '默认播放速度',
                value: settings.playbackSpeed,
                min: 0.25,
                max: 2.0,
                divisions: 7,
                label: '${settings.playbackSpeed}x',
                onChanged: (value) => settingsNotifier.setPlaybackSpeed(value),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // 保险箱设置
          _buildSection(
            context,
            title: '私密保险箱',
            icon: FluentIcons.lock_closed_24_regular,
            children: [
              _buildSwitchTile(
                context,
                title: '启用保险箱',
                subtitle: '保护私密视频和图片',
                value: settings.vaultEnabled,
                onChanged: (value) => settingsNotifier.setVaultEnabled(value),
              ),
              _buildSwitchTile(
                context,
                title: '生物识别解锁',
                subtitle: '使用指纹或面容解锁保险箱',
                value: settings.vaultBiometric,
                onChanged: (value) => settingsNotifier.setVaultBiometric(value),
              ),
              _buildSwitchTile(
                context,
                title: '自动锁定',
                subtitle: '离开应用后自动锁定保险箱',
                value: settings.vaultAutoLock,
                onChanged: (value) => settingsNotifier.setVaultAutoLock(value),
              ),
              if (settings.vaultAutoLock)
                _buildDropdownTile(
                  context,
                  title: '自动锁定时间',
                  value: settings.vaultAutoLockTimeout,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1分钟')),
                    DropdownMenuItem(value: 5, child: Text('5分钟')),
                    DropdownMenuItem(value: 10, child: Text('10分钟')),
                    DropdownMenuItem(value: 30, child: Text('30分钟')),
                  ],
                  onChanged: (value) => settingsNotifier.setVaultAutoLockTimeout(value ?? 5),
                ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // 显示设置
          _buildSection(
            context,
            title: '显示',
            icon: FluentIcons.eye_24_regular,
            children: [
              _buildSwitchTile(
                context,
                title: '显示最近播放',
                subtitle: '在首页显示最近播放的视频',
                value: settings.showRecentFiles,
                onChanged: (value) {
                  // settingsNotifier.setShowRecentFiles(value);
                },
              ),
              _buildSwitchTile(
                context,
                title: '显示缩略图',
                subtitle: '显示视频预览缩略图',
                value: settings.showThumbnails,
                onChanged: (value) => settingsNotifier.setShowThumbnails(value),
              ),
              _buildSwitchTile(
                context,
                title: '按文件夹分组',
                subtitle: '将视频按文件夹分类显示',
                value: settings.groupByFolder,
                onChanged: (value) => settingsNotifier.setGroupByFolder(value),
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
              _buildInfoTile(
                context,
                title: '版本',
                value: '1.0.0',
              ),
              _buildInfoTile(
                context,
                title: '构建版本',
                value: '1',
              ),
              ListTile(
                leading: Icon(
                  FluentIcons.document_text_24_regular,
                  color: colorScheme.onSurface,
                ),
                title: const Text('开源许可'),
                trailing: Icon(
                  FluentIcons.chevron_right_24_regular,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Fluent VLC Player',
                    applicationVersion: '1.0.0',
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // 重置按钮
          FilledButton.icon(
            onPressed: () => _showResetDialog(context, settingsNotifier),
            icon: const Icon(FluentIcons.arrow_reset_24_regular),
            label: const Text('重置所有设置'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.errorContainer,
              foregroundColor: colorScheme.onErrorContainer,
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
          child: Column(
            children: children,
          ),
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

  Widget _buildColorPickerTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color currentColor,
    required ValueChanged<Color> onColorSelected,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: currentColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
          ),
        ),
      ),
      onTap: () => _showColorPicker(context, currentColor, onColorSelected),
    );
  }

  Widget _buildThemeModeTile(
    BuildContext context, {
    required String title,
    required ThemeMode currentMode,
    required ValueChanged<ThemeMode> onModeChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(_getThemeModeName(currentMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeModeDialog(context, currentMode, onModeChanged),
    );
  }

  Widget _buildSliderTile(
    BuildContext context, {
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDropdownTile<T>(
    BuildContext context, {
    required String title,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        underline: const SizedBox(),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required String title,
    required String value,
  }) {
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

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
    }
  }

  void _showColorPicker(
    BuildContext context,
    Color currentColor,
    ValueChanged<Color> onColorSelected,
  ) {
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
            children: ThemeColors.presetColors.map((color) {
              final isSelected = color.value == currentColor.value;
              return GestureDetector(
                onTap: () {
                  onColorSelected(color);
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

  void _showThemeModeDialog(
    BuildContext context,
    ThemeMode currentMode,
    ValueChanged<ThemeMode> onModeChanged,
  ) {
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
              groupValue: currentMode,
              onChanged: (value) {
                onModeChanged(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('浅色模式'),
              value: ThemeMode.light,
              groupValue: currentMode,
              onChanged: (value) {
                onModeChanged(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('深色模式'),
              value: ThemeMode.dark,
              groupValue: currentMode,
              onChanged: (value) {
                onModeChanged(value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(
    BuildContext context,
    SettingsNotifier settingsNotifier,
  ) {
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
              settingsNotifier.resetToDefaults();
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
