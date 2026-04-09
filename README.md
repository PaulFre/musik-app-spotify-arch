# musik-app-spotify-arch

Flutter-basierte `2.0`-Neuausrichtung der bisherigen `party-queue-app`.

Dieses Repository ist nicht nur ein Spotify-Experiment, sondern soll die neue
Hauptbasis der App werden: architektonisch sauberer, testbarer und spaeter mit
echter Spotify-Integration.

## Aktueller Stand

Der aktuelle Stand ist ein belastbares Architektur- und Playback-Geruest:

- getrennte Bereiche fuer `party` und `spotify`
- `application / domain / data / presentation` in den Features
- entkoppelter `PartyRoomController`
- `PlaybackOrchestrator` fuer serielle Playback-Kommandos
- getrennte Room- und Playback-Zustaende
- Host-Setup fuer Spotify-Verbindung und Device-Auswahl als MVP-Geruest

Spotify ist im Moment noch ueber Fake-Services angebunden. Das ist bewusst so,
damit die Produktlogik stabil bleibt, waehrend die echte Integration spaeter
schrittweise ersetzt wird.

## Zielbild 2.0

Dieses Repo soll die bessere, ueberarbeitete Version der ersten App werden.

Das bedeutet:

- architektonisch besser als `party-queue-app`
- funktional mindestens auf MVP-Niveau des alten Repos
- danach echte Spotify-Integration in klarer Reihenfolge

Wichtig:

- Das neue Repo ersetzt nicht einfach blind das alte.
- Alte Faehigkeiten werden in die neue Struktur ueberfuehrt.
- Spotify kommt erst sauber auf diese neue Basis.

## Prioritaeten

Die Arbeit folgt aktuell dieser Reihenfolge:

1. Produktparitaet und Scope fuer `2.0` festziehen
2. Realtime-/Firebase-Strategie in neuer Struktur zurueckholen
3. Join-/Session-/Room-Lifecycle vervollstaendigen
4. Docs, CI und Qualitaetsbasis nachziehen
5. Erst danach echte Spotify-Integration weiterbauen

Details dazu stehen in:

- [docs/00_2.0_SCOPE.md](/d:/dev/projects/musik_app%20-%20Kopie/docs/00_2.0_SCOPE.md)
- [docs/01_MIGRATION_BACKLOG.md](/d:/dev/projects/musik_app%20-%20Kopie/docs/01_MIGRATION_BACKLOG.md)

## Was bereits funktioniert

- lokales Host-/Gast-Raummodell
- Queue, Voting, Cooldown, Host-Rechte
- isolierte Playback-Architektur fuer Host-only-Steuerung
- Mehrcontroller-Simulationen und Stresstests
- Analyzer und Test-Suite gruen

## Was noch bewusst offen ist

- echte Spotify OAuth-/PKCE-Integration
- echte Device-/Playback-API-Anbindung
- Firebase-/Realtime-Rueckholung aus dem alten MVP
- QR-/Invite-/Scanner-Flows
- CI, Coverage, Firestore-Regeltests, Deploy-Kontext

## Lokale Checks

```bash
flutter analyze
flutter test
```

## Repo-Rolle

Dieses Repository ist aktuell die `2.0`-Basis.

Es ist kein fertig migrierter Nachfolger von `party-queue-app`, sondern der
neue Hauptpfad, in den die fehlenden Produkt- und Realtime-Faehigkeiten jetzt
kontrolliert wieder eingezogen werden.
