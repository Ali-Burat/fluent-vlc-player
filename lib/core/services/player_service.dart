import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

/// 视频文件模型
class VideoFile {
  final String id;
  final String path;
  final String name;
  final String? thumbnailPath;
  final int? duration;
  final int? size;
  final DateTime addedAt;
  final DateTime? lastPlayedAt;
  final int? lastPosition; // 毫秒
  final int playCount;

  const VideoFile({
    required this.id,
    required this.path,
    required this.name,
    this.thumbnailPath,
    this.duration,
    this.size,
    required this.addedAt,
    this.lastPlayedAt,
    this.lastPosition,
    this.playCount = 0,
  });

  VideoFile copyWith({
    String? id,
    String? path,
    String? name,
    String? thumbnailPath,
    int? duration,
    int? size,
    DateTime? addedAt,
    DateTime? lastPlayedAt,
    int? lastPosition,
    int? playCount,
  }) {
    return VideoFile(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      duration: duration ?? this.duration,
      size: size ?? this.size,
      addedAt: addedAt ?? this.addedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      lastPosition: lastPosition ?? this.lastPosition,
      playCount: playCount ?? this.playCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'name': name,
      'thumbnailPath': thumbnailPath,
      'duration': duration,
      'size': size,
      'addedAt': addedAt.toIso8601String(),
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      'lastPosition': lastPosition,
      'playCount': playCount,
    };
  }

  factory VideoFile.fromJson(Map<String, dynamic> json) {
    return VideoFile(
      id: json['id'] as String,
      path: json['path'] as String,
      name: json['name'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      duration: json['duration'] as int?,
      size: json['size'] as int?,
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastPlayedAt: json['lastPlayedAt'] != null
          ? DateTime.parse(json['lastPlayedAt'] as String)
          : null,
      lastPosition: json['lastPosition'] as int?,
      playCount: json['playCount'] as int? ?? 0,
    );
  }
}

/// 播放器状态
class PlayerState {
  final VlcPlayerController? controller;
  final VideoFile? currentVideo;
  final List<VideoFile> playlist;
  final int currentIndex;
  final bool isPlaying;
  final bool isLooping;
  final bool isSeamlessLoop;
  final double playbackSpeed;
  final double volume;
  final bool isMuted;
  final Duration position;
  final Duration duration;
  final bool isBuffering;
  final bool hasError;
  final String? errorMessage;
  final bool isFullscreen;
  final bool showControls;

  const PlayerState({
    this.controller,
    this.currentVideo,
    this.playlist = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.isLooping = true,
    this.isSeamlessLoop = true,
    this.playbackSpeed = 1.0,
    this.volume = 1.0,
    this.isMuted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isBuffering = false,
    this.hasError = false,
    this.errorMessage,
    this.isFullscreen = false,
    this.showControls = true,
  });

  PlayerState copyWith({
    VlcPlayerController? controller,
    VideoFile? currentVideo,
    List<VideoFile>? playlist,
    int? currentIndex,
    bool? isPlaying,
    bool? isLooping,
    bool? isSeamlessLoop,
    double? playbackSpeed,
    double? volume,
    bool? isMuted,
    Duration? position,
    Duration? duration,
    bool? isBuffering,
    bool? hasError,
    String? errorMessage,
    bool? isFullscreen,
    bool? showControls,
  }) {
    return PlayerState(
      controller: controller ?? this.controller,
      currentVideo: currentVideo ?? this.currentVideo,
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isLooping: isLooping ?? this.isLooping,
      isSeamlessLoop: isSeamlessLoop ?? this.isSeamlessLoop,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isBuffering: isBuffering ?? this.isBuffering,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      showControls: showControls ?? this.showControls,
    );
  }
}

/// 播放器服务提供者
final playerServiceProvider = Provider<PlayerService>((ref) {
  return PlayerService();
});

/// 播放器状态提供者
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref.read(playerServiceProvider));
});

/// 播放器服务
class PlayerService {
  static const String _recentFilesKey = 'recent_files';
  static const String _playPositionsKey = 'play_positions';
  
  Box get _box => Hive.box('settings');
  
  /// 获取最近播放文件
  Future<List<VideoFile>> getRecentFiles() async {
    final data = _box.get(_recentFilesKey);
    if (data == null) return [];
    
    final List<dynamic> items = data;
    return items.map((item) => VideoFile.fromJson(Map<String, dynamic>.from(item))).toList();
  }
  
