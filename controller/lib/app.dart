import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/controller_state.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_shell.dart';
import 'theme.dart';

class RMODZControllerApp extends StatelessWidget {
  const RMODZControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerState>();
    return MaterialApp(
      title: 'RMODZ Remote Controller',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: controller.session == null
          ? const AuthScreen()
          : const HomeShell(),
    );
  }
}