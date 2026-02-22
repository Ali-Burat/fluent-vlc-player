import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
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
  String _aspectRatio = 'fit';
  bool _isMuted = false;
  
  // 字幕
  List<SubtitleEntry> _subtitles = [];
  bool _showSubtitle = true;
  double _subtitleFontSize = 18;
  Color _subtitleColor = Colors.white;
  Color _subtitleBgColor = Colors.black54;
  String? _subtitlePath;
  double _subtitlePosition = 0.85; // 0-1, 0.85表示底部85%位置
  bool _isDraggingSubtitle = false;
  
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
  
  // 自动取色
  Color? _dominantColor;
  List<Color> _paletteColors = [];

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final settings = context.read<SettingsService>();
    _isSeamlessLoop = settings.seamlessLoop;
    _playbackSpeed = settings.playbackSpeed;
    
    if (widget.videoPath.startsWith('http')) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoPath));
    } else {
      _videoController = VideoPlayerController.file(File(widget.videoPath));
    }

    try {
      await _videoController.initialize();
      
      if (settings.rememberPosition && widget.videoId != null) {
        final savedPos = settings.getPlayPosition(widget.videoId!);
        if (savedPos != null && savedPos > 0) {
          await _videoController.seekTo(Duration(milliseconds: savedPos));
        }
      }
      
      await _videoController.setPlaybackSpeed(_playbackSpeed);
      await _videoController.setVolume(_volume);

      _videoController.addListener(_onVideoStateChanged);
      _startProgressTimer();

      if (_isSeamlessLoop) {
        _startLoopDetection();
      }
      
      if (settings.rememberPosition) {
        _startPositionSaving();
      }

      setState(() {
        _isInitialized = true;
      });
      
      _videoController.play();
      setState(() {
        _isPlaying = true;
      });
      
      _startControlsHideTimer();
      
      // 提取视频颜色
      _extractVideoColors();
    } catch (e) {
      debugPrint('初始化播放器失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法播放此视频: $e')),
        );
      }
    }
  }

  /// 提取视频主要颜色
  Future<void> _extractVideoColors() async {
    try {
      // 跳转到视频中间位置获取帧
      final duration = _videoController.value.duration;
      final middlePosition = Duration(milliseconds: duration.inMilliseconds ~/ 2);
      
      await _videoController.seekTo(middlePosition);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 获取视频帧并提取颜色
      final image = await _videoController.value.image;
      if (image != null) {
        final colors = await _extractColorsFromImage(image);
        setState(() {
          _paletteColors = colors;
          _dominantColor = colors.isNotEmpty ? colors[0] : null;
        });
      }
      
      // 恢复到开始位置
      await _videoController.seekTo(Duration.zero);
    } catch (e) {
      debugPrint('提取颜色失败: $e');
    }
  }

  /// 从图像提取颜色
  Future<List<Color>> _extractColorsFromImage(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return [];
    
    final pixels = byteData.buffer.asUint8List();
    final Map<int, int> colorCounts = {};
    
    // 采样像素
    for (int i = 0; i < pixels.length; i += 16) { // 每16个像素采样一次
      if (i + 3 < pixels.length) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        final a = pixels[i + 3];
        
        if (a > 128) { // 忽略透明像素
          // 量化颜色（减少颜色数量）
          final qr = (r ~/ 32) * 32;
          final qg = (g ~/ 32) * 32;
          final qb = (b ~/ 32) * 32;
          final colorValue = (qr << 16) | (qg << 8) | qb;
          colorCounts[colorValue] = (colorCounts[colorValue] ?? 0) + 1;
        }
      }
    }
    
    // 排序获取主要颜色
    final sortedColors = colorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedColors.take(5).map((e) {
      final r = (e.key >> 16) & 0xFF;
      final g = (e.key >> 8) & 0xFF;
      final b = e.key & 0xFF;
      return Color.fromRGBO(r, g, b, 1.0);
    }).toList();
  }

  void _onVideoStateChanged() {
    if (!mounted) return;
    
    if (_videoController.value.position >= _videoController.value.duration) {
      if (_isSeamlessLoop && !_isPreparingLoop) {
        _handleSeamlessLoop();
      }
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) setState(() {});
    });
  }

  void _startControlsHideTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isPlaying && !_isLocked) {
        setState(() => _showControls = false);
      }
    });
  }

  void _startLoopDetection() {
    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || !_isSeamlessLoop || !_videoController.value.isPlaying) return;

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

  Future<void> _handleSeamlessLoop() async {
    if (!_isSeamlessLoop || _isPreparingLoop) return;
    _isPreparingLoop = true;
    
    try {
      await _videoController.seekTo(Duration.zero);
      if (!_videoController.value.isPlaying) await _videoController.play();
    } finally {
      Future.delayed(const Duration(milliseconds: 200), () {
        _isPreparingLoop = false;
      });
    }
  }

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
            const SnackBar(content: Text('字幕加载成功，可拖动调整位置')),
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
    return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
  }

  void _setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    setState(() => _sleepMinutes = minutes);
    
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
    // 使用自动提取的颜色或主题色
    final accentColor = _dominantColor ?? colorScheme.primary;

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
          
          // 字幕显示（可拖动）
          if (_isInitialized && _showSubtitle && _subtitles.isNotEmpty)
            _buildSubtitleOverlay(),
          
          // 手势控制层
          if (_isInitialized) _buildGestureLayer(),
          
          // 控制层
          if (_isInitialized && _showControls && !_isLocked)
            _buildControlsOverlay(context, colorScheme, accentColor),
          
          // 锁定状态
          if (_isLocked) _buildLockedOverlay(accentColor),
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
          child: FittedBox(fit: BoxFit.cover, child: video),
        );
      case '16:9':
        return AspectRatio(aspectRatio: 16 / 9, child: video);
      case '4:3':
        return AspectRatio(aspectRatio: 4 / 3, child: video);
      default:
        return AspectRatio(aspectRatio: _videoController.value.aspectRatio, child: video);
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
    
    final screenHeight = MediaQuery.of(context).size.height;
    final subtitleTop = screenHeight * _subtitlePosition;
    
    return Positioned(
      left: 16,
      right: 16,
      top: subtitleTop,
      child: GestureDetector(
        onVerticalDragStart: (_) => setState(() => _isDraggingSubtitle = true),
        onVerticalDragUpdate: (details) {
          final newY = details.globalPosition.dy;
          final screenHeight = MediaQuery.of(context).size.height;
          setState(() {
            _subtitlePosition = (newY / screenHeight).clamp(0.1, 0.9);
          });
        },
        onVerticalDragEnd: (_) => setState(() => _isDraggingSubtitle = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _subtitleBgColor,
            borderRadius: BorderRadius.circular(8),
            border: _isDraggingSubtitle ? Border.all(color: Colors.blue, width: 2) : null,
          ),
          child: Text(
            currentText,
            style: TextStyle(
              color: _subtitleColor,
              fontSize: _subtitleFontSize,
              height: 1.4,
              shadows: [
                Shadow(color: Colors.black.withOpacity(0.5), offset: const Offset(1, 1), blurRadius: 2),
              ],
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
            setState(() => _showControls = !_showControls);
            if (_showControls) _startControlsHideTimer();
          }
        },
        onDoubleTap: () {
          if (!_isLocked) _togglePlay();
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
            setState(() => _seekDelta = delta * 60000);
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

  Widget _buildControlsOverlay(BuildContext context, ColorScheme colorScheme, Color accentColor) {
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
            _buildTopBar(context, colorScheme, accentColor),
            const Spacer(),
            if (_isSeeking || _isAdjustingVolume || _isAdjustingBrightness)
              _buildGestureIndicator(accentColor),
            if (!_isSeeking && !_isAdjustingVolume && !_isAdjustingBrightness)
              _buildCenterControls(context, accentColor),
            const Spacer(),
            _buildBottomControls(context, colorScheme, accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureIndicator(Color accentColor) {
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.5), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(BuildContext context, Color accentColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 快退10秒
        _buildControlButton(
          icon: FluentIcons.rewind_24_filled,
          size: 28,
          onPressed: () {
            final position = _videoController.value.position - const Duration(seconds: 10);
            _videoController.seekTo(position.isNegative ? Duration.zero : position);
          },
        ),
        const SizedBox(width: 32),
        // 播放/暂停
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accentColor, accentColor.withOpacity(0.8)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _isPlaying ? FluentIcons.pause_24_filled : FluentIcons.play_24_filled,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        const SizedBox(width: 32),
        // 快进10秒
        _buildControlButton(
          icon: FluentIcons.fast_forward_24_filled,
          size: 28,
          onPressed: () {
            final position = _videoController.value.position + const Duration(seconds: 10);
            final duration = _videoController.value.duration;
            _videoController.seekTo(position > duration ? duration : position);
          },
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 24,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.white),
        iconSize: size,
        padding: const EdgeInsets.all(12),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ColorScheme colorScheme, Color accentColor) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            _buildControlButton(
              icon: Icons.arrow_back,
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        style: TextStyle(color: accentColor, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
            // 循环模式指示器
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isSeamlessLoop
                    ? accentColor.withOpacity(0.9)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: _isSeamlessLoop
                    ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                    : null,
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
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildControlButton(
              icon: _isLocked ? FluentIcons.lock_closed_24_filled : FluentIcons.lock_open_24_regular,
              onPressed: () => setState(() => _isLocked = !_isLocked),
            ),
            _buildControlButton(
              icon: FluentIcons.settings_24_regular,
              onPressed: () => _showSettingsSheet(context, accentColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, ColorScheme colorScheme, Color accentColor) {
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
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Expanded(
                  child: Container(
                    height: 28,
                    alignment: Alignment.center,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: accentColor,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: accentColor.withOpacity(0.3),
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
                ),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                // 播放速度
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            // 底部按钮栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: _isLocked ? FluentIcons.lock_closed_24_filled : FluentIcons.lock_open_24_regular,
                  onPressed: () => setState(() => _isLocked = !_isLocked),
                ),
                _buildControlButton(
                  icon: _subtitles.isNotEmpty
                      ? (_showSubtitle ? FluentIcons.closed_caption_24_filled : FluentIcons.closed_caption_24_regular)
                      : FluentIcons.closed_caption_off_24_regular,
                  color: _subtitles.isNotEmpty ? Colors.white : Colors.white38,
                  onPressed: _subtitles.isNotEmpty
                      ? () => setState(() => _showSubtitle = !_showSubtitle)
                      : _loadSubtitle,
                ),
                _buildControlButton(
                  icon: _isMuted ? FluentIcons.speaker_mute_24_filled : FluentIcons.speaker_2_24_filled,
                  onPressed: () {
                    setState(() {
                      _isMuted = !_isMuted;
                      _videoController.setVolume(_isMuted ? 0 : _volume);
                    });
                  },
                ),
                _buildControlButton(
                  icon: FluentIcons.full_screen_maximize_24_regular,
                  onPressed: _showAspectRatioDialog,
                ),
                _buildControlButton(
                  icon: FluentIcons.full_screen_maximize_24_regular,
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedOverlay(Color accentColor) {
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _isLocked = false),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(FluentIcons.lock_closed_24_filled, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 12),
              const Text('屏幕已锁定', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('点击解锁', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
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
    setState(() => _isPlaying = !_isPlaying);
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
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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

  void _showSettingsSheet(BuildContext context, Color accentColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            children: [
              // 拖动条
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // 标题
              Text(
                '播放设置',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accentColor),
              ),
              const SizedBox(height: 24),
              
              // 播放速度
              _buildSettingSection(
                title: '播放速度',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
                    final isSelected = _playbackSpeed == speed;
                    return GestureDetector(
                      onTap: () {
                        _videoController.setPlaybackSpeed(speed);
                        setState(() => _playbackSpeed = speed);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? accentColor : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected ? null : Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '${speed}x',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 无感循环
              _buildSettingSwitch(
                title: '无感循环',
                subtitle: '视频循环时无黑屏闪烁',
                value: _isSeamlessLoop,
                onChanged: (value) {
                  setState(() => _isSeamlessLoop = value);
                  if (value) {
                    _startLoopDetection();
                  } else {
                    _loopTimer?.cancel();
                  }
                },
                accentColor: accentColor,
              ),
              
              const SizedBox(height: 24),
              
              // 睡眠定时
              _buildSettingSection(
                title: '睡眠定时',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    {'label': '关闭', 'value': null},
                    {'label': '15分钟', 'value': 15},
                    {'label': '30分钟', 'value': 30},
                    {'label': '60分钟', 'value': 60},
                  ].map((item) {
                    final isSelected = _sleepMinutes == item['value'];
                    return GestureDetector(
                      onTap: () => _setSleepTimer(item['value'] as int?),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? accentColor : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected ? null : Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          item['label'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 字幕设置
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(FluentIcons.closed_caption_24_regular, color: accentColor),
                ),
                title: const Text('加载字幕', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  _subtitlePath ?? '支持 SRT 格式',
                  style: TextStyle(color: Colors.white54),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  Navigator.pop(context);
                  _loadSubtitle();
                },
              ),
              
              if (_subtitles.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSettingSection(
                  title: '字幕位置',
                  child: Column(
                    children: [
                      Slider(
                        value: _subtitlePosition,
                        min: 0.1,
                        max: 0.9,
                        activeColor: accentColor,
                        onChanged: (value) {
                          setState(() => _subtitlePosition = value);
                        },
                      ),
                      Text(
                        _subtitlePosition < 0.4 ? '顶部' : _subtitlePosition > 0.7 ? '底部' : '中间',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingSection(
                  title: '字幕大小',
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _subtitleFontSize,
                          min: 12,
                          max: 32,
                          activeColor: accentColor,
                          onChanged: (value) {
                            setState(() => _subtitleFontSize = value);
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_subtitleFontSize.toInt()}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingSection(
                  title: '字幕颜色',
                  child: Wrap(
                    spacing: 12,
                    children: [
                      Colors.white,
                      Colors.yellow,
                      Colors.cyan,
                      Colors.green,
                      Colors.pink,
                      Colors.orange,
                    ].map((color) => GestureDetector(
                      onTap: () => setState(() => _subtitleColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: _subtitleColor == color
                              ? Border.all(color: accentColor, width: 3)
                              : null,
                          boxShadow: [
                            BoxShadow(color: color.withOpacity(0.4), blurRadius: 8),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ],
              
              // 自动取色
              if (_paletteColors.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSettingSection(
                  title: '视频配色',
                  subtitle: '从视频中提取的颜色',
                  child: Wrap(
                    spacing: 12,
                    children: _paletteColors.map((color) => GestureDetector(
                      onTap: () {
                        setState(() => _dominantColor = color);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: _dominantColor == color
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: [
                            BoxShadow(color: color.withOpacity(0.5), blurRadius: 8),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ],
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingSection({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildSettingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.white54)),
        value: value,
        onChanged: onChanged,
        activeColor: accentColor,
        activeTrackColor: accentColor.withOpacity(0.5),
      ),
    );
  }
}

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
