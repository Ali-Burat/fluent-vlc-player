import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';

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
  late VlcPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _isMuted = false;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  bool _isLooping = true;
  bool _isSeamlessLoop = true;
  Timer? _hideControlsTimer;
  Timer? _positionTimer;

  // 无感循环相关
  static const int _loopPreloadMs = 500; // 提前500ms准备循环
  bool _isPreparingLoop = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _startHideControlsTimer();
  }

  Future<void> _initializePlayer() async {
    _controller = VlcPlayerController.network(
      widget.videoPath,
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

    _controller.addListener(_onPlayerStateChanged);
    
    // 设置循环模式
    await _controller.setLooping(_isSeamlessLoop);

    setState(() {
      _isInitialized = true;
    });

    _startPositionTimer();
  }

  void _onPlayerStateChanged() {
    if (!mounted) return;

    // 无感循环处理
    if (_isSeamlessLoop && _controller.value.isEnded) {
      _handleSeamlessLoop();
    }

    setState(() {});
  }

  /// 无感循环处理
  Future<void> _handleSeamlessLoop() async {
    if (_isPreparingLoop) return;
    _isPreparingLoop = true;

    try {
      // 立即跳转到开头并播放
      await _controller.seekTo(Duration.zero);
      await _controller.play();
    } finally {
      _isPreparingLoop = false;
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;

      final position = _controller.value.position;
      final duration = _controller.value.duration;

      // 无感循环预检测
      if (_isSeamlessLoop && duration.inMilliseconds > 0) {
        final remainingMs = duration.inMilliseconds - position.inMilliseconds;
        if (remainingMs < _loopPreloadMs && remainingMs > 0 && !_isPreparingLoop) {
          _handleSeamlessLoop();
        }
      }

      setState(() {});
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (_controller.value.isPlaying && mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  Future<void> _togglePlayPause() async {
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
    setState(() {});
  }

  Future<void> _seekTo(Duration position) async {
    await _controller.seekTo(position);
    setState(() {});
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    await _controller.setSpeed(speed);
    setState(() {
      _playbackSpeed = speed;
    });
  }

  Future<void> _toggleMute() async {
    if (_isMuted) {
      await _controller.setVolume((_volume * 100).toInt());
    } else {
      await _controller.setVolume(0);
    }
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  Future<void> _setVolume(double volume) async {
    await _controller.setVolume((volume * 100).toInt());
    setState(() {
      _volume = volume;
      _isMuted = volume == 0;
    });
  }

  Future<void> _toggleLoopMode() async {
    setState(() {
      _isSeamlessLoop = !_isSeamlessLoop;
    });
    await _controller.setLooping(_isSeamlessLoop);
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
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
    _hideControlsTimer?.cancel();
    _positionTimer?.cancel();
    _controller.removeListener(_onPlayerStateChanged);
    _controller.dispose();
    
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 视频播放器
          GestureDetector(
            onTap: _toggleControls,
            onDoubleTap: _togglePlayPause,
            child: Center(
              child: _isInitialized
                  ? VlcPlayer(
                      controller: _controller,
                      aspectRatio: 16 / 9,
                      placeholder: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
            ),
          ),

          // 控制层
          if (_showControls) _buildControlsOverlay(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay(BuildContext context, ColorScheme colorScheme) {
    return Container(
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
          stops: const [0, 0.2, 0.8, 1],
        ),
      ),
      child: Column(
        children: [
          _buildTopBar(context, colorScheme),
          const Spacer(),
          _buildCenterControls(context, colorScheme),
          const Spacer(),
          _buildBottomControls(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
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
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 循环模式指示器
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingS,
                vertical: AppTheme.spacingXS,
              ),
              decoration: BoxDecoration(
                color: _isSeamlessLoop
                    ? colorScheme.primary.withOpacity(0.8)
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSeamlessLoop
                        ? FluentIcons.arrow_sync_24_filled
                        : FluentIcons.arrow_sync_24_regular,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isSeamlessLoop ? '无感循环' : '单次播放',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            IconButton(
              icon: Icon(
                _isFullscreen
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                color: Colors.white,
              ),
              onPressed: _toggleFullscreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls(BuildContext context, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 快退
        IconButton(
          icon: const Icon(
            FluentIcons.rewind_24_filled,
            color: Colors.white,
            size: 32,
          ),
          onPressed: () async {
            final newPosition = _controller.value.position - const Duration(seconds: 10);
            await _seekTo(newPosition.isNegative ? Duration.zero : newPosition);
          },
        ),
        const SizedBox(width: AppTheme.spacingL),
        // 播放/暂停
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              _controller.value.isPlaying
                  ? FluentIcons.pause_24_filled
                  : FluentIcons.play_24_filled,
              color: Colors.white,
              size: 36,
            ),
            onPressed: _togglePlayPause,
          ),
        ),
        const SizedBox(width: AppTheme.spacingL),
        // 快进
        IconButton(
          icon: const Icon(
            FluentIcons.fast_forward_24_filled,
            color: Colors.white,
            size: 32,
          ),
          onPressed: () async {
            final newPosition = _controller.value.position + const Duration(seconds: 10);
            final duration = _controller.value.duration;
            await _seekTo(newPosition > duration ? duration : newPosition);
          },
        ),
      ],
    );
  }

  Widget _buildBottomControls(BuildContext context, ColorScheme colorScheme) {
    final position = _controller.value.position;
    final duration = _controller.value.duration;

    return SafeArea(
      child: Padding(
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
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor: Colors.white.withOpacity(0.3),
                      thumbColor: colorScheme.primary,
                      overlayColor: colorScheme.primary.withOpacity(0.3),
                    ),
                    child: Slider(
                      value: duration.inMilliseconds > 0
                          ? position.inMilliseconds.toDouble()
                          : 0,
                      min: 0,
                      max: duration.inMilliseconds > 0
                          ? duration.inMilliseconds.toDouble()
                          : 1,
                      onChanged: (value) async {
                        await _seekTo(Duration(milliseconds: value.toInt()));
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
            const SizedBox(height: AppTheme.spacingS),
            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 音量
                _buildControlButton(
                  icon: _isMuted
                      ? FluentIcons.speaker_mute_24_filled
                      : FluentIcons.speaker_2_24_filled,
                  label: '音量',
                  onTap: _toggleMute,
                  child: SizedBox(
                    width: 100,
                    child: Slider(
                      value: _isMuted ? 0 : _volume,
                      onChanged: _setVolume,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
                // 播放速度
                _buildControlButton(
                  icon: FluentIcons.top_speed_24_regular,
                  label: '${_playbackSpeed}x',
                  onTap: () => _showSpeedDialog(context),
                ),
                // 循环模式
                _buildControlButton(
                  icon: _isSeamlessLoop
                      ? FluentIcons.arrow_sync_24_filled
                      : FluentIcons.arrow_sync_24_regular,
                  label: '循环',
                  onTap: _toggleLoopMode,
                  isActive: _isSeamlessLoop,
                ),
                // 画面比例
                _buildControlButton(
                  icon: FluentIcons.aspect_ratio_24_regular,
                  label: '比例',
                  onTap: () {
                    // 切换画面比例
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? child,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingS,
          vertical: AppTheme.spacingXS,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.blue : Colors.white,
              size: 24,
            ),
            if (child != null) child,
            if (child == null)
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.blue : Colors.white,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSpeedDialog(BuildContext context) {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '播放速度',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Wrap(
              spacing: AppTheme.spacingS,
              children: speeds.map((speed) {
                final isSelected = speed == _playbackSpeed;
                return ChoiceChip(
                  label: Text('${speed}x'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      _setPlaybackSpeed(speed);
                      Navigator.pop(context);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
