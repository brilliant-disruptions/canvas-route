import 'package:flutter/services.dart';

/// Detects a marketplace listing URL on the clipboard so the Map screen can
/// offer "Add the sale from your clipboard?". Never fetches the URL (spec §4.2).
class ListingLink {
  static final _hosts = {
    'craigslist.org': 'Craigslist',
    'facebook.com': 'Facebook',
    'fb.com': 'Facebook',
    'estatesales.net': 'EstateSales.net',
    'estatesales.org': 'EstateSales.org',
    'gsalr.com': 'gsalr',
    'yardsalesearch.com': 'YardSaleSearch',
    'nextdoor.com': 'Nextdoor',
  };

  static String? sourceLabel(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    for (final e in _hosts.entries) {
      if (host == e.key || host.endsWith('.${e.key}')) return e.value;
    }
    return host.isEmpty ? null : 'Link';
  }

  static bool looksLikeListing(String? text) {
    if (text == null) return false;
    final uri = Uri.tryParse(text.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  static Future<String?> readClipboardUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    return looksLikeListing(text) ? text : null;
  }
}
