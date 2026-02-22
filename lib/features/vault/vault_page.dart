import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';

/// 保险箱页面
class VaultPage extends StatefulWidget {
  const VaultPage({super.key});
  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final _pwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  final _duressPwdCtrl = TextEditingController();
  bool _obscure = true, _unlocked = false, _loading = false;
  List<VaultFile> _files = [];
  double _encryptProgress = 0;
  bool _showProgress = false;
  
  enc.Encrypter? _enc;
  enc.IV? _iv;
  late Directory _vaultDir, _hiddenDir, _configDir;
  File? _vaultDataFile;
  
  String? _duressPassword;
  DateTime? _duressActivated;
  List<String> _decoyFiles = [];

  @override
  void initState() { super.initState(); _initVault(); }

  Future<void> _initVault() async {
    final appDir = await getApplicationDocumentsDirectory();
    _vaultDir = Directory('${appDir.path}/.vault_enc');
    _hiddenDir = Directory('${appDir.path}/.vault_hidden');
    _configDir = Directory('/storage/emulated/0/Documents/fluent_player');
    
    if (!await _vaultDir.exists()) await _vaultDir.create(recursive: true);
    if (!await _hiddenDir.exists()) await _hiddenDir.create(recursive: true);
    if (!await _configDir.exists()) await _configDir.create(recursive: true);
    
    _vaultDataFile = File('${_configDir.path}/.vault_data');
    
    await _loadDuressConfig();
    await _loadFileList();
  }

  Future<void> _loadDuressConfig() async {
    try {
      final configFile = File('${_configDir.path}/.bipo.txt');
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final decoded = _decryptConfig(content);
        if (decoded != null) {
          final parts = decoded.split('|');
          if (parts.length >= 2) {
            _duressPassword = parts[0];
            if (parts.length > 1 && parts[1].isNotEmpty) {
              _duressActivated = DateTime.tryParse(parts[1]);
            }
            if (parts.length > 2) {
              _decoyFiles = parts[2].split(',').where((s) => s.isNotEmpty).toList();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('加载逼迫密码配置失败: $e');
    }
  }

  String _encryptConfig(String data) {
    final random = DateTime.now().millisecondsSinceEpoch % 26;
    final shifted = data.split('').map((c) {
      if (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) {
        return String.fromCharCode((c.codeUnitAt(0) - 65 + random) % 26 + 65);
      } else if (c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122) {
        return String.fromCharCode((c.codeUnitAt(0) - 97 + random) % 26 + 97);
      }
      return c;
    }).join();
    return base64Encode(utf8.encode('$random$shifted'));
  }

  String? _decryptConfig(String encrypted) {
    try {
      final decoded = utf8.decode(base64Decode(encrypted));
      final random = int.parse(decoded[0]);
      final shifted = decoded.substring(1);
      return shifted.split('').map((c) {
        if (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) {
          return String.fromCharCode((c.codeUnitAt(0) - 65 - random + 26) % 26 + 65);
        } else if (c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122) {
          return String.fromCharCode((c.codeUnitAt(0) - 97 - random + 26) % 26 + 97);
        }
        return c;
      }).join();
    } catch (e) {
      return null;
    }
  }

  void _initEnc(String pwd) {
    final keyBytes = sha256.convert(utf8.encode(pwd)).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));
    _iv = enc.IV.fromLength(16);
    _enc = enc.Encrypter(enc.AES(key));
  }

  Future<void> _loadFileList() async {
    try {
      if (_vaultDataFile != null && await _vaultDataFile!.exists()) {
        final content = await _vaultDataFile!.readAsString();
        final List<dynamic> data = jsonDecode(content);
        setState(() {
          _files = data.map((e) => VaultFile.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('加载文件列表失败: $e');
    }
  }

  Future<void> _saveFileList() async {
    try {
      if (_vaultDataFile != null) {
        final data = jsonEncode(_files.map((f) => f.toJson()).toList());
        await _vaultDataFile!.writeAsString(data);
      }
    } catch (e) {
      debugPrint('保存文件列表失败: $e');
    }
  }

  @override
  void dispose() {
    _pwdCtrl.dispose(); _newPwdCtrl.dispose(); _confirmPwdCtrl.dispose(); _duressPwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    if (!settings.hasVaultPassword) return _buildSetup(settings);
    if (!_unlocked) return _buildUnlock(settings);
    return _buildContent();
  }

  Widget _buildSetup(SettingsService s) => Padding(padding: const EdgeInsets.all(24), child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(FluentIcons.lock_closed_24_filled, size: 64),
      const SizedBox(height: 24),
      const Text('设置保险箱密码', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      TextField(controller: _newPwdCtrl, obscureText: _obscure, decoration: InputDecoration(labelText: '新密码', suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)))),
      const SizedBox(height: 16),
      TextField(controller: _confirmPwdCtrl, obscureText: _obscure, decoration: const InputDecoration(labelText: '确认密码')),
      const SizedBox(height: 16),
      TextField(controller: _duressPwdCtrl, obscureText: _obscure, decoration: const InputDecoration(labelText: '逼迫密码（可选）', helperText: '输入此密码时隐藏真实文件')),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () => _setupPwd(s), child: const Text('设置密码'))),
    ],
  ));

