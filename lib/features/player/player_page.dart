import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../core/theme/app_theme.dart';

/// 播放器页面
class PlayerPage extends ConsumerStatefulWidget {
  final String videoPath;
  final String videoName;

  const PlayerPage({
    super.key,
    required this.videoPath,
    required this.videoName,
  });

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _isLooping = true;
  bool _isSeamlessLoop = true;
  Timer? _loopTimer;

  // 无感循环相关
  static const int _loopPreloadMs = 500;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // 创建视频控制器
    if (widget.videoPath.startsWith('http')) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoPath));
    } else {
      _videoController = VideoPlayerController.file(File(widget.videoPath));
    }

    try {
      await _videoController.initialize();
      
      // 设置循环
      await _videoController.setLooping(_isSeamlessLoop);

      // 创建Chewie控制器
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: _isSeamlessLoop,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: const [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
        optionsTranslation: OptionsTranslation(
          optionsButtonButtonText: '设置',
          subtitlesButtonText: '字幕',
          cancelButtonText: '取消',
        ),
        additionalOptions: (context) => [
          OptionItem(
            onTap: () {
              Navigator.pop(context);
              _toggleSeamlessLoop();
            },
            iconData: _isSeamlessLoop 
                ? FluentIcons.arrow_sync_24_filled 
                : FluentIcons.arrow_sync_24_regular,
            title: _isSeamlessLoop ? '关闭无感循环' : '开启无感循环',
          ),
        ],
      );

      // 监听播放状态
      _videoController.addListener(_onVideoStateChanged);

      // 启动无感循环检测
      _startLoopDetection();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('初始化播放器失败: $e');
    }
  }

  void _onVideoStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// 启动无感循环检测
  void _startLoopDetection() {
    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isSeamlessLoop || !_videoController.value.isPlaying) {
        return;
      }

      final position = _videoController.value.position;
      final duration = _videoController.value.duration;

      if (duration.inMilliseconds > 0) {
        final remainingMs = duration.inMilliseconds - position.inMilliseconds;
        
        // 提前预加载循环
        if (remainingMs < _loopPreloadMs && remainingMs > 0) {
          _handleSeamlessLoop();
        }
      }
    });
  }

  /// 无感循环处理
  Future<void> _handleSeamlessLoop() async {
    if (!_isSeamlessLoop) return;
    
    try {
      await _videoController.seekTo(Duration.zero);
      await _videoController.play();
    } catch (e) {
      debugPrint('循环播放失败: $e');
    }
  }

  /// 切换无感循环
  void _toggleSeamlessLoop() {
    setState(() {
      _isSeamlessLoop = !_isSeamlessLoop;
    });
    _videoController.setLooping(_isSeamlessLoop);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSeamlessLoop ? '已开启无感循环' : '已关闭无感循环'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _videoController.removeListener(_onVideoStateChanged);
    _chewieController?.dispose();
    _videoController.dispose();
    
    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.videoName,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          // 循环模式指示器
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _isSeamlessLoop
                  ? colorScheme.primary.withOpacity(0.8)
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isSeamlessLoop
                      ? FluentIcons.arrow_sync_24_filled
                      : FluentIcons.arrow_sync_24_regular,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _isSeamlessLoop ? '无感循环' : '单次',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _isInitialized && _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : const CircularProgressIndicator(),
            ),
          ),
          // 底部控制栏
          if (_isInitialized) _buildBottomControls(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, ColorScheme colorScheme) {
    final position = _videoController.value.position;
    final duration = _videoController.value.duration;

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            Row(
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: colorScheme.primary,
                    ),
                    child: Slider(
                      value: duration.inMilliseconds > 0
                          ? position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble())
                          : 0,
                      min: 0,
                      max: duration.inMilliseconds > 0
                          ? duration.inMilliseconds.toDouble()
                          : 1,
                      onChanged: (value) {
                        _videoController.seekTo(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 快退
                IconButton(
                  icon: const Icon(FluentIcons.rewind_24_filled, color: Colors.white),
                  onPressed: () {
                    final newPosition = position - const Duration(seconds: 10);
                    _videoController.seekTo(
                      newPosition.isNegative ? Duration.zero : newPosition,
                    );
                  },
                ),
                const SizedBox(width: 16),
                // 播放/暂停
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _videoController.value.isPlaying
                          ? FluentIcons.pause_24_filled
                          : FluentIcons.play_24_filled,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      if (_videoController.value.isPlaying) {
                        _videoController.pause();
                      } else {
                        _videoController.play();
                      }
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // 快进
                IconButton(
                  icon: const Icon(FluentIcons.fast_forward_24_filled, color: Colors.white),
                  onPressed: () {
                    final newPosition = position + const Duration(seconds: 10);
                    _videoController.seekTo(
                      newPosition > duration ? duration : newPosition,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
