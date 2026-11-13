// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Open Chess';

  @override
  String get menuSinglePlayer => 'لاعب واحد';

  @override
  String get menuTwoPlayers => 'لاعبان';

  @override
  String get menuLan => 'اللعب عبر الشبكة المحلية';

  @override
  String get menuPuzzles => 'الألغاز';

  @override
  String get menuResume => 'استئناف اللعبة';

  @override
  String get menuSettings => 'الإعدادات';

  @override
  String get menuPlayFromPosition => 'اللعب من وضعية';

  @override
  String get ok => 'موافق';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get delete => 'حذف';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get close => 'إغلاق';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get copy => 'نسخ';

  @override
  String get share => 'مشاركة';

  @override
  String get start => 'ابدأ';

  @override
  String get accept => 'قبول';

  @override
  String get decline => 'رفض';

  @override
  String get send => 'إرسال';

  @override
  String get whiteToMove => 'دور الأبيض';

  @override
  String get blackToMove => 'دور الأسود';

  @override
  String get whiteToMoveCheck => 'دور الأبيض — كش!';

  @override
  String get blackToMoveCheck => 'دور الأسود — كش!';

  @override
  String get checkmateWhiteWins => 'كش مات — الأبيض يفوز';

  @override
  String get checkmateBlackWins => 'كش مات — الأسود يفوز';

  @override
  String get whiteWinsOnTime => 'الأبيض يفوز بانتهاء الوقت';

  @override
  String get blackWinsOnTime => 'الأسود يفوز بانتهاء الوقت';

  @override
  String get drawStalemate => 'تعادل — جمود';

  @override
  String get drawFiftyMove => 'تعادل — قاعدة الخمسين نقلة';

  @override
  String get drawThreefold => 'تعادل — تكرار الوضعية ثلاث مرات';

  @override
  String get drawInsufficient => 'تعادل — عدم كفاية القطع';

  @override
  String get resign => 'الاستسلام';

  @override
  String get offerDraw => 'عرض التعادل';

  @override
  String get drawOfferTitle => 'عرض تعادل';

  @override
  String get drawOfferBody => 'خصمك يعرض التعادل.';

  @override
  String get takeBack => 'التراجع عن النقلة';

  @override
  String get newGame => 'لعبة جديدة';

  @override
  String get mainMenu => 'القائمة الرئيسية';

  @override
  String get flipBoard => 'قلب الرقعة';

  @override
  String get autoFlipOn => 'القلب التلقائي: مفعّل';

  @override
  String get autoFlipOff => 'القلب التلقائي: معطّل';

  @override
  String get saveGame => 'حفظ اللعبة';

  @override
  String get aiMove => 'نقلة الذكاء الاصطناعي (الجانب الحالي)';

  @override
  String get playAgain => 'العب مرة أخرى';

  @override
  String get analyzeGame => 'تحليل اللعبة';

  @override
  String get gameSaved => 'تم حفظ اللعبة';

  @override
  String get boardDesync => 'عدم تزامن الرقعة — تم إيقاف اللعبة';

  @override
  String get youResigned => 'لقد استسلمت — أنت خاسر';

  @override
  String get opponentResigned => 'استسلم الخصم — أنت الفائز';

  @override
  String get drawAgreed => 'تم الاتفاق على التعادل';

  @override
  String get opponentDisconnected => 'انقطع اتصال الخصم';

  @override
  String get name => 'الاسم';

  @override
  String get gameName => 'اسم اللعبة';

  @override
  String get myGame => 'لعبتي';

  @override
  String get analysis => 'التحليل';

  @override
  String get opening => 'الافتتاح';

  @override
  String get openingGambit => 'جامبيت';

  @override
  String get openingVariation => 'التنويع';

  @override
  String get openingNone => 'لا يوجد افتتاح مسمى';

  @override
  String get ratingEstimate => 'التصنيف التقديري';

  @override
  String get ratingConfidenceLow => 'ثقة منخفضة';

  @override
  String get ratingConfidenceMedium => 'ثقة متوسطة';

  @override
  String get ratingConfidenceHigh => 'ثقة عالية';

  @override
  String get ratingUnavailable => 'تقدير التصنيف غير متاح';

  @override
  String get white => 'الأبيض';

  @override
  String get black => 'الأسود';

  @override
  String get accuracy => 'الدقة';

  @override
  String analyzingProgress(Object done, Object total) {
    return 'جارٍ التحليل $done/$total…';
  }

  @override
  String get preparingAnalysis => 'جارٍ تحضير التحليل…';

  @override
  String get clsBrilliant => 'نقلة رائعة';

  @override
  String get clsGreat => 'نقلة عظيمة';

  @override
  String get clsBest => 'أفضل نقلة';

  @override
  String get clsGood => 'نقلة جيدة';

  @override
  String get clsBook => 'نقلة معروفة';

  @override
  String get clsInaccuracy => 'نقلة غير دقيقة';

  @override
  String get clsMiss => 'فرصة ضائعة';

  @override
  String get clsMistake => 'خطأ';

  @override
  String get clsBlunder => 'خطأ فادح';

  @override
  String get coachBrilliant => 'نقلة رائعة — تضحية رابحة.';

  @override
  String get coachGreat => 'نقلة عظيمة — النقلة الوحيدة التي تصمد.';

  @override
  String get coachBest => 'أفضل نقلة.';

  @override
  String get coachBook => 'نقلة افتتاحية معروفة.';

  @override
  String get coachGood => 'نقلة جيدة.';

  @override
  String coachInaccuracy(Object best) {
    return 'نقلة غير دقيقة — كانت $best أفضل قليلاً.';
  }

  @override
  String coachMiss(Object best) {
    return 'فرصة رابحة ضائعة — كانت $best أقوى بكثير.';
  }

  @override
  String coachMistake(Object best) {
    return 'خطأ — كانت $best أقوى.';
  }

  @override
  String coachBlunder(Object best) {
    return 'خطأ فادح — كانت $best أفضل بكثير.';
  }

  @override
  String get settings => 'الإعدادات';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get profileUsername => 'اسم المستخدم';

  @override
  String get profileUsernameHint => 'اختر اسم مستخدم';

  @override
  String get profileAvatar => 'الصورة الرمزية';

  @override
  String get profileChangeAvatar => 'تغيير الصورة الرمزية';

  @override
  String get profileRemoveAvatar => 'إزالة الصورة الرمزية';

  @override
  String get profileImageError => 'تعذر استخدام هذه الصورة.';

  @override
  String get appearance => 'المظهر';

  @override
  String get boardThemeLabel => 'سمة الرقعة';

  @override
  String get theme => 'السمة';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get language => 'اللغة';

  @override
  String get languageSystem => 'افتراضي النظام';

  @override
  String get accessibility => 'إمكانية الوصول';

  @override
  String get highContrast => 'رقعة عالية التباين';

  @override
  String get colorblindSafe => 'ألوان نقلات مناسبة لعمى الألوان';

  @override
  String get textSize => 'حجم النص';

  @override
  String get gameplay => 'طريقة اللعب';

  @override
  String get sound => 'الصوت';

  @override
  String get moveHints => 'تلميحات النقلات';

  @override
  String get haptics => 'الاهتزاز اللمسي';

  @override
  String get animationSpeed => 'سرعة الحركة';

  @override
  String get defaultTimeControl => 'التحكم الافتراضي بالوقت';

  @override
  String get defaultDifficulty => 'مستوى الصعوبة الافتراضي';

  @override
  String get hostGame => 'استضافة لعبة';

  @override
  String get yourName => 'اسمك';

  @override
  String get yourColour => 'لونك';

  @override
  String get colourWhite => 'الأبيض';

  @override
  String get colourBlack => 'الأسود';

  @override
  String get colourRandom => 'عشوائي';

  @override
  String get hostAGame => 'استضف لعبة';

  @override
  String get joinOnNetwork => 'انضم إلى لعبة على هذه الشبكة';

  @override
  String get searchingHosts => 'جارٍ البحث عن المضيفين…';

  @override
  String get waitingOpponent => 'في انتظار اتصال خصم…';

  @override
  String get lanGame => 'لعبة عبر الشبكة المحلية';

  @override
  String get lanAllowSpectators => 'السماح بالمشاهدين';

  @override
  String get lanSpectate => 'مشاهدة المباراة';

  @override
  String get chat => 'الدردشة';

  @override
  String get typeMessage => 'اكتب رسالة…';

  @override
  String get noSavedGames => 'لا توجد ألعاب محفوظة بعد';

  @override
  String get renameGameTitle => 'إعادة تسمية اللعبة';

  @override
  String get pasteFen => 'الصق سلسلة FEN';

  @override
  String get fenHint =>
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  String get invalidFen => 'سلسلة FEN غير صالحة — تحقق من سلسلة الوضعية';

  @override
  String get useStartPosition => 'استخدام وضعية البداية';

  @override
  String get loadPosition => 'تحميل الوضعية';

  @override
  String get exportPgn => 'تصدير PGN';

  @override
  String get copyPgn => 'نسخ PGN';

  @override
  String get copiedToClipboard => 'تم النسخ إلى الحافظة';

  @override
  String get game => 'اللعبة';

  @override
  String get lanTitle => 'لاعبان — الشبكة المحلية';

  @override
  String get playAs => 'اللعب بـ';

  @override
  String get difficulty => 'الصعوبة';

  @override
  String get timeControl => 'التحكم بالوقت';

  @override
  String get startGame => 'بدء اللعبة';

  @override
  String get custom => 'مخصص';

  @override
  String get tcInfinite => 'غير محدود';

  @override
  String get diffVeryEasy => 'سهل جدًا';

  @override
  String get diffEasy => 'سهل';

  @override
  String get diffNormal => 'عادي';

  @override
  String get diffHard => 'صعب';

  @override
  String get diffVeryHard => 'صعب جدًا';

  @override
  String get diffImpossible => 'مستحيل';

  @override
  String get baseMinutes => 'الدقائق الأساسية';

  @override
  String get incrementSeconds => 'ثواني الزيادة';

  @override
  String get baseTimeError => 'يجب ألا يقل الوقت الأساسي عن دقيقة واحدة';

  @override
  String get searchDepth => 'عمق البحث';

  @override
  String get timePerMove => 'الوقت/النقلة (مللي ثانية)';

  @override
  String get maxEvalLoss => 'أقصى خسارة في التقييم (سم)';

  @override
  String get moveVariety => 'تنوع النقلات';

  @override
  String puzzlesSolved(Object solved, Object total) {
    return 'تم حل $solved/$total';
  }

  @override
  String get alreadySolved => 'تم حله مسبقاً';

  @override
  String get puzzleWrong => 'ليست النقلة الصحيحة — حاول مجدداً';

  @override
  String get puzzleSolvedMsg => 'تم الحل! ✓  انقر ▶ للأحجية التالية';

  @override
  String puzzleFooter(
    Object index,
    Object total,
    Object rating,
    Object streak,
    Object best,
  ) {
    return 'الأحجية $index/$total  ·  التصنيف $rating  ·  السلسلة $streak (الأفضل $best)';
  }

  @override
  String get loadPuzzlesFailed => 'فشل تحميل الأحجيات';

  @override
  String get previous => 'السابق';

  @override
  String get hint => 'تلميح';

  @override
  String get restartPuzzle => 'إعادة الأحجية';

  @override
  String get next => 'التالي';

  @override
  String get savedCorrupt => 'كانت اللعبة المحفوظة تالفة؛ تم تحميلها جزئياً';

  @override
  String get menuBughouse => 'باغهاوس';

  @override
  String get bugMode => 'الوضع';

  @override
  String get bugBoardA => 'الرقعة أ';

  @override
  String get bugBoardB => 'الرقعة ب';

  @override
  String get bugWhite => 'الأبيض';

  @override
  String get bugBlack => 'الأسود';

  @override
  String bugTeamWins(String team) {
    return 'فوز الفريق $team';
  }

  @override
  String get bugStart => 'ابدأ المباراة';

  @override
  String get bugLan => 'الشبكة المحلية';

  @override
  String get bugHostMatch => 'استضافة مباراة';

  @override
  String get bugJoinMatch => 'الانضمام إلى مباراة';

  @override
  String get bugWaitingHost => 'في انتظار المضيف لبدء المباراة…';

  @override
  String get bugPlayersJoined => 'اللاعبون المنضمّون';

  @override
  String get bugAssignSeats => 'توزيع المقاعد الأربعة';

  @override
  String get bugSeatHost => 'المضيف (أنت)';

  @override
  String get variant => 'النوع';

  @override
  String get vStandard => 'الكلاسيكية';

  @override
  String get vThreeCheck => 'الكشوف الثلاثة';

  @override
  String get vKingOfTheHill => 'ملك التل';

  @override
  String get vChess960 => 'شطرنج 960';

  @override
  String get vAtomic => 'الذرية';

  @override
  String get vCrazyhouse => 'البيت المجنون';

  @override
  String get vFogOfWar => 'شطرنج الظلام';

  @override
  String get menuFourPlayer => '4 لاعبين';

  @override
  String get fourFormat => 'النمط';

  @override
  String get fourFFA => 'الكل ضد الكل';

  @override
  String get fourTeams => 'فِرَق (2 ضد 2)';

  @override
  String get fourVsBots => 'ضد الروبوتات';

  @override
  String get fourSeatAi => 'ذكاء اصطناعي';

  @override
  String get fourPerspective => 'المنظور';

  @override
  String get fourYourSeats => 'مقاعدك';

  @override
  String get fourRed => 'الأحمر';

  @override
  String get fourBlue => 'الأزرق';

  @override
  String get fourYellow => 'الأصفر';

  @override
  String get fourGreen => 'الأخضر';

  @override
  String fourTeamWins(String team) {
    return 'فوز $team';
  }

  @override
  String fourWins(String player) {
    return 'فوز $player';
  }

  @override
  String get checksLabel => 'الكشوف';

  @override
  String get support => 'الدعم';

  @override
  String get donate => 'تبرّع';

  @override
  String get donateSubtitle => 'ادعم التطوير عبر GitHub Sponsors';

  @override
  String get checkForUpdates => 'التحقق من التحديثات';

  @override
  String get checkingForUpdates => 'جارٍ التحقق من التحديثات…';

  @override
  String get upToDate => 'أنت تستخدم أحدث إصدار.';

  @override
  String get updateAvailable => 'يتوفر تحديث';

  @override
  String get newVersionAvailable => 'يتوفر إصدار جديد:';

  @override
  String get download => 'تنزيل';

  @override
  String get later => 'لاحقًا';

  @override
  String get about => 'حول';

  @override
  String storeCorrupt(Object path) {
    return 'تعذّرت قراءة ملف بيانات. تم الاحتفاظ بنسخة في $path.';
  }

  @override
  String get settingsSaveFailed =>
      'تعذّر حفظ أحد الإعدادات. سيظل ساريًا حتى تغلق التطبيق.';

  @override
  String get fenCastlingRemoved =>
      'تمت إزالة حقوق التبييت التي لا تطابق الوضع.';

  @override
  String get fenEnPassantRemoved =>
      'تمت إزالة مربع الأخذ بالمرور الذي لا يطابق الوضع.';

  @override
  String get fenOpenedAsChess960 =>
      'تم الفتح كـ Chess960: ترتيب التبييت هذا غير صالح في الشطرنج القياسي.';

  @override
  String savedPartialReplay(int count) {
    return 'عدد النقلات التي تعذّرت إعادتها وفق القواعد الحالية: $count. فُتحت اللعبة عند آخر نقلة ممكنة؛ لم تتغير لعبتك المحفوظة.';
  }

  @override
  String savedGameDefaultName(Object stamp) {
    return 'مباراة $stamp';
  }

  @override
  String get gameSaveFailed => 'تعذّر حفظ المباراة.';

  @override
  String get pauseGame => 'إيقاف مؤقت';

  @override
  String get resumeGame => 'استئناف';

  @override
  String get gamePaused => 'المباراة متوقفة مؤقتًا';

  @override
  String get chatTooLong => 'الرسالة طويلة جدًا.';

  @override
  String get aiThinking => 'الذكاء الاصطناعي يفكّر…';

  @override
  String aiDepthEval(int depth, Object eval) {
    return 'الذكاء الاصطناعي: العمق $depth، التقييم $eval';
  }

  @override
  String pliesCount(int count) {
    return '$count نقلة';
  }

  @override
  String get openLinkFailed => 'تعذّر فتح الرابط.';

  @override
  String get boardGreen => 'أخضر';

  @override
  String get boardBrown => 'بني';

  @override
  String get boardBlue => 'أزرق';

  @override
  String get boardGray => 'رمادي';

  @override
  String get animationOff => 'إيقاف';

  @override
  String animationMs(int ms) {
    return '$ms مللي ثانية';
  }

  @override
  String get checkUpdatesOnLaunch => 'التحقق من التحديثات عند التشغيل';

  @override
  String get gameOverGeneric => 'انتهت المباراة';

  @override
  String get lanIncompatibleVersion =>
      'يعمل الجهاز الآخر بإصدار مختلف من Open Chess. حدّث التطبيق على كلا الجهازين.';

  @override
  String get tooManyPendingUpdates =>
      'عدد كبير جدًا من تحديثات المباراة المعلّقة.';

  @override
  String get continueGame => 'متابعة المباراة غير المكتملة';

  @override
  String get discardGame => 'تجاهل';

  @override
  String get noMovesYet => 'لا توجد نقلات بعد';

  @override
  String get promoteTo => 'ترقية إلى';

  @override
  String get piecePawn => 'بيدق';

  @override
  String get pieceKnight => 'حصان';

  @override
  String get pieceBishop => 'فيل';

  @override
  String get pieceRook => 'قلعة';

  @override
  String get pieceQueen => 'وزير';

  @override
  String get pieceKing => 'ملك';

  @override
  String squarePieceLabel(Object square, Object color, Object piece) {
    return '$square، $piece $color';
  }

  @override
  String get staleCastlingTitle => 'حقوق تبييت قديمة';

  @override
  String get staleCastlingBody =>
      'يسمح هذا الوضع المحفوظ بالتبييت بقلعة لم تعد موجودة. هل تريد فتحه دون حقوق التبييت هذه؟ لن تتغير المباراة المحفوظة نفسها.';

  @override
  String get openAnyway => 'فتح';

  @override
  String savedFenRejected(Object error) {
    return 'لا يمكن فتح هذه المباراة المحفوظة: $error';
  }

  @override
  String analysisFailed(Object error) {
    return 'فشل التحليل. $error';
  }

  @override
  String get importGame => 'استيراد PGN / FEN';

  @override
  String get importFromClipboard => 'لصق';

  @override
  String get importFromFile => 'فتح ملف';

  @override
  String get importHint => 'الصق مباراة PGN أو وضعية FEN';

  @override
  String get importEmpty => 'لا يوجد ما يُستورد.';

  @override
  String get importTooLarge => 'النص أكبر من أن يُستورد.';

  @override
  String importTooLong(int max) {
    return 'المباراة أطول من $max نقلة.';
  }

  @override
  String importBadFen(Object error) {
    return 'وضعية غير صالحة: $error';
  }

  @override
  String importBadMove(Object move) {
    return 'نقلة غير قانونية أو غير مقروءة: $move';
  }

  @override
  String importUnsupported(Object variant) {
    return 'لا يمكن تحليل هذا النوع: $variant';
  }

  @override
  String get importReadFailed => 'تعذّرت قراءة الملف.';

  @override
  String engineFailed(Object error) {
    return 'تعذّر على المحرك تحليل هذه الوضعية: $error';
  }
}
