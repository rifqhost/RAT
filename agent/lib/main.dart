import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/agent_state.dart';
import 'core/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AgentSessionStore.load();
  final agent = AgentState(store);
  runApp(
    ChangeNotifierProvider<AgentState>.value(
      value: agent,
      child: const RMODZAgentApp(),
    ),
  );
  agent.bootstrap();
}
