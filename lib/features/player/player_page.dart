import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';

/// 播放器页面 - 完整功能版
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
  // 视频控制器
  late VideoPlayerController _videoController;
  
  // 状态
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isSeamlessLoop = true;
  bool _showControls = true;
  bool _isLocked = false;
  
  // 播放设置
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  double _brightness = 0.5;
  String _aspectRatio = 'fit'; // fit, fill, 16:9, 4:3
  bool _isMuted = false;
  
  // 字幕
  List<SubtitleEntry> _subtitles = [];
  bool _showSubtitle = true;
  double _subtitleFontSize = 18;
  Color _subtitleColor = Colors.white;
  Color _subtitleBgColor = Colors.black54;
  String? _subtitlePath;
  
  // 手势控制
  bool _isSeeking = false;
  bool _isAdjustingVolume = false;
  bool _isAdjustingBrightness = false;
  double _seekDelta = 0;
  double _volumeDelta = 0;
  double _brightnessDelta = 0;
  double _gestureStartX = 0;
  double _gestureStartY = 0;
  
  // 睡眠定时
  int? _sleepMinutes;
  Timer? _sleepTimer;
  
  // 计时器
  Timer? _loopTimer;
  Timer? _positionSaveTimer;
  Timer? _progressTimer;
  Timer? _controlsHideTimer;
  
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
    _playbackSpeed = settings.playbackSpeed;
    
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
      
      // 设置播放速度和音量
      await _videoController.setPlaybackSpeed(_playbackSpeed);
      await _videoController.setVolume(_volume);

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
      
      // 自动隐藏控制栏
      _startControlsHideTimer();
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

  void _startControlsHideTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isPlaying && !_isLocked) {
        setState(() {
          _showControls = false;
        });
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

  /// 加载字幕文件
  Future<void> _loadSubtitle() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'ass', 'ssa', 'vtt'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final content = await file.readAsString();
        final subtitles = _parseSubtitle(content, result.files.first.extension ?? 'srt');
        
        setState(() {
          _subtitles = subtitles;
          _subtitlePath = result.files.first.path;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('字幕加载成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载字幕失败: $e')),
        );
      }
    }
  }

  /// 解析字幕文件
  List<SubtitleEntry> _parseSubtitle(String content, String format) {
    final List<SubtitleEntry> entries = [];
    
    if (format.toLowerCase() == 'srt') {
      final blocks = content.split('\n\n');
      for (final block in blocks) {
        final lines = block.split('\n');
        if (lines.length >= 3) {
          try {
            final timeLine = lines[1];
            final times = timeLine.split(' --> ');
            if (times.length == 2) {
              final startTime = _parseSrtTime(times[0]);
              final endTime = _parseSrtTime(times[1]);
              final text = lines.sublist(2).join('\n');
              
              entries.add(SubtitleEntry(
                startTime: startTime,
                endTime: endTime,
                text: text,
              ));
            }
          } catch (e) {
            debugPrint('解析字幕块失败: $e');
          }
        }
      }
    }
    
    return entries;
  }

  Duration _parseSrtTime(String time) {
    final parts = time.trim().split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final secondParts = parts[2].split(',');
    final seconds = int.parse(secondParts[0]);
    final milliseconds = int.parse(secondParts[1]);
    
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }

  /// 设置睡眠定时
  void _setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    setState(() {
      _sleepMinutes = minutes;
    });
    
    if (minutes != null) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        _videoController.pause();
        setState(() {
          _isPlaying = false;
          _sleepMinutes = null;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('睡眠定时结束，已暂停播放')),
          );
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已设置 $minutes 分钟后暂停')),
        );
      }
    }
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
    _controlsHideTimer?.cancel();
    _sleepTimer?.cancel();
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
                ? _buildVideoWithAspectRatio()
                : const CircularProgressIndicator(),
          ),
          
          // 字幕显示
          if (_isInitialized && _showSubtitle && _subtitles.isNotEmpty)
            _buildSubtitleOverlay(),
          
          // 手势控制层
          if (_isInitialized) _buildGestureLayer(),
          
          // 控制层
          if (_isInitialized && _showControls && !_isLocked)
            _buildControlsOverlay(context, colorScheme),
          
          // 锁定状态
          if (_isLocked) _buildLockedOverlay(),
        ],
      ),
    );
  }

  Widget _buildVideoWithAspectRatio() {
    Widget video = VideoPlayer(_videoController);
    
    switch (_aspectRatio) {
      case 'fill':
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: FittedBox(
            fit: BoxFit.cover,
            child: video,
          ),
        );
      case '16:9':
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: video,
        );
      case '4:3':
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: video,
        );
      default:
        return AspectRatio(
          aspectRatio: _videoController.value.aspectRatio,
          child: video,
        );
    }
  }

  Widget _buildSubtitleOverlay() {
    final position = _videoController.value.position;
    String? currentText;
    
    for (final entry in _subtitles) {
      if (position >= entry.startTime && position <= entry.endTime) {
        currentText = entry.text;
        break;
      }
    }
    
    if (currentText == null) return const SizedBox.shrink();
    
    return Positioned(
      left: 16,
      right: 16,
      bottom: 140,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _subtitleBgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            currentText,
            style: TextStyle(
              color: _subtitleColor,
              fontSize: _subtitleFontSize,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildGestureLayer() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_isLocked) {
            setState(() => _isLocked = false);
          } else {
            setState(() {
              _showControls = !_showControls;
            });
            if (_showControls) {
              _startControlsHideTimer();
            }
          }
        },
        onDoubleTap: () {
          if (!_isLocked) {
            _togglePlay();
          }
        },
        onHorizontalDragStart: (details) {
          if (!_isLocked) {
            _gestureStartX = details.globalPosition.dx;
            setState(() {
              _isSeeking = true;
              _seekDelta = 0;
            });
          }
        },
        onHorizontalDragUpdate: (details) {
          if (!_isLocked && _isSeeking) {
            final width = MediaQuery.of(context).size.width;
            final delta = (details.globalPosition.dx - _gestureStartX) / width;
            setState(() {
              _seekDelta = delta * 60000; // 60秒范围
            });
            _gestureStartX = details.globalPosition.dx;
          }
        },
        onHorizontalDragEnd: (details) {
          if (!_isLocked && _isSeeking) {
            final position = _videoController.value.position;
            final newPosition = position + Duration(milliseconds: _seekDelta.toInt());
            _videoController.seekTo(newPosition);
            setState(() {
              _isSeeking = false;
              _seekDelta = 0;
            });
          }
        },
        onVerticalDragStart: (details) {
          if (!_isLocked) {
            final width = MediaQuery.of(context).size.width;
            _gestureStartY = details.globalPosition.dy;
            setState(() {
              _isAdjustingVolume = details.globalPosition.dx > width / 2;
              _isAdjustingBrightness = details.globalPosition.dx <= width / 2;
              _volumeDelta = 0;
              _brightnessDelta = 0;
            });
          }
        },
        onVerticalDragUpdate: (details) {
          if (!_isLocked) {
            final height = MediaQuery.of(context).size.height;
            final delta = (details.globalPosition.dy - _gestureStartY) / height;
            
            if (_isAdjustingVolume) {
              setState(() {
                _volumeDelta = -delta;
                _volume = (_volume + _volumeDelta).clamp(0.0, 1.0);
              });
              _videoController.setVolume(_volume);
              _gestureStartY = details.globalPosition.dy;
            } else if (_isAdjustingBrightness) {
              setState(() {
                _brightnessDelta = -delta;
                _brightness = (_brightness + _brightnessDelta).clamp(0.0, 1.0);
              });
              _gestureStartY = details.globalPosition.dy;
            }
          }
        },
        onVerticalDragEnd: (details) {
          setState(() {
            _isAdjustingVolume = false;
            _isAdjustingBrightness = false;
          });
        },
      ),
    );
  }

  Widget _buildControlsOverlay(BuildContext context, ColorScheme colorScheme) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
            stops: const [0, 0.15, 0.85, 1],
          ),
        ),
        child: Column(
          children: [
            _buildTopBar(context, colorScheme),
            const Spacer(),
            // 手势调节提示
            if (_isSeeking || _isAdjustingVolume || _isAdjustingBrightness)
              _buildGestureIndicator(),
            // 中间播放按钮
            if (!_isSeeking && !_isAdjustingVolume && !_isAdjustingBrightness)
              _buildCenterControls(context, colorScheme),
            const Spacer(),
            _buildBottomControls(context, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureIndicator() {
    String text = '';
    IconData icon = Icons.adjust;
    
    if (_isSeeking) {
      final delta = _seekDelta.toInt();
      final sign = delta >= 0 ? '+' : '';
      text = '$sign${(delta.abs() / 1000).toStringAsFixed(1)}秒';
      icon = delta >= 0 ? Icons.fast_forward : Icons.fast_rewind;
    } else if (_isAdjustingVolume) {
      text = '音量 ${(_volume * 100).toInt()}%';
      icon = _volume == 0 ? Icons.volume_off : Icons.volume_up;
    } else if (_isAdjustingBrightness) {
      text = '亮度 ${(_brightness * 100).toInt()}%';
      icon = Icons.brightness_6;
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 40),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(BuildContext context, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 快退10秒
        IconButton(
          icon: const Icon(FluentIcons.rewind_24_filled, color: Colors.white),
          iconSize: 36,
          onPressed: () {
            final position = _videoController.value.position - const Duration(seconds: 10);
            _videoController.seekTo(position.isNegative ? Duration.zero : position);
          },
        ),
        const SizedBox(width: 40),
        // 播放/暂停
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? FluentIcons.pause_24_filled : FluentIcons.play_24_filled,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        const SizedBox(width: 40),
        // 快进10秒
        IconButton(
          icon: const Icon(FluentIcons.fast_forward_24_filled, color: Colors.white),
          iconSize: 36,
          onPressed: () {
            final position = _videoController.value.position + const Duration(seconds: 10);
            final duration = _videoController.value.duration;
            _videoController.seekTo(position > duration ? duration : position);
          },
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, ColorScheme colorScheme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.videoName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_sleepMinutes != null)
                    Text(
                      '睡眠定时: $_sleepMinutes分钟',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            // 循环模式指示器
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isSeamlessLoop
                    ? colorScheme.primary.withOpacity(0.9)
                    : Colors.white24,
                borderRadius: BorderRadius.circular(12),
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
                    _isSeamlessLoop ? '循环' : '单次',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // 锁定按钮
            IconButton(
              icon: Icon(
                _isLocked ? FluentIcons.lock_closed_24_filled : FluentIcons.lock_open_24_regular,
                color: Colors.white,
              ),
              onPressed: () => setState(() => _isLocked = !_isLocked),
            ),
            // 设置按钮
            IconButton(
              icon: const Icon(FluentIcons.settings_24_regular, color: Colors.white),
              onPressed: () => _showSettingsSheet(context),
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
        padding: const EdgeInsets.all(8),
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
                    activeColor: colorScheme.primary,
                    inactiveColor: Colors.white24,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 8),
                // 播放速度
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            // 底部按钮栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 锁定
                IconButton(
                  icon: Icon(
                    _isLocked ? FluentIcons.lock_closed_24_filled : FluentIcons.lock_open_24_regular,
                    color: Colors.white,
                  ),
                  onPressed: () => setState(() => _isLocked = !_isLocked),
                ),
                // 字幕
                IconButton(
                  icon: Icon(
                    _subtitles.isNotEmpty
                        ? (_showSubtitle ? FluentIcons.closed_caption_24_filled : FluentIcons.closed_caption_24_regular)
                        : FluentIcons.closed_caption_off_24_regular,
                    color: _subtitles.isNotEmpty ? Colors.white : Colors.white54,
                  ),
                  onPressed: _subtitles.isNotEmpty
                      ? () => setState(() => _showSubtitle = !_showSubtitle)
                      : _loadSubtitle,
                ),
                // 音量
                IconButton(
                  icon: Icon(
                    _isMuted ? FluentIcons.speaker_mute_24_filled : FluentIcons.speaker_2_24_filled,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _isMuted = !_isMuted;
                      _videoController.setVolume(_isMuted ? 0 : _volume);
                    });
                  },
                ),
                // 画面比例
                IconButton(
                  icon: const Icon(FluentIcons.full_screen_maximize_24_regular, color: Colors.white),
                  onPressed: _showAspectRatioDialog,
                ),
                // 全屏
                IconButton(
                  icon: const Icon(FluentIcons.full_screen_maximize_24_regular, color: Colors.white),
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedOverlay() {
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _isLocked = false),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            FluentIcons.lock_closed_24_filled,
            color: Colors.white,
            size: 48,
          ),
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
    _startControlsHideTimer();
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

  void _showAspectRatioDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('画面比例'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('自适应'),
              value: 'fit',
              groupValue: _aspectRatio,
              onChanged: (value) {
                setState(() => _aspectRatio = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('填充屏幕'),
              value: 'fill',
              groupValue: _aspectRatio,
              onChanged: (value) {
                setState(() => _aspectRatio = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('16:9'),
              value: '16:9',
              groupValue: _aspectRatio,
              onChanged: (value) {
                setState(() => _aspectRatio = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('4:3'),
              value: '4:3',
              groupValue: _aspectRatio,
              onChanged: (value) {
                setState(() => _aspectRatio = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              const Text(
                '播放设置',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // 播放速度
              const Text('播放速度', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
                  return ChoiceChip(
                    label: Text('${speed}x'),
                    selected: _playbackSpeed == speed,
                    onSelected: (selected) {
                      if (selected) {
                        _videoController.setPlaybackSpeed(speed);
                        setState(() => _playbackSpeed = speed);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              
              // 无感循环
              SwitchListTile(
                title: const Text('无感循环'),
                subtitle: const Text('视频循环时无黑屏闪烁'),
                value: _isSeamlessLoop,
                onChanged: (value) {
                  setState(() => _isSeamlessLoop = value);
                  if (value) {
                    _startLoopDetection();
                  } else {
                    _loopTimer?.cancel();
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // 睡眠定时
              const Text('睡眠定时', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('关闭'),
                    selected: _sleepMinutes == null,
                    onSelected: (_) => _setSleepTimer(null),
                  ),
                  ChoiceChip(
                    label: const Text('15分钟'),
                    selected: _sleepMinutes == 15,
                    onSelected: (_) => _setSleepTimer(15),
                  ),
                  ChoiceChip(
                    label: const Text('30分钟'),
                    selected: _sleepMinutes == 30,
                    onSelected: (_) => _setSleepTimer(30),
                  ),
                  ChoiceChip(
                    label: const Text('60分钟'),
                    selected: _sleepMinutes == 60,
                    onSelected: (_) => _setSleepTimer(60),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 字幕设置
              ListTile(
                leading: const Icon(FluentIcons.closed_caption_24_regular),
                title: const Text('加载字幕'),
                subtitle: Text(_subtitlePath ?? '未加载'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  _loadSubtitle();
                },
              ),
              
              if (_subtitles.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('字幕设置', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('字体大小: '),
                    Expanded(
                      child: Slider(
                        value: _subtitleFontSize,
                        min: 12,
                        max: 32,
                        onChanged: (value) {
                          setState(() => _subtitleFontSize = value);
                        },
                      ),
                    ),
                    Text('${_subtitleFontSize.toInt()}'),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('字幕颜色:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Colors.white,
                    Colors.yellow,
                    Colors.cyan,
                    Colors.green,
                    Colors.pink,
                  ].map((color) {
                    return GestureDetector(
                      onTap: () => setState(() => _subtitleColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: _subtitleColor == color
                              ? Border.all(color: Colors.blue, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 字幕条目
class SubtitleEntry {
  final Duration startTime;
  final Duration endTime;
  final String text;

  const SubtitleEntry({
    required this.startTime,
    required this.endTime,
    required this.text,
  });
}
