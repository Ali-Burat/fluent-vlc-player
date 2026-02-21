import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 保险箱项目模型
class VaultItem {
  final String id;
  final String name;
  final String originalPath;
  final String encryptedPath;
  final String type; // 'video', 'image', 'document'
  final int size;
  final DateTime createdAt;
  final DateTime? lastAccessed;
  final String? thumbnailPath;
  final String? note;

  const VaultItem({
    required this.id,
    required this.name,
    required this.originalPath,
    required this.encryptedPath,
    required this.type,
    required this.size,
    required this.createdAt,
    this.lastAccessed,
    this.thumbnailPath,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'originalPath': originalPath,
      'encryptedPath': encryptedPath,
      'type': type,
      'size': size,
      'createdAt': createdAt.toIso8601String(),
      'lastAccessed': lastAccessed?.toIso8601String(),
      'thumbnailPath': thumbnailPath,
      'note': note,
    };
  }

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] as String,
      name: json['name'] as String,
      originalPath: json['originalPath'] as String,
      encryptedPath: json['encryptedPath'] as String,
      type: json['type'] as String,
      size: json['size'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAccessed: json['lastAccessed'] != null
          ? DateTime.parse(json['lastAccessed'] as String)
          : null,
      thumbnailPath: json['thumbnailPath'] as String?,
      note: json['note'] as String?,
    );
  }
}

/// 保险箱服务提供者
final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService();
});

/// 保险箱状态提供者
final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  return VaultNotifier(ref.read(vaultServiceProvider));
});

/// 保险箱状态
class VaultState {
  final bool isInitialized;
  final bool isUnlocked;
  final bool hasPassword;
  final List<VaultItem> items;
  final String? error;

  const VaultState({
    this.isInitialized = false,
    this.isUnlocked = false,
    this.hasPassword = false,
    this.items = const [],
    this.error,
  });

  VaultState copyWith({
    bool? isInitialized,
    bool? isUnlocked,
    bool? hasPassword,
    List<VaultItem>? items,
    String? error,
  }) {
    return VaultState(
      isInitialized: isInitialized ?? this.isInitialized,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      hasPassword: hasPassword ?? this.hasPassword,
      items: items ?? this.items,
      error: error,
    );
  }
}

/// 保险箱服务
class VaultService {
  static const String _vaultKey = 'vault_items';
  static const String _passwordKey = 'vault_password_hash';
  static const String _saltKey = 'vault_salt';
  
  Box get _box => Hive.box('vault');
  
  late Directory _vaultDirectory;
  encrypt.Key? _encryptionKey;
  encrypt.IV? _iv;
  encrypt.Encrypter? _encrypter;
  
  /// 初始化保险箱
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _vaultDirectory = Directory('${appDir.path}/.vault');
    
