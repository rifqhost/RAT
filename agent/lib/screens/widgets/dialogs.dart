import 'package:flutter/material.dart';
import '../../core/agent_state.dart';
import '../../core/protocol.dart';
import '../../theme.dart';

/// Modal dialogs for pair approval and incoming session requests.
class PairDialogs {
  static bool _pairShown = false;
  static bool _sessionShown = false;

  static void reset() {
    _pairShown = false;
    _sessionShown = false;
  }

  static void showPairApproval(BuildContext context, AgentState agent) {
    if (_pairShown) return;
    final pair = agent.pendingPair;
    if (pair == null) return;
    _pairShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.link, color: AppTheme.warning),
              SizedBox(width: 8),
              Text('Pairing request'),
            ],
          ),
          content: Text(
            '${pair.controllerName} wants to pair with this device.\n\n'
            'Approving lets them connect for remote help sessions. You can revoke at any time.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _pairShown = false;
                agent.denyPair();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Deny'),
            ),
            FilledButton(
              onPressed: () {
                _pairShown = false;
                agent.approvePair();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Approve'),
            ),
          ],
        );
      },
    ).whenComplete(() => _pairShown = false);
  }

  static void showSessionRequest(BuildContext context, AgentState agent) {
    if (_sessionShown) return;
    final session = agent.pendingSession;
    if (session == null) return;
    _sessionShown = true;

    final selected = <String>{
      ...session.requestedPermissions,
    };

    var open = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.support_agent, color: AppTheme.accent),
                  SizedBox(width: 8),
                  Text('Remote support request'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${session.controllerName} wants to view or control this device.'),
                    const SizedBox(height: 12),
                    const Text('Grant access to:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    for (final p in session.requestedPermissions)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(Permissions.label(p)),
                        value: selected.contains(p),
                        onChanged: (v) => setState(() {
                          if (v ?? false) {
                            selected.add(p);
                          } else {
                            selected.remove(p);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    open = false;
                    _sessionShown = false;
                    agent.denySession(reason: 'Declined by agent');
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Decline'),
                ),
                FilledButton(
                  onPressed: () {
                    open = false;
                    _sessionShown = false;
                    agent.acceptSession(granted: List<String>.from(selected));
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Accept'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      if (open) _sessionShown = false;
    });
  }
}
