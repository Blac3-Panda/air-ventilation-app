// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

class DaumPostcode {
  static Future<String?> pickAddress() async {
    final completer = Completer<String?>();

    late html.EventListener listener;
    listener = (event) {
      String? address;
      if (event is html.CustomEvent) {
        final detail = event.detail;
        if (detail is Map) {
          final raw = detail['address'];
          if (raw is String && raw.trim().isNotEmpty) {
            address = raw.trim();
          }
        }
      }

      html.window.removeEventListener('air-guide-daum-postcode', listener);
      if (!completer.isCompleted) {
        completer.complete(address);
      }
    };

    html.window.addEventListener('air-guide-daum-postcode', listener);

    try {
      js.context.callMethod('airGuideOpenPostcode');
    } catch (_) {
      html.window.removeEventListener('air-guide-daum-postcode', listener);
      return null;
    }

    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        html.window.removeEventListener('air-guide-daum-postcode', listener);
        return null;
      },
    );
  }
}
