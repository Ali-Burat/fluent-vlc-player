import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置服务
class SettingsService extends ChangeNotifier {
  final SharedPreferences _prefs;
  
  // 默认值
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyAccentColor = 'accent_color';
  static const String _keyMaterialYou = 'material_you';
  static const String _keyAutoLoop = 'auto_loop';
  static const String _keySeamlessLoop = 'seamless_loop';
  static const String _keyRememberPosition = 'remember_position';
  static const String _keyVaultEnabled = 'vault_enabled';
  
  SettingsService(this._prefs);
  
  /// 主题模式
  ThemeMode get themeMode {
    final index = _prefs.getInt(_keyThemeMode) ?? 0;
    return ThemeMode.values[index];
  }
  
  set themeMode(ThemeMode mode) {
    _prefs.setInt(_keyThemeMode, mode.index);
    notifyListeners();
  }
  
  /// 强调色
  Color get accentColor {
    final value = _prefs.getInt(_keyAccentColor);
    return value != null ? Color(value) : Colors.blue;
  }
  
  set accentColor(Color color) {
    _prefs.setInt(_keyAccentColor, color.value);
    notifyListeners();
  }
  
  /// 是否使用Material You
  bool get useMaterialYou => _prefs.getBool(_keyMaterialYou) ?? true;
  
  set useMaterialYou(bool value) {
    _prefs.setBool(_keyMaterialYou, value);
    notifyListeners();
  }
  
  /// 自动循环
  bool get autoLoop => _prefs.getBool(_keyAutoLoop) ?? true;
  
  set autoLoop(bool value) {
    _prefs.setBool(_keyAutoLoop, value);
    notifyListeners();
  }
  
  /// 无感循环
  bool get seamlessLoop => _prefs.getBool(_keySeamlessLoop) ?? true;
  
  set seamlessLoop(bool value) {
    _prefs.setBool(_keySeamlessLoop, value);
    notifyListeners();
  }
  
  /// 记住播放位置
  bool get rememberPosition => _prefs.getBool(_keyRememberPosition) ?? true;
  
  set rememberPosition(bool value) {
    _prefs.setBool(_keyRememberPosition, value);
    notifyListeners();
  }
  
  /// 保险箱启用
  bool get vaultEnabled => _prefs.getBool(_keyVaultEnabled) ?? false;
  
  set vaultEnabled(bool value) {
    _prefs.setBool(_keyVaultEnabled, value);
    notifyListeners();
  }
  
  /// 重置设置
  void reset() {
    _prefs.clear();
    notifyListeners();
  }
}
