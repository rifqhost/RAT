import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../core/controller_state.dart';
import '../../theme.dart';

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  StreamSubscription? _connSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribe();
    });
  }

  void _subscribe() {
    final controller = context.read<ControllerState>();
    _connSub?.cancel();
    _connSub = controller.rtc?.connectionState.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerState>();
    final renderer = controller.remoteRenderer;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        title: Text('${controller.sessionPermissions.contains('SCREEN') ? 'Remote Screen' : 'Session'} · Connected',
            style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            tooltip: 'End session',
            icon: const Icon(Icons.call_end, color: AppTheme.danger),
            onPressed: () => _confirmEnd(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (renderer != null && controller.sessionPermissions.contains('SCREEN'))
                  Container(
                    color: Colors.black,
                    child: RTCVideoView(renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                  )
                else
                  const _NoStream(),
                if (controller.sessionPermissions.contains('SCREEN') && renderer != null)
                  Positioned.fill(child: _TouchOverlay()),
              ],
            ),
          ),
          _BottomToolbar(controller: controller, onEnd: () => _confirmEnd(context)),
        ],
      ),
    );
  }

  Future<void> _confirmEnd(BuildContext context) async {
    final controller = context.read<ControllerState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End session?'),
        content: const Text('This will disconnect the agent immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.stopSession(reason: 'controller_stop');
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _NoStream extends StatelessWidget {
  const _NoStream();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Waiting for the agent\u2019s screen stream...', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Gesture overlay that translates touches into normalized coordinates
/// over the remote video.
class _TouchOverlay extends StatefulWidget {
  const _TouchOverlay();

  @override
  State<_TouchOverlay> createState() => _TouchOverlayState();
}

class _TouchOverlayState extends State<_TouchOverlay> {
  @override
  Widget build(BuildContext context) {
    final controller = context.read<ControllerState>();
    return Listener(
      onPointerDown: (e) {
        if (!controller.sessionPermissions.contains('TOUCH')) {
          _showTouchUnsupported(context);
          return;
        }
        _send(context, 'touch_down', e.localPosition);
      },
      onPointerMove: (e) {
        if (!controller.sessionPermissions.contains('TOUCH')) return;
        _send(context, 'touch_move', e.localPosition);
      },
      onPointerUp: (e) {
        if (!controller.sessionPermissions.contains('TOUCH')) return;
        _send(context, 'touch_up', e.localPosition);
      },
      child: GestureDetector(
        onTap: () {
          if (!controller.sessionPermissions.contains('TOUCH')) {
            _showTouchUnsupported(context);
          }
        },
        onDoubleTap: () {
          if (controller.sessionPermissions.contains('TOUCH')) {
            _send(context, 'tap', Offset.zero);
          }
        },
        child: Container(color: Colors.transparent),
      ),
    );
  }

  void _send(BuildContext context, String type, Offset pos) {
    final controller = context.read<ControllerState>();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.width == 0 || box.size.height == 0) return;
    final nx = (pos.dx / box.size.width).clamp(0.0, 1.0);
    final ny = (pos.dy / box.size.height).clamp(0.0, 1.0);
    controller.sendTouch(
      eventType: type,
      x: nx,
      y: ny,
      screenWidth: box.size.width.round(),
      screenHeight: box.size.height.round(),
    );
  }

  void _showTouchUnsupported(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Touch control was not granted by the agent.')),
    );
  }
}

class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({required this.controller, required this.onEnd});
  final ControllerState controller;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final perms = controller.sessionPermissions;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolButton(icon: Icons.arrow_back, label: 'Back', onTap: () => controller.sendControl('NAV_BACK')),
          _ToolButton(icon: Icons.home, label: 'Home', onTap: () => controller.sendControl('NAV_HOME')),
          _ToolButton(icon: Icons.apps, label: 'Recent', onTap: () => controller.sendControl('NAV_RECENTS')),
          _ToolButton(
            icon: Icons.keyboard,
            label: 'Text',
            onTap: () => _showKeyboard(context),
          ),
          if (perms.contains('CAMERA'))
            _ToolButton(
              icon: Icons.photo_camera,
              label: 'Camera',
              onTap: () {
                controller.sendControl('CAMERA_ON');
              },
            ),
          if (perms.contains('FILES'))
            _ToolButton(
              icon: Icons.folder,
              label: 'Files',
              onTap: () => _showFilePicker(context),
            ),
          if (perms.contains('MICROPHONE'))
            _ToolButton(
              icon: Icons.mic,
              label: 'Mic',
              toggled: false,
              onTap: () => _showMicMenu(context),
            ),
          _ToolButton(icon: Icons.close, label: 'End', danger: true, onTap: onEnd),
        ],
      ),
    );
  }

  void _showKeyboard(BuildContext context) {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remote Keyboard'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Text to type on the agent'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textController.text;
              if (text.isNotEmpty) {
                controller.sendControl('TEXT_INPUT', text);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showMicMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mic, color: AppTheme.success),
              title: const Text('Turn on microphone'),
              onTap: () {
                controller.sendControl('MIC_ON');
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_off, color: AppTheme.danger),
              title: const Text('Turn off microphone'),
              onTap: () {
                controller.sendControl('MIC_OFF');
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFilePicker(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Select a file in the Files tab to send it to the agent.')),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.toggled,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppTheme.danger
        : (toggled == true ? AppTheme.success : AppTheme.textPrimary);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}