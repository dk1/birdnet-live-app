import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../live/live_providers.dart';
import '../live/live_session.dart';
import 'aru_active_screen.dart';
import 'aru_controller.dart';
import 'aru_providers.dart';
import 'aru_setup_screen.dart';

/// Landing route used when Android launches the app from the ARU foreground
/// notification.
class AruNotificationRoute extends ConsumerStatefulWidget {
  const AruNotificationRoute({required this.requestStop, super.key});

  final bool requestStop;

  @override
  ConsumerState<AruNotificationRoute> createState() =>
      _AruNotificationRouteState();
}

class _AruNotificationRouteState extends ConsumerState<AruNotificationRoute> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final active = await _ensureActiveDeploymentRestored();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder:
            (_) =>
                active
                    ? AruActiveScreen(confirmStopOnOpen: widget.requestStop)
                    : const AruSetupScreen(),
      ),
    );
  }

  Future<bool> _ensureActiveDeploymentRestored() async {
    final inMemorySession = ref.read(aruSessionProvider);
    final inMemoryState = ref.read(aruStateProvider);
    if (inMemorySession != null &&
        inMemoryState != AruControllerState.completed &&
        inMemoryState != AruControllerState.idle) {
      return true;
    }

    final repo = ref.read(sessionRepositoryProvider);
    final sessions = await repo.listAll();
    final restorable =
        sessions
            .where(
              (session) =>
                  session.type == SessionType.aru &&
                  session.endTime == null &&
                  session.aruMetadata != null,
            )
            .toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));
    final pendingSession = restorable.firstOrNull;
    if (pendingSession == null) return false;

    final controller = ref.read(aruControllerProvider);
    await controller.restoreDeployment(pendingSession);
    ref.read(aruStateProvider.notifier).state = controller.state;
    ref.read(aruSessionProvider.notifier).state = controller.session;

    return controller.state != AruControllerState.completed &&
        controller.session != null;
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
