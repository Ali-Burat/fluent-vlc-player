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
  final String videoPath; final String videoName; final String? videoId;
  const PlayerPage({super.key, required this.videoPath, required this.videoName, this.videoId});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with TickerProviderStateMixin {
  late VideoPlayerController _vc;
  bool _init = false, _playing = false, _loop = true, _showCtrl = true, _locked = false;
  double _speed = 1.0, _volume = 1.0;
  String _aspect = 'fit';
  List<SubtitleEntry> _subs = [];
  bool _showSub = true;
  double _subSize = 18;
  Color _subColor = Colors.white;
  int? _sleepMin;
  Timer? _sleepTimer, _hideTimer;
  bool _seeking = false, _volAdj = false;
  double _seekDelta = 0, _volDelta = 0;

  @override
  void initState() { super.initState(); _initPlayer(); }

  Future<void> _initPlayer() async {
    final s = context.read<SettingsService>();
    _loop = s.seamlessLoop; _speed = s.playbackSpeed;
    _vc = widget.videoPath.startsWith('http') ? VideoPlayerController.networkUrl(Uri.parse(widget.videoPath)) : VideoPlayerController.file(File(widget.videoPath));
    await _vc.initialize();
    if (s.rememberPosition && widget.videoId != null) { final p = s.getPlayPosition(widget.videoId!); if (p != null && p > 0) await _vc.seekTo(Duration(milliseconds: p)); }
    await _vc.setPlaybackSpeed(_speed); await _vc.setVolume(_volume);
    _vc.addListener(() { if (_vc.value.position >= _vc.value.duration && _loop) _handleLoop(); });
    setState(() => _init = true);
    _vc.play(); setState(() => _playing = true);
    _startHideTimer();
  }

  void _handleLoop() async { await _vc.seekTo(Duration.zero); if (!_vc.value.isPlaying) await _vc.play(); }
  void _startHideTimer() { _hideTimer?.cancel(); _hideTimer = Timer(const Duration(seconds: 5), () { if (mounted && _playing) setState(() => _showCtrl = false); }); }

  String _fmt(Duration d) { final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60); return h > 0 ? '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}' : '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}'; }

  @override
  void dispose() { _sleepTimer?.cancel(); _hideTimer?.cancel(); _vc.dispose(); SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      Center(child: _init ? AspectRatio(aspectRatio: _vc.value.aspectRatio, child: VideoPlayer(_vc)) : const CircularProgressIndicator()),
      if (_init && _showSub && _subs.isNotEmpty) _buildSub(),
      if (_init) _buildGesture(),
      if (_init && _showCtrl && !_locked) _buildControls(cs),
      if (_locked) Center(child: IconButton(icon: const Icon(FluentIcons.lock_closed_24_filled, color: Colors.white, size: 48), onPressed: () => setState(() => _locked = false))),
    ]));
  }

  Widget _buildSub() { final p = _vc.value.position; String? t; for (final e in _subs) { if (p >= e.start && p <= e.end) { t = e.text; break; } } return t == null ? const SizedBox() : Positioned(left: 16, right: 16, bottom: 140, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Text(t, style: TextStyle(color: _subColor, fontSize: _subSize), textAlign: TextAlign.center))); }

  Widget _buildGesture() => Positioned.fill(child: GestureDetector(
    onTap: () { if (_locked) setState(() => _locked = false); else { setState(() => _showCtrl = !_showCtrl); if (_showCtrl) _startHideTimer(); } },
    onDoubleTap: () { if (!_locked) { if (_playing) _vc.pause(); else _vc.play(); setState(() => _playing = !_playing); } },
    onHorizontalDragStart: (_) => setState(() => _seeking = true),
    onHorizontalDragUpdate: (d) => setState(() => _seekDelta += d.primaryDelta! * 100),
    onHorizontalDragEnd: (_) { _vc.seekTo(_vc.value.position + Duration(milliseconds: _seekDelta.toInt())); setState(() { _seeking = false; _seekDelta = 0; }); },
    onVerticalDragStart: (d) => setState(() => _volAdj = d.globalPosition.dx > MediaQuery.of(context).size.width / 2),
    onVerticalDragUpdate: (d) { if (_volAdj) { setState(() { _volDelta -= d.primaryDelta! / 200; _volume = (_volume + _volDelta).clamp(0.0, 1.0); }); _vc.setVolume(_volume); } },
    onVerticalDragEnd: (_) => setState(() => _volAdj = false),
  ));

  Widget _buildControls(ColorScheme cs) => Positioned.fill(child: Container(
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black54], stops: const [0, 0.15, 0.85, 1])),
    child: Column(children: [
      SafeArea(child: Row(children: [IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)), Expanded(child: Text(widget.videoName, style: const TextStyle(color: Colors.white, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _loop ? cs.primary : Colors.white24, borderRadius: BorderRadius.circular(12)), child: Text(_loop ? '循环' : '单次', style: const TextStyle(color: Colors.white, fontSize: 12))), IconButton(icon: const Icon(FluentIcons.lock_open_24_regular, color: Colors.white), onPressed: () => setState(() => _locked = true)), IconButton(icon: const Icon(FluentIcons.settings_24_regular, color: Colors.white), onPressed: () => _showSettings())])),
      const Spacer(),
      if (_seeking) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: Text('${_seekDelta > 0 ? '+' : ''}${(_seekDelta / 1000).toStringAsFixed(1)}秒', style: const TextStyle(color: Colors.white, fontSize: 24))),
      if (_volAdj) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: Text('音量 ${(_volume * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 24))),
      if (!_seeking && !_volAdj) Row(mainAxisAlignment: MainAxisAlignment.center, children: [IconButton(icon: const Icon(FluentIcons.rewind_24_filled, color: Colors.white, size: 32), onPressed: () => _vc.seekTo(_vc.value.position - const Duration(seconds: 10))), const SizedBox(width: 40), GestureDetector(onTap: () { if (_playing) _vc.pause(); else _vc.play(); setState(() => _playing = !_playing); }, child: Container(width: 72, height: 72, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle), child: Icon(_playing ? FluentIcons.pause_24_filled : FluentIcons.play_24_filled, color: Colors.white, size: 36))), const SizedBox(width: 40), IconButton(icon: const Icon(FluentIcons.fast_forward_24_filled, color: Colors.white, size: 32), onPressed: () => _vc.seekTo(_vc.value.position + const Duration(seconds: 10)))]),
      const Spacer(),
      SafeArea(child: Column(children: [Row(children: [Text(_fmt(_vc.value.position), style: const TextStyle(color: Colors.white, fontSize: 12)), Expanded(child: Slider(value: _vc.value.duration.inMilliseconds > 0 ? _vc.value.position.inMilliseconds.toDouble().clamp(0, _vc.value.duration.inMilliseconds.toDouble()) : 0, min: 0, max: _vc.value.duration.inMilliseconds > 0 ? _vc.value.duration.inMilliseconds.toDouble() : 1, onChanged: (v) => _vc.seekTo(Duration(milliseconds: v.toInt())), activeColor: cs.primary, inactiveColor: Colors.white24)), Text(_fmt(_vc.value.duration), style: const TextStyle(color: Colors.white, fontSize: 12)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: Text('${_speed}x', style: const TextStyle(color: Colors.white, fontSize: 12)))]), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [IconButton(icon: Icon(_locked ? FluentIcons.lock_closed_24_filled : FluentIcons.lock_open_24_regular, color: Colors.white), onPressed: () => setState(() => _locked = !_locked)), IconButton(icon: Icon(_subs.isNotEmpty ? (_showSub ? FluentIcons.closed_caption_24_filled : FluentIcons.closed_caption_24_regular) : FluentIcons.closed_caption_off_24_regular, color: _subs.isNotEmpty ? Colors.white : Colors.white54), onPressed: _subs.isNotEmpty ? () => setState(() => _showSub = !_showSub) : _loadSub), IconButton(icon: Icon(FluentIcons.speaker_2_24_filled, color: Colors.white), onPressed: () {}), IconButton(icon: const Icon(FluentIcons.aspect_ratio_24_regular, color: Colors.white), onPressed: _showAspect), IconButton(icon: const Icon(FluentIcons.full_screen_maximize_24_regular, color: Colors.white), onPressed: _toggleFS)])]))
    ]),
  ));

  void _loadSub() async { final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['srt']); if (r != null && r.files.isNotEmpty) { final f = File(r.files.first.path!); final c = await f.readAsString(); setState(() => _subs = _parseSrt(c)); } }
  List<SubtitleEntry> _parseSrt(String c) { final List<SubtitleEntry> e = []; for (final b in c.split('\n\n')) { final l = b.split('\n'); if (l.length >= 3) { final t = l[1].split(' --> '); if (t.length == 2) e.add(SubtitleEntry(start: _parseT(t[0]), end: _parseT(t[1]), text: l.sublist(2).join('\n'))); } } return e; }
  Duration _parseT(String t) { final p = t.trim().split(':'); return Duration(hours: int.parse(p[0]), minutes: int.parse(p[1]), seconds: int.parse(p[2].split(',')[0]), milliseconds: int.parse(p[2].split(',')[1])); }

  void _showAspect() => showDialog(context: context, builder: (c) => AlertDialog(title: const Text('画面比例'), content: Column(mainAxisSize: MainAxisSize.min, children: ['fit', 'fill', '16:9', '4:3'].map((a) => RadioListTile(title: Text({'fit':'自适应','fill':'填充','16:9':'16:9','4:3':'4:3'}[a]!), value: a, groupValue: _aspect, onChanged: (v) { setState(() => _aspect = v!); Navigator.pop(c); })).toList())));
  void _toggleFS() { if (MediaQuery.of(context).orientation == Orientation.portrait) { SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]); } else { SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); } }

  void _showSettings() => showModalBottomSheet(context: context, builder: (c) => Container(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('播放设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 16),
    const Text('播放速度'), Wrap(spacing: 8, children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) => ChoiceChip(label: Text('${s}x'), selected: _speed == s, onSelected: (_) { _vc.setPlaybackSpeed(s); setState(() => _speed = s); })).toList()),
    const SizedBox(height: 16),
    SwitchListTile(title: const Text('无感循环'), value: _loop, onChanged: (v) => setState(() => _loop = v)),
    ListTile(leading: const Icon(FluentIcons.closed_caption_24_regular), title: const Text('加载字幕'), onTap: () { Navigator.pop(c); _loadSub(); }),
  ])));
}

class SubtitleEntry { final Duration start; final Duration end; final String text; const SubtitleEntry({required this.start, required this.end, required this.text}); }
