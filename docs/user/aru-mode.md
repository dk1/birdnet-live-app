# ARU Mode

!!! note "Early implementation"
    ARU Mode currently creates a recoverable scheduled deployment session and tracks planned recording cycles. Cycle audio recording and Android foreground notifications are wired in this early version; inference, detection-only clips, and full review playback are still under development.

ARU (Autonomous Recording Unit) Mode is the fixed-location workflow for scheduled acoustic deployments.

## Current Setup Flow

- **Deployment and audio**: Enter a deployment name, ARU/station ID, observer name, fixed site location, and recording mode. The setup reuses the shared microphone picker and shows the weather preview card when weather lookup is allowed. Detection-only clip recording and clip-retention controls stay hidden until scheduled inference is wired end to end.
- **Schedule**: Choose cycle duration, repeat interval, how the deployment should end, and a low-battery stop threshold. You can stop manually, stop after a fixed number of cycles, or stop at a fixed date and time. The optional one-minute test cycle is still planned, but stays hidden until it works end to end.
- **Ready**: Review the schedule and estimated audio storage, then start the deployment.

Starting a deployment immediately saves a `SessionType.aru` session with ARU schedule metadata so cycle state can be recovered later.

JSON and ZIP exports include ARU deployment metadata. If a later build has saved per-cycle recording files on the session, ZIP export bundles those files under `aru_cycles/`.

## Active Deployment Screen

The active ARU screen shows whether the deployment is waiting, recording, or complete. Its layout follows Survey: a compact status row, upper tabs for schedule, live spectrogram, and summary, a stats strip, and a persistent detection feed below. The feed shows current-cycle detections while recording and recent deployment detections while waiting. On Android, active deployments show a foreground notification with Stop and Open actions.

On iOS, this early implementation should be treated as a foreground workflow until scheduled audio/background behavior has been validated on iOS.

## Still Planned

- Inference and detection-only clip creation during scheduled recording cycles.
- iOS background behavior validation.
- Full Session Review playback and spectrogram support for segmented ARU recordings.
