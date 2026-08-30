import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/controller_state.dart';
import '../../theme.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;
  String? _error;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null) {
        _processQrData(rawValue);
        break;
      }
    }
  }

  Future<void> _processQrData(String rawValue) async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final data = jsonDecode(rawValue);
      if (data['type'] != 'rmodz-pair') {
        throw Exception('Invalid QR code: not a pairing code');
      }
      final String agentDeviceId = data['deviceId'] as String;
      final String agentToken = data['token'] as String;

      if (!agentDeviceId.startsWith('RMDZ-')) {
        throw Exception('Invalid device ID format');
      }

      final controller = context.read<ControllerState>();
      final result = await controller.api.pairQr(agentDeviceId: agentDeviceId, agentToken: agentToken);

      if (!mounted) return;

      if (result['status'] == 'approved') {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully paired!'), backgroundColor: AppTheme.success),
        );
      } else {
        throw Exception('Pairing failed: ${result['status']}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
            tooltip: 'Toggle flashlight',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Text('Camera error: ${error.errorDetails?.message ?? 'Unknown error'}'),
              );
            },
          ),
          // Scan overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Bottom instructions
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white))),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => setState(() => _error = null),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Point camera at the QR code on the Agent device',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}