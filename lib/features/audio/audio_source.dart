import 'dart:io';

import 'package:flutter/foundation.dart';

// =============================================================================
// Audio Source — what we record from, and how the OS pre-processes it
// =============================================================================
//
// Two orthogonal things decide what lands in the ring buffer:
//
//   1. The *device* — built-in mic, wired headset, USB interface, Bluetooth.
//   2. The *processing profile* — how much DSP the OS applies on the way.
//
// The UI flattens both into a single picker (see `AudioSourceTile`), so this
// file models the flattened selection rather than two independent settings.
//
// ### Why the profile exists
//
// On Android, `RecordConfig.noiseSuppress` / `.autoGain` / `.echoCancel` only
// toggle the software `AudioEffect` modules attached to the recording session.
// They do nothing about the OEM's voice DSP, which is baked into the capture
// path of the DEFAULT and MIC audio sources and tuned for speech: it applies
// noise reduction, spectral shaping and automatic gain that badly distort bird
// song. The only way past it is to ask for a *different audio source*, which is
// what the profile selects.
//
// ### Platform support
//
// Android only. iOS's equivalent lever is the AVAudioSession mode
// (`.measurement`), which Apple requires be set between `setCategory` and
// `setActive` — a window the `record` plugin does not expose. On iOS the picker
// therefore lists devices only, and the profile stays at [systemDefault].
// =============================================================================

/// How much processing the OS applies to captured audio.
///
/// Maps to `MediaRecorder.AudioSource` on Android. Ignored on other platforms.
enum AudioSourceProfile {
  /// `AudioSource.DEFAULT` — whatever the phone does normally, OEM voice DSP
  /// included. The pre-0.19 behaviour, and still the default so existing
  /// installs don't change under people.
  systemDefault,

  /// `AudioSource.UNPROCESSED` — the raw mic signal, no noise reduction and no
  /// automatic gain.
  ///
  /// Gated on the device declaring `PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED`.
  /// Phones that don't support it silently fall back rather than failing, which
  /// is why [voiceRecognition] is offered alongside it.
  unprocessed,

  /// `AudioSource.VOICE_RECOGNITION` — the dependable fallback.
  ///
  /// Android's CDD *requires* AGC, noise suppression and echo cancellation to
  /// be off for this source, so it delivers unprocessed audio on effectively
  /// every device, including the many that ignore [unprocessed].
  voiceRecognition;

  /// Parse a persisted profile name, falling back to [systemDefault] for
  /// unknown or missing values.
  static AudioSourceProfile fromName(String? name) => values.firstWhere(
    (profile) => profile.name == name,
    orElse: () => AudioSourceProfile.systemDefault,
  );
}

/// Whether the running platform honours [AudioSourceProfile] at all.
///
/// When false the picker hides the profile entries and lists devices only.
bool get audioSourceProfilesSupported => Platform.isAndroid;

/// What the app records from: a [deviceId] and a processing [profile].
///
/// The two are genuinely independent — Android takes the audio source in the
/// `AudioRecord` constructor and the device via `setPreferredDevice()`, so any
/// combination is legal, including a USB mic captured unprocessed. The picker
/// therefore offers them as two controls rather than folding them into one
/// list of mutually exclusive choices.
@immutable
class AudioSourceSelection {
  const AudioSourceSelection({
    this.deviceId,
    this.profile = AudioSourceProfile.systemDefault,
  });

  /// The default device with no profile override. The out-of-the-box selection.
  static const AudioSourceSelection systemDefault = AudioSourceSelection();

  /// Specific input device, or `null` for the system-default device.
  ///
  /// Note that "device" is not the same as "external": Android reports each
  /// built-in mic (bottom, back, …) as its own device on many handsets, so a
  /// non-null [deviceId] may still be an internal mic — which is exactly why
  /// [profile] has to remain selectable alongside it.
  final String? deviceId;

  /// How much processing the OS may apply. Android only.
  final AudioSourceProfile profile;

  AudioSourceSelection withDevice(String? deviceId) =>
      AudioSourceSelection(deviceId: deviceId, profile: profile);

  AudioSourceSelection withProfile(AudioSourceProfile profile) =>
      AudioSourceSelection(deviceId: deviceId, profile: profile);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSourceSelection &&
          other.deviceId == deviceId &&
          other.profile == profile;

  @override
  int get hashCode => Object.hash(deviceId, profile);

  @override
  String toString() => 'AudioSourceSelection($deviceId, ${profile.name})';
}
