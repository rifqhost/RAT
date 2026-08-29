import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarBack(title: 'Security'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    NeonBadge(label: 'ENCRYPTED', color: AppTheme.success, icon: Icons.lock),
                    SizedBox(width: 10),
                    NeonBadge(label: 'AUTHENTICATED', color: AppTheme.accent, icon: Icons.verified),
                  ],
                ),
                SizedBox(height: 16),
                _SecurityRow('Transport', 'TLS/HTTPS + WSS to signaling server'),
                _SecurityRow('WebRTC', 'DTLS-SRTP end-to-end for media'),
                _SecurityRow('Tokens', 'Short-lived device + session tokens with rotation'),
                _SecurityRow('Pairing', 'Random 6-digit codes, short-lived and one-time use'),
                _SecurityRow('Sessions', 'Explicit agent approval with granular permissions'),
                _SecurityRow('Revoke', 'Agent can revoke any permission instantly'),
                _SecurityRow('Storage', 'No screen recordings or call audio stored'),
              ],
            ),
          ),
          SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your control is consent-based', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text(
                  'RMODZ Remote only operates while the agent device has granted access. '
                  'The agent shows a clear live indicator while a session is active and can '
                  'terminate it or revoke individual permissions at any time.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}