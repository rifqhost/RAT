import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/agent_state.dart';
import '../../core/native_bridge.dart';
import '../../theme.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool? _accessibilityEnabled;

  @override
  void initState() {
    super.initState();
    _checkAccessibility();
  }

  Future<void> _checkAccessibility() async {
    final enabled = await NativeBridge.isAccessibilityEnabled();
    if (mounted) setState(() => _accessibilityEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _card(
                context,
                title: 'Remote control permissions',
                icon: Icons.security,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The controller can only use the permissions you grant during a session, and nothing else. '
                      'You can revoke access at any time during an active session.',
                    ),
                    const SizedBox(height: 12),
                    for (final p in const ['SCREEN', 'TOUCH', 'CAMERA', 'MICROPHONE', 'FILES', 'CLIPBOARD', 'DEVICE_INFO'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              p == 'TOUCH' ? Icons.touch_app : p == 'SCREEN' ? Icons.screen_share : p == 'FILES' ? Icons.folder_open : Icons.lock_outline,
                              size: 18,
                              color: AppTheme.accent,
                            ),
                            const SizedBox(width: 10),
                            Text(PermissionsLabel.map[p] ?? p),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _card(
                context,
                title: 'Accessibility service',
                icon: Icons.accessibility_new,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Touch control, navigation, and text input need the RMODZ accessibility service to be enabled. '
                      'This is required only for TOUCH-related features.',
                    ),
                    const SizedBox(height: 12),
                    if (_accessibilityEnabled == null)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        children: [
                          Icon(
                            _accessibilityEnabled! ? Icons.check_circle : Icons.error,
                            color: _accessibilityEnabled! ? AppTheme.success : AppTheme.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _accessibilityEnabled! ? 'Accessibility service is enabled' : 'Accessibility service is off',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await NativeBridge.openAccessibilitySettings();
                          if (!mounted) return;
                          await _checkAccessibility();
                        },
                        icon: const Icon(Icons.tune),
                        label: const Text('Open accessibility settings'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _card(
                context,
                title: 'Device identity',
                icon: Icons.badge_outlined,
                child: Row(
                  children: [
                    Expanded(
                      child: Text('This device (${agent.deviceId ?? '—'}) is a remote-helpable agent.',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class PermissionsLabel {
  static const map = {
    'SCREEN': 'Screen sharing',
    'TOUCH': 'Touch & navigation',
    'CAMERA': 'Camera',
    'MICROPHONE': 'Microphone',
    'FILES': 'File transfer',
    'CLIPBOARD': 'Clipboard',
    'DEVICE_INFO': 'Device info',
  };
}
