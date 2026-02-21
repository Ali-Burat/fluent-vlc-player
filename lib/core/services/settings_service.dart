import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置服务 - 本地持久化
class SettingsService extends ChangeNotifier {
  final SharedPreferences _prefs;
  
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyAccentColor = 'accent_color';
  static const String _keyMaterialYou = 'material_you';
  static const String _keyAmoledDark = 'amoled_dark';
  static const String _keyAutoLoop = 'auto_loop';
  static const String _keySeamlessLoop = 'seamless_loop';
  static const String _keyRememberPosition = 'remember_position';
  static const String _keyPlaybackSpeed = 'playback_speed';
  static const String _keyVaultEnabled = 'vault_enabled';
  static const String _keyVaultPassword = 'vault_password_hash';
  static const String _keyShowThumbnails = 'show_thumbnails';
  static const String _keyPlayPositions = 'play_positions';
  
  SettingsService(this._prefs);
  
  // ========== 主题设置 ==========
  
  ThemeMode get themeMode {
    final index = _prefs.getInt(_keyThemeMode) ?? 0;
    return ThemeMode.values[index];
  }
  
  set themeMode(ThemeMode mode) {
    _prefs.setInt(_keyThemeMode, mode.index);
    notifyListeners();
  }
  
  Color get accentColor {
    final value = _prefs.getInt(_keyAccentColor);
    return value != null ? Color(value) : Colors.blue;
  }
  
  set accentColor(Color color) {
    _prefs.setInt(_keyAccentColor, color.value);
    notifyListeners();
  }
  
  bool get useMaterialYou => _prefs.getBool(_keyMaterialYou) ?? true;
  
  set useMaterialYou(bool value) {
    _prefs.setBool(_keyMaterialYou, value);
    notifyListeners();
  }
  
  bool get useAmoledDark => _prefs.getBool(_keyAmoledDark) ?? false;
  
  set useAmoledDark(bool value) {
    _prefs.setBool(_keyAmoledDark, value);
    notifyListeners();
  }
  
  // ========== 播放设置 ==========
  
  bool get autoLoop => _prefs.getBool(_keyAutoLoop) ?? true;
  
  set autoLoop(bool value) {
    _prefs.setBool(_keyAutoLoop, value);
    notifyListeners();
  }
  
  bool get seamlessLoop => _prefs.getBool(_keySeamlessLoop) ?? true;
  
  set seamlessLoop(bool value) {
    _prefs.setBool(_keySeamlessLoop, value);
    notifyListeners();
  }
  
  bool get rememberPosition => _prefs.getBool(_keyRememberPosition) ?? true;
  
  set rememberPosition(bool value) {
    _prefs.setBool(_keyRememberPosition, value);
    notifyListeners();
  }
  
  double get playbackSpeed {
    final value = _prefs.getDouble(_keyPlaybackSpeed);
    return value ?? 1.0;
  }
  
  set playbackSpeed(double value) {
    _prefs.setDouble(_keyPlaybackSpeed, value);
    notifyListeners();
  }
  
  bool get showThumbnails => _prefs.getBool(_keyShowThumbnails) ?? true;
  
  set showThumbnails(bool value) {
    _prefs.setBool(_keyShowThumbnails, value);
    notifyListeners();
  }
  
  // ========== 保险箱设置 ==========
  
  bool get vaultEnabled => _prefs.getBool(_keyVaultEnabled) ?? false;
  
  set vaultEnabled(bool value) {
    _prefs.setBool(_keyVaultEnabled, value);
    notifyListeners();
  }
  
  bool get hasVaultPassword => _prefs.containsKey(_keyVaultPassword);
  
  void setVaultPassword(String password) {
    // 简单哈希存储
    final hash = password.hashCode.toString();
    _prefs.setString(_keyVaultPassword, hash);
    notifyListeners();
  }
  
  bool verifyVaultPassword(String password) {
    final stored = _prefs.getString(_keyVaultPassword);
    if (stored == null) return false;
    return stored == password.hashCode.toString();
  }
  
  // ========== 播放位置记录 ==========
  
  void savePlayPosition(String videoId, int positionMs) {
    final positions = getPlayPositions();
    positions[videoId] = positionMs;
    _prefs.setString(_keyPlayPositions, jsonEncode(positions));
  }
  
  int? getPlayPosition(String videoId) {
    final positions = getPlayPositions();
    return positions[videoId];
  }
  
  Map<String, int> getPlayPositions() {
    final data = _prefs.getString(_keyPlayPositions);
    if (data == null) return {};
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }
  
  void clearPlayPositions() {
    _prefs.remove(_keyPlayPositions);
  }
  
  // ========== 重置 ==========
  
  void reset() {
    _prefs.clear();
    notifyListeners();
  }
}
