import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:party_queue_app/src/features/party/domain/join_entry_link_resolver.dart';
import 'package:party_queue_app/src/features/party/domain/join_input_parser.dart';

abstract class AppLinkSource {
  Future<Uri?> getInitialUri();

  Stream<Uri> get uriStream;
}

class PlatformAppLinkSource implements AppLinkSource {
  PlatformAppLinkSource() : _appLinks = kIsWeb ? null : AppLinks();

  final AppLinks? _appLinks;

  @override
  Future<Uri?> getInitialUri() async {
    if (kIsWeb) {
      return Uri.base;
    }
    return _appLinks?.getInitialLink();
  }

  @override
  Stream<Uri> get uriStream {
    if (kIsWeb) {
      return const Stream<Uri>.empty();
    }
    return _appLinks!.uriLinkStream;
  }
}

class AppJoinLinkService {
  AppJoinLinkService({AppLinkSource? linkSource})
    : _linkSource = linkSource ?? PlatformAppLinkSource();

  final AppLinkSource _linkSource;

  Future<ParsedJoinInput?> getInitialJoinInput() async {
    final uri = await _linkSource.getInitialUri();
    return resolveJoinEntryLink(uri);
  }

  Stream<ParsedJoinInput> get joinInputStream {
    return _linkSource.uriStream
        .map(resolveJoinEntryLink)
        .where((joinInput) => joinInput != null)
        .cast<ParsedJoinInput>();
  }
}
