import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/controller_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = ControllerState();
  runApp(
    ChangeNotifierProvider<ControllerState>.value(
      value: controller,
      child: const RMODZControllerApp(),
    ),
  );
  controller.bootstrap();
}
