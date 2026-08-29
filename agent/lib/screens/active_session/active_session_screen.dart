import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/agent_state.dart';
import '../../core/protocol.dart';
import '../../theme.dart';

class ActiveSessionScreen extends StatelessWidget {
  const ActiveSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active session'),
        leading: const SizedBox(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.record_voice_over, color: AppTheme.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'A controller is connected to this device.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.success),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Granted permissions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final p in Permissions.all)
                      if (agent.permissions.contains(p))
                        _PermissionRow(permission: p, agent: agent),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
                onPressed: () => _confirmEnd(context, agent),
                icon: const Icon(Icons.stop_circle),
                label: const Text('End session'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmEnd(BuildContext context, AgentState agent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End session?'),
        content: const Text('The controller will lose access to this device immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      agent.endSession(reason: 'Ended by agent');
    }
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.permission, required this.agent});
  final String permission;
  final AgentState agent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Icon(permission == 'TOUCH' ? Icons.touch_app : permission == 'SCREEN' ? Icons.screen_share : Icons.lock_outline, color: AppTheme.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(Permissions.label(permission))),
          TextButton(
            onPressed: () => agent.revokePermission(permission),
            child: const Text('Revoke', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}
