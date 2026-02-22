import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';

class PlayerPage extends StatefulWidget {
  final String videoPath;
  final String videoName;
  final String? videoId;
  final List<VideoItem>? playlist;
  final int? currentIndex;
  
  const PlayerPage({
    super.key, 
    required this.videoPath, 
    required this.videoName, 
    this.videoId,
    this.playlist,
    this.currentIndex,
  });
  
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with TickerProviderStateMixin {
  late VideoPlayerController _vc;
  bool _init = false, _playing = false, _loop = true, _showCtrl = true, _locked = false;
  double _speed = 1.0, _volume = 0.6, _brightness = 0.5;
  String _aspect = 'fit';
  bool _landscape = false;
  
  // 双字幕
  SubtitleTrack _sub1 = SubtitleTrack(), _sub2 = SubtitleTrack();
  bool _showSub1 = true, _showSub2 = false;
  
  // 手势 - 只在调整时显示
  bool _seeking = false, _volAdj = false, _brightAdj = false;
  double _seekDelta = 0;
  double _gestureStartY = 0;
  
  // 睡眠
  int? _sleepMin;
  Timer? _sleepTimer, _hideTimer, _loopTimer, _posTimer, _progTimer;
  static const int _preload = 800;
  bool _prepLoop = false;
  
  // 选集菜单
  bool _showPlaylist = false;
  String? _thumbnailPath;

  @override
  void initState() { super.initState(); _initPlayer(); }

  Future<void> _initPlayer() async {
    final s = context.read<SettingsService>();
    _loop = s.seamlessLoop; _speed = s.playbackSpeed;
    _vc = widget.videoPath.startsWith('http') 
        ? VideoPlayerController.networkUrl(Uri.parse(widget.videoPath)) 
        : VideoPlayerController.file(File(widget.videoPath));
    await _vc.initialize();
    
    if (s.rememberPosition && widget.videoId != null) {
      final p = s.getPlayPosition(widget.videoId!);
      if (p != null && p > 0) await _vc.seekTo(Duration(milliseconds: p));
    }
    
    await _vc.setPlaybackSpeed(_speed);
    await _vc.setVolume(_volume);
    _vc.addListener(() { if (_vc.value.position >= _vc.value.duration && _loop && !_prepLoop) _doLoop(); });
    _startProg();
    if (_loop) _startLoop();
    if (s.rememberPosition) _startPos();
    
    // 自动加载相似字幕
    await _autoLoadSubtitles();
    
    setState(() => _init = true);
    _vc.play(); 
    setState(() => _playing = true);
    _startHide();
  }

  /// 自动加载相似名称的字幕文件
  Future<void> _autoLoadSubtitles() async {
    if (widget.videoPath.startsWith('http')) return;
    try {
      final videoFile = File(widget.videoPath);
      final dir = videoFile.parent;
      final baseName = p.basenameWithoutExtension(widget.videoPath).toLowerCase();
      final extensions = ['.srt', '.ass', '.ssa', '.vtt'];
      
      List<File> matchedSubs = [];
      
      await for (final entity in dir.list()) {
        if (entity is File) {
          final fileName = p.basenameWithoutExtension(entity.path).toLowerCase();
          final ext = p.extension(entity.path).toLowerCase();
          
          // 检查是否是字幕文件
          if (extensions.contains(ext)) {
            // 检查文件名是否相似（包含视频文件名或视频文件名包含字幕文件名）
            if (fileName.contains(baseName) || baseName.contains(fileName) || 
                _calculateSimilarity(fileName, baseName) > 0.6) {
              matchedSubs.add(entity);
            }
          }
        }
      }
      
      // 加载找到的字幕
      if (matchedSubs.isNotEmpty) {
        final content1 = await matchedSubs[0].readAsString();
        final subs1 = _parseSrt(content1);
        if (subs1.isNotEmpty) {
          setState(() { 
            _sub1 = SubtitleTrack(subtitles: subs1, path: matchedSubs[0].path); 
            _showSub1 = true; 
          });
        }
        
        if (matchedSubs.length > 1) {
          final content2 = await matchedSubs[1].readAsString();
          final subs2 = _parseSrt(content2);
          if (subs2.isNotEmpty) {
            setState(() { 
              _sub2 = SubtitleTrack(subtitles: subs2, path: matchedSubs[1].path); 
              _showSub2 = true; 
            });
          }
        }
      }
    } catch (e) { debugPrint('自动加载字幕失败: $e'); }
  }
  
  /// 计算字符串相似度
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    int matches = 0;
    final shorter = s1.length < s2.length ? s1 : s2;
    final longer = s1.length < s2.length ? s2 : s1;
    
    for (int i = 0; i < shorter.length; i++) {
      if (longer.contains(shorter.substring(i, i + 1))) {
        matches++;
      }
    }
    
    return matches / longer.length;
  }

