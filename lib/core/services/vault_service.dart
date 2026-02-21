import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 保险箱项目
class VaultItem {
  final String id;
  final String name;
  final String encryptedPath;
  final String type;
  final int size;
  final DateTime createdAt;
  final String? note;

  const VaultItem({
    required this.id,
    required this.name,
    required this.encryptedPath,
    required this.type,
    required this.size,
    required this.createdAt,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'encryptedPath': encryptedPath,
    'type': type,
    'size': size,
    'createdAt': createdAt.toIso8601String(),
    'note': note,
  };

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
    id: json['id'] as String,
    name: json['name'] as String,
    encryptedPath: json['encryptedPath'] as String,
    type: json['type'] as String,
    size: json['size'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    note: json['note'] as String?,
  );
}

/// 保险箱服务 - AES加密存储
class VaultService extends ChangeNotifier {
  static const String _itemsKey = 'vault_items';
  
  List<VaultItem> _items = [];
  bool _isUnlocked = false;
  String? _password;
  encrypt.Encrypter? _encrypter;
  encrypt.IV? _iv;
  late Directory _vaultDir;
  
  List<VaultItem> get items => _items;
  bool get isUnlocked => _isUnlocked;
  
  /// 初始化
  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _vaultDir = Directory('${appDir.path}/.vault');
    if (!await _vaultDir.exists()) {
      await _vaultDir.create(recursive: true);
    }
    await _loadItems();
  }
  
  void _initEncryption(String password) {
    final keyBytes = sha256.convert(utf8.encode(password)).bytes;
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    _iv = encrypt.IV.fromLength(16);
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
  }
  
  /// 解锁
  bool unlock(String password) {
    _password = password;
    _initEncryption(password);
    _isUnlocked = true;
    notifyListeners();
    return true;
  }
  
  /// 锁定
  void lock() {
    _isUnlocked = false;
    _password = null;
    _encrypter = null;
    _iv = null;
    notifyListeners();
  }
  
  /// 加密文件
  Future<VaultItem?> addFile(File file, {String? note}) async {
    if (!_isUnlocked || _encrypter == null) return null;
    
    try {
      final bytes = await file.readAsBytes();
      final encrypted = _encrypter!.encryptBytes(bytes, iv: _iv!);
      
      final id = const Uuid().v4();
      final encryptedFileName = '$id.enc';
      final encryptedPath = '${_vaultDir.path}/$encryptedFileName';
      
      await File(encryptedPath).writeAsBytes(encrypted.bytes);
      
      final fileName = file.path.split('/').last;
      final ext = fileName.split('.').last.toLowerCase();
      
      String type = 'document';
      if (['mp4', 'avi', 'mkv', 'mov', 'webm', 'flv', 'wmv', '3gp'].contains(ext)) {
        type = 'video';
      } else if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'].contains(ext)) {
        type = 'image';
      }
      
      final item = VaultItem(
        id: id,
        name: fileName,
        encryptedPath: encryptedPath,
        type: type,
        size: bytes.length,
        createdAt: DateTime.now(),
        note: note,
      );
      
      _items.add(item);
      await _saveItems();
      
      // 删除原文件
      try {
        await file.delete();
      } catch (_) {}
      
      notifyListeners();
      return item;
    } catch (e) {
      debugPrint('加密文件失败: $e');
      return null;
    }
  }
  
  /// 解密文件
  Future<File?> decryptFile(VaultItem item) async {
    if (!_isUnlocked || _encrypter == null) return null;
    
    try {
      final encryptedBytes = await File(item.encryptedPath).readAsBytes();
      final encrypted = encrypt.Encrypted(encryptedBytes);
      final decryptedBytes = _encrypter!.decryptBytes(encrypted, iv: _iv!);
      
      final tempDir = await getTemporaryDirectory();
      final decryptedFile = File('${tempDir.path}/${item.name}');
      await decryptedFile.writeAsBytes(decryptedBytes);
      
      return decryptedFile;
    } catch (e) {
      debugPrint('解密文件失败: $e');
      return null;
    }
  }
  
  /// 删除文件
  Future<void> removeItem(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _items[index];
      try {
        await File(item.encryptedPath).delete();
      } catch (_) {}
      _items.removeAt(index);
      await _saveItems();
      notifyListeners();
    }
  }
  
  /// 导出文件
  Future<File?> exportFile(VaultItem item, String exportPath) async {
    final decrypted = await decryptFile(item);
    if (decrypted == null) return null;
    
    final exported = await decrypted.copy(exportPath);
    return exported;
  }
  
  Future<void> _loadItems() async {
    // 从本地存储加载项目列表
    // 简化实现：使用SharedPreferences
  }
  
  Future<void> _saveItems() async {
    // 保存项目列表到本地存储
  }
  
  /// 清空保险箱
  Future<void> clear() async {
    for (final item in _items) {
      try {
        await File(item.encryptedPath).delete();
      } catch (_) {}
    }
    _items.clear();
    notifyListeners();
  }
}
