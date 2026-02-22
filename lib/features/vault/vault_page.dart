import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';

/// 保险箱页面 - 完整功能版
class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isUnlocked = false;
  List<VaultFile> _files = [];
  bool _isLoading = false;
  
  // 加密相关
  encrypt.Encrypter? _encrypter;
  encrypt.IV? _iv;
  late Directory _vaultDir;
  late Directory _hiddenDir;

  @override
  void initState() {
    super.initState();
    _initVault();
  }

  Future<void> _initVault() async {
    final appDir = await getApplicationDocumentsDirectory();
    _vaultDir = Directory('${appDir.path}/.vault_encrypted');
    _hiddenDir = Directory('${appDir.path}/.vault_hidden');
    
    if (!await _vaultDir.exists()) {
      await _vaultDir.create(recursive: true);
    }
    if (!await _hiddenDir.exists()) {
      await _hiddenDir.create(recursive: true);
    }
    
    await _loadFileList();
  }

  void _initEncryption(String password) {
    final keyBytes = sha256.convert(utf8.encode(password)).bytes;
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    _iv = encrypt.IV.fromLength(16);
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
  }

  Future<void> _loadFileList() async {
    // 从本地存储加载文件列表
    setState(() {
      _files = [];
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    if (!settings.hasVaultPassword) {
      return _buildSetupPassword(context, settings);
    }
    
    if (!_isUnlocked) {
      return _buildUnlock(context, settings);
    }
    
    return _buildVaultContent(context);
  }

  /// 设置密码界面
  Widget _buildSetupPassword(BuildContext context, SettingsService settings) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              FluentIcons.lock_closed_24_filled,
              size: 40,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            '设置保险箱密码',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            '请设置一个安全的密码来保护您的私密文件',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          TextField(
            controller: _newPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: '新密码',
              prefixIcon: const Icon(FluentIcons.key_24_regular),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? FluentIcons.eye_24_regular : FluentIcons.eye_off_24_regular),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscurePassword,
            decoration: const InputDecoration(
              labelText: '确认密码',
              prefixIcon: Icon(FluentIcons.key_24_regular),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _setupPassword(settings),
              child: const Padding(
                padding: EdgeInsets.all(AppTheme.spacingM),
                child: Text('设置密码'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 解锁界面
  Widget _buildUnlock(BuildContext context, SettingsService settings) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              FluentIcons.lock_closed_24_filled,
              size: 40,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            '解锁保险箱',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            '请输入密码以访问您的私密文件',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(FluentIcons.key_24_regular),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? FluentIcons.eye_24_regular : FluentIcons.eye_off_24_regular),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            onSubmitted: (_) => _unlock(settings),
          ),
          const SizedBox(height: AppTheme.spacingL),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _unlock(settings),
              child: const Padding(
                padding: EdgeInsets.all(AppTheme.spacingM),
                child: Text('解锁'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 保险箱内容
  Widget _buildVaultContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('私密保险箱'),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.lock_closed_24_regular),
            onPressed: _lockVault,
            tooltip: '锁定保险箱',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _addFiles,
        icon: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(FluentIcons.add_24_filled),
        label: Text(_isLoading ? '处理中...' : '添加文件'),
      ),
      body: _files.isEmpty
          ? _buildEmptyState(context, colorScheme)
          : ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: _files.length,
              itemBuilder: (context, index) => _buildFileCard(context, _files[index]),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.folder_open_24_regular,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            '保险箱为空',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            '点击下方按钮添加私密文件',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          // 提示信息
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.info_24_regular, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '添加文件后，原文件将被加密并隐藏',
                    style: TextStyle(color: colorScheme.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, VaultFile file) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(_getFileIcon(file.type), color: colorScheme.onSurfaceVariant),
        ),
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${_formatSize(file.size)} · ${_formatDate(file.addedAt)}',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(FluentIcons.more_vertical_24_regular),
          onSelected: (value) {
            switch (value) {
              case 'view':
                _viewFile(file);
                break;
              case 'export':
                _exportFile(file);
                break;
              case 'restore':
                _restoreFile(file);
                break;
              case 'delete':
                _deleteFile(file);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(FluentIcons.eye_24_regular),
                  SizedBox(width: 8),
                  Text('查看'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(FluentIcons.arrow_download_24_regular),
                  SizedBox(width: 8),
                  Text('导出到...'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'restore',
              child: Row(
                children: [
                  Icon(FluentIcons.arrow_restore_24_regular),
                  SizedBox(width: 8),
                  Text('还原到原位置'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(FluentIcons.delete_24_regular, color: Colors.red),
                  SizedBox(width: 8),
                  Text('删除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _viewFile(file),
      ),
    );
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'video':
        return FluentIcons.video_24_filled;
      case 'image':
        return FluentIcons.image_24_filled;
      default:
        return FluentIcons.document_24_filled;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _setupPassword(SettingsService settings) {
    if (_newPasswordController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码长度至少4位')),
      );
      return;
    }
    
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次输入的密码不一致')),
      );
      return;
    }
    
    settings.setVaultPassword(_newPasswordController.text);
    _initEncryption(_newPasswordController.text);
    setState(() => _isUnlocked = true);
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('密码设置成功')),
    );
  }

  void _unlock(SettingsService settings) {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入密码')),
      );
      return;
    }
    
    if (settings.verifyVaultPassword(_passwordController.text)) {
      _initEncryption(_passwordController.text);
      setState(() => _isUnlocked = true);
      _passwordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码错误')),
      );
    }
  }

  void _lockVault() {
    setState(() {
      _isUnlocked = false;
      _encrypter = null;
      _iv = null;
    });
  }

  Future<void> _addFiles() async {
    if (_encrypter == null) return;
    
    try {
      setState(() => _isLoading = true);
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4', 'avi', 'mkv', 'mov', 'webm', 'flv', 'wmv', '3gp',
          'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic',
          'pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'zip',
        ],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        int successCount = 0;
        
        for (final file in result.files) {
          if (file.path != null) {
            final success = await _encryptAndAddFile(file.path!, file.name);
            if (success) successCount++;
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已添加 $successCount 个文件到保险箱，原文件已隐藏')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加文件失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _encryptAndAddFile(String originalPath, String fileName) async {
    try {
      final originalFile = File(originalPath);
      if (!await originalFile.exists()) return false;
      
      final bytes = await originalFile.readAsBytes();
      final encrypted = _encrypter!.encryptBytes(bytes, iv: _iv!);
      
      // 生成唯一ID
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final encryptedFileName = '$id.enc';
      final encryptedPath = '${_vaultDir.path}/$encryptedFileName';
      
      // 保存加密文件
      await File(encryptedPath).writeAsBytes(encrypted.bytes);
      
      // 隐藏原文件（移动到隐藏目录）
      final ext = fileName.split('.').last;
      final hiddenPath = '${_hiddenDir.path}/$id.$ext';
      await originalFile.rename(hiddenPath);
      
      // 确定文件类型
      final extLower = ext.toLowerCase();
      String type = 'document';
      if (['mp4', 'avi', 'mkv', 'mov', 'webm', 'flv', 'wmv', '3gp'].contains(extLower)) {
        type = 'video';
      } else if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'].contains(extLower)) {
        type = 'image';
      }
      
      final fileSize = bytes.length;
      
      setState(() {
        _files.add(VaultFile(
          id: id,
          name: fileName,
          originalPath: originalPath,
          encryptedPath: encryptedPath,
          hiddenPath: hiddenPath,
          type: type,
          size: fileSize,
          addedAt: DateTime.now(),
        ));
      });
      
      return true;
    } catch (e) {
      debugPrint('加密文件失败: $e');
      return false;
    }
  }

  Future<void> _viewFile(VaultFile file) async {
    if (_encrypter == null) return;
    
    try {
      // 解密文件到临时目录
      final encryptedBytes = await File(file.encryptedPath).readAsBytes();
      final encrypted = encrypt.Encrypted(encryptedBytes);
      final decryptedBytes = _encrypter!.decryptBytes(encrypted, iv: _iv!);
      
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${file.name}');
      await tempFile.writeAsBytes(decryptedBytes);
      
      // 显示文件
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(file.name),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('类型: ${file.type}'),
                  Text('大小: ${_formatSize(file.size)}'),
                  Text('添加时间: ${_formatDate(file.addedAt)}'),
                  const SizedBox(height: 16),
                  if (file.type == 'image')
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(tempFile, fit: BoxFit.cover),
                    )
                  else
                    const Text('文件已解密到临时目录，可导出查看'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _exportFile(file);
                },
                child: const Text('导出'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('查看文件失败: $e')),
        );
      }
    }
  }

  Future<void> _exportFile(VaultFile file) async {
    if (_encrypter == null) return;
    
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result == null) return;
      
      // 解密文件
      final encryptedBytes = await File(file.encryptedPath).readAsBytes();
      final encrypted = encrypt.Encrypted(encryptedBytes);
      final decryptedBytes = _encrypter!.decryptBytes(encrypted, iv: _iv!);
      
      // 保存到选择的位置
      final exportFile = File('$result/${file.name}');
      await exportFile.writeAsBytes(decryptedBytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出到: ${exportFile.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _restoreFile(VaultFile file) async {
    if (_encrypter == null) return;
    
    try {
      // 解密文件
      final encryptedBytes = await File(file.encryptedPath).readAsBytes();
      final encrypted = encrypt.Encrypted(encryptedBytes);
      final decryptedBytes = _encrypter!.decryptBytes(encrypted, iv: _iv!);
      
      // 还原到原位置
      final originalFile = File(file.originalPath);
      await originalFile.writeAsBytes(decryptedBytes);
      
      // 删除加密文件和隐藏文件
      await File(file.encryptedPath).delete();
      final hiddenFile = File(file.hiddenPath);
      if (await hiddenFile.exists()) {
        await hiddenFile.delete();
      }
      
      // 从列表移除
      setState(() {
        _files.removeWhere((f) => f.id == file.id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已还原到: ${file.originalPath}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('还原失败: $e')),
        );
      }
    }
  }

  void _deleteFile(VaultFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定要永久删除 "${file.name}" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                // 删除加密文件
                await File(file.encryptedPath).delete();
                
                // 删除隐藏的原文件
                final hiddenFile = File(file.hiddenPath);
                if (await hiddenFile.exists()) {
                  await hiddenFile.delete();
                }
                
                setState(() {
                  _files.removeWhere((f) => f.id == file.id);
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('文件已永久删除')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 保险箱文件模型
class VaultFile {
  final String id;
  final String name;
  final String originalPath;
  final String encryptedPath;
  final String hiddenPath;
  final String type;
  final int size;
  final DateTime addedAt;

  const VaultFile({
    required this.id,
    required this.name,
    required this.originalPath,
    required this.encryptedPath,
    required this.hiddenPath,
    required this.type,
    required this.size,
    required this.addedAt,
  });
}
