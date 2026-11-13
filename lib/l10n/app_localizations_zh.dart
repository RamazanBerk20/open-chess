// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Open Chess';

  @override
  String get menuSinglePlayer => '单人对战';

  @override
  String get menuTwoPlayers => '双人对战';

  @override
  String get menuLan => '局域网对战';

  @override
  String get menuPuzzles => '战术题';

  @override
  String get menuResume => '继续对局';

  @override
  String get menuSettings => '设置';

  @override
  String get menuPlayFromPosition => '从指定局面开始';

  @override
  String get ok => '确定';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get rename => '重命名';

  @override
  String get close => '关闭';

  @override
  String get retry => '重试';

  @override
  String get copy => '复制';

  @override
  String get share => '分享';

  @override
  String get start => '开始';

  @override
  String get accept => '接受';

  @override
  String get decline => '拒绝';

  @override
  String get send => '发送';

  @override
  String get whiteToMove => '轮到白方走棋';

  @override
  String get blackToMove => '轮到黑方走棋';

  @override
  String get whiteToMoveCheck => '轮到白方走棋 — 将军！';

  @override
  String get blackToMoveCheck => '轮到黑方走棋 — 将军！';

  @override
  String get checkmateWhiteWins => '将死 — 白方获胜';

  @override
  String get checkmateBlackWins => '将死 — 黑方获胜';

  @override
  String get whiteWinsOnTime => '白方超时获胜';

  @override
  String get blackWinsOnTime => '黑方超时获胜';

  @override
  String get drawStalemate => '和棋 — 逼和';

  @override
  String get drawFiftyMove => '和棋 — 五十回合规则';

  @override
  String get drawThreefold => '和棋 — 三次重复局面';

  @override
  String get drawInsufficient => '和棋 — 子力不足';

  @override
  String get resign => '认输';

  @override
  String get offerDraw => '提和';

  @override
  String get drawOfferTitle => '提和请求';

  @override
  String get drawOfferBody => '对手向你提和。';

  @override
  String get takeBack => '悔棋';

  @override
  String get newGame => '新对局';

  @override
  String get mainMenu => '主菜单';

  @override
  String get flipBoard => '翻转棋盘';

  @override
  String get autoFlipOn => '自动翻转：开';

  @override
  String get autoFlipOff => '自动翻转：关';

  @override
  String get saveGame => '保存对局';

  @override
  String get aiMove => 'AI走棋（当前一方）';

  @override
  String get playAgain => '再来一局';

  @override
  String get analyzeGame => '分析对局';

  @override
  String get gameSaved => '对局已保存';

  @override
  String get boardDesync => '棋盘不同步 — 对局已中止';

  @override
  String get youResigned => '你已认输 — 你输了';

  @override
  String get opponentResigned => '对手认输 — 你赢了';

  @override
  String get drawAgreed => '双方同意和棋';

  @override
  String get opponentDisconnected => '对手已断开连接';

  @override
  String get name => '名称';

  @override
  String get gameName => '对局名称';

  @override
  String get myGame => '我的对局';

  @override
  String get analysis => '分析';

  @override
  String get opening => '开局';

  @override
  String get openingGambit => '弃兵';

  @override
  String get openingVariation => '变例';

  @override
  String get openingNone => '无已命名开局';

  @override
  String get ratingEstimate => '估算等级分';

  @override
  String get ratingConfidenceLow => '低置信度';

  @override
  String get ratingConfidenceMedium => '中等置信度';

  @override
  String get ratingConfidenceHigh => '高置信度';

  @override
  String get ratingUnavailable => '无法估算等级分';

  @override
  String get white => '白方';

  @override
  String get black => '黑方';

  @override
  String get accuracy => '准确率';

  @override
  String analyzingProgress(Object done, Object total) {
    return '正在分析 $done/$total…';
  }

  @override
  String get preparingAnalysis => '正在准备分析…';

  @override
  String get clsBrilliant => '妙手';

  @override
  String get clsGreat => '精彩';

  @override
  String get clsBest => '最佳';

  @override
  String get clsGood => '良好';

  @override
  String get clsBook => '定式';

  @override
  String get clsInaccuracy => '不精确';

  @override
  String get clsMiss => '错失';

  @override
  String get clsMistake => '失误';

  @override
  String get clsBlunder => '漏着';

  @override
  String get coachBrilliant => '妙手 — 制胜的弃子。';

  @override
  String get coachGreat => '精彩 — 唯一能守住的一手。';

  @override
  String get coachBest => '最佳着法。';

  @override
  String get coachBook => '已知的开局着法。';

  @override
  String get coachGood => '不错的一手。';

  @override
  String coachInaccuracy(Object best) {
    return '不精确 — $best 会稍好一些。';
  }

  @override
  String coachMiss(Object best) {
    return '错失制胜良机 — $best 要强得多。';
  }

  @override
  String coachMistake(Object best) {
    return '失误 — $best 更强。';
  }

  @override
  String coachBlunder(Object best) {
    return '漏着 — $best 要好得多。';
  }

  @override
  String get settings => '设置';

  @override
  String get profile => '个人资料';

  @override
  String get profileUsername => '用户名';

  @override
  String get profileUsernameHint => '输入用户名';

  @override
  String get profileAvatar => '头像';

  @override
  String get profileChangeAvatar => '更改头像';

  @override
  String get profileRemoveAvatar => '删除头像';

  @override
  String get profileImageError => '无法使用此图片。';

  @override
  String get appearance => '外观';

  @override
  String get boardThemeLabel => '棋盘主题';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '系统默认';

  @override
  String get accessibility => '无障碍';

  @override
  String get highContrast => '高对比度棋盘';

  @override
  String get colorblindSafe => '色盲友好的走法颜色';

  @override
  String get textSize => '文字大小';

  @override
  String get gameplay => '玩法';

  @override
  String get sound => '音效';

  @override
  String get moveHints => '走法提示';

  @override
  String get haptics => '触感反馈';

  @override
  String get animationSpeed => '动画速度';

  @override
  String get defaultTimeControl => '默认时间控制';

  @override
  String get defaultDifficulty => '默认难度';

  @override
  String get hostGame => '创建对局';

  @override
  String get yourName => '你的名字';

  @override
  String get yourColour => '你的执棋方';

  @override
  String get colourWhite => '白方';

  @override
  String get colourBlack => '黑方';

  @override
  String get colourRandom => '随机';

  @override
  String get hostAGame => '创建一局对战';

  @override
  String get joinOnNetwork => '加入本网络中的对局';

  @override
  String get searchingHosts => '正在搜索主机…';

  @override
  String get waitingOpponent => '正在等待对手连接…';

  @override
  String get lanGame => '局域网对局';

  @override
  String get lanAllowSpectators => '允许观战';

  @override
  String get lanSpectate => '观看对局';

  @override
  String get chat => '聊天';

  @override
  String get typeMessage => '输入消息…';

  @override
  String get noSavedGames => '暂无已保存的对局';

  @override
  String get renameGameTitle => '重命名对局';

  @override
  String get pasteFen => '粘贴 FEN 字符串';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen => '无效的 FEN — 请检查局面字符串';

  @override
  String get useStartPosition => '使用初始局面';

  @override
  String get loadPosition => '加载局面';

  @override
  String get exportPgn => '导出 PGN';

  @override
  String get copyPgn => '复制 PGN';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get game => '对局';

  @override
  String get lanTitle => '双人对战 — 局域网';

  @override
  String get playAs => '执子';

  @override
  String get difficulty => '难度';

  @override
  String get timeControl => '时间控制';

  @override
  String get startGame => '开始对局';

  @override
  String get custom => '自定义';

  @override
  String get tcInfinite => '无限制';

  @override
  String get diffVeryEasy => '非常简单';

  @override
  String get diffEasy => '简单';

  @override
  String get diffNormal => '标准';

  @override
  String get diffHard => '困难';

  @override
  String get diffVeryHard => '非常困难';

  @override
  String get diffImpossible => '不可能';

  @override
  String get baseMinutes => '基础时间（分钟）';

  @override
  String get incrementSeconds => '加秒（秒）';

  @override
  String get baseTimeError => '基础时间至少为 1 分钟';

  @override
  String get searchDepth => '搜索深度';

  @override
  String get timePerMove => '每步用时（毫秒）';

  @override
  String get maxEvalLoss => '最大评估损失（兵值）';

  @override
  String get moveVariety => '走法多样性';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return '已解 $solved/$total';
  }

  @override
  String get alreadySolved => '已解出';

  @override
  String get puzzleWrong => '不是这一步 — 请再试一次';

  @override
  String get puzzleSolvedMsg => '解出！✓  点击 ▶ 进入下一题';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return '残局 $index/$total  ·  等级分 $rating  ·  连胜 $streak（最佳 $best）';
  }

  @override
  String get loadPuzzlesFailed => '加载残局失败';

  @override
  String get previous => '上一个';

  @override
  String get hint => '提示';

  @override
  String get restartPuzzle => '重新开始残局';

  @override
  String get next => '下一个';

  @override
  String get savedCorrupt => '存档已损坏；已部分加载';

  @override
  String get menuBughouse => '双人换子棋';

  @override
  String get bugMode => '模式';

  @override
  String get bugBoardA => '棋盘A';

  @override
  String get bugBoardB => '棋盘B';

  @override
  String get bugWhite => '白方';

  @override
  String get bugBlack => '黑方';

  @override
  String bugTeamWins(String team) {
    return '$team队获胜';
  }

  @override
  String get bugStart => '开始对局';

  @override
  String get bugLan => '局域网';

  @override
  String get bugHostMatch => '创建对局';

  @override
  String get bugJoinMatch => '加入对局';

  @override
  String get bugWaitingHost => '正在等待房主开始…';

  @override
  String get bugPlayersJoined => '已加入玩家';

  @override
  String get bugAssignSeats => '分配四个座位';

  @override
  String get bugSeatHost => '房主（你）';

  @override
  String get variant => '变体';

  @override
  String get vStandard => '标准';

  @override
  String get vThreeCheck => '三次将军';

  @override
  String get vKingOfTheHill => '占山为王';

  @override
  String get vChess960 => '国际象棋960';

  @override
  String get vAtomic => '原子象棋';

  @override
  String get vCrazyhouse => '疯狂屋';

  @override
  String get vFogOfWar => '黑暗棋';

  @override
  String get menuFourPlayer => '四人';

  @override
  String get fourFormat => '模式';

  @override
  String get fourFFA => '混战';

  @override
  String get fourTeams => '组队（2v2）';

  @override
  String get fourVsBots => '对战电脑';

  @override
  String get fourSeatAi => 'AI';

  @override
  String get fourPerspective => '视角';

  @override
  String get fourYourSeats => '你的座位';

  @override
  String get fourRed => '红方';

  @override
  String get fourBlue => '蓝方';

  @override
  String get fourYellow => '黄方';

  @override
  String get fourGreen => '绿方';

  @override
  String fourTeamWins(String team) {
    return '$team获胜';
  }

  @override
  String fourWins(String player) {
    return '$player获胜';
  }

  @override
  String get checksLabel => '将军次数';

  @override
  String get support => '支持';

  @override
  String get donate => '捐赠';

  @override
  String get donateSubtitle => '通过 GitHub Sponsors 支持开发';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get checkingForUpdates => '正在检查更新…';

  @override
  String get upToDate => '您使用的是最新版本。';

  @override
  String get updateAvailable => '有可用更新';

  @override
  String get newVersionAvailable => '有新版本可用：';

  @override
  String get download => '下载';

  @override
  String get later => '稍后';

  @override
  String get about => '关于';

  @override
  String storeCorrupt(Object path) {
    return '无法读取数据文件。已在 $path 保留一份副本。';
  }

  @override
  String get settingsSaveFailed => '无法保存某项设置。在关闭应用之前它仍会生效。';

  @override
  String get fenCastlingRemoved => '已移除与局面不符的王车易位权利。';

  @override
  String get fenEnPassantRemoved => '已移除与局面不符的吃过路兵格。';

  @override
  String get fenOpenedAsChess960 => '已作为 Chess960 打开：此易位布局在标准国际象棋中无效。';

  @override
  String savedPartialReplay(int count) {
    return '无法按当前规则重放的着法数：$count。对局已打开到最后一个可走的着法；已保存的对局未被更改。';
  }

  @override
  String savedGameDefaultName(Object stamp) {
    return '对局 $stamp';
  }

  @override
  String get gameSaveFailed => '无法保存对局。';

  @override
  String get pauseGame => '暂停';

  @override
  String get resumeGame => '继续';

  @override
  String get gamePaused => '对局已暂停';

  @override
  String get chatTooLong => '消息太长。';

  @override
  String get aiThinking => 'AI 思考中…';

  @override
  String aiDepthEval(int depth, Object eval) {
    return 'AI：深度 $depth，评估 $eval';
  }

  @override
  String pliesCount(int count) {
    return '$count 步';
  }

  @override
  String get openLinkFailed => '无法打开链接。';

  @override
  String get boardGreen => '绿色';

  @override
  String get boardBrown => '棕色';

  @override
  String get boardBlue => '蓝色';

  @override
  String get boardGray => '灰色';

  @override
  String get animationOff => '关闭';

  @override
  String animationMs(int ms) {
    return '$ms 毫秒';
  }

  @override
  String get checkUpdatesOnLaunch => '启动时检查更新';

  @override
  String get gameOverGeneric => '对局结束';

  @override
  String get lanIncompatibleVersion => '另一台设备运行的 Open Chess 版本不同。请在两台设备上都更新应用。';

  @override
  String get tooManyPendingUpdates => '待处理的对局更新过多。';

  @override
  String get continueGame => '继续未完成的对局';

  @override
  String get discardGame => '丢弃';

  @override
  String get noMovesYet => '尚无着法';

  @override
  String get promoteTo => '升变为';

  @override
  String get piecePawn => '兵';

  @override
  String get pieceKnight => '马';

  @override
  String get pieceBishop => '象';

  @override
  String get pieceRook => '车';

  @override
  String get pieceQueen => '后';

  @override
  String get pieceKing => '王';

  @override
  String squarePieceLabel(Object square, Object color, Object piece) {
    return '$square，$color$piece';
  }

  @override
  String get staleCastlingTitle => '过期的王车易位权';

  @override
  String get staleCastlingBody =>
      '此保存局面允许与已不存在的车进行王车易位。是否去掉这些易位权后打开？已保存的对局本身不会被修改。';

  @override
  String get openAnyway => '打开';

  @override
  String savedFenRejected(Object error) {
    return '无法打开此保存的对局：$error';
  }

  @override
  String analysisFailed(Object error) {
    return '分析失败。$error';
  }

  @override
  String get importGame => '导入 PGN / FEN';

  @override
  String get importFromClipboard => '粘贴';

  @override
  String get importFromFile => '打开文件';

  @override
  String get importHint => '粘贴 PGN 对局或 FEN 局面';

  @override
  String get importEmpty => '没有可导入的内容。';

  @override
  String get importTooLarge => '文本过大，无法导入。';

  @override
  String importTooLong(int max) {
    return '对局超过 $max 步。';
  }

  @override
  String importBadFen(Object error) {
    return '无效局面：$error';
  }

  @override
  String importBadMove(Object move) {
    return '非法或无法识别的着法：$move';
  }

  @override
  String importUnsupported(Object variant) {
    return '无法分析此变体：$variant';
  }

  @override
  String get importReadFailed => '无法读取文件。';

  @override
  String engineFailed(Object error) {
    return '引擎无法搜索此局面：$error';
  }
}
