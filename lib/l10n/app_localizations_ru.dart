// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Open Chess';

  @override
  String get menuSinglePlayer => 'Одиночная игра';

  @override
  String get menuTwoPlayers => 'На двоих';

  @override
  String get menuLan => 'Игра по локальной сети';

  @override
  String get menuPuzzles => 'Задачи';

  @override
  String get menuResume => 'Продолжить игру';

  @override
  String get menuSettings => 'Настройки';

  @override
  String get menuPlayFromPosition => 'Игра с позиции';

  @override
  String get ok => 'ОК';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get rename => 'Переименовать';

  @override
  String get close => 'Закрыть';

  @override
  String get retry => 'Повторить';

  @override
  String get copy => 'Копировать';

  @override
  String get share => 'Поделиться';

  @override
  String get start => 'Начать';

  @override
  String get accept => 'Принять';

  @override
  String get decline => 'Отклонить';

  @override
  String get send => 'Отправить';

  @override
  String get whiteToMove => 'Ход белых';

  @override
  String get blackToMove => 'Ход чёрных';

  @override
  String get whiteToMoveCheck => 'Ход белых — шах!';

  @override
  String get blackToMoveCheck => 'Ход чёрных — шах!';

  @override
  String get checkmateWhiteWins => 'Мат — победа белых';

  @override
  String get checkmateBlackWins => 'Мат — победа чёрных';

  @override
  String get whiteWinsOnTime => 'Белые выигрывают по времени';

  @override
  String get blackWinsOnTime => 'Чёрные выигрывают по времени';

  @override
  String get drawStalemate => 'Ничья — пат';

  @override
  String get drawFiftyMove => 'Ничья — правило пятидесяти ходов';

  @override
  String get drawThreefold => 'Ничья — троекратное повторение позиции';

  @override
  String get drawInsufficient => 'Ничья — недостаточно материала';

  @override
  String get resign => 'Сдаться';

  @override
  String get offerDraw => 'Предложить ничью';

  @override
  String get drawOfferTitle => 'Предложение ничьей';

  @override
  String get drawOfferBody => 'Соперник предлагает ничью.';

  @override
  String get takeBack => 'Вернуть ход';

  @override
  String get newGame => 'Новая партия';

  @override
  String get mainMenu => 'Главное меню';

  @override
  String get flipBoard => 'Перевернуть доску';

  @override
  String get autoFlipOn => 'Автоповорот: вкл.';

  @override
  String get autoFlipOff => 'Автоповорот: выкл.';

  @override
  String get saveGame => 'Сохранить партию';

  @override
  String get aiMove => 'Ход ИИ (текущая сторона)';

  @override
  String get playAgain => 'Играть снова';

  @override
  String get analyzeGame => 'Анализировать партию';

  @override
  String get gameSaved => 'Партия сохранена';

  @override
  String get boardDesync => 'Рассинхронизация доски — партия прервана';

  @override
  String get youResigned => 'Вы сдались — поражение';

  @override
  String get opponentResigned => 'Соперник сдался — победа';

  @override
  String get drawAgreed => 'Ничья по соглашению';

  @override
  String get opponentDisconnected => 'Соперник отключился';

  @override
  String get name => 'Имя';

  @override
  String get gameName => 'Название партии';

  @override
  String get myGame => 'Моя партия';

  @override
  String get analysis => 'Анализ';

  @override
  String get opening => 'Дебют';

  @override
  String get openingGambit => 'Гамбит';

  @override
  String get openingVariation => 'Вариант';

  @override
  String get openingNone => 'Нет названного дебюта';

  @override
  String get ratingEstimate => 'Оценочный рейтинг';

  @override
  String get ratingConfidenceLow => 'Низкая достоверность';

  @override
  String get ratingConfidenceMedium => 'Средняя достоверность';

  @override
  String get ratingConfidenceHigh => 'Высокая достоверность';

  @override
  String get ratingUnavailable => 'Оценка рейтинга недоступна';

  @override
  String get white => 'Белые';

  @override
  String get black => 'Чёрные';

  @override
  String get accuracy => 'точность';

  @override
  String analyzingProgress(Object done, Object total) {
    return 'Анализ $done/$total…';
  }

  @override
  String get preparingAnalysis => 'Подготовка анализа…';

  @override
  String get clsBrilliant => 'Блестяще';

  @override
  String get clsGreat => 'Отлично';

  @override
  String get clsBest => 'Лучший ход';

  @override
  String get clsGood => 'Хорошо';

  @override
  String get clsBook => 'По дебюту';

  @override
  String get clsInaccuracy => 'Неточность';

  @override
  String get clsMiss => 'Упущение';

  @override
  String get clsMistake => 'Ошибка';

  @override
  String get clsBlunder => 'Грубая ошибка';

  @override
  String get coachBrilliant => 'Блестяще — выигрывающая жертва.';

  @override
  String get coachGreat => 'Отлично — единственный ход, удерживающий позицию.';

  @override
  String get coachBest => 'Лучший ход.';

  @override
  String get coachBook => 'Известный дебютный ход.';

  @override
  String get coachGood => 'Хороший ход.';

  @override
  String coachInaccuracy(Object best) {
    return 'Неточность — $best был немного лучше.';
  }

  @override
  String coachMiss(Object best) {
    return 'Упущен выигрывающий шанс — $best был намного сильнее.';
  }

  @override
  String coachMistake(Object best) {
    return 'Ошибка — $best был сильнее.';
  }

  @override
  String coachBlunder(Object best) {
    return 'Грубая ошибка — $best был намного лучше.';
  }

  @override
  String get settings => 'Настройки';

  @override
  String get profile => 'Профиль';

  @override
  String get profileUsername => 'Имя пользователя';

  @override
  String get profileUsernameHint => 'Выберите имя пользователя';

  @override
  String get profileAvatar => 'Аватар';

  @override
  String get profileChangeAvatar => 'Изменить аватар';

  @override
  String get profileRemoveAvatar => 'Удалить аватар';

  @override
  String get profileImageError => 'Не удалось использовать это изображение.';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get boardThemeLabel => 'Тема доски';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Системный по умолчанию';

  @override
  String get accessibility => 'Специальные возможности';

  @override
  String get highContrast => 'Контрастная доска';

  @override
  String get colorblindSafe => 'Цвета ходов для дальтоников';

  @override
  String get textSize => 'Размер текста';

  @override
  String get gameplay => 'Игровой процесс';

  @override
  String get sound => 'Звук';

  @override
  String get moveHints => 'Подсказки ходов';

  @override
  String get haptics => 'Вибрация';

  @override
  String get animationSpeed => 'Скорость анимации';

  @override
  String get defaultTimeControl => 'Контроль времени по умолчанию';

  @override
  String get defaultDifficulty => 'Сложность по умолчанию';

  @override
  String get hostGame => 'Создать игру';

  @override
  String get yourName => 'Ваше имя';

  @override
  String get yourColour => 'Ваш цвет';

  @override
  String get colourWhite => 'Белые';

  @override
  String get colourBlack => 'Чёрные';

  @override
  String get colourRandom => 'Случайный';

  @override
  String get hostAGame => 'Создать игру';

  @override
  String get joinOnNetwork => 'Присоединиться к игре в этой сети';

  @override
  String get searchingHosts => 'Поиск хостов…';

  @override
  String get waitingOpponent => 'Ожидание подключения соперника…';

  @override
  String get lanGame => 'Игра по локальной сети';

  @override
  String get lanAllowSpectators => 'Разрешить зрителей';

  @override
  String get lanSpectate => 'Смотреть партию';

  @override
  String get chat => 'Чат';

  @override
  String get typeMessage => 'Введите сообщение…';

  @override
  String get noSavedGames => 'Пока нет сохранённых партий';

  @override
  String get renameGameTitle => 'Переименовать партию';

  @override
  String get pasteFen => 'Вставьте строку FEN';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen => 'Некорректный FEN — проверьте строку позиции';

  @override
  String get useStartPosition => 'Использовать начальную позицию';

  @override
  String get loadPosition => 'Загрузить позицию';

  @override
  String get exportPgn => 'Экспорт PGN';

  @override
  String get copyPgn => 'Копировать PGN';

  @override
  String get copiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get game => 'Партия';

  @override
  String get lanTitle => 'Два игрока — локальная сеть';

  @override
  String get playAs => 'Играть за';

  @override
  String get difficulty => 'Сложность';

  @override
  String get timeControl => 'Контроль времени';

  @override
  String get startGame => 'Начать партию';

  @override
  String get custom => 'Свой';

  @override
  String get tcInfinite => 'Без ограничения';

  @override
  String get diffVeryEasy => 'Очень лёгкий';

  @override
  String get diffEasy => 'Лёгкий';

  @override
  String get diffNormal => 'Обычный';

  @override
  String get diffHard => 'Сложный';

  @override
  String get diffVeryHard => 'Очень сложный';

  @override
  String get diffImpossible => 'Невозможный';

  @override
  String get baseMinutes => 'Основное время (минуты)';

  @override
  String get incrementSeconds => 'Добавление (секунды)';

  @override
  String get baseTimeError => 'Основное время должно быть не менее 1 минуты';

  @override
  String get searchDepth => 'Глубина расчёта';

  @override
  String get timePerMove => 'Время на ход (мс)';

  @override
  String get maxEvalLoss => 'Максимальная потеря оценки (сантипешки)';

  @override
  String get moveVariety => 'Разнообразие ходов';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return 'Решено $solved/$total';
  }

  @override
  String get alreadySolved => 'уже решено';

  @override
  String get puzzleWrong => 'Не тот ход — попробуйте снова';

  @override
  String get puzzleSolvedMsg => 'Решено! ✓  Нажмите ▶ для следующей задачи';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return 'Задача $index/$total  ·  рейтинг $rating  ·  серия $streak (рекорд $best)';
  }

  @override
  String get loadPuzzlesFailed => 'Не удалось загрузить задачи';

  @override
  String get previous => 'Назад';

  @override
  String get hint => 'Подсказка';

  @override
  String get restartPuzzle => 'Заново';

  @override
  String get next => 'Далее';

  @override
  String get savedCorrupt =>
      'Сохранённая партия повреждена; загружена частично';

  @override
  String get menuBughouse => 'Багхаус';

  @override
  String get bugMode => 'Режим';

  @override
  String get bugBoardA => 'Доска A';

  @override
  String get bugBoardB => 'Доска B';

  @override
  String get bugWhite => 'Белые';

  @override
  String get bugBlack => 'Чёрные';

  @override
  String bugTeamWins(String team) {
    return 'Команда $team побеждает';
  }

  @override
  String get bugStart => 'Начать матч';

  @override
  String get bugLan => 'Локальная сеть';

  @override
  String get bugHostMatch => 'Создать матч';

  @override
  String get bugJoinMatch => 'Присоединиться к матчу';

  @override
  String get bugWaitingHost => 'Ожидание начала матча хостом…';

  @override
  String get bugPlayersJoined => 'Игроков присоединилось';

  @override
  String get bugAssignSeats => 'Распределите четыре места';

  @override
  String get bugSeatHost => 'Хост (вы)';

  @override
  String get variant => 'Вариант';

  @override
  String get vStandard => 'Стандартные';

  @override
  String get vThreeCheck => 'Три шаха';

  @override
  String get vKingOfTheHill => 'Король горы';

  @override
  String get vChess960 => 'Шахматы 960';

  @override
  String get vAtomic => 'Атомные шахматы';

  @override
  String get vCrazyhouse => 'Крейзихаус';

  @override
  String get vFogOfWar => 'Тёмные шахматы';

  @override
  String get menuFourPlayer => '4 игрока';

  @override
  String get fourFormat => 'Формат';

  @override
  String get fourFFA => 'Каждый сам за себя';

  @override
  String get fourTeams => 'Команды (2 на 2)';

  @override
  String get fourVsBots => 'Против ботов';

  @override
  String get fourSeatAi => 'ИИ';

  @override
  String get fourPerspective => 'Перспектива';

  @override
  String get fourYourSeats => 'Ваши места';

  @override
  String get fourRed => 'Красные';

  @override
  String get fourBlue => 'Синие';

  @override
  String get fourYellow => 'Жёлтые';

  @override
  String get fourGreen => 'Зелёные';

  @override
  String fourTeamWins(String team) {
    return '$team побеждает';
  }

  @override
  String fourWins(String player) {
    return '$player побеждает';
  }

  @override
  String get checksLabel => 'Шахи';

  @override
  String get support => 'Поддержка';

  @override
  String get donate => 'Поддержать';

  @override
  String get donateSubtitle => 'Поддержите разработку через GitHub Sponsors';

  @override
  String get checkForUpdates => 'Проверить обновления';

  @override
  String get checkingForUpdates => 'Проверка обновлений…';

  @override
  String get upToDate => 'У вас последняя версия.';

  @override
  String get updateAvailable => 'Доступно обновление';

  @override
  String get newVersionAvailable => 'Доступна новая версия:';

  @override
  String get download => 'Скачать';

  @override
  String get later => 'Позже';

  @override
  String get about => 'О приложении';

  @override
  String storeCorrupt(Object path) {
    return 'Не удалось прочитать файл данных. Копия сохранена в $path.';
  }

  @override
  String get settingsSaveFailed =>
      'Не удалось сохранить настройку. Она будет действовать, пока вы не закроете приложение.';

  @override
  String get fenCastlingRemoved =>
      'Права на рокировку, не соответствовавшие позиции, удалены.';

  @override
  String get fenEnPassantRemoved =>
      'Поле взятия на проходе, не соответствовавшее позиции, удалено.';

  @override
  String get fenOpenedAsChess960 =>
      'Открыто как Chess960: такая расстановка для рокировки недопустима в стандартных шахматах.';

  @override
  String savedPartialReplay(int count) {
    return 'Ходов, которые не удалось воспроизвести по текущим правилам: $count. Партия открыта на последнем допустимом ходе; сохранённая партия не изменена.';
  }

  @override
  String savedGameDefaultName(Object stamp) {
    return 'Партия $stamp';
  }

  @override
  String get gameSaveFailed => 'Не удалось сохранить партию.';

  @override
  String get pauseGame => 'Пауза';

  @override
  String get resumeGame => 'Продолжить';

  @override
  String get gamePaused => 'Партия на паузе';

  @override
  String get chatTooLong => 'Сообщение слишком длинное.';

  @override
  String get aiThinking => 'ИИ думает…';

  @override
  String aiDepthEval(int depth, Object eval) {
    return 'ИИ: глубина $depth, оценка $eval';
  }

  @override
  String pliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count полуходов',
      few: '$count полухода',
      one: '$count полуход',
    );
    return '$_temp0';
  }

  @override
  String get openLinkFailed => 'Не удалось открыть ссылку.';

  @override
  String get boardGreen => 'Зелёная';

  @override
  String get boardBrown => 'Коричневая';

  @override
  String get boardBlue => 'Синяя';

  @override
  String get boardGray => 'Серая';

  @override
  String get animationOff => 'Выкл.';

  @override
  String animationMs(int ms) {
    return '$ms мс';
  }

  @override
  String get checkUpdatesOnLaunch => 'Проверять обновления при запуске';

  @override
  String get gameOverGeneric => 'Партия окончена';

  @override
  String get lanIncompatibleVersion =>
      'На другом устройстве другая версия Open Chess. Обновите приложение на обоих устройствах.';

  @override
  String get tooManyPendingUpdates =>
      'Слишком много ожидающих обновлений партии.';

  @override
  String get continueGame => 'Продолжить незаконченную партию';

  @override
  String get discardGame => 'Отбросить';

  @override
  String get noMovesYet => 'Ходов пока нет';

  @override
  String get promoteTo => 'Превратить в';

  @override
  String get piecePawn => 'пешка';

  @override
  String get pieceKnight => 'конь';

  @override
  String get pieceBishop => 'слон';

  @override
  String get pieceRook => 'ладья';

  @override
  String get pieceQueen => 'ферзь';

  @override
  String get pieceKing => 'король';

  @override
  String squarePieceLabel(Object square, Object color, Object piece) {
    return '$square, $piece ($color)';
  }

  @override
  String get staleCastlingTitle => 'Устаревшие права на рокировку';

  @override
  String get staleCastlingBody =>
      'В этой сохранённой позиции разрешена рокировка с ладьёй, которой уже нет. Открыть без этих прав на рокировку? Сама сохранённая партия не изменится.';

  @override
  String get openAnyway => 'Открыть';

  @override
  String savedFenRejected(Object error) {
    return 'Не удаётся открыть эту сохранённую партию: $error';
  }

  @override
  String analysisFailed(Object error) {
    return 'Анализ не удался. $error';
  }

  @override
  String get importGame => 'Импорт PGN / FEN';

  @override
  String get importFromClipboard => 'Вставить';

  @override
  String get importFromFile => 'Открыть файл';

  @override
  String get importHint => 'Вставьте партию PGN или позицию FEN';

  @override
  String get importEmpty => 'Нечего импортировать.';

  @override
  String get importTooLarge => 'Текст слишком большой для импорта.';

  @override
  String importTooLong(int max) {
    return 'Партия длиннее $max полуходов.';
  }

  @override
  String importBadFen(Object error) {
    return 'Недопустимая позиция: $error';
  }

  @override
  String importBadMove(Object move) {
    return 'Недопустимый или нечитаемый ход: $move';
  }

  @override
  String importUnsupported(Object variant) {
    return 'Этот вариант нельзя проанализировать: $variant';
  }

  @override
  String get importReadFailed => 'Не удалось прочитать файл.';

  @override
  String engineFailed(Object error) {
    return 'Движок не смог рассчитать эту позицию: $error';
  }
}
