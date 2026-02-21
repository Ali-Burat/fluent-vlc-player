import 'package:flutter/material.dart';

/// 应用设置模型
class AppSettings {
  final ThemeMode themeMode;
  final Color accentColor;
  final bool useMaterialYou;
  final bool useAmoledDark;
  final double playbackSpeed;
  final bool autoLoop;
  final bool seamlessLoop;
  final bool rememberPosition;
  final bool showControls;
  final bool hardwareAcceleration;
  final String defaultVideoFilter;
  final bool vaultEnabled;
  final bool vaultBiometric;
  final bool vaultAutoLock;
  final int vaultAutoLockTimeout;
  final bool showRecentFiles;
  final int maxRecentFiles;
  final bool showThumbnails;
  final String defaultSortOrder;
  final bool groupByFolder;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.accentColor = Colors.blue,
    this.useMaterialYou = true,
    this.useAmoledDark = false,
    this.playbackSpeed = 1.0,
    this.autoLoop = true,
    this.seamlessLoop = true,
    this.rememberPosition = true,
    this.showControls = true,
    this.hardwareAcceleration = true,
    this.defaultVideoFilter = 'none',
    this.vaultEnabled = false,
    this.vaultBiometric = false,
    this.vaultAutoLock = true,
    this.vaultAutoLockTimeout = 5,
    this.showRecentFiles = true,
    this.maxRecentFiles = 20,
    this.showThumbnails = true,
    this.defaultSortOrder = 'name_asc',
    this.groupByFolder = true,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    Color? accentColor,
    bool? useMaterialYou,
    bool? useAmoledDark,
    double? playbackSpeed,
    bool? autoLoop,
    bool? seamlessLoop,
    bool? rememberPosition,
    bool? showControls,
    bool? hardwareAcceleration,
    String? defaultVideoFilter,
    bool? vaultEnabled,
    bool? vaultBiometric,
    bool? vaultAutoLock,
    int? vaultAutoLockTimeout,
    bool? showRecentFiles,
    int? maxRecentFiles,
    bool? showThumbnails,
    String? defaultSortOrder,
    bool? groupByFolder,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      useMaterialYou: useMaterialYou ?? this.useMaterialYou,
      useAmoledDark: useAmoledDark ?? this.useAmoledDark,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      autoLoop: autoLoop ?? this.autoLoop,
      seamlessLoop: seamlessLoop ?? this.seamlessLoop,
      rememberPosition: rememberPosition ?? this.rememberPosition,
      showControls: showControls ?? this.showControls,
      hardwareAcceleration: hardwareAcceleration ?? this.hardwareAcceleration,
      defaultVideoFilter: defaultVideoFilter ?? this.defaultVideoFilter,
      vaultEnabled: vaultEnabled ?? this.vaultEnabled,
      vaultBiometric: vaultBiometric ?? this.vaultBiometric,
      vaultAutoLock: vaultAutoLock ?? this.vaultAutoLock,
      vaultAutoLockTimeout: vaultAutoLockTimeout ?? this.vaultAutoLockTimeout,
      showRecentFiles: showRecentFiles ?? this.showRecentFiles,
      maxRecentFiles: maxRecentFiles ?? this.maxRecentFiles,
      showThumbnails: showThumbnails ?? this.showThumbnails,
      defaultSortOrder: defaultSortOrder ?? this.defaultSortOrder,
      groupByFolder: groupByFolder ?? this.groupByFolder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'accentColor': accentColor.value,
      'useMaterialYou': useMaterialYou,
      'useAmoledDark': useAmoledDark,
      'playbackSpeed': playbackSpeed,
      'autoLoop': autoLoop,
      'seamlessLoop': seamlessLoop,
      'rememberPosition': rememberPosition,
      'showControls': showControls,
      'hardwareAcceleration': hardwareAcceleration,
      'defaultVideoFilter': defaultVideoFilter,
      'vaultEnabled': vaultEnabled,
      'vaultBiometric': vaultBiometric,
      'vaultAutoLock': vaultAutoLock,
      'vaultAutoLockTimeout': vaultAutoLockTimeout,
      'showRecentFiles': showRecentFiles,
      'maxRecentFiles': maxRecentFiles,
      'showThumbnails': showThumbnails,
      'defaultSortOrder': defaultSortOrder,
      'groupByFolder': groupByFolder,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: ThemeMode.values[json['themeMode'] as int? ?? 0],
      accentColor: Color(json['accentColor'] as int? ?? Colors.blue.value),
      useMaterialYou: json['useMaterialYou'] as bool? ?? true,
      useAmoledDark: json['useAmoledDark'] as bool? ?? false,
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      autoLoop: json['autoLoop'] as bool? ?? true,
      seamlessLoop: json['seamlessLoop'] as bool? ?? true,
      rememberPosition: json['rememberPosition'] as bool? ?? true,
      showControls: json['showControls'] as bool? ?? true,
      hardwareAcceleration: json['hardwareAcceleration'] as bool? ?? true,
      defaultVideoFilter: json['defaultVideoFilter'] as String? ?? 'none',
      vaultEnabled: json['vaultEnabled'] as bool? ?? false,
      vaultBiometric: json['vaultBiometric'] as bool? ?? false,
      vaultAutoLock: json['vaultAutoLock'] as bool? ?? true,
      vaultAutoLockTimeout: json['vaultAutoLockTimeout'] as int? ?? 5,
      showRecentFiles: json['showRecentFiles'] as bool? ?? true,
      maxRecentFiles: json['maxRecentFiles'] as int? ?? 20,
      showThumbnails: json['showThumbnails'] as bool? ?? true,
      defaultSortOrder: json['defaultSortOrder'] as String? ?? 'name_asc',
      groupByFolder: json['groupByFolder'] as bool? ?? true,
    );
  }
}

/// 预设主题颜色
class ThemeColors {
  static const List<Color> presetColors = [
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.indigo,
    Colors.cyan,
    Colors.lime,
  ];
  
  static const List<MapEntry<String, Color>> namedColors = [
    MapEntry('海洋蓝', Colors.blue),
    MapEntry('青碧', Colors.teal),
    MapEntry('翠绿', Colors.green),
    MapEntry('琥珀', Colors.amber),
    MapEntry('橙黄', Colors.orange),
    MapEntry('深橙', Colors.deepOrange),
    MapEntry('中国红', Colors.red),
    MapEntry('粉红', Colors.pink),
    MapEntry('紫罗兰', Colors.purple),
    MapEntry('靛蓝', Colors.indigo),
    MapEntry('天青', Colors.cyan),
    MapEntry('柠檬绿', Colors.lime),
  ];
}
