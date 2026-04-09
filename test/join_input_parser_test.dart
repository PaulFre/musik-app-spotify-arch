import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/domain/join_input_parser.dart';

void main() {
  test('parses direct room code', () {
    final parsed = parseJoinInput('ab12cd');

    expect(parsed, isNotNull);
    expect(parsed!.normalizedCode, 'AB12CD');
  });

  test('parses invite link with code query parameter', () {
    final parsed = parseJoinInput('https://example.com/join?code=ab12cd');

    expect(parsed, isNotNull);
    expect(parsed!.normalizedCode, 'AB12CD');
  });

  test('parses invite link with room code path segment', () {
    final parsed = parseJoinInput('https://example.com/rooms/ab12cd');

    expect(parsed, isNotNull);
    expect(parsed!.normalizedCode, 'AB12CD');
  });

  test('rejects invalid join input', () {
    expect(parseJoinInput('??'), isNull);
    expect(parseJoinInput('https://example.com/join?code=abc'), isNull);
  });
}
