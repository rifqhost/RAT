import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/agent_state.dart';
import '../../theme.dart';
import '../about/about_screen.dart';
import '../security/security_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/dialogs.dart';
import 'widgets/pairing_panel.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentState>();
    _showPendingDialogs(context, agent);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, agent),
              const SizedBox(height: 20),
              const PairingPanel(),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _navTile(context, agent, Icons.verified_user_outlined, 'Security', const SecurityScreen()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _navTile(context, agent, Icons.settings_outlined, 'Settings', const SettingsScreen()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _navTile(context, agent, Icons.info_outline, 'About', const AboutScreen()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AgentState agent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.smartphone, color: AppTheme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RMODZ Agent', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    agent.deviceId ?? '—',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            _connectionBadge(agent.wsConnected),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sync, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  agent.wsConnected ? 'Connected to signaling server' : 'Connecting…',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _connectionBadge(bool online) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: online ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.offline.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? AppTheme.success : AppTheme.offline)),
          const SizedBox(width: 6),
          Text(online ? 'Online' : 'Offline', style: TextStyle(fontSize: 12, color: online ? AppTheme.success : AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _navTile(BuildContext context, AgentState agent, IconData icon, String label, Widget screen) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.accent),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }

  void _showPendingDialogs(BuildContext context, AgentState agent) {
    if (agent.pendingPair != null) {
      PairDialogs.showPairApproval(context, agent);
    } else if (agent.pendingSession != null) {
      PairDialogs.showSessionRequest(context, agent);
    }
  }
}
