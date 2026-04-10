import 'package:party_queue_app/src/app/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/domain/join_input_parser.dart';
import 'package:party_queue_app/src/features/party/domain/room_invite_link_builder.dart';

void main() {
  test('builds query invite link that parses back to the same room code', () {
    final inviteLink = buildRoomInviteLink(
      'ab12cd',
      publicBaseUri: Uri.parse('https://party.example.dev/room/AB12CD'),
    );

    expect(inviteLink.toString(), 'https://party.example.dev/join?code=AB12CD');
    expect(parseJoinInput(inviteLink.toString())?.normalizedCode, 'AB12CD');
  });

  test('uses explicit public base url instead of relying on Uri.base', () {
    final inviteLink = buildRoomInviteLink(
      'ZX90QP',
      publicBaseUri: Uri.parse('https://party.example.dev/app?foo=bar'),
    );

    expect(inviteLink.scheme, 'https');
    expect(inviteLink.host, 'party.example.dev');
    expect(inviteLink.path, '/join');
    expect(inviteLink.queryParameters['code'], 'ZX90QP');
  });

  test('app config exposes a public invite base url for non-web platforms', () {
    const config = AppConfig(publicInviteBaseUrl: 'https://invite.party.dev');

    final inviteLink = buildRoomInviteLink(
      'QW12ER',
      publicBaseUri: config.publicInviteBaseUri,
    );

    expect(inviteLink.toString(), 'https://invite.party.dev/join?code=QW12ER');
    expect(parseJoinInput(inviteLink.toString())?.normalizedCode, 'QW12ER');
  });
}
