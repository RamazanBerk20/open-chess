// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Open Chess';

  @override
  String get menuSinglePlayer => 'Un jugador';

  @override
  String get menuTwoPlayers => 'Dos jugadores';

  @override
  String get menuLan => 'Jugar por LAN';

  @override
  String get menuPuzzles => 'Ejercicios';

  @override
  String get menuResume => 'Reanudar partida';

  @override
  String get menuSettings => 'Ajustes';

  @override
  String get menuPlayFromPosition => 'Jugar desde una posición';

  @override
  String get ok => 'Aceptar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get rename => 'Renombrar';

  @override
  String get close => 'Cerrar';

  @override
  String get retry => 'Reintentar';

  @override
  String get copy => 'Copiar';

  @override
  String get share => 'Compartir';

  @override
  String get start => 'Empezar';

  @override
  String get accept => 'Aceptar';

  @override
  String get decline => 'Rechazar';

  @override
  String get send => 'Enviar';

  @override
  String get whiteToMove => 'Juegan las blancas';

  @override
  String get blackToMove => 'Juegan las negras';

  @override
  String get whiteToMoveCheck => 'Juegan las blancas — ¡jaque!';

  @override
  String get blackToMoveCheck => 'Juegan las negras — ¡jaque!';

  @override
  String get checkmateWhiteWins => 'Jaque mate — ganan las blancas';

  @override
  String get checkmateBlackWins => 'Jaque mate — ganan las negras';

  @override
  String get whiteWinsOnTime => 'Las blancas ganan por tiempo';

  @override
  String get blackWinsOnTime => 'Las negras ganan por tiempo';

  @override
  String get drawStalemate => 'Tablas — rey ahogado';

  @override
  String get drawFiftyMove => 'Tablas — regla de los cincuenta movimientos';

  @override
  String get drawThreefold => 'Tablas — triple repetición';

  @override
  String get drawInsufficient => 'Tablas — material insuficiente';

  @override
  String get resign => 'Abandonar';

  @override
  String get offerDraw => 'Ofrecer tablas';

  @override
  String get drawOfferTitle => 'Oferta de tablas';

  @override
  String get drawOfferBody => 'Tu rival ofrece tablas.';

  @override
  String get takeBack => 'Deshacer jugada';

  @override
  String get newGame => 'Nueva partida';

  @override
  String get mainMenu => 'Menú principal';

  @override
  String get flipBoard => 'Girar tablero';

  @override
  String get autoFlipOn => 'Giro automático: activado';

  @override
  String get autoFlipOff => 'Giro automático: desactivado';

  @override
  String get saveGame => 'Guardar partida';

  @override
  String get aiMove => 'Jugada de la IA (bando actual)';

  @override
  String get playAgain => 'Jugar de nuevo';

  @override
  String get analyzeGame => 'Analizar partida';

  @override
  String get gameSaved => 'Partida guardada';

  @override
  String get boardDesync => 'Desincronización del tablero — partida cancelada';

  @override
  String get youResigned => 'Has abandonado — pierdes';

  @override
  String get opponentResigned => 'El rival ha abandonado — ganas';

  @override
  String get drawAgreed => 'Tablas acordadas';

  @override
  String get opponentDisconnected => 'El rival se ha desconectado';

  @override
  String get name => 'Nombre';

  @override
  String get gameName => 'Nombre de la partida';

  @override
  String get myGame => 'Mi partida';

  @override
  String get analysis => 'Análisis';

  @override
  String get opening => 'Apertura';

  @override
  String get openingGambit => 'Gambito';

  @override
  String get openingVariation => 'Variante';

  @override
  String get openingNone => 'Sin apertura conocida';

  @override
  String get ratingEstimate => 'Puntuación estimada';

  @override
  String get ratingConfidenceLow => 'Confianza baja';

  @override
  String get ratingConfidenceMedium => 'Confianza media';

  @override
  String get ratingConfidenceHigh => 'Confianza alta';

  @override
  String get ratingUnavailable => 'Estimación de puntuación no disponible';

  @override
  String get white => 'Blancas';

  @override
  String get black => 'Negras';

  @override
  String get accuracy => 'precisión';

  @override
  String analyzingProgress(Object done, Object total) {
    return 'Analizando $done/$total…';
  }

  @override
  String get preparingAnalysis => 'Preparando el análisis…';

  @override
  String get clsBrilliant => 'Brillante';

  @override
  String get clsGreat => 'Genial';

  @override
  String get clsBest => 'La mejor';

  @override
  String get clsGood => 'Buena';

  @override
  String get clsBook => 'Teórica';

  @override
  String get clsInaccuracy => 'Imprecisión';

  @override
  String get clsMiss => 'Oportunidad perdida';

  @override
  String get clsMistake => 'Error';

  @override
  String get clsBlunder => 'Error grave';

  @override
  String get coachBrilliant => 'Brillante — un sacrificio ganador.';

  @override
  String get coachGreat => 'Genial — la única jugada que aguanta.';

  @override
  String get coachBest => 'La mejor jugada.';

  @override
  String get coachBook => 'Una jugada de apertura conocida.';

  @override
  String get coachGood => 'Una buena jugada.';

  @override
  String coachInaccuracy(Object best) {
    return 'Imprecisión — $best era un poco mejor.';
  }

  @override
  String coachMiss(Object best) {
    return 'Oportunidad ganadora perdida — $best era mucho más fuerte.';
  }

  @override
  String coachMistake(Object best) {
    return 'Error — $best era más fuerte.';
  }

  @override
  String coachBlunder(Object best) {
    return 'Error grave — $best era mucho mejor.';
  }

  @override
  String get settings => 'Ajustes';

  @override
  String get profile => 'Perfil';

  @override
  String get profileUsername => 'Nombre de usuario';

  @override
  String get profileUsernameHint => 'Elige un nombre de usuario';

  @override
  String get profileAvatar => 'Avatar';

  @override
  String get profileChangeAvatar => 'Cambiar avatar';

  @override
  String get profileRemoveAvatar => 'Quitar avatar';

  @override
  String get profileImageError => 'No se pudo usar esa imagen.';

  @override
  String get appearance => 'Apariencia';

  @override
  String get boardThemeLabel => 'Tema del tablero';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Predeterminado del sistema';

  @override
  String get accessibility => 'Accesibilidad';

  @override
  String get highContrast => 'Tablero de alto contraste';

  @override
  String get colorblindSafe => 'Colores de jugada aptos para daltónicos';

  @override
  String get textSize => 'Tamaño del texto';

  @override
  String get gameplay => 'Juego';

  @override
  String get sound => 'Sonido';

  @override
  String get moveHints => 'Sugerencias de jugada';

  @override
  String get haptics => 'Vibración';

  @override
  String get animationSpeed => 'Velocidad de animación';

  @override
  String get defaultTimeControl => 'Control de tiempo predeterminado';

  @override
  String get defaultDifficulty => 'Dificultad predeterminada';

  @override
  String get hostGame => 'Crear partida';

  @override
  String get yourName => 'Tu nombre';

  @override
  String get yourColour => 'Tu color';

  @override
  String get colourWhite => 'Blancas';

  @override
  String get colourBlack => 'Negras';

  @override
  String get colourRandom => 'Aleatorio';

  @override
  String get hostAGame => 'Crear una partida';

  @override
  String get joinOnNetwork => 'Unirse a una partida en esta red';

  @override
  String get searchingHosts => 'Buscando anfitriones…';

  @override
  String get waitingOpponent => 'Esperando a que se conecte un rival…';

  @override
  String get lanGame => 'Partida en LAN';

  @override
  String get lanAllowSpectators => 'Permitir espectadores';

  @override
  String get lanSpectate => 'Ver partida';

  @override
  String get chat => 'Chat';

  @override
  String get typeMessage => 'Escribe un mensaje…';

  @override
  String get noSavedGames => 'Aún no hay partidas guardadas';

  @override
  String get renameGameTitle => 'Renombrar partida';

  @override
  String get pasteFen => 'Pega una cadena FEN';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen => 'FEN no válido — revisa la cadena de la posición';

  @override
  String get useStartPosition => 'Usar posición inicial';

  @override
  String get loadPosition => 'Cargar posición';

  @override
  String get exportPgn => 'Exportar PGN';

  @override
  String get copyPgn => 'Copiar PGN';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get game => 'Partida';

  @override
  String get lanTitle => 'Dos jugadores — LAN';

  @override
  String get playAs => 'Jugar con';

  @override
  String get difficulty => 'Dificultad';

  @override
  String get timeControl => 'Control de tiempo';

  @override
  String get startGame => 'Iniciar partida';

  @override
  String get custom => 'Personalizado';

  @override
  String get tcInfinite => 'Ilimitado';

  @override
  String get diffVeryEasy => 'Muy fácil';

  @override
  String get diffEasy => 'Fácil';

  @override
  String get diffNormal => 'Normal';

  @override
  String get diffHard => 'Difícil';

  @override
  String get diffVeryHard => 'Muy difícil';

  @override
  String get diffImpossible => 'Imposible';

  @override
  String get baseMinutes => 'Minutos base';

  @override
  String get incrementSeconds => 'Segundos de incremento';

  @override
  String get baseTimeError => 'El tiempo base debe ser de al menos 1 minuto';

  @override
  String get searchDepth => 'Profundidad de búsqueda';

  @override
  String get timePerMove => 'Tiempo/jugada (ms)';

  @override
  String get maxEvalLoss => 'Pérdida máxima de evaluación (cp)';

  @override
  String get moveVariety => 'Variedad de jugadas';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return '$solved/$total resueltos';
  }

  @override
  String get alreadySolved => 'ya resuelto';

  @override
  String get puzzleWrong => 'No es la jugada — inténtalo de nuevo';

  @override
  String get puzzleSolvedMsg =>
      '¡Resuelto! ✓  Toca ▶ para el siguiente problema';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return 'Problema $index/$total  ·  ELO $rating  ·  racha $streak (mejor $best)';
  }

  @override
  String get loadPuzzlesFailed => 'Error al cargar los problemas';

  @override
  String get previous => 'Anterior';

  @override
  String get hint => 'Pista';

  @override
  String get restartPuzzle => 'Reiniciar problema';

  @override
  String get next => 'Siguiente';

  @override
  String get savedCorrupt =>
      'La partida guardada estaba dañada; se cargó parcialmente';

  @override
  String get menuBughouse => 'Bughouse';

  @override
  String get bugMode => 'Modo';

  @override
  String get bugBoardA => 'Tablero A';

  @override
  String get bugBoardB => 'Tablero B';

  @override
  String get bugWhite => 'Blancas';

  @override
  String get bugBlack => 'Negras';

  @override
  String bugTeamWins(String team) {
    return 'El equipo $team gana';
  }

  @override
  String get bugStart => 'Iniciar partida';

  @override
  String get bugLan => 'LAN';

  @override
  String get bugHostMatch => 'Crear partida';

  @override
  String get bugJoinMatch => 'Unirse a una partida';

  @override
  String get bugWaitingHost => 'Esperando a que el anfitrión empiece…';

  @override
  String get bugPlayersJoined => 'Jugadores unidos';

  @override
  String get bugAssignSeats => 'Asigna los cuatro asientos';

  @override
  String get bugSeatHost => 'Anfitrión (tú)';

  @override
  String get variant => 'Variante';

  @override
  String get vStandard => 'Estándar';

  @override
  String get vThreeCheck => 'Tres jaques';

  @override
  String get vKingOfTheHill => 'Rey de la colina';

  @override
  String get vChess960 => 'Ajedrez 960';

  @override
  String get vAtomic => 'Atómico';

  @override
  String get vCrazyhouse => 'Crazyhouse';

  @override
  String get vFogOfWar => 'Ajedrez a ciegas';

  @override
  String get menuFourPlayer => '4 jugadores';

  @override
  String get fourFormat => 'Formato';

  @override
  String get fourFFA => 'Todos contra todos';

  @override
  String get fourTeams => 'Equipos (2 vs 2)';

  @override
  String get fourVsBots => 'Contra bots';

  @override
  String get fourSeatAi => 'IA';

  @override
  String get fourPerspective => 'Perspectiva';

  @override
  String get fourYourSeats => 'Tus asientos';

  @override
  String get fourRed => 'Rojo';

  @override
  String get fourBlue => 'Azul';

  @override
  String get fourYellow => 'Amarillo';

  @override
  String get fourGreen => 'Verde';

  @override
  String fourTeamWins(String team) {
    return 'Gana $team';
  }

  @override
  String fourWins(String player) {
    return 'Gana $player';
  }

  @override
  String get checksLabel => 'Jaques';

  @override
  String get support => 'Apoyo';

  @override
  String get donate => 'Donar';

  @override
  String get donateSubtitle => 'Apoya el desarrollo en GitHub Sponsors';

  @override
  String get checkForUpdates => 'Buscar actualizaciones';

  @override
  String get checkingForUpdates => 'Buscando actualizaciones…';

  @override
  String get upToDate => 'Tienes la última versión.';

  @override
  String get updateAvailable => 'Actualización disponible';

  @override
  String get newVersionAvailable => 'Hay una nueva versión disponible:';

  @override
  String get download => 'Descargar';

  @override
  String get later => 'Más tarde';

  @override
  String get about => 'Acerca de';

  @override
  String storeCorrupt(Object path) {
    return 'No se pudo leer un archivo de datos. Se guardó una copia en $path.';
  }

  @override
  String get settingsSaveFailed =>
      'No se pudo guardar un ajuste. Se aplicará hasta que cierres la aplicación.';

  @override
  String get fenCastlingRemoved =>
      'Se quitaron los derechos de enroque que no coincidían con la posición.';

  @override
  String get fenEnPassantRemoved =>
      'Se quitó una casilla de captura al paso que no coincidía con la posición.';

  @override
  String get fenOpenedAsChess960 =>
      'Abierta como Chess960: esta disposición de enroque no es válida en el ajedrez estándar.';

  @override
  String savedPartialReplay(int count) {
    return 'Jugadas que no se pudieron reproducir con las reglas actuales: $count. La partida se abrió en la última jugada posible; tu partida guardada no se modificó.';
  }

  @override
  String savedGameDefaultName(Object stamp) {
    return 'Partida $stamp';
  }

  @override
  String get gameSaveFailed => 'No se pudo guardar la partida.';

  @override
  String get pauseGame => 'Pausar';

  @override
  String get resumeGame => 'Reanudar';

  @override
  String get gamePaused => 'Partida en pausa';

  @override
  String get chatTooLong => 'El mensaje es demasiado largo.';

  @override
  String get aiThinking => 'La IA está pensando…';

  @override
  String aiDepthEval(int depth, Object eval) {
    return 'IA: profundidad $depth, evaluación $eval';
  }

  @override
  String pliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jugadas',
      one: '1 jugada',
    );
    return '$_temp0';
  }

  @override
  String get openLinkFailed => 'No se pudo abrir el enlace.';

  @override
  String get boardGreen => 'Verde';

  @override
  String get boardBrown => 'Marrón';

  @override
  String get boardBlue => 'Azul';

  @override
  String get boardGray => 'Gris';

  @override
  String get animationOff => 'Desactivado';

  @override
  String animationMs(int ms) {
    return '$ms ms';
  }

  @override
  String get checkUpdatesOnLaunch => 'Buscar actualizaciones al iniciar';

  @override
  String get gameOverGeneric => 'Partida terminada';

  @override
  String get lanIncompatibleVersion =>
      'El otro dispositivo usa otra versión de Open Chess. Actualiza la app en ambos dispositivos.';

  @override
  String get tooManyPendingUpdates =>
      'Demasiadas actualizaciones de partida pendientes.';

  @override
  String get continueGame => 'Continuar partida sin terminar';

  @override
  String get discardGame => 'Descartar';

  @override
  String get noMovesYet => 'Aún no hay jugadas';

  @override
  String get promoteTo => 'Promocionar a';

  @override
  String get piecePawn => 'peón';

  @override
  String get pieceKnight => 'caballo';

  @override
  String get pieceBishop => 'alfil';

  @override
  String get pieceRook => 'torre';

  @override
  String get pieceQueen => 'dama';

  @override
  String get pieceKing => 'rey';

  @override
  String squarePieceLabel(Object square, Object color, Object piece) {
    return '$square, $piece ($color)';
  }

  @override
  String get staleCastlingTitle => 'Derechos de enroque obsoletos';

  @override
  String get staleCastlingBody =>
      'Esta posición guardada permite enrocar con una torre que ya no está. ¿Abrirla sin esos derechos de enroque? La partida guardada no se modifica.';

  @override
  String get openAnyway => 'Abrir';

  @override
  String savedFenRejected(Object error) {
    return 'No se puede abrir esta partida guardada: $error';
  }

  @override
  String analysisFailed(Object error) {
    return 'El análisis falló. $error';
  }

  @override
  String get importGame => 'Importar PGN / FEN';

  @override
  String get importFromClipboard => 'Pegar';

  @override
  String get importFromFile => 'Abrir archivo';

  @override
  String get importHint => 'Pega una partida PGN o una posición FEN';

  @override
  String get importEmpty => 'No hay nada que importar.';

  @override
  String get importTooLarge => 'El texto es demasiado grande para importarlo.';

  @override
  String importTooLong(int max) {
    return 'La partida tiene más de $max jugadas.';
  }

  @override
  String importBadFen(Object error) {
    return 'Posición no válida: $error';
  }

  @override
  String importBadMove(Object move) {
    return 'Jugada ilegal o ilegible: $move';
  }

  @override
  String importUnsupported(Object variant) {
    return 'Esta variante no se puede analizar: $variant';
  }

  @override
  String get importReadFailed => 'No se pudo leer el archivo.';

  @override
  String engineFailed(Object error) {
    return 'El motor no pudo analizar esta posición: $error';
  }
}
