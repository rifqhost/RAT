import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/agent_state.dart';
import '../../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              Text('About this device', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _tile(context, 'Device id', context.read<AgentState>().deviceId ?? '—'),
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
}
