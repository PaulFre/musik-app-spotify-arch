# Milestone B1 bis C2

## Zweck dieses Dokuments

Dieses Dokument fasst den abgeschlossenen Arbeitsblock von `B1` bis `C2`
praezise zusammen. Es dient als belastbarer Zwischenstand fuer weitere Arbeit,
Code-Reviews, Uebergaben und Git-Historie.

Der Fokus liegt auf:

- was fachlich umgesetzt wurde
- wie es architektonisch eingeordnet ist
- welche Schutzmechanismen und Tests nachgezogen wurden
- welche bewussten Scope-Entscheidungen getroffen wurden

## Architekturrahmen

Die bestehende Architektur wurde im gesamten Block beibehalten:

- `Controller -> Intent -> Processor -> Orchestrator`
- keine Spotify-Calls im Controller
- keine Produktlogik in der UI, wenn sie sauber in Controller oder kleine
  Domain-Helper gehoert
- Room-State bleibt die zentrale Wahrheit

Wichtige bestehende Bereiche:

- `party` fuer Room-, Queue-, Voting- und Host-Flows
- `spotify` fuer Auth, Playback und Orchestrierung
- `settings` fuer globale App-Einstellungen wie Theme und Sprache

## Ausgangspunkt vor diesem Block

Vor Beginn dieses Milestones war bereits vorhanden:

- saubere Trennung der Party- und Spotify-Schichten
- Spotify-Auth / Playback-Grundlage
- Queue, Voting und Cooldown-Logik
- Host-Menue als UI-Grundstruktur
- belastbare Testbasis mit Controller-, Simulation- und Widget-Tests

Dieser Block hat die naechsten Produktfeatures der Roadmap umgesetzt:

- `B2 Invite / Share / QR`
- `B3 Gaesteliste`
- `C1 Einstellungen (Limits)`
- `C2 Playlist Export`

`B1` wurde in diesem Arbeitsstand als sauber abgeschlossen behandelt und war
damit die Basis fuer die folgenden Schritte.

---

## B2 Invite / Share / QR

### Ziel

Hosts sollen einen Raum ueber einen echten Invite-Flow teilen koennen, ohne
einen zweiten Join-Sonderweg einzufuehren.

### Umsetzung

- Der Host-Menuepunkt `Einladen` oeffnet jetzt ein echtes Invite-Bottom-Sheet.
- Das Sheet zeigt:
  - Invite-Link
  - Room-Code
  - QR-Code
  - Copy-Aktionen fuer Link und Code
- Der Invite-Link wird nicht im UI zusammengebaut, sondern ueber einen kleinen
  dedizierten Link-Builder erzeugt.
- Das Link-Format wurde bewusst auf dem bestehenden Join-Pfad gehalten:
  - `/join?code=ROOMCODE`
- Der QR-Code kodiert exakt denselben Link.

### Plattform-/Deep-Link-Absicherung

Der Invite-Flow wurde plattformuebergreifend vorbereitet und vereinheitlicht:

- Flutter erzeugt Invite-Links ueber `PUBLIC_APP_BASE_URL`
- Android leitet App-Link-Schema und Host aus derselben Basis-URL ab
- iOS erzeugt Associated-Domain-Entitlements aus derselben Basis-URL
- ein zentraler App-Join-Link-Service verarbeitet Initial-Links und laufend
  eingehende Links
- gueltige Join-Links oeffnen den bestehenden `JoinRoomScreen`
- der Join-Screen wird mit erkanntem Code vorbefuellt
- ungueltige oder fachlich nicht passende Links werden ignoriert

### Wichtige Scope-Entscheidungen

- kein zweiter Invite-Sonderweg
- keine Invite-Logik direkt im UI
- keine echte serverseitige Deep-Link-Infrastruktur im Repo selbst
- keine vollstaendige Web-Routing-/Hosting-Loesung im Repo

### Produktive Restschritte ausserhalb des Repos

Fuer echten Produktionseinsatz bleiben externe Deployment-Schritte noetig:

- echte Domain via `--dart-define=PUBLIC_APP_BASE_URL=...`
- Android `assetlinks.json`
- iOS `apple-app-site-association`
- korrektes Signing / Team / Bundle-ID auf iOS
- Web-Hosting muss `/join?...` auf die Flutter-Web-App routen

