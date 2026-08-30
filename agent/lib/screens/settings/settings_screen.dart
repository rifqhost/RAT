import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';
import '../../core/agent_state.dart';
import '../../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Server', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _tile(context, 'Signaling server', AppConfig.baseUrlDisplay),
              const Divider(),
              Text('Auto-pair & Auto-accept', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _switchTile(
                context,
                'Auto-accept sessions from paired controllers',
                'When enabled, sessions from QR-paired controllers start automatically without confirmation.',
                agent.autoAcceptSessions,
                (val) => agent.setAutoAcceptSessions(val),
              ),
              const Divider(),
              Text('About this device', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _tile(context, 'Device id', agent.deviceId ?? '—'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _switchTile(BuildContext context, String label, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
