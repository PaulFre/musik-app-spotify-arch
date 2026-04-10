import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RoomPlaylistExportSheet extends StatelessWidget {
  const RoomPlaylistExportSheet({
    super.key,
    required this.exportText,
    required this.hasTracks,
  });

  final String exportText;
  final bool hasTracks;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Playlist exportieren',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (!hasTracks)
              const Text('Aktuell ist keine Queue zum Exportieren vorhanden.')
            else ...[
              const Text(
                'Die aktuelle Queue wird als Text in ihrer bestehenden Reihenfolge exportiert.',
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      child: SelectableText(exportText),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: hasTracks ? () => _copy(context) : null,
                child: const Text('Export kopieren'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: exportText));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Playlist-Export kopiert.')));
  }
}
