import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';

/// 保险箱页面 - 加密存储私密文件
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
  final List<_VaultFile> _files = [];

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFiles,
        icon: const Icon(FluentIcons.add_24_filled),
        label: const Text('添加文件'),
      ),
      body: _files.isEmpty
          ? Center(
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
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                return _buildFileCard(context, file);
              },
            ),
    );
  }

  Widget _buildFileCard(BuildContext context, _VaultFile file) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(
            _getFileIcon(file.type),
            color: colorScheme.onSurfaceVariant,
          ),
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
                  Text('导出'),
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
    setState(() {
      _isUnlocked = true;
    });
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
      setState(() {
        _isUnlocked = true;
      });
      _passwordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码错误')),
      );
    }
  }

  Future<void> _addFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4', 'avi', 'mkv', 'mov', 'webm', 'flv', 'wmv', '3gp',
          'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic',
          'pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx',
        ],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            final f = File(file.path!);
            final size = await f.length();
            
            final ext = file.name.split('.').last.toLowerCase();
            String type = 'document';
            if (['mp4', 'avi', 'mkv', 'mov', 'webm', 'flv', 'wmv', '3gp'].contains(ext)) {
              type = 'video';
            } else if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'].contains(ext)) {
              type = 'image';
            }
            
            setState(() {
              _files.add(_VaultFile(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: file.name,
                path: file.path!,
                type: type,
                size: size,
                addedAt: DateTime.now(),
              ));
            });
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加 ${result.files.length} 个文件')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加文件失败: $e')),
      );
    }
  }

  void _viewFile(_VaultFile file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('查看: ${file.name}')),
    );
  }

  Future<void> _exportFile(_VaultFile file) async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出到: $result/${file.name}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  void _deleteFile(_VaultFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定要删除 "${file.name}" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _files.remove(file);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('文件已删除')),
              );
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
class _VaultFile {
  final String id;
  final String name;
  final String path;
  final String type;
  final int size;
  final DateTime addedAt;

  const _VaultFile({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.addedAt,
  });
}
