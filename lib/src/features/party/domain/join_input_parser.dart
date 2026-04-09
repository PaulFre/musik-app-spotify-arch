class ParsedJoinInput {
  const ParsedJoinInput({required this.raw, required this.normalizedCode});

  final String raw;
  final String normalizedCode;
}

ParsedJoinInput? parseJoinInput(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final directCode = _extractValidCode(trimmed);
  if (directCode != null) {
    return ParsedJoinInput(raw: trimmed, normalizedCode: directCode);
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return null;
  }

  final queryCandidates = <String?>[
    uri.queryParameters['code'],
    uri.queryParameters['room'],
    uri.queryParameters['roomCode'],
  ];
  for (final candidate in queryCandidates) {
    final parsed = _extractValidCode(candidate);
    if (parsed != null) {
      return ParsedJoinInput(raw: trimmed, normalizedCode: parsed);
    }
  }

  for (final segment in uri.pathSegments.reversed) {
    final parsed = _extractValidCode(segment);
    if (parsed != null) {
      return ParsedJoinInput(raw: trimmed, normalizedCode: parsed);
    }
  }

  return null;
}

String? _extractValidCode(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim().toUpperCase().replaceAll(
    RegExp(r'[^A-Z0-9]'),
    '',
  );
  if (normalized.length != 6) {
    return null;
  }
  if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(normalized)) {
    return null;
  }
  return normalized;
}
