import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/controller_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'scan_qr_screen.dart';

class ConnectDeviceScreen extends StatefulWidget {
  const ConnectDeviceScreen({super.key});

  @override
  State<ConnectDeviceScreen> createState() => _ConnectDeviceScreenState();
}

class _ConnectDeviceScreenState extends State<ConnectDeviceScreen> {
  final _deviceId = TextEditingController();
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _deviceId.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerState>();
    return Scaffold(
      appBar: const AppBarBack(title: 'Connect Device'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.qr_code_scanner, color: AppTheme.accent, size: 40),
                const SizedBox(height: 12),
                Text('Pair with an Agent', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  'Scan the QR code on the Agent device, or enter the Device ID and 6-digit code manually.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // QR Scanner button
                OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Code'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.accent),
                    foregroundColor: AppTheme.accent,
                  ),
                  onPressed: controller.ws == null ? null : () => _scanQr(context),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                // Manual entry
                Text('Or enter manually:', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextField(
                  controller: _deviceId,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Device ID',
                    hintText: 'RMDZ-A7F92K',
                    prefixIcon: Icon(Icons.devices_other),
                    helperText: 'Shown on the agent dashboard',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Pairing Code',
                    hintText: '842913',
                    prefixIcon: Icon(Icons.pin_outlined),
                    helperText: 'Short-lived 6-digit code',
                    counterText: '',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: controller.ws == null ? null : () => _connect(controller),
                  icon: const Icon(Icons.link),
                  label: const Text('CONNECT (Manual)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (controller.stageDetail != null) _StageCard(controller),
        ],
      ),
    );
  }

  Future<void> _scanQr(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ScanQrScreen()),
    );
    if (result == true && mounted) {
      // Pairing successful, refresh devices
      context.read<ControllerState>().refreshDevices();
    }
  }

  Future<void> _connect(ControllerState controller) async {
    final deviceId = _deviceId.text.trim().toUpperCase();
    final code = _code.text.trim();
    if (deviceId.isEmpty || code.length != 6) {
      setState(() => _error = 'Enter both the Device ID and the 6-digit pairing code.');
      return;
    }
    setState(() => _error = null);
    await controller.pairWith(deviceId: deviceId, code: code);
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard(this.controller);
  final ControllerState controller;

  @override
  Widget build(BuildContext context) {
    final stage = controller.stage;
    final (icon, color, title) = switch (stage) {
      ConnectStage.waitingApproval => (Icons.hourglass_top, AppTheme.warning, 'Waiting for approval'),
      ConnectStage.waitingAccept => (Icons.hourglass_top, AppTheme.warning, 'Waiting for agent'),
      ConnectStage.connected => (Icons.check_circle, AppTheme.success, 'Connected'),
      ConnectStage.denied => (Icons.error, AppTheme.danger, 'Connection failed'),
      ConnectStage.error => (Icons.error, AppTheme.danger, 'Connection failed'),
      _ => (Icons.info, AppTheme.accent, 'Status'),
    };
    return GlassCard(
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(controller.stageDetail ?? '', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}