### Ergebnis

`B2` ist aus Repo-Sicht als Feature abgeschlossen:

- Invite-Link
- QR-Code
- Copy-Flow
- konsistenter Join-Eintrittspfad
- plattformuebergreifend vorbereitete Host-/Domain-Kopplung

---

## B3 Gaesteliste

### Ziel

Der Host-Menuepunkt `Gaeste` soll statt eines Platzhalters eine echte
Teilnehmeransicht oeffnen.

### Umsetzung

- `Gaeste` oeffnet jetzt ein echtes Bottom Sheet.
- Die Liste liest direkt aus `room.participants`.
- Es wurde kein zweiter Teilnehmerpfad eingefuehrt.

### Darstellung

Die Gaesteliste zeigt:

- Anzeigename
- Host-Markierung
- `Du`-Markierung fuer den aktuellen Nutzer

Sortierung:

- Host zuerst
- danach weitere Teilnehmer stabil nach Anzeigename

Leerzustand:

- wenn nur der Host vorhanden ist:
  - `Noch keine weiteren Gaeste im Raum.`

### Moderation / Kick

Die bereits vorhandene `kickParticipant(...)`-Logik wurde sauber integriert:

- nur im Host-Kontext sichtbar
- Host kann sich nicht selbst entfernen
- Nicht-Hosts sehen keine Kick-Aktion

Nach dem Nachziehen der Restpunkte arbeitet das Sheet reaktiv ueber den
bestehenden `PartyRoomController`:

- kein einmaliger Room-Snapshot mehr
- bei Room-Aenderungen baut sich die Liste neu auf
- nach Kick verschwindet der Gast direkt aus der offenen UI
- Erfolgsmeldung wird nur gezeigt, wenn der Teilnehmer im echten Room-State
  wirklich entfernt wurde

### Ergebnis

`B3` ist aus Repo-Sicht abgeschlossen:

- echter Host-Menuepfad
- stabile Gaesteliste
- Markierungen
- Empty-State
- Kick-Integration ohne Architekturbruch

---

## C1 Raum-Einstellungen (Limits)

### Ziel

Der Host soll Raum-Limits ueber eine echte UI bearbeiten koennen.

### Bewusste Scope-Entscheidung

`C1` bezieht sich auf Raum-Limits, nicht auf globale App-Einstellungen.

Nicht Teil dieses Schritts:

- Theme / Sprache
- neue Admin-/Backend-Logik
- neue Settings-Welten neben `RoomSettings`

### Umsetzung

Der Host-Menuepunkt `Einstellungen` oeffnet jetzt ein echtes
Room-Settings-Bottom-Sheet.

Bearbeitbare Werte:

- `cooldownMinutes`
- `maxParticipants`
- `maxQueuedTracksPerUser`

Die Werte werden ueber `PartyRoomController.updateRoomSettings(...)`
gespeichert.

### Validierung / Rechte

Host-only:

- nur der Host kann das Sheet produktiv oeffnen und speichern
- im Controller ist zusaetzlich abgesichert, dass Nicht-Hosts `false`
  erhalten

Validierung:

- Teilnehmerlimit nicht unter aktueller Teilnehmerzahl
- Queue-Limit pro Nutzer mindestens `1`
- Cooldown nicht negativ

### Wirkung im Produkt

Die geaenderten Werte landen direkt in `room.settings`.

Da bestehende Produktlogik bereits aus `room.settings` liest, wirken die
Aenderungen direkt weiter in:

- Join-Limit
- Queue-Limit
- Cooldown-/Voting-Verhalten

### Nachgezogener Randfall

Ein Slider-Grenzfall bei `100` Teilnehmern wurde nachtraeglich sauber
abgesichert:

- Teilnehmer-Slider setzt `divisions` nur, wenn `minParticipants < 100`
- bei `min == max == 100` wird `divisions == null`
- dadurch bleibt das Sheet auch im Vollraum stabil renderbar

### Ergebnis

`C1` ist aus Repo-Sicht abgeschlossen:

