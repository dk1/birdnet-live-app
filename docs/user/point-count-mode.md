# Point Count Mode

Point Count Mode is the timed stationary workflow in BirdNET Live.

## How to Open It

From Home, tap the **Point Count Mode** card with the :material-map-marker: icon.

## Setup Flow

Point Count setup uses four steps.

### 1. Duration and location

Choose:

- one of the available duration chips
- current GPS with :material-crosshairs-gps:
- manual coordinates with :material-map-marker-plus:
- no location with :material-map-marker-off:
- map picker with :material-map:

The setup screen refreshes GPS when you return from the system permission
dialog or app settings, so a newly granted location permission should update
the coordinates without restarting the wizard. The same section also includes
a weather card. If weather access is off, the card asks for **Allow weather
lookup** consent; once enabled, it previews the site with a weather icon,
temperature, and wind only. The same cached Open-Meteo snapshot is reused when
the point count is saved.

### 2. Inference parameters

Choose per-session analysis settings such as window duration, inference rate,
confidence threshold, and species-filter mode. These start from your global
settings but can be adjusted for this count without changing your defaults.

### 3. Field tips

This screen presents a short in-app checklist to run through before starting.

### 4. Ready

The ready screen summarizes the selected duration and lets you start with :material-play:.

## Live Point Count Screen

The live point-count screen focuses on a timed dashboard.

### Top bar

- :material-stop: — end the point count early
- :material-timer: — show time remaining
- :material-tune: — open Point Count settings

### Main indicators

- countdown progress bar
- compact info bar with current detections, unique species count, and total detections
- spectrogram view
- detection list

## After the Count

When the point count ends, BirdNET Live saves the session and opens [Session Review](session-review.md).