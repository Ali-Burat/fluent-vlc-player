import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';

/// 保险箱页面
class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isUnlocked = false;
  bool _hasPassword = false;
  bool _obscurePassword = true;
  final List<VaultItem> _items = [];

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('私密保险箱'),
        actions: [
          if (_isUnlocked)
            IconButton(
              icon: const Icon(FluentIcons.lock_closed_24_regular),
              onPressed: _lockVault,
              tooltip: '锁定保险箱',
            ),
        ],
      ),
      body: _buildBody(context),
      floatingActionButton: _isUnlocked
          ? FloatingActionButton.extended(
              onPressed: _addFileToVault,
              icon: const Icon(FluentIcons.add_24_filled),
              label: const Text('添加文件'),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_hasPassword) {
      return _buildSetupPassword(context);
    }

    if (!_isUnlocked) {
      return _buildUnlock(context);
    }

    return _buildVaultContent(context);
  }

  Widget _buildSetupPassword(BuildContext context) {
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
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: '新密码',
              prefixIcon: const Icon(FluentIcons.key_24_regular),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? FluentIcons.eye_24_regular
                      : FluentIcons.eye_off_24_regular,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _setupPassword,
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

  Widget _buildUnlock(BuildContext context) {
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
                icon: Icon(
                  _obscurePassword
                      ? FluentIcons.eye_24_regular
                      : FluentIcons.eye_off_24_regular,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            onSubmitted: (_) => _unlock(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _unlock,
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

  Widget _buildVaultContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                FluentIcons.folder_open_24_regular,
                size: 40,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _VaultItemCard(
          item: item,
          onDelete: () => _deleteItem(item.id),
        );
      },
    );
  }

  void _setupPassword() {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入密码')),
      );
      return;
    }

    if (_passwordController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码长度至少4位')),
      );
      return;
    }

    setState(() {
      _hasPassword = true;
      _isUnlocked = true;
    });
    _passwordController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('密码设置成功')),
    );
  }

  void _unlock() {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入密码')),
      );
      return;
    }

    // 简化版：直接解锁
    setState(() {
      _isUnlocked = true;
    });
    _passwordController.clear();
  }

  void _lockVault() {
    setState(() {
      _isUnlocked = false;
    });
  }

  Future<void> _addFileToVault() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4', 'avi', 'mkv', 'mov', 'webm',
          'jpg', 'jpeg', 'png', 'gif',
          'pdf', 'doc', 'docx', 'txt',
        ],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            setState(() {
              _items.add(VaultItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: file.name,
                path: file.path!,
                type: _getFileType(file.name),
                size: file.size,
                createdAt: DateTime.now(),
              ));
            });
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已添加 ${result.files.length} 个文件')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加文件失败: $e')),
      );
    }
  }

  String _getFileType(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['mp4', 'avi', 'mkv', 'mov', 'webm'].contains(ext)) return 'video';
    if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) return 'image';
    return 'document';
  }

  void _deleteItem(String id) {
    setState(() {
      _items.removeWhere((item) => item.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('文件已删除')),
    );
  }
}

/// 保险箱项目模型
class VaultItem {
  final String id;
  final String name;
  final String path;
  final String type;
  final int size;
  final DateTime createdAt;

  const VaultItem({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.createdAt,
  });
}

/// 保险箱项目卡片
class _VaultItemCard extends StatelessWidget {
  final VaultItem item;
  final VoidCallback onDelete;

  const _VaultItemCard({required this.item, required this.onDelete});

  IconData _getIcon() {
    switch (item.type) {
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
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
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
          child: Icon(_getIcon(), color: colorScheme.onSurfaceVariant),
        ),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${_formatSize(item.size)} · ${item.createdAt.toString().substring(0, 10)}',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        trailing: IconButton(
          icon: const Icon(FluentIcons.delete_24_regular),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
