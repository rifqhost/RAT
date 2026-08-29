import 'package:flutter/material.dart';
import '../../core/controller_state.dart';
import '../../core/models.dart';
import '../../core/protocol.dart';
import '../../theme.dart';

/// Shared helpers for dashboard UI.
class DashboardComponents {
  static Gradient deviceBg(int index) {
    const gradients = [
      AppTheme.accentGradient,
      LinearGradient(colors: [Color(0xFF35E0A1), Color(0xFF13B78A)]),
      LinearGradient(colors: [Color(0xFFFF8A5C), Color(0xFFE85D75)]),
      LinearGradient(colors: [Color(0xFF4FB8FF), Color(0xFF6E5BFF)]),
    ];
    return gradients[index % gradients.length];
  }

  /// Opens the permission picker then requests a remote session.
  static Future<void> requestSession(BuildContext context, ControllerState controller, Device device) async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PermissionSheet(),
    );
    if (selected == null || selected.isEmpty) return;
    if (!context.mounted) return;
    await controller.requestSession(device, permissions: selected);
  }
}

class _PermissionSheet extends StatefulWidget {
  const _PermissionSheet();

  static IconData icon(String perm) {
    switch (perm) {
      case 'SCREEN':
        return Icons.screen_share;
      case 'TOUCH':
        return Icons.touch_app;
      case 'CAMERA':
        return Icons.camera_alt;
      case 'MICROPHONE':
        return Icons.mic;
      case 'FILES':
        return Icons.folder_copy;
      case 'CLIPBOARD':
        return Icons.content_paste;
      default:
        return Icons.info_outline;
    }
  }

  @override
  State<_PermissionSheet> createState() => _PermissionSheetState();
}

class _PermissionSheetState extends State<_PermissionSheet> {
  final Set<String> _selected = {...Permissions.all};

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Request remote access', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('The agent must approve each permission.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          for (final perm in Permissions.all)
            CheckboxListTile(
              value: _selected.contains(perm),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selected.add(perm);
                } else {
                  _selected.remove(perm);
                }
              }),
              title: Text(Permissions.label(perm)),
              secondary: Icon(_PermissionSheet.icon(perm), color: AppTheme.accent),
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(_selected.toList()),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }
}