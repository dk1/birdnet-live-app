# ARU Mode

!!! note "Early implementation"
    ARU Mode currently creates a recoverable scheduled deployment session, records scheduled cycles, runs live inference during active cycles, and shows Android foreground notification controls. iOS background behavior still needs field validation.

ARU (Autonomous Recording Unit) Mode is the fixed-location workflow for scheduled acoustic deployments.

## Current Setup Flow

- **Deployment and audio**: Enter a deployment name, ARU/station ID, observer name, fixed site location, recording mode, recording format, and detection-clip retention rules. The setup reuses the shared microphone picker and shows the weather preview card when weather lookup is allowed.
- **Schedule**: Choose cycle duration, repeat interval, how the deployment should end, and a low-battery stop threshold. You can stop manually, stop after a fixed number of scheduled cycles, or stop at a fixed date and time. Regular cycles are anchored to wall-clock interval boundaries, so a 10-minute cycle every hour starts on the hour rather than relative to the moment you started setup. The one-minute test run is enabled by default, starts immediately, and does not consume the scheduled cycle count.
- **Ready**: Review the schedule and estimated audio storage, then start the deployment.

Starting a deployment immediately saves a `SessionType.aru` session with ARU schedule metadata so cycle state can be recovered later.

JSON and ZIP exports include ARU deployment metadata. If a later build has saved per-cycle recording files on the session, ZIP export bundles those files under `aru_cycles/`.

## Active Deployment Screen

The active ARU screen shows whether the deployment is waiting, recording, or complete. Its layout uses four tabs: **Status** for current deployment state and detections, **Spectrogram** for checking that audio is arriving while keeping detections visible below, **Schedule** for the next 10 scheduled cycle times, and **Summary** for elapsed time, recorded audio duration, and detection totals. On Android, active deployments show a foreground notification with Stop and Open actions.

Stopping a deployment opens Session Review for the saved deployment when cycles are grouped into one session. When the setup saves each cycle as a separate session, stopping opens the latest cycle session.

On iOS, this early implementation should be treated as a foreground workflow until scheduled audio/background behavior has been validated on iOS.

## Still Planned

- iOS background behavior validation.
- Full Session Review playback and spectrogram support for multi-file segmented ARU recordings.
