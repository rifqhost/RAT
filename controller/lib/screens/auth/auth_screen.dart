import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/controller_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../home/home_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _deviceName = TextEditingController(text: 'HP A Controller'); // placeholder, editable
  bool _register = false;
  bool _busy = false;
  String? _error;
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ControllerState>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Logo(),
                  const SizedBox(height: 32),
                  GlassCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _register ? 'Create Account' : 'Welcome Back',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text('Sign in to control your devices remotely.', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 20),
                        if (_register) ...[
                          TextField(
                            controller: _name,
                            decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          onSubmitted: (_) => _submit(controller),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _deviceName,
                          decoration: const InputDecoration(
                            labelText: 'Controller Device Name',
                            helperText: 'Identify this controller, e.g. HP A',
                            prefixIcon: Icon(Icons.smartphone),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                            ),
                            child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _busy ? null : () => _submit(controller),
                          child: _busy
                              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                              : Text(_register ? 'Create Account & Sign In' : 'Sign In'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() {
                            _register = !_register;
                            _error = null;
                          }),
                          child: Text(_register ? 'Already have an account? Sign in' : "New here? Create an account"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(ControllerState controller) async {
    final email = _email.text.trim();
    final password = _password.text;
    final deviceName = _deviceName.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in email and password.');
      return;
    }
    if (_register && _name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await controller.registerAndLogin(
          name: _name.text.trim(),
          email: email,
          password: password,
          deviceName: deviceName.isEmpty ? 'HP A Controller' : deviceName,
        );
      } else {
        await controller.login(
          email: email,
          password: password,
          deviceName: deviceName.isEmpty ? 'HP A Controller' : deviceName,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.4), blurRadius: 24)],
          ),
          child: const Icon(Icons.podcasts, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => AppTheme.accentGradient.createShader(bounds),
          child: Text('RMODZ', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(height: 2),
        Text('REMOTE CONTROLLER', style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 4)),
      ],
    );
  }
}
