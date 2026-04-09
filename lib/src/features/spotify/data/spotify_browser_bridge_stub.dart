Uri getCurrentUri() => Uri.base;

Future<void> redirectTo(Uri uri) async {
  throw UnsupportedError('Spotify PKCE redirect is only supported on web.');
}

void replaceCurrentUrl(Uri uri) {}
