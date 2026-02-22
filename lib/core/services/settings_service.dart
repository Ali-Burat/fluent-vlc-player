import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  final SharedPreferences _prefs;
  SettingsService(this._prefs);
  
  ThemeMode get themeMode => ThemeMode.values[_prefs.getInt('theme_mode') ?? 0];
  set themeMode(ThemeMode mode) { _prefs.setInt('theme_mode', mode.index); notifyListeners(); }
  
  Color get accentColor { final v = _prefs.getInt('accent_color'); return v != null ? Color(v) : Colors.blue; }
  set accentColor(Color c) { _prefs.setInt('accent_color', c.value); notifyListeners(); }
  
  bool get useAmoledDark => _prefs.getBool('amoled_dark') ?? false;
  set useAmoledDark(bool v) { _prefs.setBool('amoled_dark', v); notifyListeners(); }
  
  bool get autoLoop => _prefs.getBool('auto_loop') ?? true;
  set autoLoop(bool v) { _prefs.setBool('auto_loop', v); notifyListeners(); }
  
  bool get seamlessLoop => _prefs.getBool('seamless_loop') ?? true;
  set seamlessLoop(bool v) { _prefs.setBool('seamless_loop', v); notifyListeners(); }
  
  bool get rememberPosition => _prefs.getBool('remember_position') ?? true;
  set rememberPosition(bool v) { _prefs.setBool('remember_position', v); notifyListeners(); }
  
  double get playbackSpeed => _prefs.getDouble('playback_speed') ?? 1.0;
  set playbackSpeed(double v) { _prefs.setDouble('playback_speed', v); notifyListeners(); }
  
  bool get hasVaultPassword => _prefs.containsKey('vault_password');
  void setVaultPassword(String p) { _prefs.setString('vault_password', p.hashCode.toString()); notifyListeners(); }
  bool verifyVaultPassword(String p) => _prefs.getString('vault_password') == p.hashCode.toString();
  
  void savePlayPosition(String id, int pos) { final m = getPlayPositions(); m[id] = pos; _prefs.setString('play_positions', jsonEncode(m)); }
  int? getPlayPosition(String id) => getPlayPositions()[id];
  Map<String, int> getPlayPositions() { final d = _prefs.getString('play_positions'); return d == null ? {} : Map.from(jsonDecode(d).map((k, v) => MapEntry(k, v as int))); }
  
  void reset() { _prefs.clear(); notifyListeners(); }
}
