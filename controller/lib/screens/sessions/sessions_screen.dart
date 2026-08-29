import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/controller_state.dart';
import '../../core/models.dart';
import '../../core/protocol.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<SessionInfo> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller = context.read<ControllerState>();
    try {
      final list = await controller.api.getSessions();
      if (mounted) setState(() => _sessions = list);
    } catch (_) {
      if (mounted) setState(() => _sessions = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (controller.sessionActive) _ActiveSessionCard(controller: controller),
          const SectionHeader('History'),
          if (_loading)
            const LoadingIndicator(label: 'Loading sessions...')
          else if (_sessions.isEmpty)
            const EmptyState(icon: Icons.history, title: 'No sessions yet', subtitle: 'Connections you make with agent devices will appear here.')
          else
            ..._sessions.map((s) => _HistoryTile(s)),
        ],
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({required this.controller});
  final ControllerState controller;

  @override
  Widget build(BuildContext context) {
    final started = controller.sessionStartedAt;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const NeonBadge(label: 'SESSION ACTIVE', color: AppTheme.danger, icon: Icons.fiber_manual_record),
              const Spacer(),
              if (started != null)
                Text(_elapsed(started), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 14),
          Text('Session: ${controller.activeSessionId ?? ''}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: controller.sessionPermissions.map((p) {
              return NeonBadge(label: Permissions.label(p), color: AppTheme.online, icon: Icons.check);
            }).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, side: const BorderSide(color: AppTheme.danger)),
              onPressed: () async {
                await controller.stopSession(reason: 'controller_stop');
              },
              icon: const Icon(Icons.stop_circle),
              label: const Text('DISCONNECT'),
            ),
          ),
        ],
      ),
    );
  }

  static String _elapsed(DateTime started) {
    final d = DateTime.now().difference(started);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.s);
  final SessionInfo s;

  @override
  Widget build(BuildContext context) {
    final active = s.status == 'active';
    final color = active ? AppTheme.online : AppTheme.offline;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(active ? Icons.fiber_manual_record : Icons.history, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session ${s.id.substring(0, s.id.length.clamp(0, 8))}…', style: Theme.of(context).textTheme.titleMedium),
                Text('${s.status.toUpperCase()} · ${Permissions.all.where((p) => s.permissions.contains(p)).length} permissions',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}