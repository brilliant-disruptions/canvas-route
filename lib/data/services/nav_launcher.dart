import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Hands a stop to the platform's maps app for turn-by-turn.
class NavLauncher {
  Future<bool> navigateTo({required double lat, required double lng, String? label}) async {
    final name = Uri.encodeComponent(label ?? 'Stop');
    final uri = Platform.isIOS
        ? Uri.parse('maps://?daddr=$lat,$lng&q=$name')
        : Uri.parse('google.navigation:q=$lat,$lng');
    if (await canLaunchUrl(uri)) return launchUrl(uri, mode: LaunchMode.externalApplication);
    final web = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    return launchUrl(web, mode: LaunchMode.externalApplication);
  }

  Future<bool> call(String phone) => launchUrl(Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}'));
  Future<bool> email(String address) => launchUrl(Uri.parse('mailto:$address'));
  Future<bool> open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
