import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});
  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final _pwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _obscure = true, _unlocked = false, _loading = false;
  List<VaultFile> _files = [];
  enc.Encrypter? _enc; enc.IV? _iv;
  late Directory _vaultDir, _hiddenDir;

  @override
  void initState() { super.initState(); _init(); }
  Future<void> _init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _vaultDir = Directory('${appDir.path}/.vault_enc'); _hiddenDir = Directory('${appDir.path}/.vault_hidden');
    if (!await _vaultDir.exists()) await _vaultDir.create(recursive: true);
    if (!await _hiddenDir.exists()) await _hiddenDir.create(recursive: true);
  }

  void _initEnc(String pwd) { final k = enc.Key(Uint8List.fromList(sha256.convert(utf8.encode(pwd)).bytes)); _iv = enc.IV.fromLength(16); _enc = enc.Encrypter(enc.AES(k)); }

  @override
  void dispose() { _pwdCtrl.dispose(); _newPwdCtrl.dispose(); _confirmPwdCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsService>();
    if (!s.hasVaultPassword) return _buildSetup(s);
    if (!_unlocked) return _buildUnlock(s);
    return _buildContent();
  }

  Widget _buildSetup(SettingsService s) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(FluentIcons.lock_closed_24_filled, size: 64), const SizedBox(height: 24),
    const Text('设置保险箱密码', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 24),
    TextField(controller: _newPwdCtrl, obscureText: _obscure, decoration: InputDecoration(labelText: '新密码', suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)))),
    const SizedBox(height: 16),
    TextField(controller: _confirmPwdCtrl, obscureText: _obscure, decoration: const InputDecoration(labelText: '确认密码')),
    const SizedBox(height: 24),
    SizedBox(width: double.infinity, child: FilledButton(onPressed: () {
      if (_newPwdCtrl.text.length < 4) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码至少4位'))); return; }
      if (_newPwdCtrl.text != _confirmPwdCtrl.text) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次密码不一致'))); return; }
      s.setVaultPassword(_newPwdCtrl.text); _initEnc(_newPwdCtrl.text); setState(() => _unlocked = true);
    }, child: const Text('设置密码'))),
  ]));

  Widget _buildUnlock(SettingsService s) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(FluentIcons.lock_closed_24_filled, size: 64), const SizedBox(height: 24),
    const Text('解锁保险箱', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 24),
    TextField(controller: _pwdCtrl, obscureText: _obscure, decoration: InputDecoration(labelText: '密码', suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure))), onSubmitted: (_) => _unlock(s)),
    const SizedBox(height: 24),
    SizedBox(width: double.infinity, child: FilledButton(onPressed: () => _unlock(s), child: const Text('解锁'))),
  ]));

  void _unlock(SettingsService s) {
    if (s.verifyVaultPassword(_pwdCtrl.text)) { _initEnc(_pwdCtrl.text); setState(() => _unlocked = true); _pwdCtrl.clear(); }
    else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码错误')));
  }

  Widget _buildContent() => Scaffold(
    appBar: AppBar(title: const Text('私密保险箱'), actions: [IconButton(icon: const Icon(FluentIcons.lock_closed_24_regular), onPressed: () => setState(() { _unlocked = false; _enc = null; }))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _loading ? null : _addFiles, icon: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(FluentIcons.add_24_filled), label: Text(_loading ? '处理中...' : '添加文件')),
    body: _files.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(FluentIcons.folder_open_24_regular, size: 64), const SizedBox(height: 16),
      const Text('保险箱为空'), const SizedBox(height: 8),
      const Text('添加文件后原文件将被加密隐藏'),
    ])) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _files.length, itemBuilder: (_, i) => _fileCard(_files[i])),
  );

  Widget _fileCard(VaultFile f) => Card(child: ListTile(
    leading: Icon({'video': FluentIcons.video_24_filled, 'image': FluentIcons.image_24_filled}[f.type] ?? FluentIcons.document_24_filled),
    title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text('${_fmtSize(f.size)} · ${_fmtDate(f.addedAt)}'),
    trailing: PopupMenuButton(onSelected: (v) { if (v == 'view') _view(f); else if (v == 'restore') _restore(f); else if (v == 'delete') _delete(f); },
      itemBuilder: (_) => [const PopupMenuItem(value: 'view', child: Text('查看')), const PopupMenuItem(value: 'restore', child: Text('还原')), const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red)))]),
    onTap: () => _view(f),
  ));

  String _fmtSize(int b) => b < 1024 ? '${b}B' : b < 1024*1024 ? '${(b/1024).toStringAsFixed(1)}KB' : '${(b/1024/1024).toStringAsFixed(1)}MB';
  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _addFiles() async {
    if (_enc == null) return;
    setState(() => _loading = true);
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp4','avi','mkv','mov','jpg','jpeg','png','gif','pdf','doc','txt'], allowMultiple: true);
      if (r != null && r.files.isNotEmpty) for (final f in r.files) if (f.path != null) await _encFile(f.path!, f.name);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _encFile(String path, String name) async {
    final orig = File(path); if (!await orig.exists()) return;
    final bytes = await orig.readAsBytes(); final encd = _enc!.encryptBytes(bytes, iv: _iv!);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await File('${_vaultDir.path}/$id.enc').writeAsBytes(encd.bytes);
    await orig.rename('${_hiddenDir.path}/$id.${name.split('.').last}');
    final ext = name.split('.').last.toLowerCase();
    setState(() => _files.add(VaultFile(id: id, name: name, origPath: path, encPath: '${_vaultDir.path}/$id.enc', hiddenPath: '${_hiddenDir.path}/$id.$ext', type: ['mp4','avi','mkv','mov'].contains(ext) ? 'video' : ['jpg','jpeg','png','gif'].contains(ext) ? 'image' : 'doc', size: bytes.length, addedAt: DateTime.now())));
  }

  Future<void> _view(VaultFile f) async {
    final encd = enc.Encrypted(await File(f.encPath).readAsBytes());
    final dec = _enc!.decryptBytes(encd, iv: _iv!);
    final tmp = File('${(await getTemporaryDirectory()).path}/${f.name}');
    await tmp.writeAsBytes(dec);
    showDialog(context: context, builder: (c) => AlertDialog(title: Text(f.name), content: f.type == 'image' ? Image.file(tmp) : const Text('文件已解密'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('关闭'))]));
  }

  Future<void> _restore(VaultFile f) async {
    final encd = enc.Encrypted(await File(f.encPath).readAsBytes());
    final dec = _enc!.decryptBytes(encd, iv: _iv!);
    await File(f.origPath).writeAsBytes(dec);
    await File(f.encPath).delete();
    await File(f.hiddenPath).delete();
    setState(() => _files.removeWhere((e) => e.id == f.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已还原到 ${f.origPath}')));
  }

  void _delete(VaultFile f) => showDialog(context: context, builder: (c) => AlertDialog(title: const Text('删除文件'), content: Text('确定永久删除 ${f.name}？'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')), FilledButton(onPressed: () async { Navigator.pop(c); await File(f.encPath).delete(); await File(f.hiddenPath).delete(); setState(() => _files.removeWhere((e) => e.id == f.id)); }, child: const Text('删除'))]));
}

class VaultFile { final String id, name, origPath, encPath, hiddenPath, type; final int size; final DateTime addedAt; const VaultFile({required this.id, required this.name, required this.origPath, required this.encPath, required this.hiddenPath, required this.type, required this.size, required this.addedAt}); }
