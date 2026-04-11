# Regression Fixes R1 bis R3

## Zweck

Dieses Dokument fasst den gezielten Regression-Fix-Block nach den Feature-Arbeiten
zusammen. Fokus war nicht neuer Scope, sondern die Wiederherstellung der
funktionalen Kernfluesse.

## Behobene Probleme

### R1 Login-Return-Flow

Problem:

- Nach erfolgreichem Spotify-Login sprang die App zur Startseite zurueck oder
  zeigte kurz die Home-UI, statt sauber im Host-Flow zu bleiben.

Fix:

- Der Pending-Host-Resume-Flag wird nicht mehr zu frueh konsumiert.
- Der Resume-Flow bleibt bis zur echten Rueckkehrstelle erhalten.
- Der Home-Screen wurde so gegatet, dass im Pending-Resume-Fall kein sichtbarer
  Home-Flash mehr auftritt.

Ergebnis:

- Spotify-Login fuehrt wieder direkt zurueck in den Host-Flow.
- Kein sichtbarer Ruecksprung auf die Startseite.

### R2 Auto-Advance

Problem:

- Nach natuerlichem Song-Ende startete der naechste Song nicht automatisch.
- Erst `Skip` fuehrte zum naechsten Titel.

Fix:

- Der bestaetigte Playback-State wurde minimal um `actualProgressMs` erweitert.
- Natuerliches Song-Ende kann jetzt auch im Fall erkannt werden:
  - gleicher Track
  - Progress springt zurueck
  - Pause-/Fehler-/Device-Guards bleiben erhalten

Ergebnis:

- Naechster Song startet nach natuerlichem Ende wieder automatisch.

### R3 Suggestions

Problem:

- Vorschlaege blieben nach `Top Song spielen` haengen oder verschwanden.
- Der Suggestions-Bereich konnte in einem Dauer-Loading enden.

Fixes:

- stale Request-/Reload-Pfade im Screen wurden abgesichert
- serielle Seed-Suchen im Controller/Service wurden fail-fast gemacht
- der Build-Trigger fuer Suggestions-Reload wurde aus dem aktiven Build-Frame
  herausgenommen und sauber per Post-Frame-Scheduling geplant

Ergebnis:

- Kein `setState() called during build` mehr
- Suggestions laden wieder stabil
- Vorschlaege werden lokal wieder sichtbar und enden mit `visibleCount=3`

## Lokal verifiziert

Folgende reale Browser-Flows wurden erfolgreich lokal geprueft:

- Spotify-Login kehrt sauber in den Host-Flow zurueck
- kein sichtbarer Home-Flash im Resume-Fall
- Auto-Advance nach natuerlichem Song-Ende funktioniert
- Suggestions laden nach `Top Song spielen` wieder stabil und sichtbar

## Qualitaetslage

- `flutter analyze` war nach den Reparaturen gruen
- einige gezielte Testlaeufe in dieser Shell-Umgebung waren weiterhin nicht
  immer verlaesslich bis zum Ende bestaetigbar
- die entscheidenden Kernfluesse wurden jedoch lokal im echten Lauf geprueft

## Ergebnis

Der Regression-Fix-Block `R1 bis R3` ist aus lokaler Produktsicht erfolgreich
abgeschlossen:

- Login-Return-Flow stabil
- Auto-Advance stabil
- Suggestions stabil

Damit ist die App wieder in einem deutlich belastbareren funktionalen Zustand
als vor diesem Reparaturblock.
