import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/settings_service.dart';
import '../core/services/vault_service.dart';
import '../core/services/player_service.dart';

// Re-export providers
export '../core/services/settings_service.dart';
export '../core/services/vault_service.dart';
export '../core/services/player_service.dart';

/// 应用初始化提供者
final appInitializedProvider = FutureProvider<bool>((ref) async {
  // 确保所有服务都已初始化
  ref.watch(settingsProvider);
  ref.watch(vaultProvider);
  return true;
});

/// 当前主题提供者
final currentThemeProvider = Provider((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.themeMode;
});

/// 是否使用Material You
final useMaterialYouProvider = Provider((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.useMaterialYou;
});

/// 强调色提供者
final accentColorProvider = Provider((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.accentColor;
});

/// 保险箱是否解锁
final isVaultUnlockedProvider = Provider((ref) {
  final vault = ref.watch(vaultProvider);
  return vault.isUnlocked;
});

/// 当前播放视频
final currentVideoProvider = Provider((ref) {
  final player = ref.watch(playerProvider);
  return player.currentVideo;
});

/// 是否正在播放
final isPlayingProvider = Provider((ref) {
  final player = ref.watch(playerProvider);
  return player.isPlaying;
});
