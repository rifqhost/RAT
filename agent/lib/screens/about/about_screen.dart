import 'package:flutter/material.dart';
import '../../config.dart';
import '../../theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(22)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.smartphone, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Text(AppConfig.appName, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Version ${AppConfig.appVersion}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    const Text('Consent-based remote help agent', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('How it works', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'This app turns your device into a remote-help agent. A trusted controller pairs with your device '
                'using a 6-digit code, then requests a session. You review exactly what they can access, grant or '
                'deny each permission, and can end or revoke access at any time. Nothing runs without your explicit '
                'consent.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
