import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/controller_state.dart';
import '../../core/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../devices/connect_device_screen.dart';
import 'dashboard_components.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('RMODZ REMOTE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Connect a device',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectDeviceScreen()));
            },
            iconSize: 26,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refreshDevices(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
          children: [
            const _ConnectionBanner(),
            const SectionHeader('Devices', subtitle: 'Paired and ready devices'),
            ..._deviceList(controller),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                button: true,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectDeviceScreen()));
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('Connect New Device'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _deviceList(ControllerState controller) {
    if (controller.loadingDevices) {
      return [const Padding(padding: EdgeInsets.all(24), child: LoadingIndicator(label: 'Loading devices...'))];
    }
    if (controller.devices.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(12),
          child: EmptyState(
            icon: Icons.devices_other,
            title: 'No paired devices yet',
            subtitle: 'Generate a pairing code on the agent and connect here.',
          ),
        ),
      ];
    }
    return controller.devices.asMap().entries.map((entry) {
      return _DeviceCard(device: entry.value, index: entry.key);
    }).toList();
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerState>();
    final server = AppConfig.baseUrl;
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: controller.connected ? AppTheme.online : AppTheme.offline,
              boxShadow: [
                BoxShadow(color: (controller.connected ? AppTheme.online : AppTheme.offline).withValues(alpha: 0.6), blurRadius: 12),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.connected ? 'Connected to server' : 'Connecting to server...',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(server, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.index});
  final Device device;
  final int index;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ControllerState>();
    final isOnline = device.online;
    final bg = DashboardComponents.deviceBg(index);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(gradient: bg, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.smartphone, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, style: Theme.of(context).textTheme.titleMedium),
                      Text(device.id, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                NeonBadge(
                  label: isOnline ? 'Online' : 'Offline',
                  color: isOnline ? AppTheme.online : AppTheme.offline,
                  icon: isOnline ? Icons.circle : Icons.circle_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(icon: Icons.battery_full, label: 'On device', hint: 'Battery via agent'),
                const SizedBox(width: 6),
                _Stat(icon: Icons.wifi, label: isOnline ? 'Reachable' : 'Unreachable'),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOnline ? AppTheme.accent : AppTheme.surfaceElevated,
                ),
                onPressed: isOnline ? () {
                  DashboardComponents.requestSession(context, controller, device);
                } : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(isOnline ? 'CONNECT' : 'Offline'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, this.hint});
  final IconData icon;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
