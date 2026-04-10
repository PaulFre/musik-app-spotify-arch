import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/app/app_config.dart';

void main() {
  test('derives invite host and scheme from the same public base url', () {
    const config = AppConfig(
      publicInviteBaseUrl: 'https://party.example.dev/app',
    );

    expect(config.publicInviteLinkScheme, 'https');
    expect(config.publicInviteLinkHost, 'party.example.dev');
    expect(config.publicInviteBaseUri.path, '/app');
  });
}
