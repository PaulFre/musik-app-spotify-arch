import 'package:flutter/material.dart';

class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  static AppStrings of(BuildContext context) {
    return AppStrings(Localizations.localeOf(context));
  }

  bool get _isGerman => locale.languageCode != 'en';

  String get appTitle => 'Party Queue';
  String get homeTagline =>
      _isGerman ? 'Demokratische Spotify-Queue' : 'Democratic Spotify queue';
  String get hostRoom => _isGerman ? 'Raum hosten' : 'Host room';
  String get joinRoom => _isGerman ? 'Raum beitreten' : 'Join room';
  String get settings => _isGerman ? 'Einstellungen' : 'Settings';
  String get themeMode => _isGerman ? 'Dark Mode' : 'Theme';
  String get language => _isGerman ? 'Sprache' : 'Language';
  String get light => _isGerman ? 'Hell' : 'Light';
  String get dark => _isGerman ? 'Dunkel' : 'Dark';
  String get defaultCooldown =>
      _isGerman ? 'Standard-Cooldown' : 'Default cooldown';
  String minutes(int value) => _isGerman ? '$value Minuten' : '$value minutes';
  String cooldownOption(int value) =>
      _isGerman ? '$value Minuten Cooldown' : '$value minute cooldown';
  String get notifications =>
      _isGerman ? 'Benachrichtigungen' : 'Notifications';
  String get spotifyHostSetup =>
      _isGerman ? 'Spotify-Host Setup' : 'Spotify host setup';
  String connectedAs(String name) =>
      _isGerman ? 'Verbunden als $name' : 'Connected as $name';
  String get spotifyHostFallback => _isGerman ? 'Spotify Host' : 'Spotify host';
  String get spotifyNotConnected =>
      _isGerman ? 'Spotify noch nicht verbunden' : 'Spotify not connected yet';
  String get spotifyConnectionCancelled => _isGerman
      ? 'Spotify-Verbindung wurde abgebrochen.'
      : 'Spotify connection was cancelled.';
  String get connectSpotify =>
      _isGerman ? 'Mit Spotify verbinden' : 'Connect Spotify';
  String get spotifyConnected =>
      _isGerman ? 'Spotify verbunden' : 'Spotify connected';
  String get loadDevices => _isGerman ? 'Geräte laden' : 'Load devices';
  String get logout => _isGerman ? 'Ausloggen' : 'Log out';
  String get playbackDevice =>
      _isGerman ? 'Wiedergabegerät' : 'Playback device';
  String get playbackSetupStillOpen => _isGerman
      ? 'Noch keine Geräte geladen. Raum-Erstellung bleibt erlaubt, Playback aber gesperrt.'
      : 'No devices loaded yet. Room creation stays available, but playback remains blocked.';
  String get yourDisplayName =>
      _isGerman ? 'Dein Anzeigename' : 'Your display name';
  String get songCooldown => _isGerman ? 'Song-Cooldown' : 'Song cooldown';
  String maxParticipants(int count) =>
      _isGerman ? 'Max. Teilnehmer: $count' : 'Max participants: $count';
  String get publicRoom => _isGerman ? 'Öffentlicher Raum' : 'Public room';
  String get privateRoomPassword =>
      _isGerman ? 'Passwort für privaten Raum' : 'Password for private room';
  String get missingPrivateRoomPassword => _isGerman
      ? 'Bitte ein Passwort für den privaten Raum festlegen.'
      : 'Please set a password for the private room.';
  String get createRoom => _isGerman ? 'Raum erstellen' : 'Create room';
  String get invalidJoinInput => _isGerman
      ? 'Bitte einen gültigen Raumcode oder Einladungslink eingeben.'
      : 'Please enter a valid room code or invitation link.';
  String get joinFailed =>
      _isGerman ? 'Beitritt fehlgeschlagen' : 'Join failed';
  String get displayName => _isGerman ? 'Anzeigename' : 'Display name';
  String get guestDefaultName => _isGerman ? 'Gast' : 'Guest';
  String get roomCodeOrLink =>
      _isGerman ? 'Raumcode oder Link' : 'Room code or link';
  String get join => _isGerman ? 'Beitreten' : 'Join';
  String get publicRooms => _isGerman ? 'Öffentliche Räume' : 'Public rooms';
  String get noPublicRoomsOpen => _isGerman
      ? 'Aktuell sind keine öffentlichen Räume offen.'
      : 'There are currently no public rooms open.';
  String hostLabel(String fallback) => fallback;
  String publicRoomListSubtitle(String code, int current, int max) => _isGerman
      ? 'Raum $code | $current/$max Teilnehmer'
      : 'Room $code | $current/$max participants';
  String get roomClosed => _isGerman ? 'Raum geschlossen' : 'Room closed';
  String get roomClosedMessage => _isGerman
      ? 'Der Host hat den Raum geschlossen.'
      : 'The host has closed the room.';
  String roomTitle(String code) => _isGerman ? 'Raum $code' : 'Room $code';
  String get hostMenu => _isGerman ? 'Host-Menü' : 'Host menu';
  String get invite => _isGerman ? 'Einladen' : 'Invite';
  String get exportPlaylist =>
      _isGerman ? 'Playlist exportieren' : 'Export playlist';
  String get guests => _isGerman ? 'Gäste' : 'Guests';
  String get closeRoom => _isGerman ? 'Raum schließen' : 'Close room';
  String get noSongYet => _isGerman ? 'Noch kein Song' : 'No song yet';
  String get spotifySearch => _isGerman ? 'Spotify Suche' : 'Spotify search';
  String get searchHint => _isGerman
      ? 'Tippe einen Song oder Artist ein. Addbar sind nur echte Spotify-Treffer.'
      : 'Type a song or artist. Only real Spotify matches can be added.';
  String get suggestions => _isGerman ? 'Vorschläge' : 'Suggestions';
  String get noSpotifySuggestions => _isGerman
      ? 'Keine Spotify-Vorschläge verfügbar.'
      : 'No Spotify suggestions available.';
  String get excludedArtistWarning => _isGerman
      ? 'Dieser Interpret wurde vom Host für diesen Raum gesperrt.'
      : 'This artist has been blocked by the host for this room.';
  String get noAddableResults => _isGerman
      ? 'Keine addbaren Spotify-Treffer gefunden.'
      : 'No addable Spotify results found.';
  String participantsSummary(int current, int max) =>
      _isGerman ? 'Teilnehmer: $current/$max' : 'Participants: $current/$max';
  String get queue => _isGerman ? 'Warteschlange' : 'Queue';
  String get noSongsAvailable =>
      _isGerman ? 'Keine Songs verfügbar.' : 'No songs available.';
  String get nowPlaying => 'Now Playing';
  String get unknownArtist =>
      _isGerman ? 'Interpret unbekannt' : 'Unknown artist';
  String addedBy(String name) =>
      _isGerman ? 'Hinzugefügt von: $name' : 'Added by: $name';
  String get paused => _isGerman ? 'Pausiert' : 'Paused';
  String get active => _isGerman ? 'Aktiv' : 'Active';
  String get setupOpen => _isGerman ? 'Setup offen' : 'Setup open';
  String get playbackHostNeedsSpotify => _isGerman
      ? 'Host braucht Spotify und ein Gerät für Playback'
      : 'Host needs Spotify and a device for playback';
  String get playTopSong => _isGerman ? 'Top Song spielen' : 'Play top song';
  String get skip => 'Skip';
  String get pauseResume => _isGerman ? 'Pause/Resume' : 'Pause/resume';
  String roomNotFoundOrClosed() => _isGerman
      ? 'Raum nicht gefunden oder geschlossen.'
      : 'Room not found or closed.';
  String privateRoomPasswordWrong() => _isGerman
      ? 'Passwort für privaten Raum ist falsch.'
      : 'Private room password is incorrect.';
  String excludedArtistAddError() => _isGerman
      ? 'Dieser Interpret wurde vom Host ausgeschlossen.'
      : 'This artist has been excluded by the host.';
}

extension AppStringsContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);
}
