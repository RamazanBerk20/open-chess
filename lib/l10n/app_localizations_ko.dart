// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Open Chess';

  @override
  String get menuSinglePlayer => '1인 플레이';

  @override
  String get menuTwoPlayers => '2인 플레이';

  @override
  String get menuLan => 'LAN으로 플레이';

  @override
  String get menuPuzzles => '퍼즐';

  @override
  String get menuResume => '게임 이어하기';

  @override
  String get menuSettings => '설정';

  @override
  String get menuPlayFromPosition => '특정 국면에서 시작';

  @override
  String get ok => '확인';

  @override
  String get cancel => '취소';

  @override
  String get save => '저장';

  @override
  String get delete => '삭제';

  @override
  String get rename => '이름 변경';

  @override
  String get close => '닫기';

  @override
  String get retry => '다시 시도';

  @override
  String get copy => '복사';

  @override
  String get share => '공유';

  @override
  String get start => '시작';

  @override
  String get accept => '수락';

  @override
  String get decline => '거절';

  @override
  String get send => '보내기';

  @override
  String get whiteToMove => '백 차례';

  @override
  String get blackToMove => '흑 차례';

  @override
  String get whiteToMoveCheck => '백 차례 — 체크!';

  @override
  String get blackToMoveCheck => '흑 차례 — 체크!';

  @override
  String get checkmateWhiteWins => '체크메이트 — 백 승리';

  @override
  String get checkmateBlackWins => '체크메이트 — 흑 승리';

  @override
  String get whiteWinsOnTime => '시간 승부로 백 승리';

  @override
  String get blackWinsOnTime => '시간 승부로 흑 승리';

  @override
  String get drawStalemate => '무승부 — 스테일메이트';

  @override
  String get drawFiftyMove => '무승부 — 50수 규칙';

  @override
  String get drawThreefold => '무승부 — 동형 3회 반복';

  @override
  String get drawInsufficient => '무승부 — 기물 부족';

  @override
  String get resign => '기권';

  @override
  String get offerDraw => '무승부 제안';

  @override
  String get drawOfferTitle => '무승부 제안';

  @override
  String get drawOfferBody => '상대가 무승부를 제안했습니다.';

  @override
  String get takeBack => '무르기';

  @override
  String get newGame => '새 게임';

  @override
  String get mainMenu => '메인 메뉴';

  @override
  String get flipBoard => '보드 뒤집기';

  @override
  String get autoFlipOn => '자동 뒤집기: 켜짐';

  @override
  String get autoFlipOff => '자동 뒤집기: 꺼짐';

  @override
  String get saveGame => '게임 저장';

  @override
  String get aiMove => 'AI 착수 (현재 차례)';

  @override
  String get playAgain => '다시 플레이';

  @override
  String get analyzeGame => '게임 분석';

  @override
  String get gameSaved => '게임이 저장되었습니다';

  @override
  String get boardDesync => '보드 동기화 오류 — 게임 중단됨';

  @override
  String get youResigned => '기권했습니다 — 패배';

  @override
  String get opponentResigned => '상대가 기권했습니다 — 승리';

  @override
  String get drawAgreed => '무승부 합의';

  @override
  String get opponentDisconnected => '상대 연결이 끊어졌습니다';

  @override
  String get name => '이름';

  @override
  String get gameName => '게임 이름';

  @override
  String get myGame => '내 게임';

  @override
  String get analysis => '분석';

  @override
  String get opening => '오프닝';

  @override
  String get openingGambit => '갬빗';

  @override
  String get openingVariation => '변형';

  @override
  String get openingNone => '이름 있는 오프닝 없음';

  @override
  String get ratingEstimate => '추정 레이팅';

  @override
  String get ratingConfidenceLow => '낮은 신뢰도';

  @override
  String get ratingConfidenceMedium => '보통 신뢰도';

  @override
  String get ratingConfidenceHigh => '높은 신뢰도';

  @override
  String get ratingUnavailable => '레이팅 추정을 사용할 수 없음';

  @override
  String get white => '백';

  @override
  String get black => '흑';

  @override
  String get accuracy => '정확도';

  @override
  String analyzingProgress(Object done, Object total) {
    return '분석 중 $done/$total…';
  }

  @override
  String get preparingAnalysis => '분석 준비 중…';

  @override
  String get clsBrilliant => '최고의 한 수';

  @override
  String get clsGreat => '훌륭한 수';

  @override
  String get clsBest => '최선의 수';

  @override
  String get clsGood => '좋은 수';

  @override
  String get clsBook => '정석';

  @override
  String get clsInaccuracy => '부정확한 수';

  @override
  String get clsMiss => '놓친 수';

  @override
  String get clsMistake => '실수';

  @override
  String get clsBlunder => '대실수';

  @override
  String get coachBrilliant => '최고의 한 수 — 승리를 부르는 희생입니다.';

  @override
  String get coachGreat => '훌륭한 수 — 국면을 지키는 유일한 수입니다.';

  @override
  String get coachBest => '최선의 수입니다.';

  @override
  String get coachBook => '잘 알려진 오프닝 수입니다.';

  @override
  String get coachGood => '좋은 수입니다.';

  @override
  String coachInaccuracy(Object best) {
    return '부정확한 수 — $best가 조금 더 나았습니다.';
  }

  @override
  String coachMiss(Object best) {
    return '이길 기회를 놓쳤습니다 — $best가 훨씬 강했습니다.';
  }

  @override
  String coachMistake(Object best) {
    return '실수 — $best가 더 강했습니다.';
  }

  @override
  String coachBlunder(Object best) {
    return '대실수 — $best가 훨씬 나았습니다.';
  }

  @override
  String get settings => '설정';

  @override
  String get profile => '프로필';

  @override
  String get profileUsername => '사용자 이름';

  @override
  String get profileUsernameHint => '사용자 이름을 입력하세요';

  @override
  String get profileAvatar => '아바타';

  @override
  String get profileChangeAvatar => '아바타 변경';

  @override
  String get profileRemoveAvatar => '아바타 삭제';

  @override
  String get profileImageError => '이 이미지를 사용할 수 없습니다.';

  @override
  String get appearance => '외관';

  @override
  String get boardThemeLabel => '보드 테마';

  @override
  String get theme => '테마';

  @override
  String get themeSystem => '시스템';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get language => '언어';

  @override
  String get languageSystem => '시스템 기본값';

  @override
  String get accessibility => '접근성';

  @override
  String get highContrast => '고대비 보드';

  @override
  String get colorblindSafe => '색맹 친화 착수 색상';

  @override
  String get textSize => '글자 크기';

  @override
  String get gameplay => '게임플레이';

  @override
  String get sound => '소리';

  @override
  String get moveHints => '착수 힌트';

  @override
  String get haptics => '햅틱';

  @override
  String get animationSpeed => '애니메이션 속도';

  @override
  String get defaultTimeControl => '기본 시간 제한';

  @override
  String get defaultDifficulty => '기본 난이도';

  @override
  String get hostGame => '게임 호스트';

  @override
  String get yourName => '이름';

  @override
  String get yourColour => '당신의 색상';

  @override
  String get colourWhite => '백';

  @override
  String get colourBlack => '흑';

  @override
  String get colourRandom => '무작위';

  @override
  String get hostAGame => '게임 호스트하기';

  @override
  String get joinOnNetwork => '이 네트워크의 게임에 참가';

  @override
  String get searchingHosts => '호스트 검색 중…';

  @override
  String get waitingOpponent => '상대의 연결을 기다리는 중…';

  @override
  String get lanGame => 'LAN 게임';

  @override
  String get lanAllowSpectators => '관전자 허용';

  @override
  String get lanSpectate => '대국 관전';

  @override
  String get chat => '채팅';

  @override
  String get typeMessage => '메시지를 입력하세요…';

  @override
  String get noSavedGames => '아직 저장된 게임이 없습니다';

  @override
  String get renameGameTitle => '게임 이름 변경';

  @override
  String get pasteFen => 'FEN 문자열을 붙여넣으세요';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen => '잘못된 FEN — 국면 문자열을 확인하세요';

  @override
  String get useStartPosition => '시작 국면 사용';

  @override
  String get loadPosition => '국면 불러오기';

  @override
  String get exportPgn => 'PGN 내보내기';

  @override
  String get copyPgn => 'PGN 복사';

  @override
  String get copiedToClipboard => '클립보드에 복사되었습니다';

  @override
  String get game => '게임';

  @override
  String get lanTitle => '2인용 — LAN';

  @override
  String get playAs => '플레이 색상';

  @override
  String get difficulty => '난이도';

  @override
  String get timeControl => '시간 제한';

  @override
  String get startGame => '게임 시작';

  @override
  String get custom => '사용자 지정';

  @override
  String get tcInfinite => '무제한';

  @override
  String get diffVeryEasy => '매우 쉬움';

  @override
  String get diffEasy => '쉬움';

  @override
  String get diffNormal => '일반';

  @override
  String get diffHard => '어려움';

  @override
  String get diffVeryHard => '매우 어려움';

  @override
  String get diffImpossible => '불가능';

  @override
  String get baseMinutes => '기본 시간(분)';

  @override
  String get incrementSeconds => '추가 시간(초)';

  @override
  String get baseTimeError => '기본 시간은 최소 1분 이상이어야 합니다';

  @override
  String get searchDepth => '탐색 깊이';

  @override
  String get timePerMove => '수당 시간(ms)';

  @override
  String get maxEvalLoss => '최대 평가 손실(cp)';

  @override
  String get moveVariety => '수 선택 다양성';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return '$solved/$total 해결';
  }

  @override
  String get alreadySolved => '이미 해결함';

  @override
  String get puzzleWrong => '올바른 수가 아닙니다 — 다시 시도하세요';

  @override
  String get puzzleSolvedMsg => '해결! ✓  다음 퍼즐은 ▶ 을 누르세요';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return '퍼즐 $index/$total  ·  레이팅 $rating  ·  연속 $streak (최고 $best)';
  }

  @override
  String get loadPuzzlesFailed => '퍼즐을 불러오지 못했습니다';

  @override
  String get previous => '이전';

  @override
  String get hint => '힌트';

  @override
  String get restartPuzzle => '퍼즐 다시 시작';

  @override
  String get next => '다음';

  @override
  String get savedCorrupt => '저장된 게임이 손상되어 일부만 불러왔습니다';

  @override
  String get menuBughouse => '버그하우스';

  @override
  String get bugMode => '모드';

  @override
  String get bugBoardA => '보드 A';

  @override
  String get bugBoardB => '보드 B';

  @override
  String get bugWhite => '백';

  @override
  String get bugBlack => '흑';

  @override
  String bugTeamWins(String team) {
    return '$team 팀 승리';
  }

  @override
  String get bugStart => '경기 시작';

  @override
  String get bugLan => 'LAN';

  @override
  String get bugHostMatch => '매치 호스트';

  @override
  String get bugJoinMatch => '매치 참가';

  @override
  String get bugWaitingHost => '호스트가 시작하기를 기다리는 중…';

  @override
  String get bugPlayersJoined => '참가한 플레이어';

  @override
  String get bugAssignSeats => '네 자리 배정';

  @override
  String get bugSeatHost => '호스트 (나)';

  @override
  String get variant => '변형';

  @override
  String get vStandard => '스탠다드';

  @override
  String get vThreeCheck => '3체크';

  @override
  String get vKingOfTheHill => '킹 오브 더 힐';

  @override
  String get vChess960 => '체스960';

  @override
  String get vAtomic => '아토믹';

  @override
  String get vCrazyhouse => '크레이지하우스';

  @override
  String get vFogOfWar => '안개 전쟁 체스';

  @override
  String get menuFourPlayer => '4인전';

  @override
  String get fourFormat => '형식';

  @override
  String get fourFFA => '개인전';

  @override
  String get fourTeams => '팀전 (2대2)';

  @override
  String get fourVsBots => '봇 대전';

  @override
  String get fourSeatAi => 'AI';

  @override
  String get fourPerspective => '관점';

  @override
  String get fourYourSeats => '내 자리';

  @override
  String get fourRed => '빨강';

  @override
  String get fourBlue => '파랑';

  @override
  String get fourYellow => '노랑';

  @override
  String get fourGreen => '초록';

  @override
  String fourTeamWins(String team) {
    return '$team 승리';
  }

  @override
  String fourWins(String player) {
    return '$player 승리';
  }

  @override
  String get checksLabel => '체크 수';

  @override
  String get support => '지원';

  @override
  String get donate => '후원';

  @override
  String get donateSubtitle => 'GitHub Sponsors로 개발을 후원하세요';

  @override
  String get checkForUpdates => '업데이트 확인';

  @override
  String get checkingForUpdates => '업데이트 확인 중…';

  @override
  String get upToDate => '최신 버전입니다.';

  @override
  String get updateAvailable => '업데이트 있음';

  @override
  String get newVersionAvailable => '새 버전이 있습니다:';

  @override
  String get download => '다운로드';

  @override
  String get later => '나중에';

  @override
  String get about => '정보';

  @override
  String storeCorrupt(Object path) {
    return '데이터 파일을 읽을 수 없습니다. 사본을 $path에 보관했습니다.';
  }

  @override
  String get settingsSaveFailed => '설정을 저장하지 못했습니다. 앱을 닫기 전까지는 적용됩니다.';

  @override
  String get fenCastlingRemoved => '포지션과 맞지 않는 캐슬링 권리를 제거했습니다.';

  @override
  String get fenEnPassantRemoved => '포지션과 맞지 않는 앙파상 칸을 제거했습니다.';

  @override
  String get fenOpenedAsChess960 =>
      'Chess960으로 열었습니다. 이 캐슬링 배치는 표준 체스에서 유효하지 않습니다.';

  @override
  String savedPartialReplay(int count) {
    return '현재 규칙으로 재생할 수 없었던 수: $count. 마지막으로 둘 수 있는 수에서 게임을 열었으며, 저장된 게임은 변경되지 않았습니다.';
  }

  @override
  String savedGameDefaultName(Object stamp) {
    return '대국 $stamp';
  }

  @override
  String get gameSaveFailed => '대국을 저장할 수 없습니다.';

  @override
  String get pauseGame => '일시정지';

  @override
  String get resumeGame => '재개';

  @override
  String get gamePaused => '대국 일시정지됨';

  @override
  String get chatTooLong => '메시지가 너무 깁니다.';

  @override
  String get aiThinking => 'AI 생각 중…';

  @override
  String aiDepthEval(int depth, Object eval) {
    return 'AI: 깊이 $depth, 평가 $eval';
  }

  @override
  String pliesCount(int count) {
    return '$count수';
  }

  @override
  String get openLinkFailed => '링크를 열 수 없습니다.';

  @override
  String get boardGreen => '초록';

  @override
  String get boardBrown => '갈색';

  @override
  String get boardBlue => '파랑';

  @override
  String get boardGray => '회색';

  @override
  String get animationOff => '끔';

  @override
  String animationMs(int ms) {
    return '${ms}ms';
  }

  @override
  String get checkUpdatesOnLaunch => '시작 시 업데이트 확인';

  @override
  String get gameOverGeneric => '대국 종료';

  @override
  String get lanIncompatibleVersion =>
      '상대 기기의 Open Chess 버전이 다릅니다. 두 기기 모두 앱을 업데이트하세요.';

  @override
  String get tooManyPendingUpdates => '대기 중인 대국 업데이트가 너무 많습니다.';

  @override
  String get continueGame => '끝나지 않은 대국 계속하기';

  @override
  String get discardGame => '삭제';

  @override
  String get noMovesYet => '아직 수가 없습니다';

  @override
  String get promoteTo => '승진할 기물';

  @override
  String get piecePawn => '폰';

  @override
  String get pieceKnight => '나이트';

  @override
  String get pieceBishop => '비숍';

  @override
  String get pieceRook => '룩';

  @override
  String get pieceQueen => '퀸';

  @override
  String get pieceKing => '킹';

  @override
  String squarePieceLabel(Object square, Object color, Object piece) {
    return '$square, $color $piece';
  }

  @override
  String get staleCastlingTitle => '오래된 캐슬링 권리';

  @override
  String get staleCastlingBody =>
      '이 저장된 국면에는 더 이상 없는 룩과의 캐슬링 권리가 있습니다. 해당 권리 없이 열까요? 저장된 대국 자체는 바뀌지 않습니다.';

  @override
  String get openAnyway => '열기';

  @override
  String savedFenRejected(Object error) {
    return '이 저장된 대국을 열 수 없습니다: $error';
  }

  @override
  String analysisFailed(Object error) {
    return '분석에 실패했습니다. $error';
  }

  @override
  String get importGame => 'PGN / FEN 가져오기';

  @override
  String get importFromClipboard => '붙여넣기';

  @override
  String get importFromFile => '파일 열기';

  @override
  String get importHint => 'PGN 기보나 FEN 국면을 붙여넣으세요';

  @override
  String get importEmpty => '가져올 내용이 없습니다.';

  @override
  String get importTooLarge => '텍스트가 너무 커서 가져올 수 없습니다.';

  @override
  String importTooLong(int max) {
    return '대국이 $max수를 초과합니다.';
  }

  @override
  String importBadFen(Object error) {
    return '잘못된 국면: $error';
  }

  @override
  String importBadMove(Object move) {
    return '불법이거나 읽을 수 없는 수: $move';
  }

  @override
  String importUnsupported(Object variant) {
    return '이 변형은 분석할 수 없습니다: $variant';
  }

  @override
  String get importReadFailed => '파일을 읽을 수 없습니다.';

  @override
  String engineFailed(Object error) {
    return '엔진이 이 국면을 탐색할 수 없습니다: $error';
  }

  @override
  String get windowMinimize => '최소화';

  @override
  String get windowMaximize => '최대화';

  @override
  String get windowRestore => '이전 크기로 복원';

  @override
  String windowMoveNumber(int number) {
    return '$number수';
  }

  @override
  String fourToMove(String player) {
    return '$player 차례';
  }
}
