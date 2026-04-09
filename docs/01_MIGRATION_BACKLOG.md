# Migration Backlog

## P0 - Scope und Basis

- README des neuen Repos auf echtes `2.0`-Zielbild umstellen
- `2.0`-Scope im Repo dokumentieren
- Pflicht-/Optional-/Weg-Faehigkeiten aus dem alten Repo festhalten
- Reihenfolge fuer den Umbau festschreiben

## P1 - Realtime und Produktparitaet

- Realtime-/Firebase-Strategie aus dem alten MVP fachlich rueckholen
- Room-Snapshots und Host-authoritative Commands neu in die Architektur einpassen
- fruehere Join-/Session-/Lifecycle-Pfade wiederherstellen
- Realtime-Tests und Join-Tests fachlich zurueckbringen

## P2 - Produktregeln

- Suggestions-/Host-Moderation wieder einziehen
- Lock room / host-only adds / pause voting
- Fairness / anti-spam / freeze window / cooldown-Regeln auswerten und zurueckholen
- Reconnect- und Fehlerpfade fuer Host/Playback sauber modellieren

## P3 - Dokumentation und Qualitaetsbasis

- README weiter ausbauen
- lokale Setup-Anleitung
- CI-/Coverage-Basis zurueckholen
- spaetere Firestore-Regeltests und Deploy-Kontext wieder einfuehren

## P4 - Echte Spotify-Integration

- Host-Connect mit OAuth / PKCE
- Profil und Premium-Pruefung
- Device-Liste und Device-Auswahl
- Host-only Playback
- Polling / Current Playback Sync
- erst spaeter Gaeste-Suche ueber Backend/Proxy

## Bewertungsregel fuer alte Features

Fuer jedes alte Feature gilt:

- `Pflicht`, wenn es fuer MVP-/Mehrclient-Niveau noetig ist
- `Optional`, wenn es UX verbessert, aber Kernlogik nicht traegt
- `Weg`, wenn es die neue Struktur unnoetig aufblaeht oder Produktziel nicht mehr passt

## Arbeitsregel

Es wird nicht alter Code 1:1 zurueckkopiert.

Stattdessen gilt:

- alte Faehigkeiten analysieren
- neue Verantwortlichkeiten festlegen
- in die neue Architektur ueberfuehren
