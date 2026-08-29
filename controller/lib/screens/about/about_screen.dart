import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarBack(title: 'About'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(26)),
              child: const Icon(Icons.podcasts, color: Colors.white, size: 46),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('RMODZ REMOTE', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.textPrimary)),
          ),
          const SizedBox(height: 4),
          Center(child: Text('Controller · v1.0.0', style: Theme.of(context).textTheme.bodyMedium)),
          const SizedBox(height: 24),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What this is', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'RMODZ Remote is a consent-based Android remote-support system. '
                  'This Controller app connects to RMODZ Remote Agent devices to provide '
                  'technical support: live screen viewing, guided touch, camera/microphone, '
                  'file transfer and clipboard sync — each guarded by explicit permission '
                  'approval on the agent.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
                ),
                const Divider(height: 28),
                Text('Architecture', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const _ArchRow('Controller', 'This app — Flutter, gestures + signaling'),
                const _ArchRow('Agent', 'Flutter + native MediaProjection & Accessibility'),
                const _ArchRow('Server', 'Node.js signaling, pairing, auth, sessions'),
                const _ArchRow('Media', 'WebRTC peer-to-peer (DTLS-SRTP), TURN fallback'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Text(
              'Open-source under the MIT License. RMODZ Remote performs no hidden operations. '
              'All access requires explicit user permission and can be revoked at any time.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchRow extends StatelessWidget {
  const _ArchRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        ],
      ),
    );
  }
}