  /// 保存最近播放文件
  Future<void> saveRecentFiles(List<VideoFile> files) async {
    await _box.put(_recentFilesKey, files.map((f) => f.toJson()).toList());
  }
  
  /// 获取播放位置
  Future<int?> getPlayPosition(String videoId) async {
    final positions = _box.get(_playPositionsKey, defaultValue: {}) as Map;
    return positions[videoId] as int?;
  }
  
  /// 保存播放位置
  Future<void> savePlayPosition(String videoId, int position) async {
    final positions = _box.get(_playPositionsKey, defaultValue: {}) as Map;
    positions[videoId] = position;
    await _box.put(_playPositionsKey, positions);
  }
  
  /// 生成视频缩略图
  Future<String?> generateThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 256,
        maxHeight: 144,
        quality: 75,
      );
      return thumbnailPath;
    } catch (e) {
      return null;
    }
  }
}

/// 播放器状态管理器
class PlayerNotifier extends StateNotifier<PlayerState> {
  final PlayerService _service;
  Timer? _positionTimer;
  Timer? _seamlessLoopTimer;
  StreamSubscription? _playerSubscription;
  
  PlayerNotifier(this._service) : super(const PlayerState());
  
  /// 初始化播放器
  Future<void> initializePlayer() async {
    // 初始化时不需要创建控制器，等待视频加载
  }
  
