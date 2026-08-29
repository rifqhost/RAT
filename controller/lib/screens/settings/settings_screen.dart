import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/controller_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../about/about_screen.dart';
import '../security/security_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerState>();
    final s = controller.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s?.user?['name'] as String? ?? 'RMODZ Controller',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(s?.user?['email'] as String? ?? '', style: Theme.of(context).textTheme.bodyMedium),
                      if (s?.deviceId != null) ...[
                        const SizedBox(height: 4),
                        Text('Device: ${s!.deviceId}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Connection'),
          GlassCard(
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.dns,
                  title: 'Server',
                  value: AppConfig.baseUrl,
                ),
                _SettingRow(
                  icon: Icons.speed,
                  title: 'Connection',
                  value: controller.connected ? 'Online' : 'Offline',
                  valueColor: controller.connected ? AppTheme.online : AppTheme.offline,
                ),
              ],
            ),
          ),
          const SectionHeader('App'),
          GlassCard(
            child: Column(
              children: [
                _NavRow(icon: Icons.security, title: 'Security', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SecurityScreen()))),
                _NavRow(icon: Icons.info_outline, title: 'About', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen()))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, side: const BorderSide(color: AppTheme.danger)),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text('Your device pairing and local session will be cleared.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sign out')),
                  ],
                ),
              );
              if (ok == true) {
                await context.read<ControllerState>().logout();
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title, required this.value, this.valueColor});
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accent),
      title: Text(title),
      subtitle: Text(value, style: TextStyle(color: valueColor ?? AppTheme.textSecondary)),
      dense: true,
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accent),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: onTap,
    );
  }
}