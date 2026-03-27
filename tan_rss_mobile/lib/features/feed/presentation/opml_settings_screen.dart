import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/feed_repository.dart';

class OpmlSettingsScreen extends ConsumerStatefulWidget {
  const OpmlSettingsScreen({super.key});

  @override
  ConsumerState<OpmlSettingsScreen> createState() => _OpmlSettingsScreenState();
}

class _OpmlSettingsScreenState extends ConsumerState<OpmlSettingsScreen> {
  bool _isImporting = false;
  bool _isExporting = false;

  Future<void> _importOpml() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['opml', 'xml'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();

      setState(() => _isImporting = true);

      final repository = ref.read(feedRepositoryProvider);
      final importResult = await repository.importOpml(content);

      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入结果'),
          content: Text('成功导入: ${importResult.imported}\n跳过: ${importResult.skipped}\n错误: ${importResult.errors.length}'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _exportOpml() async {
    setState(() => _isExporting = true);
    try {
      final repository = ref.read(feedRepositoryProvider);
      final content = await repository.exportOpmlText();

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/tan_rss_export.opml');
      await file.writeAsString(content);

      if (!mounted) return;

      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'TAN RSS 订阅源导出',
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入/导出'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OPML 导入',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('从其他 RSS 阅读器导入订阅源。支持 .opml 或 .xml 文件格式。'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isImporting ? null : _importOpml,
                      icon: _isImporting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file),
                      label: Text(_isImporting ? '导入中...' : '选择文件并导入'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OPML 导出',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('将当前的订阅源导出为 OPML 格式，以便在其他阅读器中使用。'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _isExporting ? null : _exportOpml,
                      icon: _isExporting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.download),
                      label: Text(_isExporting ? '导出中...' : '导出并分享'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}