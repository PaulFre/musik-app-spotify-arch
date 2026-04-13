# Feature-Status E bis I

Stand: 14.04.2026

Diese Datei fasst den aktuellen Umsetzungsstand der abgearbeiteten Punkte zusammen:
- was funktional fertig ist
- was bewusst entfernt wurde
- welche Einschränkungen im aktuellen MVP gelten

## Fertig

### E1. Songs gezielt ausschließen
- Host kann einzelne Songs in den Einstellungen ausschließen.
- Grundlage ist ein stabiler Song-Identifier.
- Ausschluss greift konsistent in:
  - Suche
  - Vorschläge
  - `addTrack(...)`
- Host-UI zum Hinzufügen/Entfernen ist vorhanden.
- Das Settings-Sheet wurde zusätzlich scroll- und layout-stabil gemacht.

### E2. Interpreten gezielt ausschließen
- Die frühere Genre-Idee wurde vollständig verworfen und aus dem Code entfernt.
- Stattdessen kann der Host einzelne Interpreten ausschließen.
- Grundlage sind stabile Spotify-Artist-IDs.
- Ausschluss greift konsistent in:
  - Suche
  - Vorschläge
  - `addTrack(...)`
- Artist-IDs werden nicht mehr im Nutzer-UI angezeigt.
- Bei expliziter Suche nach einem gesperrten Interpreten erscheint ein Hinweis.
- Bei reiner Songsuche wird nur still gefiltert, ohne falsche Warnmeldung.

### G1. Now Playing UI mit Track-Info
- Now Playing zeigt:
  - Songname
  - Interpret
  - aktuelle Zeit
  - Gesamtdauer
  - Progress-Bar
- Anzeige basiert auf bestätigtem Playback-State.
- Fehlende Werte werden defensiv dargestellt.
- Die Fortschrittsanzeige läuft lokal zwischen bestätigten Sync-Punkten flüssiger weiter.
- Die technische Device-ID wurde aus der Nutzer-UI entfernt.

### G2. Added-by im Now Playing
- `Hinzugefügt von: <Name>` wird angezeigt, wenn der aktuell gespielte Track belastbar einem Queue-Eintrag zugeordnet werden kann.
- Host-Fall und Gast-Fall funktionieren fachlich gleich.
- Die Zuordnung bleibt erhalten, auch wenn der Queue-Eintrag beim Start des Songs aus der Queue entfernt wird.
- Wenn die Zuordnung nicht belastbar ist, wird bewusst nichts angezeigt.

### H1. Theme-Umschaltung
- Theme-Umschaltung ist funktional in der bestehenden Settings-Struktur verankert.
- `themeMode` wird in `SharedPreferences` gespeichert und beim Start wiederhergestellt.
- In der UI gibt es nur noch:
  - `Hell`
  - `Dunkel`
- `ThemeMode.system` wurde aus der UI entfernt.
- Alte gespeicherte `system`-Werte werden sauber auf `Hell` migriert.

### DE/EN-Sprachumschaltung
- Die Sprachauswahl ist jetzt funktional an die App-Locale gebunden.
- Die Sprache wird gespeichert und beim Start wiederhergestellt.
- Die sichtbaren Hauptscreens lesen ihre Texte aus einem gemeinsamen DE/EN-Strings-Pfad.
- Der App-Root wird beim Sprachwechsel sichtbar neu aufgebaut.
- Deutsche UI-Texte wurden auf echte Umlaute umgestellt.

### I1. Öffentliche / private Räume im Host-Flow
- Der Host-Flow setzt jetzt echten Room-State:
  - `isPublic`
  - optional `roomPassword`
- Passwort wird nur für private Räume gesetzt.
- Öffentliche Räume speichern kein Passwort.
- Public/Private und `roomPassword` sind nur vor der Raum-Erstellung festlegbar.
- Ein laufender Raum kann diese Eigenschaften später nicht mehr umschalten.

### I2. Liste öffentlicher Räume für Gäste
- Das bestehende Repository liefert eine Live-Liste offener öffentlicher Räume.
- Der Join-Screen zeigt nur öffentliche Räume.
- Private Räume erscheinen dort nicht.
- Ein Tap auf einen öffentlichen Raum nutzt den bestehenden Join-Pfad.

Wichtige MVP-Einschränkung:
- Das aktuelle lokale Room-Modell ist `in-memory`.
- Deshalb ist ein echter Multi-Session-Browsertest lokal nicht sauber möglich.
- Code-seitig ist I2 plausibel, aber lokal nur als Single-Instance-MVP belastbar.

### I3. Join-Flow für private Räume
- Der bestehende Join-Pfad akzeptiert jetzt optional ein Passwort.
- Private Räume verlangen fachlich das richtige Passwort.
- Öffentliche Räume bleiben ohne Passwort joinbar.
- Die Passwortprüfung sitzt im Controller-Join-Pfad, nicht nur in der UI.

Wichtige MVP-Einschränkung:
- Wie bei I2 ist ein echter Cross-Session-Browsertest lokal auf dem aktuellen In-Memory-Modell nicht sauber möglich.
- Code/Test sprechen für korrekte Funktion, echter Zwei-Fenster-Nachweis lokal aber eingeschränkt.

## Bewusst entfernt

### F1. Spotify-Playlist des Hosts importieren
- Wurde bewusst aus dem Produkt entfernt.
- Grund: Der Playlist-Import bringt für den gewünschten Party-Flow keinen sinnvollen Mehrwert.
- Der komplette Importpfad wurde sauber zurückgebaut:
  - kein Playlist-Import-Button mehr
  - keine Playlist-Auswahlliste mehr
  - keine Import-Fehlermeldungen oder Ladezustände mehr im Host-Flow
  - keine playlistbezogenen Service-/Controller-Pfade mehr
  - keine playlistbezogenen Diagnose-/Fallback-/Fehlercode-Pfade mehr
  - zusätzliche Playlist-Scopes wurden aus der Spotify-Konfiguration entfernt
  - playlistbezogene Tests/Fakes/Modelle wurden entfernt oder zurückgeführt

### F2. Vorschläge an importierter Playlist ausrichten
- Wurde zusammen mit F1 bewusst entfernt.
- Grund: F2 baute fachlich direkt auf dem Playlist-Import auf und ist ohne F1 nicht mehr relevant.
- Alle playlistnahen Vorschlags-/Ranking-/Hilfslogiken wurden mit F1 zusammen zurückgebaut.

## Noch offen

### Cross-Session-Echtbetrieb für öffentliche/private Raumflows
- I2 und I3 sind auf dem aktuellen In-Memory-Modell als MVP plausibel.
- Für echten lokalen Multi-Session-Betrieb wäre später ein gemeinsamer persistenter Room-Datenpfad nötig.

## Empfohlener nächster Schritt

Der E-I-Block ist jetzt im Wesentlichen abgeschlossen:
- E1 fertig
- E2 fertig
- F1 bewusst entfernt
- F2 bewusst entfernt
- G1 fertig
- G2 fertig
- H1 fertig
- DE/EN-Sprachumschaltung fertig
- I1 fertig
- I2 fertig als In-Memory-MVP
- I3 fertig als In-Memory-MVP

Sinnvoll ist jetzt:

1. den aktuellen Stand committen und pushen
2. danach den nächsten geplanten Hauptblock außerhalb von E bis I beginnen

Empfehlung:
- nicht weiter an entfernten Playlist-Import-Themen arbeiten
- den stabilen Stand als neue Basis nehmen
- den nächsten unabhängigen Produktbereich auswählen