  void _startProg() { _progTimer?.cancel(); _progTimer = Timer.periodic(const Duration(milliseconds: 100), (_) { if (mounted) setState(() {}); }); }
  void _startHide() { _hideTimer?.cancel(); _hideTimer = Timer(const Duration(seconds: 5), () { if (mounted && _playing && !_locked) setState(() => _showCtrl = false); }); }
  void _startLoop() { _loopTimer?.cancel(); _loopTimer = Timer.periodic(const Duration(milliseconds: 50), (_) { if (!mounted || !_loop || !_vc.value.isPlaying) return; final rem = _vc.value.duration.inMilliseconds - _vc.value.position.inMilliseconds; if (rem < _preload && rem > 0 && !_prepLoop) _doLoop(); }); }
  void _startPos() { _posTimer?.cancel(); _posTimer = Timer.periodic(const Duration(seconds: 2), (_) { if (!mounted || widget.videoId == null) return; context.read<SettingsService>().savePlayPosition(widget.videoId!, _vc.value.position.inMilliseconds); }); }
  
  Future<void> _doLoop() async {
    if (!_loop || _prepLoop) return;
    _prepLoop = true;
    try { await _vc.seekTo(Duration.zero); if (!_vc.value.isPlaying) await _vc.play(); }
    finally { Future.delayed(const Duration(milliseconds: 200), () => _prepLoop = false); }
  }

