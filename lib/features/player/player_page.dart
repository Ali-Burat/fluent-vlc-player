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

/// 播放器页面
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
  
  // 双字幕
  SubtitleTrack _subtitle1 = SubtitleTrack();
  SubtitleTrack _subtitle2 = SubtitleTrack();
  bool _showSubtitle1 = true;
  bool _showSubtitle2 = false;
  
  // 手势控制
  bool _isSeeking = false;
  bool _isAdjustingVolume = false;
  bool _isAdjustingBrightness = false;
  double _seekDelta = 0;
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

      if (_isSeamlessLoop) _startLoopDetection();
      if (settings.rememberPosition) _startPositionSaving();

      setState(() => _isInitialized = true);
      
      _videoController.play();
      setState(() => _isPlaying = true);
      _startControlsHideTimer();
      
      _extractVideoColors();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('无法播放: $e')));
      }
    }
  }

  Future<void> _extractVideoColors() async {
    try {
      final duration = _videoController.value.duration;
      await _videoController.seekTo(Duration(milliseconds: duration.inMilliseconds ~/ 2));
      await Future.delayed(const Duration(milliseconds: 100));
      
      final image = await _videoController.value.image;
      if (image != null) {
        final colors = await _extractColorsFromImage(image);
        if (mounted) {
          setState(() {
            _paletteColors = colors;
            _dominantColor = colors.isNotEmpty ? colors[0] : null;
          });
        }
      }
      await _videoController.seekTo(Duration.zero);
    } catch (e) {
      debugPrint('提取颜色失败: $e');
    }
  }

  Future<List<Color>> _extractColorsFromImage(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return [];
    
    final pixels = byteData.buffer.asUint8List();
    final Map<int, int> colorCounts = {};
    
    for (int i = 0; i < pixels.length; i += 32) {
      if (i + 3 < pixels.length) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        final a = pixels[i + 3];
        
        if (a > 128) {
          final qr = (r ~/ 32) * 32;
          final qg = (g ~/ 32) * 32;
          final qb = (b ~/ 32) * 32;
          final colorValue = (qr << 16) | (qg << 8) | qb;
          colorCounts[colorValue] = (colorCounts[colorValue] ?? 0) + 1;
        }
      }
    }
    
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
      if (_isSeamlessLoop && !_isPreparingLoop) _handleSeamlessLoop();
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
      if (mounted && _isPlaying && !_isLocked) setState(() => _showControls = false);
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
      Future.delayed(const Duration(milliseconds: 200), () => _isPreparingLoop = false);
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

  Future<void> _loadSubtitle(int trackIndex) async {
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
          if (trackIndex == 1) {
            _subtitle1 = _subtitle1.copyWith(subtitles: subtitles, path: result.files.first.path);
            _showSubtitle1 = true;
          } else {
            _subtitle2 = _subtitle2.copyWith(subtitles: subtitles, path: result.files.first.path);
            _showSubtitle2 = true;
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('字幕${trackIndex}加载成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
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
            final times = lines[1].split(' --> ');
            if (times.length == 2) {
              entries.add(SubtitleEntry(
                startTime: _parseSrtTime(times[0]),
                endTime: _parseSrtTime(times[1]),
                text: lines.sublist(2).join('\n'),
              ));
            }
          } catch (e) {}
        }
      }
    }
    return entries;
  }

  Duration _parseSrtTime(String time) {
    final parts = time.trim().split(':');
    final secondParts = parts[2].split(',');
    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
      seconds: int.parse(secondParts[0]),
      milliseconds: int.parse(secondParts[1]),
    );
  }

  void _setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    setState(() => _sleepMinutes = minutes);
    
    if (minutes != null) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        _videoController.pause();
        setState(() { _isPlaying = false; _sleepMinutes = null; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('睡眠定时结束')));
        }
      });
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}'
                  : '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _positionSaveTimer?.cancel();
    _progressTimer?.cancel();
    _controlsHideTimer?.cancel();
    _sleepTimer?.cancel();
    _videoController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = _dominantColor ?? colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _isInitialized ? _buildVideo() : const CircularProgressIndicator(strokeWidth: 2),
          ),
          if (_isInitialized) ...[
            _buildSubtitles(),
            _buildGestureLayer(),
            if (_showControls && !_isLocked) _buildControls(accentColor),
            if (_isLocked) _buildLockedOverlay(accentColor),
          ],
        ],
      ),
    );
  }

  Widget _buildVideo() {
    Widget video = VideoPlayer(_videoController);
    switch (_aspectRatio) {
      case 'fill':
        return SizedBox(width: double.infinity, height: double.infinity, child: FittedBox(fit: BoxFit.cover, child: video));
      case '16:9':
        return AspectRatio(aspectRatio: 16 / 9, child: video);
      case '4:3':
        return AspectRatio(aspectRatio: 4 / 3, child: video);
      default:
        return AspectRatio(aspectRatio: _videoController.value.aspectRatio, child: video);
    }
  }

  Widget _buildSubtitles() {
    final position = _videoController.value.position;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Stack(
      children: [
        // 字幕1
        if (_showSubtitle1 && _subtitle1.subtitles.isNotEmpty)
          Positioned(
            left: 16, right: 16,
            top: screenHeight * _subtitle1.position,
            child: _buildSubtitleText(_subtitle1, position),
          ),
        // 字幕2
        if (_showSubtitle2 && _subtitle2.subtitles.isNotEmpty)
          Positioned(
            left: 16, right: 16,
            top: screenHeight * _subtitle2.position,
            child: _buildSubtitleText(_subtitle2, position),
          ),
      ],
    );
  }

  Widget _buildSubtitleText(SubtitleTrack track, Duration position) {
    String? text;
    for (final e in track.subtitles) {
      if (position >= e.startTime && position <= e.endTime) {
        text = e.text;
        break;
      }
    }
    if (text == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: track.bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: track.color, fontSize: track.fontSize, height: 1.3), textAlign: TextAlign.center),
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
        onDoubleTap: () { if (!_isLocked) _togglePlay(); },
        onHorizontalDragStart: (d) {
          if (!_isLocked) {
            _gestureStartX = d.globalPosition.dx;
            setState(() { _isSeeking = true; _seekDelta = 0; });
          }
        },
        onHorizontalDragUpdate: (d) {
          if (!_isLocked && _isSeeking) {
            final width = MediaQuery.of(context).size.width;
            setState(() { _seekDelta += (d.globalPosition.dx - _gestureStartX) / width * 60000; });
            _gestureStartX = d.globalPosition.dx;
          }
        },
        onHorizontalDragEnd: (d) {
          if (!_isLocked && _isSeeking) {
            _videoController.seekTo(_videoController.value.position + Duration(milliseconds: _seekDelta.toInt()));
            setState(() { _isSeeking = false; _seekDelta = 0; });
          }
        },
        onVerticalDragStart: (d) {
          if (!_isLocked) {
            _gestureStartY = d.globalPosition.dy;
            setState(() => _isAdjustingVolume = d.globalPosition.dx > MediaQuery.of(context).size.width / 2);
          }
        },
        onVerticalDragUpdate: (d) {
          if (!_isLocked) {
            final height = MediaQuery.of(context).size.height;
            final delta = (d.globalPosition.dy - _gestureStartY) / height;
            if (_isAdjustingVolume) {
              setState(() { _volume = (_volume - delta).clamp(0.0, 1.0); });
              _videoController.setVolume(_volume);
            }
            _gestureStartY = d.globalPosition.dy;
          }
        },
        onVerticalDragEnd: (d) => setState(() => _isAdjustingVolume = false),
      ),
    );
  }

  Widget _buildControls(Color accentColor) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.6), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.6)],
            stops: const [0, 0.2, 0.8, 1],
          ),
        ),
        child: Column(
          children: [
            _buildTopBar(accentColor),
            const Spacer(),
            if (_isSeeking) _buildSeekIndicator(),
            if (_isAdjustingVolume) _buildVolumeIndicator(),
            if (!_isSeeking && !_isAdjustingVolume) _buildCenterControls(accentColor),
            const Spacer(),
            _buildBottomBar(accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accentColor) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22), onPressed: () => Navigator.pop(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.videoName, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (_sleepMinutes != null) Text('睡眠: $_sleepMinutes分钟', style: TextStyle(color: accentColor, fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _isSeamlessLoop ? accentColor : Colors.white24, borderRadius: BorderRadius.circular(12)),
              child: Text(_isSeamlessLoop ? '循环' : '单次', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
            IconButton(icon: Icon(_isLocked ? FluentIcons.lock_closed_24_filled : FluentIcons.lock_open_24_regular, color: Colors.white, size: 20),
              onPressed: () => setState(() => _isLocked = !_isLocked)),
            IconButton(icon: const Icon(FluentIcons.settings_24_regular, color: Colors.white, size: 20), onPressed: () => _showSettings(accentColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
      child: Text('${_seekDelta > 0 ? '+' : ''}${(_seekDelta / 1000).toStringAsFixed(1)}秒', style: const TextStyle(color: Colors.white, fontSize: 18)),
    );
  }

  Widget _buildVolumeIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
      child: Text('音量 ${(_volume * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 18)),
    );
  }

  Widget _buildCenterControls(Color accentColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(FluentIcons.rewind_24_filled, color: Colors.white, size: 24),
          onPressed: () => _videoController.seekTo(_videoController.value.position - const Duration(seconds: 10))),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
            child: Icon(_isPlaying ? FluentIcons.pause_24_filled : FluentIcons.play_24_filled, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(width: 24),
        IconButton(icon: const Icon(FluentIcons.fast_forward_24_filled, color: Colors.white, size: 24),
          onPressed: () => _videoController.seekTo(_videoController.value.position + const Duration(seconds: 10))),
      ],
    );
  }

  Widget _buildBottomBar(Color accentColor) {
    final position = _videoController.value.position;
    final duration = _videoController.value.duration;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            Row(
              children: [
                Text(_formatDuration(position), style: const TextStyle(color: Colors.white, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: duration.inMilliseconds > 0 ? position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()) : 0,
                    min: 0, max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1,
                    onChanged: (v) => _videoController.seekTo(Duration(milliseconds: v.toInt())),
                    activeColor: accentColor, inactiveColor: Colors.white24, thumbColor: Colors.white,
                  ),
                ),
                Text(_formatDuration(duration), style: const TextStyle(color: Colors.white, fontSize: 11)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  child: Text('${_playbackSpeed}x', style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ],
            ),
            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(icon: Icon(_isMuted ? FluentIcons.speaker_mute_24_filled : FluentIcons.speaker_2_24_filled, color: Colors.white, size: 20),
                  onPressed: () { setState(() { _isMuted = !_isMuted; _videoController.setVolume(_isMuted ? 0 : _volume); }); }),
                IconButton(icon: Icon(_subtitle1.subtitles.isNotEmpty ? (_showSubtitle1 ? FluentIcons.closed_caption_24_filled : FluentIcons.closed_caption_24_regular) : FluentIcons.closed_caption_off_24_regular, color: Colors.white, size: 20),
                  onPressed: () { if (_subtitle1.subtitles.isNotEmpty) setState(() => _showSubtitle1 = !_showSubtitle1); else _loadSubtitle(1); }),
                IconButton(icon: Icon(_subtitle2.subtitles.isNotEmpty ? (_showSubtitle2 ? FluentIcons.closed_caption_24_filled : FluentIcons.closed_caption_24_regular) : FluentIcons.closed_caption_off_24_regular, color: Colors.white38, size: 20),
                  onPressed: () { if (_subtitle2.subtitles.isNotEmpty) setState(() => _showSubtitle2 = !_showSubtitle2); else _loadSubtitle(2); }),
                IconButton(icon: const Icon(FluentIcons.full_screen_maximize_24_regular, color: Colors.white, size: 20), onPressed: _showAspectRatioDialog),
                IconButton(icon: const Icon(FluentIcons.full_screen_maximize_24_regular, color: Colors.white, size: 20), onPressed: _toggleFullscreen),
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
          child: const Icon(FluentIcons.lock_closed_24_filled, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  void _togglePlay() {
    if (_isPlaying) _videoController.pause(); else _videoController.play();
    setState(() => _isPlaying = !_isPlaying);
    _startControlsHideTimer();
  }

  void _toggleFullscreen() {
    if (MediaQuery.of(context).orientation == Orientation.portrait) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  void _showAspectRatioDialog() {
    showDialog(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('画面比例'),
        children: ['fit', 'fill', '16:9', '4:3'].map((a) => RadioListTile(
          title: Text({'fit': '自适应', 'fill': '填充', '16:9': '16:9', '4:3': '4:3'}[a]!),
          value: a, groupValue: _aspectRatio,
          onChanged: (v) { setState(() => _aspectRatio = v!); Navigator.pop(c); },
        )).toList(),
      ),
    );
  }

  void _showSettings(Color accentColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('设置', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accentColor)),
              const SizedBox(height: 20),
              
              // 播放速度
              const Text('播放速度', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) => ChoiceChip(
                  label: Text('${s}x'),
                  selected: _playbackSpeed == s,
                  selectedColor: accentColor,
                  onSelected: (_) {
                    _videoController.setPlaybackSpeed(s);
                    setState(() => _playbackSpeed = s);
                    setModalState(() {});
                  },
                )).toList(),
              ),
              const SizedBox(height: 16),
              
              // 无感循环
              SwitchListTile(
                title: const Text('无感循环', style: TextStyle(color: Colors.white)),
                subtitle: const Text('视频循环时无黑屏闪烁', style: TextStyle(color: Colors.white54)),
                value: _isSeamlessLoop,
                activeColor: accentColor,
                onChanged: (v) {
                  setState(() => _isSeamlessLoop = v);
                  setModalState(() {});
                  if (v) _startLoopDetection(); else _loopTimer?.cancel();
                },
              ),
              const SizedBox(height: 8),
              
              // 睡眠定时
              const Text('睡眠定时', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  {'label': '关闭', 'value': null},
                  {'label': '15分', 'value': 15},
                  {'label': '30分', 'value': 30},
                  {'label': '60分', 'value': 60},
                ].map((i) => ChoiceChip(
                  label: Text(i['label'] as String),
                  selected: _sleepMinutes == i['value'],
                  selectedColor: accentColor,
                  onSelected: (_) {
                    _setSleepTimer(i['value'] as int?);
                    setModalState(() {});
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),
              
              // 字幕1设置
              _buildSubtitleSection(1, _subtitle1, _showSubtitle1, accentColor, (track, show) {
                setState(() { _subtitle1 = track; _showSubtitle1 = show; });
                setModalState(() {});
              }),
              const SizedBox(height: 16),
              
              // 字幕2设置
              _buildSubtitleSection(2, _subtitle2, _showSubtitle2, accentColor, (track, show) {
                setState(() { _subtitle2 = track; _showSubtitle2 = show; });
                setModalState(() {});
              }),
              
              // 视频配色
              if (_paletteColors.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('视频配色', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: _paletteColors.map((c) => GestureDetector(
                    onTap: () {
                      setState(() => _dominantColor = c);
                      setModalState(() {});
                    },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: c, shape: BoxShape.circle,
                        border: _dominantColor == c ? Border.all(color: Colors.white, width: 2) : null,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleSection(int index, SubtitleTrack track, bool show, Color accentColor, Function(SubtitleTrack, bool) onUpdate) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('字幕$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              const Spacer(),
              if (track.subtitles.isNotEmpty)
                Switch(
                  value: show,
                  activeColor: accentColor,
                  onChanged: (v) => onUpdate(track, v),
                ),
              TextButton(
                onPressed: () => _loadSubtitle(index),
                child: Text(track.subtitles.isEmpty ? '加载' : '更换', style: TextStyle(color: accentColor)),
              ),
            ],
          ),
          if (track.subtitles.isNotEmpty) ...[
            const SizedBox(height: 12),
            // 位置
            Row(
              children: [
                const Text('位置', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: track.position, min: 0.1, max: 0.9,
                    activeColor: accentColor,
                    onChanged: (v) => onUpdate(track.copyWith(position: v), show),
                  ),
                ),
                Text(track.position < 0.4 ? '上' : track.position > 0.7 ? '下' : '中', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            // 大小
            Row(
              children: [
                const Text('大小', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: track.fontSize, min: 12, max: 28,
                    activeColor: accentColor,
                    onChanged: (v) => onUpdate(track.copyWith(fontSize: v), show),
                  ),
                ),
                Text('${track.fontSize.toInt()}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            // 颜色
            const Text('颜色', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [Colors.white, Colors.yellow, Colors.cyan, Colors.green, Colors.pink].map((c) => GestureDetector(
                onTap: () => onUpdate(track.copyWith(color: c), show),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: c, shape: BoxShape.circle,
                    border: track.color == c ? Border.all(color: accentColor, width: 2) : null,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class SubtitleTrack {
  final List<SubtitleEntry> subtitles;
  final String? path;
  final double fontSize;
  final double position;
  final Color color;
  final Color bgColor;

  const SubtitleTrack({
    this.subtitles = const [],
    this.path,
    this.fontSize = 16,
    this.position = 0.85,
    this.color = Colors.white,
    this.bgColor = Colors.black54,
  });

  SubtitleTrack copyWith({List<SubtitleEntry>? subtitles, String? path, double? fontSize, double? position, Color? color, Color? bgColor}) {
    return SubtitleTrack(
      subtitles: subtitles ?? this.subtitles,
      path: path ?? this.path,
      fontSize: fontSize ?? this.fontSize,
      position: position ?? this.position,
      color: color ?? this.color,
      bgColor: bgColor ?? this.bgColor,
    );
  }
}

class SubtitleEntry {
  final Duration startTime;
  final Duration endTime;
  final String text;
  const SubtitleEntry({required this.startTime, required this.endTime, required this.text});
}
