# Survey Mode

Long-running transect surveys with GPS tracking, background monitoring, and detection sampling.

## Overview

Survey Mode is designed for rangers, researchers, and citizen scientists walking transects that may last hours. The phone clips to a backpack or belt while the app runs in the background with a persistent notification, recording audio, running inference at a battery-friendly rate, and logging a GPS track. A live dashboard shows your route and detection pins on a map. After stopping, Session Review displays an interactive map of the transect alongside the usual species list and audio playback.

## Setup Wizard

Before starting a survey, a multi-step wizard collects all session parameters.

### Step 1: Survey Details

| Field | Description |
|-------|-------------|
| **Survey name** | Optional free-text (auto-named "Survey #N" if blank) |
| **Location** | GPS (auto) / Manual lat-lon / Map picker / Skip |
| **Date & time** | Pre-filled with current date-time, editable |
| **Transect ID** | Optional free-text for repeat surveys |
| **Observer name** | Optional free-text, remembered from last session |

GPS permission is checked on wizard open:

- **"Allow all the time"** — Full background GPS tracking.
- **"While using the app"** — Manual GPS mode: points captured when the app is in the foreground.
- **Denied** — Cannot start survey; prompt for at least "While using".

### Step 2: Parameters

| Setting | Default | Description |
|---------|---------|-------------|
| **Microphone** | System default | Select input device (external USB-C or Bluetooth mics appear here) |
| **Inference rate** | 0.3 Hz | How often the classifier runs (lower = better battery) |
| **GPS logging interval** | 10 s | Track point frequency (5 / 10 / 30 / 60 s) |
| **Max duration** | 8 h | Hard cap — survey auto-stops even if forgotten |
| **Recording mode** | Detections only | Full (continuous) or Detections only (clips) |
| **Detection sampling** | Smart | All / Top N per species / Smart (spatially-distributed) |
| **Species filter** | Off | Off / Geo Exclude / Geo Merge |

### Step 3: Field Tips

Seven best-practice reminders for clean field data: walk at a steady pace, avoid wind, keep mic unobstructed, minimize talking, survey during peak activity hours, use consistent settings across surveys, and check battery level.

### Step 4: Ready

Summary card showing all chosen parameters with warnings for manual GPS mode, low battery, or low storage.

## Live Dashboard

Once started, the survey runs with a tabbed live screen.

### Tabs

| Tab | Content |
|-----|---------|
| **Map** | OpenTopoMap with GPS track polyline, species thumbnail markers at detection locations, start/end markers |
| **Spectrogram** | Real-time scrolling FFT visualization (same as Live Mode) |
| **Summary** | Species count, detection count, detection rate (det/min), ranked species list with best confidence per species |

### Status Bar

A compact bar at the top shows:

- Elapsed time
- Distance walked (cumulative Haversine)
- Detection count
- Species count
- Audio quality indicator (mic icon + signal bars)

### Background Operation

- A persistent foreground notification shows detection and species counts ("42 det · 12 spp").
- Inference and GPS logging continue when the app is in the background.
- Write-ahead persistence saves progress every 30 seconds for crash resilience.

### Stopping

Tap the stop button to end the survey. A confirmation dialog prevents accidental stops. The session is saved and navigated to Session Review.

## Detection Sampling

Survey Mode offers three sampling strategies to manage detection volume over long sessions:

| Mode | Behavior |
|------|----------|
| **All** | Keep every detection above the confidence threshold |
| **Top N per species** | Keep only the N highest-confidence detections per species (min-heap eviction) |
| **Smart** | Spatially-distributed sampling: per-species budgets across spatial bins with a global detection cap |

Inference always runs at the configured rate; sampling controls which detections are kept in the final session.

## After the Survey

Survey sessions appear in the Session Library with survey-specific metadata (distance, transect ID, observer name). Session Review includes:

- **Interactive map** showing the full GPS track with species markers (pinch-zoom, pan)
- **Map-based species filtering** — the species list updates to show only detections visible in the current map viewport
- **Tap-to-highlight** — tap a detection in the species list to highlight it on the map
- **Fullscreen map** — tap the inline map to open a fullscreen view with the entire track

Export formats include GPX (track + detection waypoints), Raven Pro, CSV, JSON, and ZIP bundle.

See [Session Review](session-review.md) and [Export & Sync](export-sync.md) for full details.

## Tips

- **Battery**: At 0.3 Hz inference rate with GPS every 10 seconds, expect roughly 2–3% battery per hour on modern hardware.
- **GPS accuracy**: For best track quality, grant "Allow all the time" location permission so GPS runs in the background.
- **External mics**: USB-C or Bluetooth microphones appear in the setup mic picker and can improve detection quality.
- **Repeat transects**: Use the Transect ID field to tag surveys along the same route for longitudinal comparison.
- **Smart sampling**: Recommended for surveys longer than 1 hour — it keeps a representative spread of detections without overwhelming the session.
