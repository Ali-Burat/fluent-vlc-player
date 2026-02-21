import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../shared/models/app_settings.dart';

/// 设置服务提供者
final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

/// 设置状态提供者
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.read(settingsServiceProvider));
});

/// 设置服务
class SettingsService {
  static const String _settingsKey = 'app_settings';
  
  Box get _box => Hive.box('settings');
  
  /// 获取设置
  Future<AppSettings> getSettings() async {
    final data = _box.get(_settingsKey);
    if (data == null) {
      return const AppSettings();
    }
    if (data is String) {
      return AppSettings.fromJson(jsonDecode(data));
    }
    return AppSettings.fromJson(Map<String, dynamic>.from(data));
  }
  
  /// 保存设置
  Future<void> saveSettings(AppSettings settings) async {
    await _box.put(_settingsKey, settings.toJson());
  }
  
  /// 重置设置
  Future<void> resetSettings() async {
    await _box.put(_settingsKey, const AppSettings().toJson());
  }
  
  /// 获取单个设置项
  T? getSetting<T>(String key, T? defaultValue) {
    return _box.get(key, defaultValue: defaultValue) as T?;
  }
  
  /// 保存单个设置项
  Future<void> setSetting<T>(String key, T value) async {
    await _box.put(key, value);
  }
}

/// 设置状态管理器
class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsService _service;
  
  SettingsNotifier(this._service) : super(const AppSettings()) {
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    state = await _service.getSettings();
  }
  
  Future<void> updateSettings(AppSettings newSettings) async {
    state = newSettings;
    await _service.saveSettings(newSettings);
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _service.saveSettings(state);
  }
  
  Future<void> setAccentColor(Color color) async {
    state = state.copyWith(accentColor: color);
    await _service.saveSettings(state);
  }
  
  Future<void> setMaterialYou(bool value) async {
    state = state.copyWith(useMaterialYou: value);
    await _service.saveSettings(state);
  }
  
  Future<void> setAmoledDark(bool value) async {
    state = state.copyWith(useAmoledDark: value);
    await _service.saveSettings(state);
  }
  
  Future<void> setPlaybackSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    await _service.saveSettings(state);
  }
  
  Future<void> setAutoLoop(bool value) async {
    state = state.copyWith(autoLoop: value);
    await _service.saveSettings(state);
  }
  
  Future<void> setSeamlessLoop(bool value) async {
    state = state.copyWith(seamlessLoop: value);
    await _service.saveSettings(state);
  }
  
  Future<void> setRememberPosition(bool value) async {
    state = state.copyWith(rememberPosition: value);
    await _service.saveSettings(state);
  }
  
  Future<void> setHardwareAcceleration(bool value) async {
    state = state.copyWith(hardwareAcceleration: value);
    await _service.saveSettings(state);
  }
  
  Future<void> setVaultEnabled(bool value) async {
    state = state.copyWith(vaultEnabled: value);
    await _service.saveSettings(state);
  }
  
  Future<void> setVaultBiometric(bool value) async {
    state = state.copyWith(vaultBiometric: value);
    await _service.saveSettings(state);
  }
  
  Future<void> setVaultAutoLock(bool value) async {
    state = state.copyWith(vaultAutoLock: value);
    await _service.saveSettings(state);
  }
  
  Future<void> setVaultAutoLockTimeout(int minutes) async {
    state = state.copyWith(vaultAutoLockTimeout: minutes);
    await _service.saveSettings(state);
  }
  
  Future<void> setShowThumbnails(bool value) async {
    state = state.copyWith(showThumbnails: value);
    await _service.saveSettings(state);
  }
  
  Future<void> setDefaultSortOrder(String order) async {
    state = state.copyWith(defaultSortOrder: order);
    await _service.saveSettings(state);
  }
  
  Future<void> setGroupByFolder(bool value) async {
    state = state.copyWith(groupByFolder: value);
    await _service.saveSettings(state);
  }
  
  Future<void> resetToDefaults() async {
    state = const AppSettings();
    await _service.saveSettings(state);
  }
}
