# Repo Status

## Einordnung

Der aktuelle Stand ist:

- architektonisch deutlich staerker als das alte Repo
- funktional aber noch nicht auf alter MVP-Breite

## Bereits vorhanden

- neue Party-/Spotify-Trennung
- Room-Playback-Intent
- Spotify-Connection-/Playback-State
- serialisierter Playback-Orchestrator
- Host-Spotify-Setup-UI als Geruest
- Test-Suite fuer lokale Mehrcontroller- und Stressfaelle

## Noch fehlend

- echte Spotify-API
- Realtime/Firebase
- Join via Link/QR/Scanner
- alte Produktregeln in voller Breite
- CI/Coverage/Regeltests
- aussagekraeftige Produktdokumentation ueber README hinaus

## Arbeitsprinzip

Dieses Repo wird ab jetzt wie die `2.0`-Hauptlinie behandelt.

Jeder naechste Schritt soll:

- die neue Architektur beibehalten
- alte MVP-Faehigkeiten kontrolliert zurueckholen
- Tests und Analyzer grün halten
