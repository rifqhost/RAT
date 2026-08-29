import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/controller_state.dart';
import '../../core/file_transfer.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  FileTransferService? _service;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureService();
    });
  }

  void _ensureService() {
    final controller = context.read<ControllerState>();
    _service ??= FileTransferService(controller);
    _service!.refreshHandler();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerState>();
    final sessionActive = controller.sessionActive;
    final files = controller.sessionPermissions.contains('FILES');
    return Scaffold(
      appBar: AppBar(title: const Text('Files')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sessionActive && files
                        ? 'Files are transferred securely over the encrypted peer-to-peer channel.'
                        : 'Start a session with the FILES permission, then pick a file to send.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: (sessionActive && files) ? _pickAndSend : null,
            icon: const Icon(Icons.upload_file),
            label: const Text('Send File'),
          ),
          const SizedBox(height: 12),
          if (_service != null && (_service!.active.isNotEmpty || _service!.finished.isNotEmpty))
            ..._service!.active.map((t) => _TransferTile(t))
          else
            const EmptyState(icon: Icons.folder_open, title: 'No transfers yet', subtitle: 'Files you send will appear here with live progress.'),
          if (_service != null && _service!.finished.isNotEmpty) ...[
            const SectionHeader('History'),
            ..._service!.finished.take(5).map((t) => _TransferTile(t)),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndSend() async {
    final result = await FilePicker.pickFiles();
    if (result.isEmpty) return;
    final file = result.first;
    final path = file.path;
    if (path == null) return;
    await _service!.sendFile(path: path);
    if (mounted) setState(() {});
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile(this.t);
  final TransferProgress t;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (t.status) {
      TransferStatus.requesting => (Icons.hourglass_top, AppTheme.warning, 'Waiting for agent...'),
      TransferStatus.sending => (Icons.upload, AppTheme.accent, 'Sending...'),
      TransferStatus.complete => (Icons.check_circle, AppTheme.success, 'Complete'),
      TransferStatus.failed => (Icons.error, AppTheme.danger, t.error ?? 'Failed'),
      TransferStatus.cancelled => (Icons.cancel, AppTheme.offline, 'Cancelled'),
    };
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.fileName, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${_fmtBytes(t.transferred)} / ${_fmtBytes(t.fileSize)}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: t.fraction, minHeight: 5, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}