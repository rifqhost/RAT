import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/agent_state.dart';
import '../../../theme.dart';

class PairingPanel extends StatelessWidget {
  const PairingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentState>();
    final code = agent.pairingCode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2, color: Colors.white),
              const SizedBox(width: 8),
              Text('Pair with a controller', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Generate a 6-digit code and give it to the person helping you. They enter it on their controller app to pair.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          if (code == null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.accent,
                ),
                onPressed: agent.canPair ? () => agent.requestPairingCode() : null,
                child: const Text('Generate pairing code'),
              ),
            ),
          ] else ...[
            // Display the code
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    agent.pairingExpiresIn != null ? 'Valid for ${agent.pairingExpiresIn} seconds' : 'Share this code',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: agent.canPair ? () => agent.requestPairingCode() : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Generate a new code'),
            ),
          ],
        ],
      ),
    );
  }
}
