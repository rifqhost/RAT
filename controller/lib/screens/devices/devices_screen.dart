import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/controller_state.dart';
import '../../core/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../dashboard/dashboard_components.dart';
import 'connect_device_screen.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            tooltip: 'Connect new device',
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectDeviceScreen())),
          ),
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: () => controller.refreshDevices()),
        ],
      ),
      body: controller.loadingDevices
          ? const LoadingIndicator(label: 'Loading devices...')
          : controller.devices.isEmpty
              ? EmptyState(
                  icon: Icons.devices_other,
                  title: 'No paired devices',
                  subtitle: 'Pair your first agent device using a pairing code.',
                )
              : RefreshIndicator(
                  onRefresh: () => controller.refreshDevices(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: controller.devices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _DeviceRow(device: controller.devices[i]),
                  ),
                ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device});
  final Device device;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ControllerState>();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeonBadge(
                label: device.online ? 'Online' : 'Offline',
                color: device.online ? AppTheme.online : AppTheme.offline,
                icon: device.online ? Icons.circle : Icons.circle_outlined,
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppTheme.textSecondary),
                onSelected: (v) {
                  if (v == 'connect' && device.online) {
                    DashboardComponents.requestSession(context, controller, device);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(enabled: device.online, value: 'connect', child: const Text('Connect')),
                  PopupMenuItem(value: 'info', child: const Text('Information')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(device.name, style: Theme.of(context).textTheme.titleLarge),
          Text(device.id, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            [
              if (device.model != null) device.model!,
              if (device.androidVersion != null) 'Android ${device.androidVersion}',
              if (device.appVersion != null) 'Agent ${device.appVersion}',
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (device.online)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => DashboardComponents.requestSession(context, controller, device),
                icon: const Icon(Icons.play_arrow),
                label: const Text('CONNECT'),
              ),
            ),
        ],
      ),
    );
  }
}