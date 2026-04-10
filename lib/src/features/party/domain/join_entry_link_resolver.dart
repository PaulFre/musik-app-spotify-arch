import 'package:party_queue_app/src/features/party/domain/join_input_parser.dart';

ParsedJoinInput? resolveJoinEntryLink(Uri? uri) {
  if (uri == null) {
    return null;
  }

  final pathSegments = uri.pathSegments
      .where((segment) => segment.trim().isNotEmpty)
      .toList();
  final isJoinPath =
      pathSegments.length == 1 && pathSegments.single.toLowerCase() == 'join';
  if (!isJoinPath) {
    return null;
  }

  return parseJoinInput(uri.toString());
}