  Future<void> _loadSub(int idx) async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['srt', 'ass', 'vtt']);
      if (r != null && r.files.isNotEmpty) {
        final f = File(r.files.first.path!);
        final c = await f.readAsString();
        final subs = _parseSrt(c);
        setState(() {
          if (idx == 1) { _sub1 = SubtitleTrack(subtitles: subs, path: r.files.first.path); _showSub1 = true; }
          else { _sub2 = SubtitleTrack(subtitles: subs, path: r.files.first.path); _showSub2 = true; }
        });
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e'))); }
  }

  List<SubtitleEntry> _parseSrt(String c) {
    final List<SubtitleEntry> e = [];
    for (final b in c.split('\n\n')) {
      final l = b.split('\n');
      if (l.length >= 3) {
        try {
          final t = l[1].split(' --> ');
          if (t.length == 2) e.add(SubtitleEntry(start: _parseT(t[0]), end: _parseT(t[1]), text: l.sublist(2).join('\n')));
        } catch (_) {}
      }
    }
    return e;
  }

  Duration _parseT(String t) {
    final p = t.trim().split(':');
    final s = p[2].split(',');
    return Duration(hours: int.parse(p[0]), minutes: int.parse(p[1]), seconds: int.parse(s[0]), milliseconds: int.parse(s[1]));
  }

  void _setSleep(int? m) { _sleepTimer?.cancel(); setState(() => _sleepMin = m); if (m != null) _sleepTimer = Timer(Duration(minutes: m), () { _vc.pause(); setState(() { _playing = false; _sleepMin = null; }); }); }
  
  String _fmt(Duration d) { final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60); return h > 0 ? '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}' : '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}'; }

  @override
  void dispose() { 
    _sleepTimer?.cancel(); _hideTimer?.cancel(); _loopTimer?.cancel(); _posTimer?.cancel(); _progTimer?.cancel(); 
    _vc.dispose(); 
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); 
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(children: [
        // 视频
        Center(child: _init ? _buildVideo() : const CircularProgressIndicator(strokeWidth: 2)),
        // 字幕
        if (_init) _buildSubs(),
        // 手势层
        if (_init) _buildGesture(),
        // 控件
        if (_init && _showCtrl && !_locked) _buildControls(cs),
        // 锁定
        if (_locked) _buildLock(),
        // 选集菜单
        if (_showPlaylist && widget.playlist != null) _buildPlaylistMenu(cs),
      ]),
    );
  }

  Widget _buildVideo() {
    Widget v = VideoPlayer(_vc);
    switch (_aspect) {
      case 'fill': return SizedBox(width: double.infinity, height: double.infinity, child: FittedBox(fit: BoxFit.cover, child: v));
      case '16:9': return AspectRatio(aspectRatio: 16 / 9, child: v);
      case '4:3': return AspectRatio(aspectRatio: 4 / 3, child: v);
      default: return AspectRatio(aspectRatio: _vc.value.aspectRatio, child: v);
    }
  }

  Widget _buildSubs() {
    final pos = _vc.value.position;
    final h = MediaQuery.of(context).size.height;
    return Stack(children: [
      if (_showSub1 && _sub1.subtitles.isNotEmpty) Positioned(left: 16, right: 16, top: h * _sub1.position, child: _subText(_sub1, pos)),
      if (_showSub2 && _sub2.subtitles.isNotEmpty) Positioned(left: 16, right: 16, top: h * _sub2.position, child: _subText(_sub2, pos)),
    ]);
  }

  /// 字幕显示 - 背景只包裹内容
  Widget _subText(SubtitleTrack t, Duration pos) {
    String? txt; 
    for (final e in t.subtitles) { 
      if (pos >= e.start && pos <= e.end) { 
        txt = e.text; 
        break; 
      } 
    }
    if (txt == null) return const SizedBox.shrink();
    
    return Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.bgColor.withOpacity(t.bgOpacity),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        txt, 
        style: TextStyle(
          color: t.color, 
          fontSize: t.fontSize, 
          height: 1.3,
          // 外层描边效果
          shadows: t.strokeColor != null 
            ? [
              Shadow(color: t.strokeColor!, offset: const Offset(-1, -1), blurRadius: 0),
              Shadow(color: t.strokeColor!, offset: const Offset(1, -1), blurRadius: 0),
              Shadow(color: t.strokeColor!, offset: const Offset(-1, 1), blurRadius: 0),
              Shadow(color: t.strokeColor!, offset: const Offset(1, 1), blurRadius: 0),
            ]
            : null,
        ), 
        textAlign: TextAlign.center
      ),
    ));
  }

  Widget _buildGesture() {
    return Positioned.fill(child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () { 
        if (_locked) { setState(() => _locked = false); }
        else { setState(() => _showCtrl = !_showCtrl); if (_showCtrl) _startHide(); }
      },
      onDoubleTap: () { if (!_locked) _togglePlay(); },
      onHorizontalDragStart: (_) { if (!_locked) setState(() { _seeking = true; _seekDelta = 0; }); },
      onHorizontalDragUpdate: (d) { if (!_locked && _seeking) setState(() { _seekDelta += d.primaryDelta! / MediaQuery.of(context).size.width * 60000; }); },
      onHorizontalDragEnd: (_) { if (!_locked && _seeking) { _vc.seekTo(_vc.value.position + Duration(milliseconds: _seekDelta.toInt())); setState(() { _seeking = false; _seekDelta = 0; }); } },
      onVerticalDragStart: (d) { 
        if (!_locked) {
          _gestureStartY = d.globalPosition.dy;
          final w = MediaQuery.of(context).size.width;
          setState(() {
            _brightAdj = d.globalPosition.dx < w * 0.4;
            _volAdj = d.globalPosition.dx > w * 0.6;
          });
        }
      },
      onVerticalDragUpdate: (d) {
        if (!_locked) {
          final h = MediaQuery.of(context).size.height;
          final delta = (d.globalPosition.dy - _gestureStartY) / h;
          if (_volAdj) {
            setState(() { _volume = (_volume - delta).clamp(0.0, 1.0); });
            _vc.setVolume(_volume);
          } else if (_brightAdj) {
            setState(() { _brightness = (_brightness - delta).clamp(0.0, 1.0); });
          }
          _gestureStartY = d.globalPosition.dy;
        }
      },
      onVerticalDragEnd: (_) => setState(() { _volAdj = false; _brightAdj = false; }),
    ));
  }

  Widget _buildControls(ColorScheme cs) {
    final size = MediaQuery.of(context).size;
    
    return Stack(children: [
      // 顶部渐变
      Positioned(top: 0, left: 0, right: 0, height: size.height * 0.12,
        child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent])))),
      
      // 底部渐变
      Positioned(bottom: 0, left: 0, right: 0, height: size.height * 0.18,
        child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])))),
      
      // 顶部栏
      Positioned(top: 0, left: 0, right: 0, child: _buildTopBar(cs, size)),
      
      // 左侧亮度条 - 只在调整时显示
      if (_brightAdj) Positioned(left: size.width * 0.08, top: size.height * 0.35, child: _buildAdjustIndicator(cs, _brightness, FluentIcons.brightness_high_24_regular, '亮度')),
      
      // 右侧音量条 - 只在调整时显示
      if (_volAdj) Positioned(right: size.width * 0.08, top: size.height * 0.35, child: _buildAdjustIndicator(cs, _volume, FluentIcons.speaker_2_24_regular, '音量')),
      
      // 中央快进快退提示
      if (_seeking) Positioned.fill(child: Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12)),
        child: Text('${_seekDelta > 0 ? '快进' : '快退'} ${(_seekDelta.abs() / 1000).toStringAsFixed(1)}秒', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
      ))),
      
      // 底部控制栏
      Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar(cs, size)),
    ]);
  }

  /// 调整指示器 - 更大更清晰
  Widget _buildAdjustIndicator(ColorScheme cs, double value, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          // 进度条
          Container(
            width: 6, height: 120,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)),
            child: Stack(alignment: Alignment.bottomCenter, children: [
              Container(
                height: 120 * value,
                decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(3)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Text('${(value * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs, Size size) {
    return SafeArea(child: Container(
      height: size.height * 0.1,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        // 返回
        GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22)),
        const SizedBox(width: 8),
        // 标题
        Expanded(child: Text(widget.videoName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        // 循环标签
        GestureDetector(
          onTap: () => setState(() => _loop = !_loop),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _loop ? cs.primary : Colors.white24, borderRadius: BorderRadius.circular(14)),
            child: Text(_loop ? '循环' : '单次', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(width: 8),
        // CC字幕
        IconButton(icon: Icon(_sub1.subtitles.isNotEmpty ? (_showSub1 ? FluentIcons.closed_caption_24_filled : FluentIcons.closed_caption_24_regular) : FluentIcons.closed_caption_off_24_regular, color: Colors.white, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: () { if (_sub1.subtitles.isNotEmpty) setState(() => _showSub1 = !_showSub1); else _loadSub(1); }),
        // 旋转
        IconButton(icon: const Icon(FluentIcons.phone_tablet_24_regular, color: Colors.white, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: _toggleRotation),
        // 锁定
        IconButton(icon: Icon(_locked ? FluentIcons.lock_closed_24_filled : FluentIcons.lock_open_24_regular, color: Colors.white, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: () => setState(() => _locked = !_locked)),
        // 设置
        IconButton(icon: const Icon(FluentIcons.options_24_regular, color: Colors.white, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: _showSettings),
      ]),
    ));
  }

  Widget _buildBottomBar(ColorScheme cs, Size size) {
    final pos = _vc.value.position, dur = _vc.value.duration;
    final hasPlaylist = widget.playlist != null && widget.playlist!.length > 1;
    
    return SafeArea(child: Container(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 进度条
        Row(children: [
          SizedBox(width: 50, child: Text(_fmt(pos), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(child: SliderTheme(
            data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5), overlayShape: const RoundSliderOverlayShape(overlayRadius: 10)),
            child: Slider(value: dur.inMilliseconds > 0 ? pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble()) : 0, min: 0, max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1, onChanged: (v) => _vc.seekTo(Duration(milliseconds: v.toInt())), activeColor: cs.primary, inactiveColor: Colors.white24, thumbColor: Colors.white),
          )),
          SizedBox(width: 50, child: Text(_fmt(dur), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
        ]),
        
        const SizedBox(height: 8),
        
        // 控制按钮组
        Row(children: [
          // 左侧：播放控制
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              // 快退
              IconButton(icon: const Icon(FluentIcons.previous_24_filled, color: Colors.white, size: 26), onPressed: () => _vc.seekTo(_vc.value.position - const Duration(seconds: 10))),
              const SizedBox(width: 20),
              // 播放/暂停（无背景）
              GestureDetector(onTap: _togglePlay, child: Icon(_playing ? FluentIcons.pause_24_filled : FluentIcons.play_24_filled, color: Colors.white, size: 40)),
              const SizedBox(width: 20),
              // 快进
              IconButton(icon: const Icon(FluentIcons.next_24_filled, color: Colors.white, size: 26), onPressed: () => _vc.seekTo(_vc.value.position + const Duration(seconds: 10))),
            ]),
          ),
          
          // 右侧：功能按钮
          Row(children: [
            // 倍速
            _textBtn('${_speed}x', _showSpeed),
            const SizedBox(width: 16),
            // 比例
            _textBtn('比例', _showAspect),
            // 选集按钮（如果有播放列表）
            if (hasPlaylist) ...[
              const SizedBox(width: 16),
              _textBtn('选集', () => setState(() => _showPlaylist = true)),
            ],
          ]),
        ]),
      ]),
    ));
  }

  /// 选集菜单
  Widget _buildPlaylistMenu(ColorScheme cs) {
    return Positioned.fill(child: GestureDetector(
      onTap: () => setState(() => _showPlaylist = false),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            height: double.infinity,
            decoration: BoxDecoration(color: Colors.grey[900]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
                  child: Row(children: [
                    const Text('选集', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _showPlaylist = false)),
                  ]),
                ),
                // 列表
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.playlist!.length,
                    itemBuilder: (context, index) {
                      final item = widget.playlist![index];
                      final isCurrent = index == widget.currentIndex;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCurrent ? cs.primary.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 80, height: 45,
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                            child: item.thumbnail != null 
                              ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(File(item.thumbnail!), fit: BoxFit.cover))
                              : const Icon(FluentIcons.video_24_regular, color: Colors.white38),
                          ),
                          title: Text(item.name, style: TextStyle(color: isCurrent ? cs.primary : Colors.white, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: isCurrent ? Icon(FluentIcons.play_24_filled, color: cs.primary, size: 16) : null,
                          onTap: () {
                            setState(() => _showPlaylist = false);
                            _playVideoAtIndex(index);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
  
  void _playVideoAtIndex(int index) {
    final item = widget.playlist![index];
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => PlayerPage(
        videoPath: item.path,
        videoName: item.name,
        videoId: item.id,
        playlist: widget.playlist,
        currentIndex: index,
      ),
    ));
  }

  Widget _textBtn(String label, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))));
  }

  Widget _buildLock() => Positioned.fill(child: Center(child: GestureDetector(onTap: () => setState(() => _locked = false), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12)), child: const Icon(FluentIcons.lock_closed_24_filled, color: Colors.white, size: 32)))));

  void _togglePlay() { if (_playing) _vc.pause(); else _vc.play(); setState(() => _playing = !_playing); _startHide(); }
  
  void _toggleRotation() {
    setState(() => _landscape = !_landscape);
    if (_landscape) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }
  
  void _showSpeed() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (c) => Container(
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('播放速度', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) => ChoiceChip(label: Text('${s}x'), selected: _speed == s, selectedColor: Theme.of(context).colorScheme.primary, onSelected: (_) { _vc.setPlaybackSpeed(s); setState(() => _speed = s); Navigator.pop(c); })).toList()),
      ]),
    ));
  }
  
  void _showAspect() => showDialog(context: context, builder: (c) => SimpleDialog(
    title: const Text('画面比例'),
    children: ['fit', 'fill', '16:9', '4:3'].map((a) => RadioListTile(title: Text({'fit': '自适应', 'fill': '填充屏幕', '16:9': '16:9', '4:3': '4:3'}[a]!), value: a, groupValue: _aspect, onChanged: (v) { setState(() => _aspect = v!); Navigator.pop(c); })).toList(),
  ));

  void _showSettings() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => StatefulBuilder(builder: (ctx, setSt) => Container(
      height: MediaQuery.of(ctx).size.height * 0.65,
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 20),
        SwitchListTile(title: const Text('无感循环', style: TextStyle(color: Colors.white)), subtitle: const Text('循环时无黑屏闪烁', style: TextStyle(color: Colors.white54)), value: _loop, activeColor: Theme.of(ctx).colorScheme.primary, onChanged: (v) { setState(() => _loop = v); setSt(() {}); if (v) _startLoop(); else _loopTimer?.cancel(); }),
        const SizedBox(height: 12),
        const Text('睡眠定时', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [{'关闭': null}, {'15分': 15}, {'30分': 30}, {'60分': 60}].map((i) => ChoiceChip(label: Text(i.keys.first), selected: _sleepMin == i.values.first, selectedColor: Theme.of(ctx).colorScheme.primary, onSelected: (_) { _setSleep(i.values.first as int?); setSt(() {}); })).toList()),
        const SizedBox(height: 16),
        _subSection(1, _sub1, _showSub1, (t, s) { setState(() { _sub1 = t; _showSub1 = s; }); setSt(() {}); }),
        const SizedBox(height: 12),
        _subSection(2, _sub2, _showSub2, (t, s) { setState(() { _sub2 = t; _showSub2 = s; }); setSt(() {}); }),
      ]),
    )));
  }

  Widget _subSection(int idx, SubtitleTrack t, bool show, Function(SubtitleTrack, bool) upd) {
    final cs = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text('字幕$idx', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)), const Spacer(), if (t.subtitles.isNotEmpty) Switch(value: show, activeColor: cs.primary, onChanged: (v) => upd(t, v)), TextButton(onPressed: () => _loadSub(idx), child: Text(t.subtitles.isEmpty ? '加载' : '更换', style: TextStyle(color: cs.primary)))]),
      if (t.subtitles.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(children: [const Text('位置', style: TextStyle(color: Colors.white54, fontSize: 12)), Expanded(child: Slider(value: t.position, min: 0.1, max: 0.9, activeColor: cs.primary, onChanged: (v) => upd(t.copyWith(position: v), show))), Text(t.position < 0.4 ? '上' : t.position > 0.7 ? '下' : '中', style: const TextStyle(color: Colors.white38, fontSize: 11))]),
        Row(children: [const Text('大小', style: TextStyle(color: Colors.white54, fontSize: 12)), Expanded(child: Slider(value: t.fontSize, min: 12, max: 28, activeColor: cs.primary, onChanged: (v) => upd(t.copyWith(fontSize: v), show))), Text('${t.fontSize.toInt()}', style: const TextStyle(color: Colors.white38, fontSize: 11))]),
        // 背景透明度
        Row(children: [const Text('背景', style: TextStyle(color: Colors.white54, fontSize: 12)), Expanded(child: Slider(value: t.bgOpacity, min: 0.0, max: 1.0, activeColor: cs.primary, onChanged: (v) => upd(t.copyWith(bgOpacity: v), show))), Text('${(t.bgOpacity * 100).toInt()}%', style: const TextStyle(color: Colors.white38, fontSize: 11))]),
        const Text('文字颜色', style: TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 6),
        Wrap(spacing: 8, children: [Colors.white, Colors.yellow, Colors.cyan, Colors.green, Colors.pink].map((c) => GestureDetector(onTap: () => upd(t.copyWith(color: c), show), child: Container(width: 26, height: 26, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: t.color == c ? Border.all(color: cs.primary, width: 2) : null)))).toList()),
        const SizedBox(height: 8),
        const Text('描边颜色', style: TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 6),
        Wrap(spacing: 8, children: [null, Colors.black, Colors.white, Colors.yellow, Colors.cyan].map((c) => GestureDetector(onTap: () => upd(t.copyWith(strokeColor: c), show), child: Container(width: 26, height: 26, decoration: BoxDecoration(color: c ?? Colors.transparent, shape: BoxShape.circle, border: Border.all(color: t.strokeColor == c ? cs.primary : Colors.white24, width: t.strokeColor == c ? 2 : 1)), child: c == null ? const Icon(Icons.close, color: Colors.white38, size: 14) : null))).toList()),
      ],
    ]));
  }
}

