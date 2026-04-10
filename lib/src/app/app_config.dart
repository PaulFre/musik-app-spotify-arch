class AppConfig {
  const AppConfig({this.publicInviteBaseUrl = _defaultPublicInviteBaseUrl});

  static const String _defaultPublicInviteBaseUrl =
      'https://party-queue.example';

  final String publicInviteBaseUrl;

  Uri get publicInviteBaseUri => Uri.parse(publicInviteBaseUrl);
  String get publicInviteLinkScheme => publicInviteBaseUri.scheme;
  String get publicInviteLinkHost => publicInviteBaseUri.host;

  factory AppConfig.fromEnvironment() {
    return AppConfig(
      publicInviteBaseUrl: const String.fromEnvironment(
        'PUBLIC_APP_BASE_URL',
        defaultValue: _defaultPublicInviteBaseUrl,
      ),
    );
  }
}