    if (!await _vaultDirectory.exists()) {
      await _vaultDirectory.create(recursive: true);
    }
  }
  
  /// 检查是否已设置密码
  Future<bool> hasPassword() async {
    return _box.containsKey(_passwordKey);
  }
  
  /// 设置密码
  Future<void> setPassword(String password) async {
    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);
    
    await _box.put(_saltKey, salt);
    await _box.put(_passwordKey, hash);
    
    _initializeEncryption(password, salt);
  }
  
  /// 验证密码
  Future<bool> verifyPassword(String password) async {
    final storedHash = _box.get(_passwordKey) as String?;
    final salt = _box.get(_saltKey) as String?;
    
    if (storedHash == null || salt == null) {
      return false;
    }
    
    final hash = _hashPassword(password, salt);
    
    if (hash == storedHash) {
      _initializeEncryption(password, salt);
      return true;
    }
    
    return false;
  }
  
  /// 修改密码
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (!await verifyPassword(oldPassword)) {
      return false;
    }
    
    await setPassword(newPassword);
    return true;
  }
  
  /// 初始化加密
  void _initializeEncryption(String password, String salt) {
    final keyBytes = sha256.convert(utf8.encode(password + salt)).bytes;
    _encryptionKey = encrypt.Key(Uint8List.fromList(keyBytes));
    _iv = encrypt.IV.fromLength(16);
    _encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey!));
  }
  
  /// 生成盐值
  String _generateSalt() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    return sha256.convert(utf8.encode(random)).toString().substring(0, 32);
  }
  
  /// 哈希密码
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
  
  /// 加密数据
  String encryptData(String data) {
    if (_encrypter == null) {
      throw Exception('Encryption not initialized');
    }
    return _encrypter!.encrypt(data, iv: _iv!).base64;
  }
  
  /// 解密数据
  String decryptData(String encryptedData) {
    if (_encrypter == null) {
      throw Exception('Encryption not initialized');
    }
    return _encrypter!.decrypt64(encryptedData, iv: _iv!);
  }
  
  /// 加密文件
  Future<String> encryptFile(File sourceFile, String fileName) async {
    if (_encrypter == null) {
      throw Exception('Encryption not initialized');
    }
    
    final bytes = await sourceFile.readAsBytes();
    final encrypted = _encrypter!.encryptBytes(bytes, iv: _iv!);
    
    final encryptedFileName = '${const Uuid().v4()}.enc';
    final encryptedFilePath = '${_vaultDirectory.path}/$encryptedFileName';
    
    final encryptedFile = File(encryptedFilePath);
    await encryptedFile.writeAsBytes(encrypted.bytes);
    
    return encryptedFilePath;
  }
  
  /// 解密文件
  Future<File> decryptFile(VaultItem item) async {
    if (_encrypter == null) {
      throw Exception('Encryption not initialized');
    }
    
    final encryptedFile = File(item.encryptedPath);
    if (!await encryptedFile.exists()) {
      throw Exception('Encrypted file not found');
    }
    
    final encryptedBytes = await encryptedFile.readAsBytes();
    final encryptedData = encrypt.Encrypted(encryptedBytes);
    final decryptedBytes = _encrypter!.decryptBytes(encryptedData, iv: _iv!);
    
    final tempDir = await getTemporaryDirectory();
    final decryptedFile = File('${tempDir.path}/${item.name}');
    await decryptedFile.writeAsBytes(decryptedBytes);
    
    return decryptedFile;
  }
  
  /// 添加文件到保险箱
  Future<VaultItem> addFile(File file, {String? note}) async {
    if (_encrypter == null) {
      throw Exception('Encryption not initialized');
    }
    
    final fileName = file.path.split('/').last;
    final extension = fileName.split('.').last.toLowerCase();
    
    String type = 'document';
    if (['mp4', 'avi', 'mkv', 'mov', 'webm', 'flv', 'wmv'].contains(extension)) {
      type = 'video';
    } else if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      type = 'image';
    }
    
    final encryptedPath = await encryptFile(file, fileName);
    final size = await file.length();
    
    final item = VaultItem(
      id: const Uuid().v4(),
      name: fileName,
      originalPath: file.path,
      encryptedPath: encryptedPath,
      type: type,
      size: size,
      createdAt: DateTime.now(),
      note: note,
    );
    
    // 保存到Hive
    final items = await getItems();
    items.add(item);
    await _saveItems(items);
    
    // 删除原文件
    try {
      await file.delete();
    } catch (_) {}
    
    return item;
  }
  
  /// 从保险箱移除文件
  Future<void> removeFile(String itemId) async {
    final items = await getItems();
    final index = items.indexWhere((item) => item.id == itemId);
    
    if (index != -1) {
      final item = items[index];
      
      // 删除加密文件
      final encryptedFile = File(item.encryptedPath);
      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
      }
      
      // 删除缩略图
      if (item.thumbnailPath != null) {
        final thumbnailFile = File(item.thumbnailPath!);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
        }
      }
      
      items.removeAt(index);
      await _saveItems(items);
    }
  }
  
  /// 从保险箱导出文件
  Future<File> exportFile(String itemId, String exportPath) async {
    final items = await getItems();
    final item = items.firstWhere((item) => item.id == itemId);
    
    final decryptedFile = await decryptFile(item);
    final exportedFile = await decryptedFile.copy(exportPath);
    
    return exportedFile;
  }
  
  /// 获取所有项目
  Future<List<VaultItem>> getItems() async {
    final data = _box.get(_vaultKey);
    if (data == null) {
      return [];
    }
    
    final List<dynamic> items = jsonDecode(data);
    return items.map((item) => VaultItem.fromJson(item)).toList();
  }
  
  /// 保存项目列表
  Future<void> _saveItems(List<VaultItem> items) async {
    final data = jsonEncode(items.map((item) => item.toJson()).toList());
    await _box.put(_vaultKey, data);
  }
  
  /// 更新项目
  Future<void> updateItem(VaultItem updatedItem) async {
    final items = await getItems();
    final index = items.indexWhere((item) => item.id == updatedItem.id);
    
    if (index != -1) {
      items[index] = updatedItem;
      await _saveItems(items);
    }
  }
  
  /// 清空保险箱
  Future<void> clearVault() async {
    final items = await getItems();
    
    for (final item in items) {
      final encryptedFile = File(item.encryptedPath);
      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
      }
      
      if (item.thumbnailPath != null) {
        final thumbnailFile = File(item.thumbnailPath!);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
        }
      }
    }
    
    await _box.delete(_vaultKey);
  }
  
  /// 锁定保险箱
  void lock() {
    _encryptionKey = null;
    _iv = null;
    _encrypter = null;
  }
}

/// 保险箱状态管理器
class VaultNotifier extends StateNotifier<VaultState> {
  final VaultService _service;
  
  VaultNotifier(this._service) : super(const VaultState()) {
    _initialize();
  }
  
  Future<void> _initialize() async {
    await _service.initialize();
    final hasPassword = await _service.hasPassword();
    state = state.copyWith(isInitialized: true, hasPassword: hasPassword);
  }
  
  Future<bool> unlock(String password) async {
    try {
      final success = await _service.verifyPassword(password);
      if (success) {
        final items = await _service.getItems();
        state = state.copyWith(isUnlocked: true, items: items, error: null);
        return true;
      }
      state = state.copyWith(error: '密码错误');
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
  
  Future<void> setupPassword(String password) async {
    await _service.setPassword(password);
    state = state.copyWith(hasPassword: true, isUnlocked: true);
  }
  
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    final success = await _service.changePassword(oldPassword, newPassword);
    if (!success) {
      state = state.copyWith(error: '原密码错误');
    }
    return success;
  }
  
  Future<void> lock() async {
    _service.lock();
    state = state.copyWith(isUnlocked: false, items: []);
  }
  
  Future<VaultItem?> addFile(File file, {String? note}) async {
    try {
      final item = await _service.addFile(file, note: note);
      final items = await _service.getItems();
      state = state.copyWith(items: items);
      return item;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
  
  Future<void> removeFile(String itemId) async {
    await _service.removeFile(itemId);
    final items = await _service.getItems();
    state = state.copyWith(items: items);
  }
  
  Future<File?> decryptFile(String itemId) async {
    try {
      final item = state.items.firstWhere((item) => item.id == itemId);
      return await _service.decryptFile(item);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
  
  Future<void> clearError() async {
    state = state.copyWith(error: null);
  }
}