class SubtitleTrack {
  final List<SubtitleEntry> subtitles;
  final String? path;
  final double fontSize, position, bgOpacity;
  final Color color, bgColor;
  final Color? strokeColor;
  
  const SubtitleTrack({
    this.subtitles = const [], 
    this.path, 
    this.fontSize = 16, 
    this.position = 0.85, 
    this.color = Colors.white, 
    this.bgColor = Colors.black,
    this.bgOpacity = 0.6,
    this.strokeColor,
  });
  
  SubtitleTrack copyWith({
    List<SubtitleEntry>? subtitles, 
    String? path, 
    double? fontSize, 
    double? position, 
    Color? color, 
    Color? bgColor,
    double? bgOpacity,
    Color? strokeColor,
  }) => SubtitleTrack(
    subtitles: subtitles ?? this.subtitles, 
    path: path ?? this.path, 
    fontSize: fontSize ?? this.fontSize, 
    position: position ?? this.position, 
    color: color ?? this.color, 
    bgColor: bgColor ?? this.bgColor,
    bgOpacity: bgOpacity ?? this.bgOpacity,
    strokeColor: strokeColor ?? this.strokeColor,
  );
}

class SubtitleEntry { 
  final Duration start, end; 
  final String text; 
  const SubtitleEntry({required this.start, required this.end, required this.text}); 
}

class VideoItem {
  final String id;
  final String path;
  final String name;
  final String? thumbnail;
  
  const VideoItem({required this.id, required this.path, required this.name, this.thumbnail});
}

// 统一的VideoItem类，包含size属性
class VideoItemData {
  final String id;
  final String path;
  final String name;
  final int size;
  final String? thumbnail;
  
  const VideoItemData({
    required this.id, 
    required this.path, 
    required this.name,
    required this.size,
    this.thumbnail
  });
}
