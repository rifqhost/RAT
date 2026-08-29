import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/controller_state.dart';
import '../dashboard/dashboard_screen.dart';
import '../devices/devices_screen.dart';
import '../files/files_screen.dart';
import '../remote/remote_screen.dart';
import '../sessions/sessions_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _navigatedToRemote = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerState>();
    _maybeNavigateToRemote(controller);
    final screens = [
      const DashboardScreen(),
      const DevicesScreen(),
      const FilesScreen(),
      const SessionsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.devices_other), selectedIcon: Icon(Icons.devices), label: 'Devices'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Files'),
          NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history), label: 'Sessions'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  void _maybeNavigateToRemote(ControllerState controller) {
    if (controller.sessionActive && !_navigatedToRemote) {
      _navigatedToRemote = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemoteScreen())).then((_) {
          _navigatedToRemote = false;
        });
      });
    }
    if (!controller.sessionActive) {
      _navigatedToRemote = false;
    }
  }
}