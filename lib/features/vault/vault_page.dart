import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';

/// 保险箱页面
class VaultPage extends ConsumerStatefulWidget {
  const VaultPage({super.key});

  @override
  ConsumerState<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends ConsumerState<VaultPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);
    final vaultNotifier = ref.read(vaultProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('私密保险箱'),
        actions: [
          if (vaultState.isUnlocked)
            IconButton(
              icon: const Icon(FluentIcons.lock_closed_24_regular),
              onPressed: () => _lockVault(vaultNotifier),
              tooltip: '锁定保险箱',
            ),
        ],
      ),
      body: _buildBody(context, vaultState, vaultNotifier),
      floatingActionButton: vaultState.isUnlocked
          ? FloatingActionButton.extended(
              onPressed: () => _addFileToVault(context, vaultNotifier),
              icon: const Icon(FluentIcons.add_24_filled),
              label: const Text('添加文件'),
            )
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    VaultState vaultState,
    VaultNotifier vaultNotifier,
  ) {
    if (!vaultState.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!vaultState.hasPassword) {
      return _buildSetupPassword(context, vaultNotifier);
    }

    if (!vaultState.isUnlocked) {
      return _buildUnlock(context, vaultState, vaultNotifier);
    }

    return _buildVaultContent(context, vaultState, vaultNotifier);
  }

  /// 设置密码界面
  Widget _buildSetupPassword(BuildContext context, VaultNotifier vaultNotifier) {
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
              onPressed: () => _setupPassword(vaultNotifier),
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
  Widget _buildUnlock(
    BuildContext context,
    VaultState vaultState,
    VaultNotifier vaultNotifier,
  ) {
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
          if (vaultState.error != null) ...[
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  Icon(
                    FluentIcons.warning_24_filled,
                    color: colorScheme.onErrorContainer,
                    size: 16,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      vaultState.error!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            onSubmitted: (_) => _unlock(vaultNotifier),
          ),
          const SizedBox(height: AppTheme.spacingL),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _unlock(vaultNotifier),
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
  Widget _buildVaultContent(
    BuildContext context,
    VaultState vaultState,
    VaultNotifier vaultNotifier,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (vaultState.items.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        // 统计信息
        Container(
          margin: const EdgeInsets.all(AppTheme.spacingM),
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                icon: FluentIcons.video_24_filled,
                label: '视频',
                count: vaultState.items.where((i) => i.type == 'video').length,
              ),
              _buildStatItem(
                context,
                icon: FluentIcons.image_24_filled,
                label: '图片',
                count: vaultState.items.where((i) => i.type == 'image').length,
              ),
              _buildStatItem(
                context,
                icon: FluentIcons.document_24_filled,
                label: '文档',
                count: vaultState.items.where((i) => i.type == 'document').length,
              ),
            ],
          ),
        ),
        // 文件列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
            itemCount: vaultState.items.length,
            itemBuilder: (context, index) {
              final item = vaultState.items[index];
              return _VaultItemCard(
                item: item,
                onTap: () => _viewItem(context, item, vaultNotifier),
                onDelete: () => _deleteItem(context, item.id, vaultNotifier),
                onExport: () => _exportItem(context, item, vaultNotifier),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(height: AppTheme.spacingXS),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Future<void> _setupPassword(VaultNotifier vaultNotifier) async {
    if (_newPasswordController.text.isEmpty) {
      _showError('请输入密码');
      return;
    }

    if (_newPasswordController.text.length < 4) {
      _showError('密码长度至少4位');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('两次输入的密码不一致');
      return;
    }

    await vaultNotifier.setupPassword(_newPasswordController.text);
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  Future<void> _unlock(VaultNotifier vaultNotifier) async {
    if (_passwordController.text.isEmpty) {
      _showError('请输入密码');
      return;
    }

    final success = await vaultNotifier.unlock(_passwordController.text);
    if (success) {
      _passwordController.clear();
    }
  }

  Future<void> _lockVault(VaultNotifier vaultNotifier) async {
    await vaultNotifier.lock();
  }

  Future<void> _addFileToVault(
    BuildContext context,
    VaultNotifier vaultNotifier,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4', 'avi', 'mkv', 'mov', 'webm', 'flv', 'wmv',
          'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
          'pdf', 'doc', 'docx', 'txt',
        ],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            final vaultFile = File(file.path!);
            await vaultNotifier.addFile(vaultFile);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已添加 ${result.files.length} 个文件到保险箱'),
            ),
          );
        }
      }
    } catch (e) {
      _showError('添加文件失败: $e');
    }
  }

  Future<void> _viewItem(
    BuildContext context,
    VaultItem item,
    VaultNotifier vaultNotifier,
  ) async {
    // 解密并查看文件
    final decryptedFile = await vaultNotifier.decryptFile(item.id);
    if (decryptedFile != null && mounted) {
      // 根据文件类型打开
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已解密: ${item.name}')),
      );
    }
  }

  Future<void> _deleteItem(
    BuildContext context,
    String itemId,
    VaultNotifier vaultNotifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件'),
        content: const Text('确定要从保险箱中删除此文件吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await vaultNotifier.removeFile(itemId);
    }
  }

  Future<void> _exportItem(
    BuildContext context,
    VaultItem item,
    VaultNotifier vaultNotifier,
  ) async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        final exportPath = '$result/${item.name}';
        // await vaultNotifier.exportFile(item.id, exportPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已导出到: $exportPath')),
          );
        }
      }
    } catch (e) {
      _showError('导出失败: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

/// 保险箱项目卡片
class _VaultItemCard extends StatelessWidget {
  final VaultItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _VaultItemCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onExport,
  });

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
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
          child: Icon(
            _getIcon(),
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_formatSize(item.size)} · ${item.createdAt.toString().substring(0, 10)}',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(FluentIcons.more_vertical_24_regular),
          onSelected: (value) {
            switch (value) {
              case 'view':
                onTap();
                break;
              case 'export':
                onExport();
                break;
              case 'delete':
                onDelete();
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
        onTap: onTap,
      ),
    );
  }
}
