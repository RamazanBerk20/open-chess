// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Open Chess';

  @override
  String get menuSinglePlayer => 'シングルプレイ';

  @override
  String get menuTwoPlayers => '2人対戦';

  @override
  String get menuLan => 'LANで対戦';

  @override
  String get menuPuzzles => 'パズル';

  @override
  String get menuResume => 'ゲームを再開';

  @override
  String get menuSettings => '設定';

  @override
  String get menuPlayFromPosition => '局面から対局';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get rename => '名前を変更';

  @override
  String get close => '閉じる';

  @override
  String get retry => '再試行';

  @override
  String get copy => 'コピー';

  @override
  String get share => '共有';

  @override
  String get start => '開始';

  @override
  String get accept => '承諾';

  @override
  String get decline => '辞退';

  @override
  String get send => '送信';

  @override
  String get whiteToMove => '白の手番';

  @override
  String get blackToMove => '黒の手番';

  @override
  String get whiteToMoveCheck => '白の手番 — チェック！';

  @override
  String get blackToMoveCheck => '黒の手番 — チェック！';

  @override
  String get checkmateWhiteWins => 'チェックメイト — 白の勝ち';

  @override
  String get checkmateBlackWins => 'チェックメイト — 黒の勝ち';

  @override
  String get whiteWinsOnTime => '時間切れで白の勝ち';

  @override
  String get blackWinsOnTime => '時間切れで黒の勝ち';

  @override
  String get drawStalemate => '引き分け — ステイルメイト';

  @override
  String get drawFiftyMove => '引き分け — 50手ルール';

  @override
  String get drawThreefold => '引き分け — 同形3回反復';

  @override
  String get drawInsufficient => '引き分け — 駒数不足';

  @override
  String get resign => '投了';

  @override
  String get offerDraw => '引き分けを提案';

  @override
  String get drawOfferTitle => '引き分けの提案';

  @override
  String get drawOfferBody => '相手が引き分けを提案しています。';

  @override
  String get takeBack => '待った';

  @override
  String get newGame => '新しいゲーム';

  @override
  String get mainMenu => 'メインメニュー';

  @override
  String get flipBoard => '盤を反転';

  @override
  String get autoFlipOn => '自動反転：オン';

  @override
  String get autoFlipOff => '自動反転：オフ';

  @override
  String get saveGame => 'ゲームを保存';

  @override
  String get aiMove => 'AIの手（現在の手番）';

  @override
  String get playAgain => 'もう一度対局';

  @override
  String get analyzeGame => '棋譜を解析';

  @override
  String get gameSaved => 'ゲームを保存しました';

  @override
  String get boardDesync => '盤面の同期エラー — ゲームを中止しました';

  @override
  String get youResigned => '投了しました — あなたの負け';

  @override
  String get opponentResigned => '相手が投了しました — あなたの勝ち';

  @override
  String get drawAgreed => '引き分けが成立しました';

  @override
  String get opponentDisconnected => '相手が切断しました';

  @override
  String get name => '名前';

  @override
  String get gameName => 'ゲーム名';

  @override
  String get myGame => 'マイゲーム';

  @override
  String get analysis => '解析';

  @override
  String get opening => 'オープニング';

  @override
  String get openingGambit => 'ギャンビット';

  @override
  String get openingVariation => '変化';

  @override
  String get openingNone => '名前の付いたオープニングなし';

  @override
  String get ratingEstimate => '推定レーティング';

  @override
  String get ratingConfidenceLow => '低い信頼度';

  @override
  String get ratingConfidenceMedium => '普通の信頼度';

  @override
  String get ratingConfidenceHigh => '高い信頼度';

  @override
  String get ratingUnavailable => '推定レーティングは利用できません';

  @override
  String get white => '白';

  @override
  String get black => '黒';

  @override
  String get accuracy => '正確度';

  @override
  String analyzingProgress(Object done, Object total) {
    return '解析中 $done/$total…';
  }

  @override
  String get preparingAnalysis => '解析を準備中…';

  @override
  String get clsBrilliant => 'ブリリアント';

  @override
  String get clsGreat => 'グレート';

  @override
  String get clsBest => 'ベスト';

  @override
  String get clsGood => 'グッド';

  @override
  String get clsBook => '定跡';

  @override
  String get clsInaccuracy => '不正確';

  @override
  String get clsMiss => 'ミス';

  @override
  String get clsMistake => 'ミステイク';

  @override
  String get clsBlunder => 'ブランダー';

  @override
  String get coachBrilliant => 'ブリリアント — 勝ちにつながる犠牲です。';

  @override
  String get coachGreat => 'グレート — これを守る唯一の手です。';

  @override
  String get coachBest => '最善手です。';

  @override
  String get coachBook => '知られた定跡の手です。';

  @override
  String get coachGood => '良い手です。';

  @override
  String coachInaccuracy(Object best) {
    return '不正確 — $best の方が少し良かったです。';
  }

  @override
  String coachMiss(Object best) {
    return '勝機を逃しました — $best の方がずっと強力でした。';
  }

  @override
  String coachMistake(Object best) {
    return 'ミステイク — $best の方が強力でした。';
  }

  @override
  String coachBlunder(Object best) {
    return 'ブランダー — $best の方がずっと良かったです。';
  }

  @override
  String get settings => '設定';

  @override
  String get profile => 'プロフィール';

  @override
  String get profileUsername => 'ユーザー名';

  @override
  String get profileUsernameHint => 'ユーザー名を入力';

  @override
  String get profileAvatar => 'アバター';

  @override
  String get profileChangeAvatar => 'アバターを変更';

  @override
  String get profileRemoveAvatar => 'アバターを削除';

  @override
  String get profileImageError => 'この画像は使用できませんでした。';

  @override
  String get appearance => '外観';

  @override
  String get boardThemeLabel => '盤のテーマ';

  @override
  String get theme => 'テーマ';

  @override
  String get themeSystem => 'システム';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get language => '言語';

  @override
  String get languageSystem => 'システムの既定';

  @override
  String get accessibility => 'アクセシビリティ';

  @override
  String get highContrast => 'ハイコントラストの盤';

  @override
  String get colorblindSafe => '色覚に配慮した移動色';

  @override
  String get textSize => '文字サイズ';

  @override
  String get gameplay => 'ゲームプレイ';

  @override
  String get sound => 'サウンド';

  @override
  String get moveHints => '手のヒント';

  @override
  String get haptics => '触覚フィードバック';

  @override
  String get animationSpeed => 'アニメーション速度';

  @override
  String get defaultTimeControl => '既定の持ち時間';

  @override
  String get defaultDifficulty => '既定の難易度';

  @override
  String get hostGame => 'ゲームを開催';

  @override
  String get yourName => 'あなたの名前';

  @override
  String get yourColour => 'あなたの色';

  @override
  String get colourWhite => '白';

  @override
  String get colourBlack => '黒';

  @override
  String get colourRandom => 'ランダム';

  @override
  String get hostAGame => 'ゲームを開催する';

  @override
  String get joinOnNetwork => 'このネットワークのゲームに参加';

  @override
  String get searchingHosts => 'ホストを検索中…';

  @override
  String get waitingOpponent => '対戦相手の接続を待っています…';

  @override
  String get lanGame => 'LAN対局';

  @override
  String get lanAllowSpectators => '観戦を許可';

  @override
  String get lanSpectate => '対局を観戦';

  @override
  String get chat => 'チャット';

  @override
  String get typeMessage => 'メッセージを入力…';

  @override
  String get noSavedGames => '保存したゲームはまだありません';

  @override
  String get renameGameTitle => 'ゲーム名を変更';

  @override
  String get pasteFen => 'FEN文字列を貼り付け';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen => '無効なFEN — 局面の文字列を確認してください';

  @override
  String get useStartPosition => '初期局面を使用';

  @override
  String get loadPosition => '局面を読み込む';

  @override
  String get exportPgn => 'PGNをエクスポート';

  @override
  String get copyPgn => 'PGNをコピー';

  @override
  String get copiedToClipboard => 'クリップボードにコピーしました';

  @override
  String get game => '対局';

  @override
  String get lanTitle => '2人対戦 — LAN';

  @override
  String get playAs => '使用する側';

  @override
  String get difficulty => '難易度';

  @override
  String get timeControl => '持ち時間';

  @override
  String get startGame => '対局開始';

  @override
  String get custom => 'カスタム';

  @override
  String get tcInfinite => '無制限';

  @override
  String get diffVeryEasy => 'とても簡単';

  @override
  String get diffEasy => '易しい';

  @override
  String get diffNormal => '標準';

  @override
  String get diffHard => '難しい';

  @override
  String get diffVeryHard => 'とても難しい';

  @override
  String get diffImpossible => '不可能';

  @override
  String get baseMinutes => '基本時間（分）';

  @override
  String get incrementSeconds => '加算時間（秒）';

  @override
  String get baseTimeError => '基本時間は最低1分必要です';

  @override
  String get searchDepth => '探索の深さ';

  @override
  String get timePerMove => '1手あたりの時間（ミリ秒）';

  @override
  String get maxEvalLoss => '最大評価損失（センチポーン）';

  @override
  String get moveVariety => '指し手の多様性';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return '$solved/$total 解決済み';
  }

  @override
  String get alreadySolved => '解決済み';

  @override
  String get puzzleWrong => 'その手ではありません — もう一度お試しください';

  @override
  String get puzzleSolvedMsg => '正解！ ✓  ▶ をタップして次のパズルへ';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return 'パズル $index/$total  ·  レーティング $rating  ·  連続正解 $streak（最高 $best）';
  }

  @override
  String get loadPuzzlesFailed => 'パズルの読み込みに失敗しました';

  @override
  String get previous => '前へ';

  @override
  String get hint => 'ヒント';

  @override
  String get restartPuzzle => 'パズルをやり直す';

  @override
  String get next => '次へ';

  @override
  String get savedCorrupt => '保存された対局が破損していました。一部のみ読み込みました';

  @override
  String get menuBughouse => 'バグハウス';

  @override
  String get bugMode => 'モード';

  @override
  String get bugBoardA => 'ボードA';

  @override
  String get bugBoardB => 'ボードB';

  @override
  String get bugWhite => '白';

  @override
  String get bugBlack => '黒';

  @override
  String bugTeamWins(String team) {
    return '$teamチームの勝ち';
  }

  @override
  String get bugStart => '対局開始';

  @override
  String get bugLan => 'LAN';

  @override
  String get bugHostMatch => '対局を作成';

  @override
  String get bugJoinMatch => '対局に参加';

  @override
  String get bugWaitingHost => 'ホストの開始を待っています…';

  @override
  String get bugPlayersJoined => '参加済みのプレイヤー';

  @override
  String get bugAssignSeats => '4つの席を割り当て';

  @override
  String get bugSeatHost => 'ホスト（あなた）';

  @override
  String get variant => 'バリアント';

  @override
  String get vStandard => 'スタンダード';

  @override
  String get vThreeCheck => 'スリーチェック';

  @override
  String get vKingOfTheHill => 'キングオブザヒル';

  @override
  String get vChess960 => 'チェス960';

  @override
  String get vAtomic => 'アトミック';

  @override
  String get vCrazyhouse => 'クレイジーハウス';

  @override
  String get vFogOfWar => '霧の戦争';

  @override
  String get menuFourPlayer => '4人対戦';

  @override
  String get fourFormat => '形式';

  @override
  String get fourFFA => 'バトルロイヤル';

  @override
  String get fourTeams => 'チーム戦（2対2）';

  @override
  String get fourVsBots => '対ボット';

  @override
  String get fourSeatAi => 'AI';

  @override
  String get fourPerspective => '視点';

  @override
  String get fourYourSeats => 'あなたの担当';

  @override
  String get fourRed => 'レッド';

  @override
  String get fourBlue => 'ブルー';

  @override
  String get fourYellow => 'イエロー';

  @override
  String get fourGreen => 'グリーン';

  @override
  String fourTeamWins(String team) {
    return '$teamの勝ち';
  }

  @override
  String fourWins(String player) {
    return '$playerの勝ち';
  }

  @override
  String get checksLabel => 'チェック数';

  @override
  String get support => 'サポート';

  @override
  String get donate => '寄付';

  @override
  String get donateSubtitle => 'GitHub Sponsors で開発を支援';

  @override
  String get checkForUpdates => 'アップデートを確認';

  @override
  String get checkingForUpdates => 'アップデートを確認しています…';

  @override
  String get upToDate => '最新バージョンです。';

  @override
  String get updateAvailable => 'アップデートがあります';

  @override
  String get newVersionAvailable => '新しいバージョンがあります:';

  @override
  String get download => 'ダウンロード';

  @override
  String get later => '後で';

  @override
  String get about => 'アプリについて';

  @override
  String storeCorrupt(Object path) {
    return 'データファイルを読み込めませんでした。コピーを $path に保存しました。';
  }

  @override
  String get settingsSaveFailed => '設定を保存できませんでした。アプリを閉じるまでは有効です。';

  @override
  String get fenCastlingRemoved => '局面と一致しないキャスリングの権利を削除しました。';

  @override
  String get fenEnPassantRemoved => '局面と一致しないアンパッサンのマスを削除しました。';

  @override
  String get fenOpenedAsChess960 => 'Chess960として開きました。このキャスリング配置は通常のチェスでは無効です。';

  @override
  String savedPartialReplay(int count) {
    return '現在のルールで再生できなかった手数：$count。最後に指せる手の位置で開きました。保存データは変更されていません。';
  }

  @override
  String savedGameDefaultName(Object stamp) {
    return '対局 $stamp';
  }

  @override
  String get gameSaveFailed => '対局を保存できませんでした。';

  @override
  String get pauseGame => '一時停止';

  @override
  String get resumeGame => '再開';

  @override
  String get gamePaused => '一時停止中';

  @override
  String get chatTooLong => 'メッセージが長すぎます。';

  @override
  String get aiThinking => 'AI思考中…';

  @override
  String aiDepthEval(int depth, Object eval) {
    return 'AI：深さ $depth、評価値 $eval';
  }

  @override
  String pliesCount(int count) {
    return '$count 手';
  }

  @override
  String get openLinkFailed => 'リンクを開けませんでした。';

  @override
  String get boardGreen => 'グリーン';

  @override
  String get boardBrown => 'ブラウン';

  @override
  String get boardBlue => 'ブルー';

  @override
  String get boardGray => 'グレー';

  @override
  String get animationOff => 'オフ';

  @override
  String animationMs(int ms) {
    return '$ms ミリ秒';
  }

  @override
  String get checkUpdatesOnLaunch => '起動時にアップデートを確認';

  @override
  String get gameOverGeneric => '対局終了';

  @override
  String get lanIncompatibleVersion =>
      '相手の端末は別のバージョンの Open Chess を使っています。両方の端末でアプリを更新してください。';

  @override
  String get tooManyPendingUpdates => '保留中の対局更新が多すぎます。';

  @override
  String get continueGame => '未完了の対局を続ける';

  @override
  String get discardGame => '破棄';

  @override
  String get noMovesYet => 'まだ指し手はありません';

  @override
  String get promoteTo => '成る駒を選択';

  @override
  String get piecePawn => 'ポーン';

  @override
  String get pieceKnight => 'ナイト';

  @override
  String get pieceBishop => 'ビショップ';

  @override
  String get pieceRook => 'ルーク';

  @override
  String get pieceQueen => 'クイーン';

  @override
  String get pieceKing => 'キング';

  @override
  String squarePieceLabel(Object square, Object color, Object piece) {
    return '$square、$colorの$piece';
  }

  @override
  String get staleCastlingTitle => '古いキャスリング権';

  @override
  String get staleCastlingBody =>
      'この保存局面には、もう存在しないルークとのキャスリング権があります。その権利を外して開きますか？保存された対局自体は変更されません。';

  @override
  String get openAnyway => '開く';

  @override
  String savedFenRejected(Object error) {
    return 'この保存対局は開けません: $error';
  }

  @override
  String analysisFailed(Object error) {
    return '解析に失敗しました。$error';
  }

  @override
  String get importGame => 'PGN / FEN を読み込む';

  @override
  String get importFromClipboard => '貼り付け';

  @override
  String get importFromFile => 'ファイルを開く';

  @override
  String get importHint => 'PGN の棋譜または FEN 局面を貼り付けてください';

  @override
  String get importEmpty => '読み込む内容がありません。';

  @override
  String get importTooLarge => 'テキストが大きすぎて読み込めません。';

  @override
  String importTooLong(int max) {
    return '対局が $max 手を超えています。';
  }

  @override
  String importBadFen(Object error) {
    return '無効な局面: $error';
  }

  @override
  String importBadMove(Object move) {
    return '不正または読み取れない指し手: $move';
  }

  @override
  String importUnsupported(Object variant) {
    return 'このバリアントは解析できません: $variant';
  }

  @override
  String get importReadFailed => 'ファイルを読み込めませんでした。';

  @override
  String engineFailed(Object error) {
    return 'エンジンはこの局面を探索できませんでした: $error';
  }
}