  /// 加载视频
  Future<void> loadVideo(VideoFile video, {int? startPosition}) async {
    // 释放之前的控制器
    await _disposeController();
    
    // 创建新的VLC控制器
    final controller = VlcPlayerController.network(
      video.path,
      hwAcc: HwAcc.auto,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(200),
        ]),
        audio: VlcAudioOptions([
          VlcAudioOptions.audioTimeStretch(true),
        ]),
      ),
    );
    
    // 设置循环模式
    await controller.setLooping(state.isSeamlessLoop);
    
    // 监听播放器事件
    _playerSubscription = controller.addListener(() {
      _onPlayerEvent(controller, video);
    });
    
    // 如果有保存的位置，跳转到该位置
    if (startPosition != null && startPosition > 0) {
      await Future.delayed(const Duration(milliseconds: 500));
      await controller.seekTo(Duration(milliseconds: startPosition));
    }
    
    state = state.copyWith(
      controller: controller,
      currentVideo: video,
      isPlaying: true,
      hasError: false,
      errorMessage: null,
    );
    
    // 开始位置更新定时器
    _startPositionTimer();
  }
  
  /// 处理播放器事件
  void _onPlayerEvent(VlcPlayerController controller, VideoFile video) {
    if (controller.value.isEnded && state.isSeamlessLoop) {
      // 无感循环：视频结束时自动重新开始
      _handleSeamlessLoop(controller);
    }
    
    state = state.copyWith(
      isPlaying: controller.value.isPlaying,
      isBuffering: controller.value.isBuffering,
      position: controller.value.position,
      duration: controller.value.duration,
      hasError: controller.value.hasError,
      errorMessage: controller.value.errorDescription,
    );
  }
  
  /// 处理无感循环
  Future<void> _handleSeamlessLoop(VlcPlayerController controller) async {
    if (!state.isSeamlessLoop) return;
    
    // 在视频即将结束时提前准备循环
    final currentPosition = controller.value.position;
    final totalDuration = controller.value.duration;
    
    if (totalDuration.inMilliseconds > 0) {
      final remainingMs = totalDuration.inMilliseconds - currentPosition.inMilliseconds;
      
      // 如果剩余时间小于500ms，准备无缝循环
      if (remainingMs < 500) {
        await controller.seekTo(Duration.zero);
        await controller.play();
      }
    }
  }
  
  /// 开始位置更新定时器
  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (state.controller != null && state.isPlaying) {
        final position = state.controller!.value.position;
        state = state.copyWith(position: position);
        
        // 保存播放位置
        if (state.currentVideo != null) {
          await _service.savePlayPosition(
            state.currentVideo!.id,
            position.inMilliseconds,
          );
        }
      }
    });
  }
  
  /// 播放/暂停
  Future<void> togglePlayPause() async {
    if (state.controller == null) return;
    
    if (state.isPlaying) {
      await state.controller!.pause();
    } else {
      await state.controller!.play();
    }
  }
  
  /// 播放
  Future<void> play() async {
    if (state.controller == null) return;
    await state.controller!.play();
    state = state.copyWith(isPlaying: true);
  }
  
  /// 暂停
  Future<void> pause() async {
    if (state.controller == null) return;
    await state.controller!.pause();
    state = state.copyWith(isPlaying: false);
  }
  
  /// 停止
  Future<void> stop() async {
    await _disposeController();
    state = const PlayerState();
  }
  
  /// 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    if (state.controller == null) return;
    await state.controller!.seekTo(position);
    state = state.copyWith(position: position);
  }
  
  /// 设置播放速度
  Future<void> setPlaybackSpeed(double speed) async {
    if (state.controller == null) return;
    await state.controller!.setSpeed(speed);
    state = state.copyWith(playbackSpeed: speed);
  }
  
  /// 设置音量
  Future<void> setVolume(double volume) async {
    if (state.controller == null) return;
    await state.controller!.setVolume((volume * 100).toInt());
    state = state.copyWith(volume: volume);
  }
  
  /// 静音/取消静音
  Future<void> toggleMute() async {
    if (state.controller == null) return;
    
    if (state.isMuted) {
      await state.controller!.setVolume((state.volume * 100).toInt());
    } else {
      await state.controller!.setVolume(0);
    }
    
    state = state.copyWith(isMuted: !state.isMuted);
  }
  
  /// 设置循环模式
  Future<void> setLoopMode(bool seamless) async {
    if (state.controller != null) {
      await state.controller!.setLooping(seamless);
    }
    state = state.copyWith(isSeamlessLoop: seamless, isLooping: true);
  }
  
  /// 切换全屏
  void toggleFullscreen() {
    state = state.copyWith(isFullscreen: !state.isFullscreen);
  }
  
  /// 显示/隐藏控制栏
  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }
  
  /// 快进
  Future<void> fastForward({Duration duration = const Duration(seconds: 10)}) async {
    if (state.controller == null) return;
    
    final newPosition = state.position + duration;
    final maxPosition = state.duration;
    
    if (newPosition < maxPosition) {
      await seekTo(newPosition);
    } else {
      await seekTo(maxPosition);
    }
  }
  
  /// 快退
  Future<void> rewind({Duration duration = const Duration(seconds: 10)}) async {
    if (state.controller == null) return;
    
    final newPosition = state.position - duration;
    if (newPosition > Duration.zero) {
      await seekTo(newPosition);
    } else {
      await seekTo(Duration.zero);
    }
  }
  
  /// 加载播放列表
  Future<void> loadPlaylist(List<VideoFile> videos, {int startIndex = 0}) async {
    state = state.copyWith(playlist: videos, currentIndex: startIndex);
    await loadVideo(videos[startIndex]);
  }
  
  /// 播放下一个
  Future<void> playNext() async {
    if (state.playlist.isEmpty || state.currentIndex < 0) return;
    
    final nextIndex = state.currentIndex + 1;
    if (nextIndex < state.playlist.length) {
      state = state.copyWith(currentIndex: nextIndex);
      await loadVideo(state.playlist[nextIndex]);
    } else if (state.isLooping) {
      // 循环播放列表
      state = state.copyWith(currentIndex: 0);
      await loadVideo(state.playlist[0]);
    }
  }
  
  /// 播放上一个
  Future<void> playPrevious() async {
    if (state.playlist.isEmpty || state.currentIndex < 0) return;
    
    final prevIndex = state.currentIndex - 1;
    if (prevIndex >= 0) {
      state = state.copyWith(currentIndex: prevIndex);
      await loadVideo(state.playlist[prevIndex]);
    } else if (state.isLooping) {
      // 循环播放列表
      final lastIndex = state.playlist.length - 1;
      state = state.copyWith(currentIndex: lastIndex);
      await loadVideo(state.playlist[lastIndex]);
    }
  }
  
  /// 释放控制器
  Future<void> _disposeController() async {
    _positionTimer?.cancel();
    _seamlessLoopTimer?.cancel();
    _playerSubscription?.cancel();
    
    if (state.controller != null) {
      await state.controller!.stopRendererScanning();
      await state.controller!.dispose();
    }
  }
  
  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }
}
