// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

Uri getCurrentUri() => Uri.base;

Future<void> redirectTo(Uri uri) async {
  html.window.location.assign(uri.toString());
}

void replaceCurrentUrl(Uri uri) {
  html.window.history.replaceState(null, '', uri.toString());
}
