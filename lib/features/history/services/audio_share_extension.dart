import 'dart:io';

import 'package:path/path.dart' as p;

const String fallbackAudioShareExtension = '.wav';
const Set<String> _knownAudioExtensions = {
  '.wav',
  '.flac',
  '.m4a',
  '.aac',
  '.mp3',
  '.ogg',
  '.oga',
};

Future<String> sharedAudioExtensionForFile(
  File file, {
  bool shareAudioAsWav = false,
}) async {
  final sourceExt = await sourceAudioExtensionForFile(file);
  return sharedAudioExtensionForSource(
    sourceExt,
    shareAudioAsWav: shareAudioAsWav,
  );
}

String sharedAudioExtensionForSource(
  String sourceExt, {
  bool shareAudioAsWav = false,
}) {
  final normalized = sourceExt.toLowerCase();
  if (shareAudioAsWav && normalized == '.flac') return '.wav';
  return normalized.isNotEmpty ? normalized : fallbackAudioShareExtension;
}

Future<String> sourceAudioExtensionForFile(File file) async {
  final pathExt = p.extension(file.path).toLowerCase();
  if (_knownAudioExtensions.contains(pathExt)) return pathExt;
  final detectedExt = await detectAudioExtension(file);
  if (detectedExt != null) return detectedExt;
  return pathExt.isNotEmpty ? pathExt : fallbackAudioShareExtension;
}

Future<String?> detectAudioExtension(File file) async {
  try {
    final header = await file
        .openRead(0, 12)
        .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
    if (header.length >= 12 &&
        header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 &&
        header[8] == 0x57 &&
        header[9] == 0x41 &&
        header[10] == 0x56 &&
        header[11] == 0x45) {
      return '.wav';
    }
    if (header.length >= 4 &&
        header[0] == 0x66 &&
        header[1] == 0x4c &&
        header[2] == 0x61 &&
        header[3] == 0x43) {
      return '.flac';
    }
  } catch (_) {
    return null;
  }
  return null;
}
