import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/agent_state.dart';
import '../../../theme.dart';

class PairingPanel extends StatelessWidget {
  const PairingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentState>();
    final code = agent.pairingCode;
    final deviceId = agent.deviceId;
    final deviceToken = agent.deviceToken;

    String? qrData;
    if (deviceId != null && deviceToken != null) {
      qrData = jsonEncode({
        'type': 'rmodz-pair',
        'deviceId': deviceId,
        'token': deviceToken,
      });
    }

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
            'Scan the QR code with the Controller app, or generate a 6-digit code to enter manually.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          // QR Code section
          if (qrData != null) ...[
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan with Controller app',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deviceId ?? '',
                    style: TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Manual pairing code section
          if (code == null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.accent,
                ),
                onPressed: agent.canPair ? () => agent.requestPairingCode() : null,
                child: const Text('Generate pairing code (manual)'),
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
