// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Open Chess';

  @override
  String get menuSinglePlayer => 'Einzelspieler';

  @override
  String get menuTwoPlayers => 'Zwei Spieler';

  @override
  String get menuLan => 'Über LAN spielen';

  @override
  String get menuPuzzles => 'Taktikaufgaben';

  @override
  String get menuResume => 'Partie fortsetzen';

  @override
  String get menuSettings => 'Einstellungen';

  @override
  String get menuPlayFromPosition => 'Aus Stellung spielen';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get close => 'Schließen';

  @override
  String get retry => 'Wiederholen';

  @override
  String get copy => 'Kopieren';

  @override
  String get share => 'Teilen';

  @override
  String get start => 'Start';

  @override
  String get accept => 'Annehmen';

  @override
  String get decline => 'Ablehnen';

  @override
  String get send => 'Senden';

  @override
  String get whiteToMove => 'Weiß am Zug';

  @override
  String get blackToMove => 'Schwarz am Zug';

  @override
  String get whiteToMoveCheck => 'Weiß am Zug — Schach!';

  @override
  String get blackToMoveCheck => 'Schwarz am Zug — Schach!';

  @override
  String get checkmateWhiteWins => 'Schachmatt — Weiß gewinnt';

  @override
  String get checkmateBlackWins => 'Schachmatt — Schwarz gewinnt';

  @override
  String get whiteWinsOnTime => 'Weiß gewinnt auf Zeit';

  @override
  String get blackWinsOnTime => 'Schwarz gewinnt auf Zeit';

  @override
  String get drawStalemate => 'Remis — Patt';

  @override
  String get drawFiftyMove => 'Remis — 50-Züge-Regel';

  @override
  String get drawThreefold => 'Remis — dreifache Stellungswiederholung';

  @override
  String get drawInsufficient => 'Remis — ungenügendes Material';

  @override
  String get resign => 'Aufgeben';

  @override
  String get offerDraw => 'Remis anbieten';

  @override
  String get drawOfferTitle => 'Remisangebot';

  @override
  String get drawOfferBody => 'Dein Gegner bietet ein Remis an.';

  @override
  String get takeBack => 'Zug zurücknehmen';

  @override
  String get newGame => 'Neue Partie';

  @override
  String get mainMenu => 'Hauptmenü';

  @override
  String get flipBoard => 'Brett drehen';

  @override
  String get autoFlipOn => 'Automatisches Drehen: an';

  @override
  String get autoFlipOff => 'Automatisches Drehen: aus';

  @override
  String get saveGame => 'Partie speichern';

  @override
  String get aiMove => 'KI-Zug (aktuelle Seite)';

  @override
  String get playAgain => 'Erneut spielen';

  @override
  String get analyzeGame => 'Partie analysieren';

  @override
  String get gameSaved => 'Partie gespeichert';

  @override
  String get boardDesync =>
      'Brettsynchronisation verloren — Partie abgebrochen';

  @override
  String get youResigned => 'Du hast aufgegeben — du verlierst';

  @override
  String get opponentResigned => 'Gegner hat aufgegeben — du gewinnst';

  @override
  String get drawAgreed => 'Remis vereinbart';

  @override
  String get opponentDisconnected => 'Gegner hat die Verbindung getrennt';

  @override
  String get name => 'Name';

  @override
  String get gameName => 'Partiename';

  @override
  String get myGame => 'Meine Partie';

  @override
  String get analysis => 'Analyse';

  @override
  String get opening => 'Eröffnung';

  @override
  String get openingGambit => 'Gambit';

  @override
  String get openingVariation => 'Variante';

  @override
  String get openingNone => 'Keine benannte Eröffnung';

  @override
  String get ratingEstimate => 'Geschätzte Wertungszahl';

  @override
  String get ratingConfidenceLow => 'Niedrige Zuverlässigkeit';

  @override
  String get ratingConfidenceMedium => 'Mittlere Zuverlässigkeit';

  @override
  String get ratingConfidenceHigh => 'Hohe Zuverlässigkeit';

  @override
  String get ratingUnavailable => 'Wertungsschätzung nicht verfügbar';

  @override
  String get white => 'Weiß';

  @override
  String get black => 'Schwarz';

  @override
  String get accuracy => 'Genauigkeit';

  @override
  String analyzingProgress(Object done, Object total) {
    return 'Analysiere $done/$total…';
  }

  @override
  String get preparingAnalysis => 'Analyse wird vorbereitet…';

  @override
  String get clsBrilliant => 'Brillant';

  @override
  String get clsGreat => 'Großartig';

  @override
  String get clsBest => 'Bester Zug';

  @override
  String get clsGood => 'Gut';

  @override
  String get clsBook => 'Eröffnung';

  @override
  String get clsInaccuracy => 'Ungenauigkeit';

  @override
  String get clsMiss => 'Verpasst';

  @override
  String get clsMistake => 'Fehler';

  @override
  String get clsBlunder => 'Grober Fehler';

  @override
  String get coachBrilliant => 'Brillant — ein gewinnbringendes Opfer.';

  @override
  String get coachGreat => 'Großartig — der einzige Zug, der hält.';

  @override
  String get coachBest => 'Bester Zug.';

  @override
  String get coachBook => 'Ein bekannter Eröffnungszug.';

  @override
  String get coachGood => 'Ein guter Zug.';

  @override
  String coachInaccuracy(Object best) {
    return 'Ungenauigkeit — $best war etwas besser.';
  }

  @override
  String coachMiss(Object best) {
    return 'Eine Gewinnchance verpasst — $best war deutlich stärker.';
  }

  @override
  String coachMistake(Object best) {
    return 'Fehler — $best war stärker.';
  }

  @override
  String coachBlunder(Object best) {
    return 'Grober Fehler — $best war deutlich besser.';
  }

  @override
  String get settings => 'Einstellungen';

  @override
  String get profile => 'Profil';

  @override
  String get profileUsername => 'Benutzername';

  @override
  String get profileUsernameHint => 'Wähle einen Benutzernamen';

  @override
  String get profileAvatar => 'Avatar';

  @override
  String get profileChangeAvatar => 'Avatar ändern';

  @override
  String get profileRemoveAvatar => 'Avatar entfernen';

  @override
  String get profileImageError => 'Dieses Bild konnte nicht verwendet werden.';

  @override
  String get appearance => 'Darstellung';

  @override
  String get boardThemeLabel => 'Brett-Design';

  @override
  String get theme => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Systemstandard';

  @override
  String get accessibility => 'Barrierefreiheit';

  @override
  String get highContrast => 'Kontrastreiches Brett';

  @override
  String get colorblindSafe => 'Farbenblindheitssichere Zugfarben';

  @override
  String get textSize => 'Textgröße';

  @override
  String get gameplay => 'Spielablauf';

  @override
  String get sound => 'Ton';

  @override
  String get moveHints => 'Zughinweise';

  @override
  String get haptics => 'Haptisches Feedback';

  @override
  String get animationSpeed => 'Animationsgeschwindigkeit';

  @override
  String get defaultTimeControl => 'Standard-Bedenkzeit';

  @override
  String get defaultDifficulty => 'Standard-Schwierigkeit';

  @override
  String get hostGame => 'Partie hosten';

  @override
  String get yourName => 'Dein Name';

  @override
  String get yourColour => 'Deine Farbe';

  @override
  String get colourWhite => 'Weiß';

  @override
  String get colourBlack => 'Schwarz';

  @override
  String get colourRandom => 'Zufällig';

  @override
  String get hostAGame => 'Eine Partie hosten';

  @override
  String get joinOnNetwork => 'Einer Partie in diesem Netzwerk beitreten';

  @override
  String get searchingHosts => 'Suche nach Hosts…';

  @override
  String get waitingOpponent => 'Warte auf Verbindung eines Gegners…';

  @override
  String get lanGame => 'LAN-Partie';

  @override
  String get lanAllowSpectators => 'Zuschauer erlauben';

  @override
  String get lanSpectate => 'Partie ansehen';

  @override
  String get chat => 'Chat';

  @override
  String get typeMessage => 'Nachricht eingeben…';

  @override
  String get noSavedGames => 'Noch keine gespeicherten Partien';

  @override
  String get renameGameTitle => 'Partie umbenennen';

  @override
  String get pasteFen => 'FEN-Zeichenkette einfügen';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen =>
      'Ungültige FEN — überprüfe die Stellungszeichenkette';

  @override
  String get useStartPosition => 'Grundstellung verwenden';

  @override
  String get loadPosition => 'Stellung laden';

  @override
  String get exportPgn => 'PGN exportieren';

  @override
  String get copyPgn => 'PGN kopieren';

  @override
  String get copiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get game => 'Partie';

  @override
  String get lanTitle => 'Zwei Spieler — LAN';

  @override
  String get playAs => 'Spielen als';

  @override
  String get difficulty => 'Schwierigkeit';

  @override
  String get timeControl => 'Bedenkzeit';

  @override
  String get startGame => 'Partie starten';

  @override
  String get custom => 'Benutzerdefiniert';

  @override
  String get tcInfinite => 'Unbegrenzt';

  @override
  String get diffVeryEasy => 'Sehr leicht';

  @override
  String get diffEasy => 'Leicht';

  @override
  String get diffNormal => 'Normal';

  @override
  String get diffHard => 'Schwer';

  @override
  String get diffVeryHard => 'Sehr schwer';

  @override
  String get diffImpossible => 'Unmöglich';

  @override
  String get baseMinutes => 'Grundzeit (Minuten)';

  @override
  String get incrementSeconds => 'Inkrement (Sekunden)';

  @override
  String get baseTimeError => 'Die Grundzeit muss mindestens 1 Minute betragen';

  @override
  String get searchDepth => 'Suchtiefe';

  @override
  String get timePerMove => 'Zeit/Zug (ms)';

  @override
  String get maxEvalLoss => 'Maximaler Bewertungsverlust (cp)';

  @override
  String get moveVariety => 'Zugvielfalt';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return '$solved/$total gelöst';
  }

  @override
  String get alreadySolved => 'bereits gelöst';

  @override
  String get puzzleWrong => 'Nicht der richtige Zug — versuche es erneut';

  @override
  String get puzzleSolvedMsg => 'Gelöst! ✓  Tippe auf ▶ für das nächste Puzzle';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return 'Puzzle $index/$total  ·  Wertung $rating  ·  Serie $streak (Bestwert $best)';
  }

  @override
  String get loadPuzzlesFailed => 'Puzzles konnten nicht geladen werden';

  @override
  String get previous => 'Zurück';

  @override
  String get hint => 'Tipp';

  @override
  String get restartPuzzle => 'Puzzle neu starten';

  @override
  String get next => 'Weiter';

  @override
  String get savedCorrupt =>
      'Der gespeicherte Spielstand war beschädigt; teilweise geladen';

  @override
  String get menuBughouse => 'Bughouse';

  @override
  String get bugMode => 'Modus';

  @override
  String get bugBoardA => 'Brett A';

  @override
  String get bugBoardB => 'Brett B';

  @override
  String get bugWhite => 'Weiß';

  @override
  String get bugBlack => 'Schwarz';

  @override
  String bugTeamWins(String team) {
    return 'Team $team gewinnt';
  }

  @override
  String get bugStart => 'Partie starten';

  @override
  String get bugLan => 'LAN';

  @override
  String get bugHostMatch => 'Partie hosten';

  @override
  String get bugJoinMatch => 'Partie beitreten';

  @override
  String get bugWaitingHost => 'Warten, bis der Host startet…';

  @override
  String get bugPlayersJoined => 'Beigetretene Spieler';

  @override
  String get bugAssignSeats => 'Die vier Plätze zuweisen';

  @override
  String get bugSeatHost => 'Host (du)';

  @override
  String get variant => 'Variante';

  @override
  String get vStandard => 'Standard';

  @override
  String get vThreeCheck => 'Dreischach';

  @override
  String get vKingOfTheHill => 'King of the Hill';

  @override
  String get vChess960 => 'Chess960';

  @override
  String get vAtomic => 'Atomschach';

  @override
  String get vCrazyhouse => 'Crazyhouse';

  @override
  String get vFogOfWar => 'Dark Chess';

  @override
  String get menuFourPlayer => '4 Spieler';

  @override
  String get fourFormat => 'Format';

  @override
  String get fourFFA => 'Jeder gegen jeden';

  @override
  String get fourTeams => 'Teams (2 gegen 2)';

  @override
  String get fourVsBots => 'gegen Bots';

  @override
  String get fourSeatAi => 'KI';

  @override
  String get fourPerspective => 'Perspektive';

  @override
  String get fourYourSeats => 'Deine Plätze';

  @override
  String get fourRed => 'Rot';

  @override
  String get fourBlue => 'Blau';

  @override
  String get fourYellow => 'Gelb';

  @override
  String get fourGreen => 'Grün';

  @override
  String fourTeamWins(String team) {
    return '$team gewinnt';
  }

  @override
  String fourWins(String player) {
    return '$player gewinnt';
  }

  @override
  String get checksLabel => 'Schachgebote';

  @override
  String get support => 'Unterstützung';

  @override
  String get donate => 'Spenden';

  @override
  String get donateSubtitle =>
      'Unterstütze die Entwicklung über GitHub Sponsors';

  @override
  String get checkForUpdates => 'Nach Updates suchen';

  @override
  String get checkingForUpdates => 'Suche nach Updates…';

  @override
  String get upToDate => 'Du hast die neueste Version.';

  @override
  String get updateAvailable => 'Update verfügbar';

  @override
  String get newVersionAvailable => 'Eine neue Version ist verfügbar:';

  @override
  String get download => 'Herunterladen';

  @override
  String get later => 'Später';

  @override
  String get about => 'Über';

  @override
  String storeCorrupt(Object path) {
    return 'Eine Datendatei konnte nicht gelesen werden. Eine Kopie wurde unter $path aufbewahrt.';
  }

  @override
  String get settingsSaveFailed =>
      'Eine Einstellung konnte nicht gespeichert werden. Sie gilt, bis die App geschlossen wird.';

  @override
  String get fenCastlingRemoved =>
      'Rochaderechte, die nicht zur Stellung passten, wurden entfernt.';

  @override
  String get fenEnPassantRemoved =>
      'Ein En-passant-Feld, das nicht zur Stellung passte, wurde entfernt.';

  @override
  String get fenOpenedAsChess960 =>
      'Als Chess960 geöffnet: Diese Rochadeaufstellung ist im Standardschach nicht gültig.';

  @override
  String savedPartialReplay(int count) {
    return 'Züge, die mit den aktuellen Regeln nicht nachgespielt werden konnten: $count. Die Partie wurde beim letzten spielbaren Zug geöffnet; Ihre gespeicherte Partie wurde nicht verändert.';
  }

  @override
  String savedGameDefaultName(Object stamp) {
    return 'Partie $stamp';
  }

  @override
  String get gameSaveFailed => 'Die Partie konnte nicht gespeichert werden.';

  @override
  String get pauseGame => 'Pause';

  @override
  String get resumeGame => 'Fortsetzen';

  @override
  String get gamePaused => 'Partie pausiert';

  @override
  String get chatTooLong => 'Die Nachricht ist zu lang.';

  @override
  String get aiThinking => 'KI denkt nach…';

  @override
  String aiDepthEval(int depth, Object eval) {
    return 'KI: Tiefe $depth, Bewertung $eval';
  }

  @override
  String pliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Halbzüge',
      one: '1 Halbzug',
    );
    return '$_temp0';
  }

  @override
  String get openLinkFailed => 'Der Link konnte nicht geöffnet werden.';

  @override
  String get boardGreen => 'Grün';

  @override
  String get boardBrown => 'Braun';

  @override
  String get boardBlue => 'Blau';

  @override
  String get boardGray => 'Grau';

  @override
  String get animationOff => 'Aus';

  @override
  String animationMs(int ms) {
    return '$ms ms';
  }

  @override
  String get checkUpdatesOnLaunch => 'Beim Start nach Updates suchen';

  @override
  String get gameOverGeneric => 'Partie beendet';

  @override
  String get lanIncompatibleVersion =>
      'Das andere Gerät nutzt eine andere Version von Open Chess. Aktualisiere die App auf beiden Geräten.';

  @override
  String get tooManyPendingUpdates =>
      'Zu viele ausstehende Spielaktualisierungen.';

  @override
  String get continueGame => 'Unbeendete Partie fortsetzen';

  @override
  String get discardGame => 'Verwerfen';

  @override
  String get noMovesYet => 'Noch keine Züge';

  @override
  String get promoteTo => 'Umwandeln in';

  @override
  String get piecePawn => 'Bauer';

  @override
  String get pieceKnight => 'Springer';

  @override
  String get pieceBishop => 'Läufer';

  @override
  String get pieceRook => 'Turm';

  @override
  String get pieceQueen => 'Dame';

  @override
  String get pieceKing => 'König';

  @override
  String squarePieceLabel(Object square, Object color, Object piece) {
    return '$square, $color: $piece';
  }

  @override
  String get staleCastlingTitle => 'Veraltete Rochaderechte';

  @override
  String get staleCastlingBody =>
      'Diese gespeicherte Stellung erlaubt eine Rochade mit einem Turm, der nicht mehr da ist. Ohne diese Rochaderechte öffnen? Die gespeicherte Partie selbst bleibt unverändert.';

  @override
  String get openAnyway => 'Öffnen';

  @override
  String savedFenRejected(Object error) {
    return 'Diese gespeicherte Partie kann nicht geöffnet werden: $error';
  }

  @override
  String analysisFailed(Object error) {
    return 'Analyse fehlgeschlagen. $error';
  }

  @override
  String get importGame => 'PGN / FEN importieren';

  @override
  String get importFromClipboard => 'Einfügen';

  @override
  String get importFromFile => 'Datei öffnen';

  @override
  String get importHint => 'PGN-Partie oder FEN-Stellung einfügen';

  @override
  String get importEmpty => 'Nichts zu importieren.';

  @override
  String get importTooLarge => 'Der Text ist zu groß für den Import.';

  @override
  String importTooLong(int max) {
    return 'Die Partie ist länger als $max Halbzüge.';
  }

  @override
  String importBadFen(Object error) {
    return 'Ungültige Stellung: $error';
  }

  @override
  String importBadMove(Object move) {
    return 'Ungültiger oder unlesbarer Zug: $move';
  }

  @override
  String importUnsupported(Object variant) {
    return 'Diese Variante kann nicht analysiert werden: $variant';
  }

  @override
  String get importReadFailed => 'Die Datei konnte nicht gelesen werden.';

  @override
  String engineFailed(Object error) {
    return 'Die Engine kann diese Stellung nicht berechnen: $error';
  }
}
