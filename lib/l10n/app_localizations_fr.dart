// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Open Chess';

  @override
  String get menuSinglePlayer => 'Un joueur';

  @override
  String get menuTwoPlayers => 'Deux joueurs';

  @override
  String get menuLan => 'Jouer en réseau local';

  @override
  String get menuPuzzles => 'Problèmes';

  @override
  String get menuResume => 'Reprendre la partie';

  @override
  String get menuSettings => 'Paramètres';

  @override
  String get menuPlayFromPosition => 'Jouer depuis une position';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get rename => 'Renommer';

  @override
  String get close => 'Fermer';

  @override
  String get retry => 'Réessayer';

  @override
  String get copy => 'Copier';

  @override
  String get share => 'Partager';

  @override
  String get start => 'Démarrer';

  @override
  String get accept => 'Accepter';

  @override
  String get decline => 'Refuser';

  @override
  String get send => 'Envoyer';

  @override
  String get whiteToMove => 'Aux Blancs de jouer';

  @override
  String get blackToMove => 'Aux Noirs de jouer';

  @override
  String get whiteToMoveCheck => 'Aux Blancs de jouer — échec !';

  @override
  String get blackToMoveCheck => 'Aux Noirs de jouer — échec !';

  @override
  String get checkmateWhiteWins => 'Échec et mat — les Blancs gagnent';

  @override
  String get checkmateBlackWins => 'Échec et mat — les Noirs gagnent';

  @override
  String get whiteWinsOnTime => 'Les Blancs gagnent au temps';

  @override
  String get blackWinsOnTime => 'Les Noirs gagnent au temps';

  @override
  String get drawStalemate => 'Nulle — pat';

  @override
  String get drawFiftyMove => 'Nulle — règle des cinquante coups';

  @override
  String get drawThreefold => 'Nulle — triple répétition';

  @override
  String get drawInsufficient => 'Nulle — matériel insuffisant';

  @override
  String get resign => 'Abandonner';

  @override
  String get offerDraw => 'Proposer la nulle';

  @override
  String get drawOfferTitle => 'Proposition de nulle';

  @override
  String get drawOfferBody => 'Votre adversaire propose la nulle.';

  @override
  String get takeBack => 'Reprendre le coup';

  @override
  String get newGame => 'Nouvelle partie';

  @override
  String get mainMenu => 'Menu principal';

  @override
  String get flipBoard => 'Retourner l\'échiquier';

  @override
  String get autoFlipOn => 'Retournement auto : activé';

  @override
  String get autoFlipOff => 'Retournement auto : désactivé';

  @override
  String get saveGame => 'Enregistrer la partie';

  @override
  String get aiMove => 'Coup de l\'IA (camp actuel)';

  @override
  String get playAgain => 'Rejouer';

  @override
  String get analyzeGame => 'Analyser la partie';

  @override
  String get gameSaved => 'Partie enregistrée';

  @override
  String get boardDesync =>
      'Désynchronisation de l\'échiquier — partie interrompue';

  @override
  String get youResigned => 'Vous avez abandonné — vous perdez';

  @override
  String get opponentResigned => 'L\'adversaire a abandonné — vous gagnez';

  @override
  String get drawAgreed => 'Nulle convenue';

  @override
  String get opponentDisconnected => 'Adversaire déconnecté';

  @override
  String get name => 'Nom';

  @override
  String get gameName => 'Nom de la partie';

  @override
  String get myGame => 'Ma partie';

  @override
  String get analysis => 'Analyse';

  @override
  String get opening => 'Ouverture';

  @override
  String get openingGambit => 'Gambit';

  @override
  String get openingVariation => 'Variante';

  @override
  String get openingNone => 'Aucune ouverture nommée';

  @override
  String get ratingEstimate => 'Classement estimé';

  @override
  String get ratingConfidenceLow => 'Confiance faible';

  @override
  String get ratingConfidenceMedium => 'Confiance moyenne';

  @override
  String get ratingConfidenceHigh => 'Confiance élevée';

  @override
  String get ratingUnavailable => 'Estimation du classement indisponible';

  @override
  String get white => 'Blancs';

  @override
  String get black => 'Noirs';

  @override
  String get accuracy => 'précision';

  @override
  String analyzingProgress(Object done, Object total) {
    return 'Analyse en cours $done/$total…';
  }

  @override
  String get preparingAnalysis => 'Préparation de l\'analyse…';

  @override
  String get clsBrilliant => 'Brillant';

  @override
  String get clsGreat => 'Excellent';

  @override
  String get clsBest => 'Meilleur';

  @override
  String get clsGood => 'Bon';

  @override
  String get clsBook => 'Théorie';

  @override
  String get clsInaccuracy => 'Imprécision';

  @override
  String get clsMiss => 'Occasion manquée';

  @override
  String get clsMistake => 'Erreur';

  @override
  String get clsBlunder => 'Gaffe';

  @override
  String get coachBrilliant => 'Brillant — un sacrifice gagnant.';

  @override
  String get coachGreat => 'Excellent — le seul coup qui tient.';

  @override
  String get coachBest => 'Meilleur coup.';

  @override
  String get coachBook => 'Un coup d\'ouverture connu.';

  @override
  String get coachGood => 'Un bon coup.';

  @override
  String coachInaccuracy(Object best) {
    return 'Imprécision — $best était un peu meilleur.';
  }

  @override
  String coachMiss(Object best) {
    return 'Occasion de gain manquée — $best était bien plus fort.';
  }

  @override
  String coachMistake(Object best) {
    return 'Erreur — $best était plus fort.';
  }

  @override
  String coachBlunder(Object best) {
    return 'Gaffe — $best était bien meilleur.';
  }

  @override
  String get settings => 'Paramètres';

  @override
  String get profile => 'Profil';

  @override
  String get profileUsername => 'Nom d\'utilisateur';

  @override
  String get profileUsernameHint => 'Choisissez un nom d\'utilisateur';

  @override
  String get profileAvatar => 'Avatar';

  @override
  String get profileChangeAvatar => 'Changer l\'avatar';

  @override
  String get profileRemoveAvatar => 'Supprimer l\'avatar';

  @override
  String get profileImageError => 'Impossible d\'utiliser cette image.';

  @override
  String get appearance => 'Apparence';

  @override
  String get boardThemeLabel => 'Thème de l\'échiquier';

  @override
  String get theme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Paramètre du système';

  @override
  String get accessibility => 'Accessibilité';

  @override
  String get highContrast => 'Échiquier à fort contraste';

  @override
  String get colorblindSafe => 'Couleurs de coups adaptées au daltonisme';

  @override
  String get textSize => 'Taille du texte';

  @override
  String get gameplay => 'Jeu';

  @override
  String get sound => 'Son';

  @override
  String get moveHints => 'Indications de coups';

  @override
  String get haptics => 'Retour haptique';

  @override
  String get animationSpeed => 'Vitesse des animations';

  @override
  String get defaultTimeControl => 'Cadence par défaut';

  @override
  String get defaultDifficulty => 'Difficulté par défaut';

  @override
  String get hostGame => 'Héberger une partie';

  @override
  String get yourName => 'Votre nom';

  @override
  String get yourColour => 'Votre couleur';

  @override
  String get colourWhite => 'Blancs';

  @override
  String get colourBlack => 'Noirs';

  @override
  String get colourRandom => 'Aléatoire';

  @override
  String get hostAGame => 'Héberger une partie';

  @override
  String get joinOnNetwork => 'Rejoindre une partie sur ce réseau';

  @override
  String get searchingHosts => 'Recherche d\'hôtes…';

  @override
  String get waitingOpponent => 'En attente de la connexion d\'un adversaire…';

  @override
  String get lanGame => 'Partie en réseau local';

  @override
  String get lanAllowSpectators => 'Autoriser les spectateurs';

  @override
  String get lanSpectate => 'Regarder la partie';

  @override
  String get chat => 'Discussion';

  @override
  String get typeMessage => 'Saisissez un message…';

  @override
  String get noSavedGames => 'Aucune partie enregistrée pour le moment';

  @override
  String get renameGameTitle => 'Renommer la partie';

  @override
  String get pasteFen => 'Collez une chaîne FEN';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen => 'FEN invalide — vérifiez la chaîne de position';

  @override
  String get useStartPosition => 'Utiliser la position de départ';

  @override
  String get loadPosition => 'Charger la position';

  @override
  String get exportPgn => 'Exporter le PGN';

  @override
  String get copyPgn => 'Copier le PGN';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get game => 'Partie';

  @override
  String get lanTitle => 'Deux joueurs — réseau local';

  @override
  String get playAs => 'Jouer avec';

  @override
  String get difficulty => 'Difficulté';

  @override
  String get timeControl => 'Cadence';

  @override
  String get startGame => 'Commencer la partie';

  @override
  String get custom => 'Personnalisé';

  @override
  String get tcInfinite => 'Illimité';

  @override
  String get diffVeryEasy => 'Très facile';

  @override
  String get diffEasy => 'Facile';

  @override
  String get diffNormal => 'Normal';

  @override
  String get diffHard => 'Difficile';

  @override
  String get diffVeryHard => 'Très difficile';

  @override
  String get diffImpossible => 'Impossible';

  @override
  String get baseMinutes => 'Minutes de base';

  @override
  String get incrementSeconds => 'Secondes d\'incrément';

  @override
  String get baseTimeError => 'Le temps de base doit être d\'au moins 1 minute';

  @override
  String get searchDepth => 'Profondeur de recherche';

  @override
  String get timePerMove => 'Temps/coup (ms)';

  @override
  String get maxEvalLoss => 'Perte d\'évaluation maximale (cp)';

  @override
  String get moveVariety => 'Variété des coups';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return '$solved/$total résolus';
  }

  @override
  String get alreadySolved => 'déjà résolu';

  @override
  String get puzzleWrong => 'Ce n\'est pas le bon coup — réessayez';

  @override
  String get puzzleSolvedMsg =>
      'Résolu ! ✓  Appuyez sur ▶ pour le problème suivant';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return 'Problème $index/$total  ·  cote $rating  ·  série $streak (meilleure $best)';
  }

  @override
  String get loadPuzzlesFailed => 'Échec du chargement des problèmes';

  @override
  String get previous => 'Précédent';

  @override
  String get hint => 'Indice';

  @override
  String get restartPuzzle => 'Recommencer le problème';

  @override
  String get next => 'Suivant';

  @override
  String get savedCorrupt =>
      'La partie enregistrée était corrompue ; chargée partiellement';

  @override
  String get menuBughouse => 'Bughouse';

  @override
  String get bugMode => 'Mode';

  @override
  String get bugBoardA => 'Échiquier A';

  @override
  String get bugBoardB => 'Échiquier B';

  @override
  String get bugWhite => 'Blancs';

  @override
  String get bugBlack => 'Noirs';

  @override
  String bugTeamWins(String team) {
    return 'L\'équipe $team gagne';
  }

  @override
  String get bugStart => 'Démarrer la partie';

  @override
  String get bugLan => 'LAN';

  @override
  String get bugHostMatch => 'Héberger une partie';

  @override
  String get bugJoinMatch => 'Rejoindre une partie';

  @override
  String get bugWaitingHost => 'En attente du démarrage par l\'hôte…';

  @override
  String get bugPlayersJoined => 'Joueurs connectés';

  @override
  String get bugAssignSeats => 'Attribuer les quatre places';

  @override
  String get bugSeatHost => 'Hôte (vous)';

  @override
  String get variant => 'Variante';

  @override
  String get vStandard => 'Standard';

  @override
  String get vThreeCheck => 'Trois échecs';

  @override
  String get vKingOfTheHill => 'Roi de la colline';

  @override
  String get vChess960 => 'Chess960';

  @override
  String get vAtomic => 'Atomique';

  @override
  String get vCrazyhouse => 'Crazyhouse';

  @override
  String get vFogOfWar => 'Échecs dans le noir';

  @override
  String get menuFourPlayer => '4 joueurs';

  @override
  String get fourFormat => 'Format';

  @override
  String get fourFFA => 'Chacun pour soi';

  @override
  String get fourTeams => 'Équipes (2c2)';

  @override
  String get fourVsBots => 'Contre des bots';

  @override
  String get fourSeatAi => 'IA';

  @override
  String get fourPerspective => 'Perspective';

  @override
  String get fourYourSeats => 'Vos places';

  @override
  String get fourRed => 'Rouge';

  @override
  String get fourBlue => 'Bleu';

  @override
  String get fourYellow => 'Jaune';

  @override
  String get fourGreen => 'Vert';

  @override
  String fourTeamWins(String team) {
    return '$team gagne';
  }

  @override
  String fourWins(String player) {
    return '$player gagne';
  }

  @override
  String get checksLabel => 'Échecs';

  @override
  String get support => 'Soutien';

  @override
  String get donate => 'Faire un don';

  @override
  String get donateSubtitle => 'Soutenez le développement via GitHub Sponsors';

  @override
  String get checkForUpdates => 'Rechercher des mises à jour';

  @override
  String get checkingForUpdates => 'Recherche de mises à jour…';

  @override
  String get upToDate => 'Vous avez la dernière version.';

  @override
  String get updateAvailable => 'Mise à jour disponible';

  @override
  String get newVersionAvailable => 'Une nouvelle version est disponible :';

  @override
  String get download => 'Télécharger';

  @override
  String get later => 'Plus tard';

  @override
  String get about => 'À propos';

  @override
  String storeCorrupt(Object path) {
    return 'Un fichier de données est illisible. Une copie a été conservée dans $path.';
  }

  @override
  String get settingsSaveFailed =>
      'Un réglage n\'a pas pu être enregistré. Il s\'appliquera jusqu\'à la fermeture de l\'application.';

  @override
  String get fenCastlingRemoved =>
      'Les droits de roque qui ne correspondaient pas à la position ont été retirés.';

  @override
  String get fenEnPassantRemoved =>
      'Une case de prise en passant qui ne correspondait pas à la position a été retirée.';

  @override
  String get fenOpenedAsChess960 =>
      'Ouverte en Chess960 : cette disposition de roque n\'est pas valide aux échecs standard.';

  @override
  String savedPartialReplay(int count) {
    return 'Coups qui n\'ont pas pu être rejoués avec les règles actuelles : $count. La partie s\'est ouverte au dernier coup jouable ; votre partie enregistrée n\'a pas été modifiée.';
  }

  @override
  String savedGameDefaultName(Object stamp) {
    return 'Partie $stamp';
  }

  @override
  String get gameSaveFailed => 'La partie n\'a pas pu être enregistrée.';

  @override
  String get pauseGame => 'Pause';

  @override
  String get resumeGame => 'Reprendre';

  @override
  String get gamePaused => 'Partie en pause';

  @override
  String get chatTooLong => 'Le message est trop long.';

  @override
  String get aiThinking => 'L\'IA réfléchit…';

  @override
  String aiDepthEval(int depth, Object eval) {
    return 'IA : profondeur $depth, évaluation $eval';
  }

  @override
  String pliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demi-coups',
      one: '1 demi-coup',
    );
    return '$_temp0';
  }

  @override
  String get openLinkFailed => 'Impossible d\'ouvrir le lien.';

  @override
  String get boardGreen => 'Vert';

  @override
  String get boardBrown => 'Marron';

  @override
  String get boardBlue => 'Bleu';

  @override
  String get boardGray => 'Gris';

  @override
  String get animationOff => 'Désactivé';

  @override
  String animationMs(int ms) {
    return '$ms ms';
  }

  @override
  String get checkUpdatesOnLaunch => 'Rechercher des mises à jour au démarrage';

  @override
  String get gameOverGeneric => 'Partie terminée';

  @override
  String get lanIncompatibleVersion =>
      'L\'autre appareil utilise une autre version d\'Open Chess. Mettez l\'application à jour sur les deux appareils.';

  @override
  String get tooManyPendingUpdates =>
      'Trop de mises à jour de partie en attente.';

  @override
  String get continueGame => 'Continuer la partie inachevée';

  @override
  String get discardGame => 'Abandonner';

  @override
  String get noMovesYet => 'Aucun coup pour le moment';

  @override
  String get promoteTo => 'Promouvoir en';

  @override
  String get piecePawn => 'pion';

  @override
  String get pieceKnight => 'cavalier';

  @override
  String get pieceBishop => 'fou';

  @override
  String get pieceRook => 'tour';

  @override
  String get pieceQueen => 'dame';

  @override
  String get pieceKing => 'roi';

  @override
  String squarePieceLabel(Object square, Object color, Object piece) {
    return '$square, $piece ($color)';
  }

  @override
  String get staleCastlingTitle => 'Droits de roque obsolètes';

  @override
  String get staleCastlingBody =>
      'Cette position enregistrée autorise un roque avec une tour qui n\'existe plus. L\'ouvrir sans ces droits de roque ? La partie enregistrée n\'est pas modifiée.';

  @override
  String get openAnyway => 'Ouvrir';

  @override
  String savedFenRejected(Object error) {
    return 'Impossible d’ouvrir cette partie enregistrée : $error';
  }

  @override
  String analysisFailed(Object error) {
    return 'L\'analyse a échoué. $error';
  }

  @override
  String get importGame => 'Importer PGN / FEN';

  @override
  String get importFromClipboard => 'Coller';

  @override
  String get importFromFile => 'Ouvrir un fichier';

  @override
  String get importHint => 'Collez une partie PGN ou une position FEN';

  @override
  String get importEmpty => 'Rien à importer.';

  @override
  String get importTooLarge =>
      'Le texte est trop volumineux pour être importé.';

  @override
  String importTooLong(int max) {
    return 'La partie dépasse $max demi-coups.';
  }

  @override
  String importBadFen(Object error) {
    return 'Position invalide : $error';
  }

  @override
  String importBadMove(Object move) {
    return 'Coup illégal ou illisible : $move';
  }

  @override
  String importUnsupported(Object variant) {
    return 'Cette variante ne peut pas être analysée : $variant';
  }

  @override
  String get importReadFailed => 'Le fichier n\'a pas pu être lu.';

  @override
  String engineFailed(Object error) {
    return 'Le moteur n\'a pas pu analyser cette position : $error';
  }

  @override
  String get windowMinimize => 'Réduire';

  @override
  String get windowMaximize => 'Agrandir';

  @override
  String get windowRestore => 'Restaurer';

  @override
  String windowMoveNumber(int number) {
    return 'Coup $number';
  }

  @override
  String fourToMove(String player) {
    return 'Au tour de $player';
  }
}
