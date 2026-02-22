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

class PlayerPage extends StatefulWidget {
  final String videoPath;
  final String videoName;
  final String? videoId;
  const PlayerPage({super.key, required this.videoPath, required this.videoName, this.videoId});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with TickerProviderStateMixin {
  late VideoPlayerController _vc;
  bool _init = false, _playing = false, _loop = true, _showCtrl = true, _locked = false;
  double _speed = 1.0, _volume = 1.0;
  String _aspect = 'fit';
  bool _muted = false;
  
  // 双字幕
  SubtitleTrack _sub1 = SubtitleTrack(), _sub2 = SubtitleTrack();
  bool _showSub1 = true, _showSub2 = false;
  
  // 手势
  bool _seeking = false, _volAdj = false;
  double _seekDelta = 0;
  
  // 睡眠
  int? _sleepMin;
  Timer? _sleepTimer, _hideTimer, _loopTimer, _posTimer, _progTimer;
  static const int _preload = 800;
  bool _prepLoop = false;

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
    setState(() => _init = true);
    _vc.play(); setState(() => _playing = true);
    _startHide();
  }

  void _startProg() { _progTimer?.cancel(); _progTimer = Timer.periodic(const Duration(milliseconds: 100), (_) { if (mounted) setState(() {}); }); }
  void _startHide() { _hideTimer?.cancel(); _hideTimer = Timer(const Duration(seconds: 5), () { if (mounted && _playing) setState(() => _showCtrl = false); }); }
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
          if (idx == 1) { _sub1 = _sub1.copyWith(subtitles: subs, path: r.files.first.path); _showSub1 = true; }
          else { _sub2 = _sub2.copyWith(subtitles: subs, path: r.files.first.path); _showSub2 = true; }
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
  void dispose() { _sleepTimer?.cancel(); _hideTimer?.cancel(); _loopTimer?.cancel(); _posTimer?.cancel(); _progTimer?.cancel(); _vc.dispose(); SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      Center(child: _init ? _buildVideo() : const CircularProgressIndicator(strokeWidth: 2)),
      if (_init) ...[_buildSubs(), _buildGesture(), if (_showCtrl && !_locked) _buildCtrl(cs), if (_locked) _buildLock()],
    ]));
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

  Widget _subText(SubtitleTrack t, Duration pos) {
    String? txt; for (final e in t.subtitles) { if (pos >= e.start && pos <= e.end) { txt = e.text; break; } }
    if (txt == null) return const SizedBox.shrink();
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: t.bgColor, borderRadius: BorderRadius.circular(6)), child: Text(txt, style: TextStyle(color: t.color, fontSize: t.fontSize, height: 1.3), textAlign: TextAlign.center));
  }

  Widget _buildGesture() {
    return Positioned.fill(child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () { if (_locked) setState(() => _locked = false); else { setState(() => _showCtrl = !_showCtrl); if (_showCtrl) _startHide(); } },
      onDoubleTap: () { if (!_locked) _togglePlay(); },
      onHorizontalDragStart: (_) { if (!_locked) setState(() { _seeking = true; _seekDelta = 0; }); },
      onHorizontalDragUpdate: (d) { if (!_locked && _seeking) setState(() { _seekDelta += d.primaryDelta! / MediaQuery.of(context).size.width * 60000; }); },
      onHorizontalDragEnd: (_) { if (!_locked && _seeking) { _vc.seekTo(_vc.value.position + Duration(milliseconds: _seekDelta.toInt())); setState(() { _seeking = false; _seekDelta = 0; }); } },
      onVerticalDragStart: (d) { if (!_locked) setState(() => _volAdj = d.globalPosition.dx > MediaQuery.of(context).size.width / 2); },
      onVerticalDragUpdate: (d) { if (!_locked && _volAdj) { setState(() { _volume = (_volume - d.primaryDelta! / MediaQuery.of(context).size.height).clamp(0.0, 1.0); }); _vc.setVolume(_volume); } },
      onVerticalDragEnd: (_) => setState(() => _volAdj = false),
    ));
  }

  Widget _buildCtrl(ColorScheme cs) {
    return Positioned.fill(child: Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.5), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.5)], stops: const [0, 0.2, 0.8, 1])),
      child: Column(children: [_buildTop(cs), const Spacer(), if (_seeking) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Text('${_seekDelta > 0 ? '+' : ''}${(_seekDelta / 1000).toStringAsFixed(1)}秒', style: const TextStyle(color: Colors.white, fontSize: 16))), if (_volAdj) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Text('音量 ${(_volume * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 16))), if (!_seeking && !_volAdj) _buildCenter(cs), const Spacer(), _buildBottom(cs)],
    )));
  }

  Widget _buildTop(ColorScheme cs) {
    return SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Row(children: [
      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.videoName, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis), if (_sleepMin != null) Text('睡眠: $_sleepMin分钟', style: TextStyle(color: cs.primary, fontSize: 10))])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _loop ? cs.primary : Colors.white24, borderRadius: BorderRadius.circular(10)), child: Text(_loop ? '循环' : '单次', style: const TextStyle(color: Colors.white, fontSize: 10))),
      IconButton(icon: Icon(_locked ? FluentIcons.lock_closed_24_filled : FluentIcons.lock_open_24_regular, color: Colors.white, size: 18), onPressed: () => setState(() => _locked = !_locked)),
      IconButton(icon: const Icon(FluentIcons.settings_24_regular, color: Colors.white, size: 18), onPressed: () => _showSettings()),
    ])));
  }

  Widget _buildCenter(ColorScheme cs) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(icon: const Icon(FluentIcons.rewind_24_filled, color: Colors.white, size: 22), onPressed: () => _vc.seekTo(_vc.value.position - const Duration(seconds: 10))),
      const SizedBox(width: 20),
      GestureDetector(onTap: _togglePlay, child: Container(width: 48, height: 48, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle), child: Icon(_playing ? FluentIcons.pause_24_filled : FluentIcons.play_24_filled, color: Colors.white, size: 24))),
      const SizedBox(width: 20),
      IconButton(icon: const Icon(FluentIcons.fast_forward_24_filled, color: Colors.white, size: 22), onPressed: () => _vc.seekTo(_vc.value.position + const Duration(seconds: 10))),
    ]);
  }

  Widget _buildBottom(ColorScheme cs) {
    final pos = _vc.value.position, dur = _vc.value.duration;
    return SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Text(_fmt(pos), style: const TextStyle(color: Colors.white, fontSize: 10)),
        Expanded(child: Slider(value: dur.inMilliseconds > 0 ? pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble()) : 0, min: 0, max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1, onChanged: (v) => _vc.seekTo(Duration(milliseconds: v.toInt())), activeColor: cs.primary, inactiveColor: Colors.white24, thumbColor: Colors.white)),
        Text(_fmt(dur), style: const TextStyle(color: Colors.white, fontSize: 10)),
        const SizedBox(width: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)), child: Text('${_speed}x', style: const TextStyle(color: Colors.white, fontSize: 9))),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        IconButton(icon: Icon(_muted ? FluentIcons.speaker_mute_24_filled : FluentIcons.speaker_2_24_filled, color: Colors.white, size: 18), onPressed: () { setState(() { _muted = !_muted; _vc.setVolume(_muted ? 0 : _volume); }); }),
        IconButton(icon: Icon(_sub1.subtitles.isNotEmpty ? (_showSub1 ? FluentIcons.closed_caption_24_filled : FluentIcons.closed_caption_24_regular) : FluentIcons.closed_caption_off_24_regular, color: Colors.white, size: 18), onPressed: () { if (_sub1.subtitles.isNotEmpty) setState(() => _showSub1 = !_showSub1); else _loadSub(1); }),
        IconButton(icon: Icon(_sub2.subtitles.isNotEmpty ? (_showSub2 ? FluentIcons.closed_caption_24_filled : FluentIcons.closed_caption_24_regular) : FluentIcons.closed_caption_off_24_regular, color: Colors.white38, size: 18), onPressed: () { if (_sub2.subtitles.isNotEmpty) setState(() => _showSub2 = !_showSub2); else _loadSub(2); }),
        IconButton(icon: const Icon(FluentIcons.full_screen_maximize_24_regular, color: Colors.white, size: 18), onPressed: _showAspect),
        IconButton(icon: const Icon(FluentIcons.full_screen_maximize_24_regular, color: Colors.white, size: 18), onPressed: _toggleFS),
      ]),
    ])));
  }

  Widget _buildLock() => Center(child: GestureDetector(onTap: () => setState(() => _locked = false), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)), child: const Icon(FluentIcons.lock_closed_24_filled, color: Colors.white, size: 28))));

  void _togglePlay() { if (_playing) _vc.pause(); else _vc.play(); setState(() => _playing = !_playing); _startHide(); }
  void _toggleFS() { if (MediaQuery.of(context).orientation == Orientation.portrait) { SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]); } else { SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); } }
  
  void _showAspect() => showDialog(context: context, builder: (c) => SimpleDialog(title: const Text('画面比例'), children: ['fit', 'fill', '16:9', '4:3'].map((a) => RadioListTile(title: Text({'fit': '自适应', 'fill': '填充', '16:9': '16:9', '4:3': '4:3'}[a]!), value: a, groupValue: _aspect, onChanged: (v) { setState(() => _aspect = v!); Navigator.pop(c); })).toList()));

  void _showSettings() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => StatefulBuilder(builder: (ctx, setSt) => Container(
      height: MediaQuery.of(ctx).size.height * 0.7,
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        const Text('设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        const Text('播放速度', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) => ChoiceChip(label: Text('${s}x'), selected: _speed == s, selectedColor: Theme.of(ctx).colorScheme.primary, onSelected: (_) { _vc.setPlaybackSpeed(s); setState(() => _speed = s); setSt(() {}); })).toList()),
        const SizedBox(height: 12),
        SwitchListTile(title: const Text('无感循环', style: TextStyle(color: Colors.white)), subtitle: const Text('循环时无黑屏', style: TextStyle(color: Colors.white54)), value: _loop, activeColor: Theme.of(ctx).colorScheme.primary, onChanged: (v) { setState(() => _loop = v); setSt(() {}); if (v) _startLoop(); else _loopTimer?.cancel(); }),
        const SizedBox(height: 8),
        const Text('睡眠定时', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: [{'关闭': null}, {'15分': 15}, {'30分': 30}, {'60分': 60}].map((i) => ChoiceChip(label: Text(i.keys.first), selected: _sleepMin == i.values.first, selectedColor: Theme.of(ctx).colorScheme.primary, onSelected: (_) { _setSleep(i.values.first as int?); setSt(() {}); })).toList()),
        const SizedBox(height: 16),
        _subSection(1, _sub1, _showSub1, (t, s) { setState(() { _sub1 = t; _showSub1 = s; }); setSt(() {}); }),
        const SizedBox(height: 12),
        _subSection(2, _sub2, _showSub2, (t, s) { setState(() { _sub2 = t; _showSub2 = s; }); setSt(() {}); }),
      ]),
    )));
  }

  Widget _subSection(int idx, SubtitleTrack t, bool show, Function(SubtitleTrack, bool) upd) {
    final cs = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text('字幕$idx', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)), const Spacer(), if (t.subtitles.isNotEmpty) Switch(value: show, activeColor: cs.primary, onChanged: (v) => upd(t, v)), TextButton(onPressed: () => _loadSub(idx), child: Text(t.subtitles.isEmpty ? '加载' : '更换', style: TextStyle(color: cs.primary, fontSize: 12)))]),
      if (t.subtitles.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(children: [const Text('位置', style: TextStyle(color: Colors.white54, fontSize: 11)), Expanded(child: Slider(value: t.position, min: 0.1, max: 0.9, activeColor: cs.primary, onChanged: (v) => upd(t.copyWith(position: v), show))), Text(t.position < 0.4 ? '上' : t.position > 0.7 ? '下' : '中', style: const TextStyle(color: Colors.white38, fontSize: 10))]),
        Row(children: [const Text('大小', style: TextStyle(color: Colors.white54, fontSize: 11)), Expanded(child: Slider(value: t.fontSize, min: 12, max: 24, activeColor: cs.primary, onChanged: (v) => upd(t.copyWith(fontSize: v), show))), Text('${t.fontSize.toInt()}', style: const TextStyle(color: Colors.white38, fontSize: 10))]),
        const Text('颜色', style: TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, children: [Colors.white, Colors.yellow, Colors.cyan, Colors.green, Colors.pink].map((c) => GestureDetector(onTap: () => upd(t.copyWith(color: c), show), child: Container(width: 24, height: 24, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: t.color == c ? Border.all(color: cs.primary, width: 2) : null)))).toList()),
      ],
    ]));
  }
}

class SubtitleTrack {
  final List<SubtitleEntry> subtitles;
  final String? path;
  final double fontSize, position;
  final Color color, bgColor;
  const SubtitleTrack({this.subtitles = const [], this.path, this.fontSize = 16, this.position = 0.85, this.color = Colors.white, this.bgColor = Colors.black54});
  SubtitleTrack copyWith({List<SubtitleEntry>? subtitles, String? path, double? fontSize, double? position, Color? color, Color? bgColor}) => SubtitleTrack(subtitles: subtitles ?? this.subtitles, path: path ?? this.path, fontSize: fontSize ?? this.fontSize, position: position ?? this.position, color: color ?? this.color, bgColor: bgColor ?? this.bgColor);
}

class SubtitleEntry { final Duration start, end; final String text; const SubtitleEntry({required this.start, required this.end, required this.text}); }
