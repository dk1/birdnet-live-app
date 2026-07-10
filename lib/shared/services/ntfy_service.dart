// =============================================================================
// Ntfy Service — local-only, throwaway ntfy.sh push for lifer alerts
// =============================================================================
//
// Not part of the upstream eBird PR. Pushes a plain HTTP POST to
// https://ntfy.sh/{topic} so a lifer alert also reaches a phone/desktop
// subscribed to that topic outside the app. Fire-and-forget: a network
// failure here must never affect the survey itself.
// =============================================================================

import 'package:http/http.dart' as http;

abstract final class NtfyService {
  static Future<void> send({
    required String topic,
    required String title,
    required String message,
  }) async {
    final trimmed = topic.trim();
    if (trimmed.isEmpty) return;
    try {
      await http
          .post(
            Uri.parse('https://ntfy.sh/$trimmed'),
            headers: {'Title': title},
            body: message,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort push only; swallow network/timeout errors.
    }
  }
}
