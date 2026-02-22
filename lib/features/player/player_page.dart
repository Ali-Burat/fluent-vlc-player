import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';

/// 播放器页面 - 支持无感循环
class PlayerPage extends StatefulWidget {
  final String videoPath;
  final String videoName;
  final String? videoId;

  const PlayerPage({
    super.key,
    required this.videoPath,
    required this.videoName,
    this.videoId,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isSeamlessLoop = true;
  Timer? _loopTimer;
  Timer? _positionSaveTimer;
  Timer? _progressTimer;
  bool _showControls = true;
  
  // 无感循环参数
  static const int _preloadMs = 800;
  bool _isPreparingLoop = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final settings = context.read<SettingsService>();
    _isSeamlessLoop = settings.seamlessLoop;
    
    // 创建视频控制器
    if (widget.videoPath.startsWith('http')) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoPath));
    } else {
      _videoController = VideoPlayerController.file(File(widget.videoPath));
    }

    try {
      await _videoController.initialize();
      
      // 恢复播放位置
      if (settings.rememberPosition && widget.videoId != null) {
        final savedPos = settings.getPlayPosition(widget.videoId!);
        if (savedPos != null && savedPos > 0) {
          await _videoController.seekTo(Duration(milliseconds: savedPos));
        }
      }
      
      // 设置播放速度
      await _videoController.setPlaybackSpeed(settings.playbackSpeed);

      // 监听播放状态
      _videoController.addListener(_onVideoStateChanged);

      // 启动进度更新
      _startProgressTimer();

      // 启动无感循环检测
      if (_isSeamlessLoop) {
        _startLoopDetection();
      }
      
      // 启动位置保存
      if (settings.rememberPosition) {
        _startPositionSaving();
      }

      setState(() {
        _isInitialized = true;
      });
      
      // 自动播放
      _videoController.play();
      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      debugPrint('初始化播放器失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法播放此视频: $e')),
        );
      }
    }
  }

  void _onVideoStateChanged() {
    if (!mounted) return;
    
    // 检测视频结束
    if (_videoController.value.position >= _videoController.value.duration) {
      if (_isSeamlessLoop && !_isPreparingLoop) {
        _handleSeamlessLoop();
      }
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// 启动无感循环检测
  void _startLoopDetection() {
    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || !_isSeamlessLoop || !_videoController.value.isPlaying) {
        return;
      }

      final position = _videoController.value.position;
      final duration = _videoController.value.duration;

      if (duration.inMilliseconds > 0) {
        final remainingMs = duration.inMilliseconds - position.inMilliseconds;
        
        if (remainingMs < _preloadMs && remainingMs > 0 && !_isPreparingLoop) {
          _handleSeamlessLoop();
        }
      }
    });
  }

  /// 无感循环处理
  Future<void> _handleSeamlessLoop() async {
    if (!_isSeamlessLoop || _isPreparingLoop) return;
    
    _isPreparingLoop = true;
    
    try {
      await _videoController.seekTo(Duration.zero);
      if (!_videoController.value.isPlaying) {
        await _videoController.play();
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 200), () {
        _isPreparingLoop = false;
      });
    }
  }

  /// 切换无感循环
  void _toggleSeamlessLoop() {
    setState(() {
      _isSeamlessLoop = !_isSeamlessLoop;
    });
    
    if (_isSeamlessLoop) {
      _startLoopDetection();
    } else {
      _loopTimer?.cancel();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSeamlessLoop ? '已开启无感循环' : '已关闭无感循环'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 启动位置保存
  void _startPositionSaving() {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || widget.videoId == null) return;
      
      final settings = context.read<SettingsService>();
      final position = _videoController.value.position;
      if (position.inMilliseconds > 0) {
        settings.savePlayPosition(widget.videoId!, position.inMilliseconds);
      }
    });
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
    _positionSaveTimer?.cancel();
    _progressTimer?.cancel();
    _videoController.removeListener(_onVideoStateChanged);
    _videoController.dispose();
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
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
      body: Stack(
        children: [
          // 视频内容
          Center(
            child: _isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController.value.aspectRatio,
                    child: VideoPlayer(_videoController),
                  )
                : const CircularProgressIndicator(),
          ),
          
          // 控制层
          if (_isInitialized && _showControls)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showControls = false;
                  });
                },
                child: Container(
                  color: Colors.black26,
                  child: Column(
                    children: [
                      // 顶部栏
                      _buildTopBar(context, colorScheme),
                      
                      const Spacer(),
                      
                      // 中间播放按钮
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlaying
                                ? FluentIcons.pause_24_filled
                                : FluentIcons.play_24_filled,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // 底部控制栏
                      _buildBottomControls(context, colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          
          // 点击显示控制层
          if (_isInitialized && !_showControls)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showControls = true;
                  });
                },
                child: Container(color: Colors.transparent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ColorScheme colorScheme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.videoName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 循环模式指示器
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isSeamlessLoop
                    ? colorScheme.primary.withOpacity(0.9)
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.fullscreen, color: Colors.white),
              onPressed: _toggleFullscreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, ColorScheme colorScheme) {
    final position = _videoController.value.position;
    final duration = _videoController.value.duration;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
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
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
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
                  icon: const Icon(FluentIcons.rewind_24_filled, color: Colors.white, size: 28),
                  onPressed: () {
                    final newPosition = position - const Duration(seconds: 10);
                    _videoController.seekTo(
                      newPosition.isNegative ? Duration.zero : newPosition,
                    );
                  },
                ),
                const SizedBox(width: 24),
                // 播放/暂停
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying
                          ? FluentIcons.pause_24_filled
                          : FluentIcons.play_24_filled,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // 快进
                IconButton(
                  icon: const Icon(FluentIcons.fast_forward_24_filled, color: Colors.white, size: 28),
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

  void _togglePlay() {
    if (_isPlaying) {
      _videoController.pause();
    } else {
      _videoController.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _toggleFullscreen() {
    if (MediaQuery.of(context).orientation == Orientation.portrait) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }
}
