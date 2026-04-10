import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/presentation/room_playlist_export_sheet.dart';

void main() {
  testWidgets('shows empty state when no queue items exist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RoomPlaylistExportSheet(exportText: '', hasTracks: false),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Aktuell ist keine Queue zum Exportieren vorhanden.'),
      findsOneWidget,
    );
    final copyButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(copyButton.onPressed, isNull);
  });

  testWidgets('copies export text to clipboard', (WidgetTester tester) async {
    const exportText = 'Party Queue Export\nRaum AB12CD\n\n1. Song - Artist';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RoomPlaylistExportSheet(
            exportText: exportText,
            hasTracks: true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Export kopieren'));
    await tester.pump();

    final clipboard = await Clipboard.getData('text/plain');
    expect(clipboard?.text, exportText);
    expect(find.text('Playlist-Export kopiert.'), findsOneWidget);
  });
}
