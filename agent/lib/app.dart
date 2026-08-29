import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'core/agent_state.dart';
import 'screens/active_session/active_session_screen.dart';
import 'screens/home/home_shell.dart';
import 'theme.dart';

class RMODZAgentApp extends StatelessWidget {
  const RMODZAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AgentScaffold(),
    );
  }
}

class AgentScaffold extends StatelessWidget {
  const AgentScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentState>();
    if (agent.stage == AgentStage.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (agent.sessionActive) {
      return const ActiveSessionScreen();
    }
    return const HomeShell();
  }
}
