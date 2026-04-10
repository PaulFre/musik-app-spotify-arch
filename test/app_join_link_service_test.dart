import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/app/app_join_link_service.dart';
import 'package:party_queue_app/src/features/party/domain/join_input_parser.dart';

void main() {
  test('recognizes a valid join link on app start', () async {
    final service = AppJoinLinkService(
      linkSource: _FakeAppLinkSource(
        initialUri: Uri.parse('https://party.example.dev/join?code=AB12CD'),
      ),
    );

    final parsed = await service.getInitialJoinInput();

    expect(parsed, isNotNull);
    expect(parsed!.normalizedCode, 'AB12CD');
  });

  test('ignores invalid join links', () async {
    final service = AppJoinLinkService(
      linkSource: _FakeAppLinkSource(
        initialUri: Uri.parse('https://party.example.dev/join?code=abc'),
      ),
    );

    final parsed = await service.getInitialJoinInput();

    expect(parsed, isNull);
  });

  test(
    'ignores non-join paths even if they contain a code-like query',
    () async {
      final service = AppJoinLinkService(
        linkSource: _FakeAppLinkSource(
          initialUri: Uri.parse('https://party.example.dev/rooms?code=AB12CD'),
        ),
      );

      final parsed = await service.getInitialJoinInput();

      expect(parsed, isNull);
    },
  );

  test('maps incoming runtime links into the same parsed join flow', () async {
    final controller = StreamController<Uri>();
    final service = AppJoinLinkService(
      linkSource: _FakeAppLinkSource(
        initialUri: null,
        incomingUriStream: controller.stream,
      ),
    );

    controller.add(Uri.parse('https://party.example.dev/join?code=ZX90QP'));

    await expectLater(
      service.joinInputStream,
      emits(
        predicate(
          (dynamic value) =>
              value is ParsedJoinInput && value.normalizedCode == 'ZX90QP',
        ),
      ),
    );

    await controller.close();
  });
}

class _FakeAppLinkSource implements AppLinkSource {
  const _FakeAppLinkSource({
    required this.initialUri,
    this.incomingUriStream = const Stream<Uri>.empty(),
  });

  final Uri? initialUri;
  final Stream<Uri> incomingUriStream;

  @override
  Future<Uri?> getInitialUri() async => initialUri;

  @override
  Stream<Uri> get uriStream => incomingUriStream;
}