- echter Host-Settings-Flow
- wirksame Limit-Aenderung im echten Room-State
- Validierung
- Host-only-Schutz
- stabiler Grenzfall bei voller Teilnehmerzahl

---

## C2 Playlist Export

### Ziel

`C2` wurde bewusst als kleiner, sauberer Export-MVP umgesetzt und nicht als
vollstaendige Spotify-Remote-Playlist-Erstellung.

### Bewusste Scope-Entscheidung

Nicht Teil dieses Schritts:

- Spotify-Playlist-Erstellung ueber Remote-APIs
- Backend-/Cloud-Ausbau
- komplexes Share-/Import-/Export-System

Stattdessen:

- echter, benutzbarer Clipboard-Export-MVP

### Umsetzung

Der Host-Menuepunkt `Playlist exportieren` oeffnet jetzt ein echtes
Bottom Sheet.

Exportiert wird:

- die aktuelle Queue des Raums
- in bestehender Reihenfolge
- bewusst ohne `now playing`

Pro Export-Eintrag:

- Titel
- Artist
- optional vorhandene Spotify-URI

### Exportformat

Der Exporttext wird ueber einen kleinen dedizierten Builder aufgebaut.

Format:

- Kopf:
  - `Party Queue Export`
  - `Raum <CODE>`
- danach Trackliste als:
  - `1. Titel - Artist`
  - optional `(<spotify:track:...>)`

### Nutzeraktion

Die konkrete MVP-Aktion ist:

- `Export kopieren`

Umsetzung:

- `Clipboard.setData(...)`
- Snackbar:
  - `Playlist-Export kopiert.`

### Leerzustand

Wenn die Queue leer ist:

- das Sheet zeigt:
  - `Aktuell ist keine Queue zum Exportieren vorhanden.`
- die Copy-Aktion ist deaktiviert

### Ergebnis

`C2` ist als MVP aus Repo-Sicht abgeschlossen:

- echter Host-only-Export-Flow
- klar definiertes Exportformat
- nutzbare Copy-Aktion
- sauberer Leerzustand
- bewusst klein gehalten

---

## Test- und Qualitaetslage

Ueber den gesamten Block hinweg wurden fuer neue Features passende Tests
nachgezogen und bei Bedarf korrigiert.

Abgedeckte Bereiche im Block:

- Invite-Link-Builder
- Invite-Sheet
- App-Join-Link-Service
- Join-Screen-Prefill
- Gaesteliste
- Kick-Verhalten im offenen Sheet
- Host-Menuepfade fuer `Gaeste`, `Einstellungen` und `Playlist exportieren`
- Room-Settings-Sheet
- Controller-Validierung fuer Room-Settings
- Playlist-Export-Builder
- Playlist-Export-Sheet inklusive Clipboard-Pruefung

Bestatigter Stand im Verlauf:

- `flutter analyze` war nach den Abschluessen der einzelnen Schritte jeweils
  gruen

Wiederkehrender Vorbehalt:

- komplette `flutter test`-Laeufe konnten in der Shell-Umgebung nicht immer
  verlaesslich bis zum Ende bestaetigt werden, weil Timeouts auftraten

Das bedeutet:

- Analyzer- und gezielte Einzelpruefungen waren stabil
- fuer finalen Release-/Merge-Standard sollte ein kompletter Testlauf in einer
  stabilen lokalen oder CI-Umgebung zusaetzlich bestaetigt werden

---

## Zusammenfassung des abgeschlossenen Blocks

Mit diesem Milestone wurden vier aufeinander aufbauende Produktschritte sauber
abgeschlossen:

- `B2 Invite / Share / QR`
- `B3 Gaesteliste`
- `C1 Raum-Einstellungen (Limits)`
- `C2 Playlist Export (MVP)`

Dabei blieb die bestehende Architektur erhalten und wurde nicht aufgeweicht.

Der aktuelle Stand bietet nun:

- plattformvorbereitete Invite- und Join-Flows
- echte Host-Menuefunktionen statt Platzhalter
- moderierbare Gaesteliste
- bearbeitbare Raum-Limits
- benutzbaren Queue-Export

Der naechste groessere Schritt kann damit auf einer klareren und funktional
deutlich staerkeren Produktbasis aufbauen.