  Widget _buildUnlock(SettingsService s) => Padding(padding: const EdgeInsets.all(24), child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(FluentIcons.lock_closed_24_filled, size: 64),
      const SizedBox(height: 24),
      const Text('解锁保险箱', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      TextField(controller: _pwdCtrl, obscureText: _obscure, decoration: InputDecoration(labelText: '密码', suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure))), onSubmitted: (_) => _unlock(s)),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () => _unlock(s), child: const Text('解锁'))),
    ],
  ));

  Widget _buildContent() => Scaffold(
    appBar: AppBar(title: const Text('私密保险箱'), actions: [
      IconButton(icon: const Icon(FluentIcons.lock_closed_24_regular), onPressed: _lock),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _loading ? null : _addFiles,
      icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(FluentIcons.add_24_filled),
      label: Text(_loading ? '处理中...' : '添加文件'),
    ),
    body: Column(
      children: [
        if (_showProgress) LinearProgressIndicator(value: _encryptProgress),
        Expanded(child: _files.isEmpty ? _buildEmpty() : _buildFileList()),
      ],
    ),
  );

  Widget _buildEmpty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(FluentIcons.folder_open_24_regular, size: 64),
      const SizedBox(height: 16),
      const Text('保险箱为空'),
      const SizedBox(height: 8),
      const Text('添加文件后原文件将被加密隐藏'),
    ],
  ));

  Widget _buildFileList() => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: _files.length,
    itemBuilder: (_, i) => Card(
      child: ListTile(
        leading: Icon({'video': FluentIcons.video_24_filled, 'image': FluentIcons.image_24_filled}[_files[i].type] ?? FluentIcons.document_24_filled),
        title: Text(_files[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${_fmtSize(_files[i].size)} · ${_fmtDate(_files[i].addedAt)}'),
        trailing: PopupMenuButton(onSelected: (v) { if (v == 'view') _view(_files[i]); else if (v == 'restore') _restore(_files[i]); else if (v == 'delete') _delete(_files[i]); },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: Text('查看')),
            const PopupMenuItem(value: 'restore', child: Text('还原')),
            const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
          ]),
        onTap: () => _view(_files[i]),
      ),
    ),
  );

  String _fmtSize(int b) => b < 1024 ? '${b}B' : b < 1024*1024 ? '${(b/1024).toStringAsFixed(1)}KB' : '${(b/1024/1024).toStringAsFixed(1)}MB';
  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  void _setupPwd(SettingsService s) {
    if (_newPwdCtrl.text.length < 4) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码至少4位'))); return; }
    if (_newPwdCtrl.text != _confirmPwdCtrl.text) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次密码不一致'))); return; }
    
    s.setVaultPassword(_newPwdCtrl.text);
    _initEnc(_newPwdCtrl.text);
    
    if (_duressPwdCtrl.text.isNotEmpty) {
      _duressPassword = _duressPwdCtrl.text;
      _saveDuressConfig();
    }
    
    setState(() => _unlocked = true);
    _newPwdCtrl.clear(); _confirmPwdCtrl.clear(); _duressPwdCtrl.clear();
  }

  void _unlock(SettingsService s) {
    if (_pwdCtrl.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入密码'))); return; }
    
    if (_pwdCtrl.text == _duressPassword) {
      _handleDuressLogin();
      return;
    }
    
    if (_duressActivated != null) {
      final now = DateTime.now();
      if (now.difference(_duressActivated!).inDays < 5) {
        _showDecoyFiles();
        return;
      } else {
        _duressActivated = null;
        _saveDuressConfig();
      }
    }
    
    if (s.verifyVaultPassword(_pwdCtrl.text)) {
      _initEnc(_pwdCtrl.text);
      setState(() => _unlocked = true);
      _pwdCtrl.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码错误')));
    }
  }

  void _handleDuressLogin() {
    setState(() {
      _duressActivated = DateTime.now();
      _unlocked = true;
      _files = _decoyFiles.map((p) => VaultFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: p.split('/').last,
        originalPath: p,
        encryptedPath: '',
        hiddenPath: '',
        type: 'video',
        size: 0,
        addedAt: DateTime.now(),
      )).toList();
    });
    _saveDuressConfig();
    _pwdCtrl.clear();
  }

  void _showDecoyFiles() {
    setState(() {
      _unlocked = true;
      _files = _decoyFiles.map((p) => VaultFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: p.split('/').last,
        originalPath: p,
        encryptedPath: '',
        hiddenPath: '',
        type: 'video',
        size: 0,
        addedAt: DateTime.now(),
      )).toList();
    });
    _pwdCtrl.clear();
  }

  void _lock() => setState(() { _unlocked = false; _enc = null; });

  Future<void> _addFiles() async {
    if (_enc == null) return;
    
    try {
      setState(() { _loading = true; _showProgress = true; _encryptProgress = 0; });
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'avi', 'mkv', 'mov', 'jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'txt'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final total = result.files.length;
        int done = 0;
        
        for (final file in result.files) {
          if (file.path != null) {
            await _encFile(file.path!, file.name);
            done++;
            setState(() => _encryptProgress = done / total);
          }
        }
        
        await _saveFileList();
      }
    } finally {
      if (mounted) setState(() { _loading = false; _showProgress = false; _encryptProgress = 0; });
    }
  }

  Future<void> _encFile(String path, String name) async {
    try {
      final orig = File(path);
      if (!await orig.exists()) return;
      
      final bytes = await orig.readAsBytes();
      final encrypted = _enc!.encryptBytes(bytes, iv: _iv!);
      
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final encPath = '${_vaultDir.path}/$id.enc';
      
      // 保存加密文件
      await File(encPath).writeAsBytes(encrypted.bytes);
      
      // 删除原文件
      await orig.delete();
      
      final ext = name.split('.').last.toLowerCase();
      String type = 'document';
      if (['mp4', 'avi', 'mkv', 'mov'].contains(ext)) type = 'video';
      else if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) type = 'image';
      
      setState(() => _files.add(VaultFile(
        id: id, name: name, originalPath: path,
        encryptedPath: encPath,
        hiddenPath: '',
        type: type, size: bytes.length, addedAt: DateTime.now(),
      )));
    } catch (e) {
      debugPrint('加密失败: $e');
    }
  }

  Future<void> _view(VaultFile f) async {
    if (_enc == null) return;
    try {
      final encFile = File(f.encryptedPath);
      if (!await encFile.exists()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加密文件不存在')));
        return;
      }
      
      final encryptedBytes = await encFile.readAsBytes();
      final encrypted = enc.Encrypted(encryptedBytes);
      final decrypted = _enc!.decryptBytes(encrypted, iv: _iv!);
      
      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/${f.name}');
      await tmpFile.writeAsBytes(decrypted);
      
      if (mounted) {
        showDialog(context: context, builder: (c) => AlertDialog(
          title: Text(f.name),
          content: f.type == 'image' ? Image.file(tmpFile) : Text('文件已解密到临时目录\n${tmpFile.path}'),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('关闭'))],
        ));
      }
    } catch (e) {
      debugPrint('解密失败: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('解密失败: $e')));
    }
  }

  Future<void> _restore(VaultFile f) async {
    if (_enc == null) return;
    try {
      final encFile = File(f.encryptedPath);
      if (!await encFile.exists()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加密文件不存在')));
        return;
      }
      
      final encryptedBytes = await encFile.readAsBytes();
      final encrypted = enc.Encrypted(encryptedBytes);
      final decrypted = _enc!.decryptBytes(encrypted, iv: _iv!);
      
      // 还原到原路径
      await File(f.originalPath).writeAsBytes(decrypted);
      
      // 删除加密文件
      await encFile.delete();
      
      setState(() => _files.removeWhere((e) => e.id == f.id));
      await _saveFileList();
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已还原到 ${f.originalPath}')));
    } catch (e) {
      debugPrint('还原失败: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('还原失败: $e')));
    }
  }

  void _delete(VaultFile f) => showDialog(context: context, builder: (c) => AlertDialog(
    title: const Text('删除文件'),
    content: Text('确定永久删除 ${f.name}？'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
      FilledButton(onPressed: () async {
        Navigator.pop(c);
        try {
          await File(f.encryptedPath).delete();
          setState(() => _files.removeWhere((e) => e.id == f.id));
          await _saveFileList();
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
        }
      }, child: const Text('删除')),
    ],
  ));
  
  Future<void> _saveDuressConfig() async {
    try {
      final configFile = File('${_configDir.path}/.bipo.txt');
      final data = '$_duressPassword|${_duressActivated?.toIso8601String() ?? ''}|${_decoyFiles.join(',')}';
      final encrypted = _encryptConfig(data);
      await configFile.writeAsString(encrypted);
    } catch (e) {
      debugPrint('保存逼迫密码配置失败: $e');
    }
  }
}

class VaultFile {
  final String id, name, originalPath, encryptedPath, hiddenPath, type;
  final int size;
  final DateTime addedAt;
  
  const VaultFile({required this.id, required this.name, required this.originalPath, required this.encryptedPath, required this.hiddenPath, required this.type, required this.size, required this.addedAt});
  
  factory VaultFile.fromJson(Map<String, dynamic> j) => VaultFile(
    id: j['id'], name: j['name'], originalPath: j['originalPath'],
    encryptedPath: j['encryptedPath'], hiddenPath: j['hiddenPath'],
    type: j['type'], size: j['size'], addedAt: DateTime.parse(j['addedAt']),
  );
  
  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'originalPath': originalPath,
    'encryptedPath': encryptedPath, 'hiddenPath': hiddenPath,
    'type': type, 'size': size, 'addedAt': addedAt.toIso8601String(),
  };
}
