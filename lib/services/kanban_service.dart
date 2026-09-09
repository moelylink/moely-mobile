import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'widget_service.dart';
import 'package:flutter/services.dart';

enum KanbanState {
  idle,
  studying,
  sleeping,
  eating,
}

class KanbanService extends ChangeNotifier {
  static final KanbanService instance = KanbanService._();
  KanbanService._();

  static const MethodChannel _widgetChannel = MethodChannel('link.moely.mobile/widget');

  int _goodwill = 0;
  KanbanState _currentState = KanbanState.idle;
  int _dailyTouches = 0;
  String _lastTouchDate = '';
  String _currentBubbleText = '你好呀，今天又是美好的一天！';

  // Moe Manor properties
  int _feedStock = 200; // Default feed stock in grams
  double _growthProgress = 0.0; // 0.0 to 1.0
  int _currentBowlFeed = 0; // Current feed in bowl (0 or 100)
  int _collectedHearts = 0;
  double _collectedStars = 0.0;
  int _level = 1;
  int _exp = 0;
  String _lastClaimDate = '';
  DateTime? _eatingEndTime;
  DateTime? _stateStartTime;
  Timer? _eatingTimer;
  Duration _serverTimeOffset = Duration.zero;

  /// Get true current DateTime calibrated with cloud UTC time when available
  DateTime get nowTime => DateTime.now().add(_serverTimeOffset);

  String _currentSkin = 'capoo';
  List<String> _unlockedSkins = ['capoo', 'classic'];

  String get currentSkin => _currentSkin;
  List<String> get unlockedSkins => _unlockedSkins;

  int get goodwill => _goodwill;
  KanbanState get currentState => _currentState;
  int get dailyTouches => _dailyTouches;
  String get currentBubbleText => _currentBubbleText;

  int get feedStock => _feedStock;
  double get growthProgress => _growthProgress;
  int get currentBowlFeed => _currentBowlFeed;
  int get collectedHearts => _collectedHearts;
  double get collectedStars => double.parse(_collectedStars.toStringAsFixed(1));
  int get level => _level;
  int get exp => _exp;
  int get expToNextLevel => 100; // Fixed 100 EXP needed per level
  double get speedMultiplier => 1.0 + (_level - 1) * 0.05; // +5% speed boost per level
  DateTime? get eatingEndTime => _eatingEndTime;

  /// Check if pet is hungry (been in idle state for >= 4 hours)
  bool get isHungry => _currentState == KanbanState.idle && _stateStartTime != null && nowTime.difference(_stateStartTime!).inSeconds >= 14400;

  /// Get the emoji associated with the current state
  String get stateEmoji {
    if (isHungry) return '🥺';
    switch (_currentState) {
      case KanbanState.idle:
        return '😸';
      case KanbanState.studying:
        return '📝';
      case KanbanState.sleeping:
        return '💤';
      case KanbanState.eating:
        return '😋';
    }
  }

  /// Initialize and load settings from disk
  Future<void> init() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final dir = Directory('${supportDir.path}/settings');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File('${dir.path}/kanban_settings.json');

      if (file.existsSync()) {
        final data = jsonDecode(file.readAsStringSync());
        if (data['goodwill'] != null) {
          _goodwill = data['goodwill'] as int;
        }
        if (data['currentState'] != null) {
          _currentState = KanbanState.values[data['currentState'] as int];
        }
        if (data['dailyTouches'] != null) {
          _dailyTouches = data['dailyTouches'] as int;
        }
        if (data['lastTouchDate'] != null) {
          _lastTouchDate = data['lastTouchDate'] as String;
        }
        if (data['currentBubbleText'] != null) {
          _currentBubbleText = data['currentBubbleText'] as String;
        }
        // Moe Manor properties
        if (data['feedStock'] != null) {
          _feedStock = data['feedStock'] as int;
        }
        if (data['growthProgress'] != null) {
          _growthProgress = (data['growthProgress'] as num).toDouble();
        }
        if (data['currentBowlFeed'] != null) {
          _currentBowlFeed = data['currentBowlFeed'] as int;
        }
        if (data['collectedHearts'] != null) {
          _collectedHearts = data['collectedHearts'] as int;
        }
        if (data['collectedStars'] != null) {
          _collectedStars = (data['collectedStars'] as num).toDouble();
        }
        if (data['level'] != null) {
          _level = data['level'] as int;
        }
        if (data['exp'] != null) {
          _exp = data['exp'] as int;
        }
        if (data['lastClaimDate'] != null) {
          _lastClaimDate = data['lastClaimDate'] as String;
        }
        if (data['eatingEndTime'] != null) {
          _eatingEndTime = DateTime.tryParse(data['eatingEndTime'] as String);
        }
        if (data['stateStartTime'] != null) {
          _stateStartTime = DateTime.tryParse(data['stateStartTime'] as String);
        }
        if (data['currentSkin'] != null) {
          _currentSkin = data['currentSkin'] as String;
        }
        if (data['unlockedSkins'] != null) {
          _unlockedSkins = List<String>.from(data['unlockedSkins'] as List);
        }
      }

      // Sync cloud UTC time asynchronously
      syncCloudTime().then((_) => checkProgress());

      // Check if we need to reset daily touches
      final todayStr = nowTime.toIso8601String().substring(0, 10);
      if (_lastTouchDate != todayStr) {
        _dailyTouches = 0;
        _lastTouchDate = todayStr;
        await save();
      }

      // Run offline catch-up progress check
      checkProgress();

      // Resume eating timer if active
      if (_currentState == KanbanState.eating && _eatingEndTime != null) {
        final now = nowTime;
        if (now.isAfter(_eatingEndTime!)) {
          _completeEating();
        } else {
          final remaining = _eatingEndTime!.difference(now);
          _startEatingTimer(remaining);
        }
      }
    } catch (e) {
      debugPrint('Failed to initialize KanbanService: $e');
    }
  }

  /// Save current settings to disk
  Future<void> save() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final dir = Directory('${supportDir.path}/settings');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File('${dir.path}/kanban_settings.json');
      final data = {
        'goodwill': _goodwill,
        'currentState': _currentState.index,
        'dailyTouches': _dailyTouches,
        'lastTouchDate': _lastTouchDate,
        'currentBubbleText': _currentBubbleText,
        // Moe Manor properties
        'feedStock': _feedStock,
        'growthProgress': _growthProgress,
        'currentBowlFeed': _currentBowlFeed,
        'collectedHearts': _collectedHearts,
        'collectedStars': _collectedStars,
        'level': _level,
        'exp': _exp,
        'lastClaimDate': _lastClaimDate,
        'eatingEndTime': _eatingEndTime?.toIso8601String(),
        'stateStartTime': _stateStartTime?.toIso8601String(),
        'currentSkin': _currentSkin,
        'unlockedSkins': _unlockedSkins,
      };
      file.writeAsStringSync(jsonEncode(data));

      // Sync to Native Android SharedPreferences for Widget
      await _syncToNativeWidget();
    } catch (e) {
      debugPrint('Failed to save KanbanService settings: $e');
    }
  }

  /// Touch the mascot (pet head)
  Future<void> touchMascot() async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    if (_lastTouchDate != todayStr) {
      _dailyTouches = 0;
      _lastTouchDate = todayStr;
    }

    // Touch feedback based on state
    List<String> touchQuotes;
    String emoji;

    if (isHungry) {
      _currentBubbleText = '咕噜噜……萌哩肚子好饿呀，快给我喂点饲料吧 🥺';
      await save();
      notifyListeners();
      return;
    }
    switch (_currentState) {
      case KanbanState.idle:
        touchQuotes = [
          '唔嗯……摸摸头会变聪明吗？',
          '好舒服呀，谢谢主人~',
          '嘿嘿，最喜欢主人了！',
          '喵呜~ 贴贴！'
        ];
        emoji = '😻';
        break;
      case KanbanState.studying:
        touchQuotes = [
          '呜……正在努力看书呢，别挠我痒痒呀~',
          '嘘，等我把这页看完再陪你玩哦！',
          '呀，头发都被揉乱啦~'
        ];
        emoji = '😸';
        break;
      case KanbanState.sleeping:
        touchQuotes = [
          '唔……呼……主人，别捏我脸蛋呀……',
          'zZZ……萌哩要抱抱……',
          '哼咪……梦到吃大餐了嘛……'
        ];
        emoji = '😴';
        break;
      case KanbanState.eating:
        touchQuotes = [
          '呜头头……主人揉揉我，吃得更香了！',
          '别挠我呀，萌哩正在认真干饭呢！',
          '唔！嘴里塞满啦，没法说话啦……'
        ];
        emoji = '😋';
        break;
    }

    _currentBubbleText = (touchQuotes..shuffle()).first;

    // Increase goodwill if daily limit not reached (max 5 touches a day for goodwill boost)
    if (_dailyTouches < 5) {
      _goodwill += 10;
      _dailyTouches++;
      _currentBubbleText += '（好感度 +10）';
    }

    await save();
    notifyListeners();
  }

  /// Talk to the mascot
  Future<void> talkToMascot() async {
    List<String> quotes;
    switch (_currentState) {
      case KanbanState.idle:
        quotes = [
          '今天天气真好，我们出去散散步吧！',
          '主人今天有什么计划吗？都要加油哦！',
          '萌哩一直都会在这里陪着你的。',
          '最近有没有看到精美的插图呢？'
        ];
        break;
      case KanbanState.studying:
        quotes = [
          '好记性不如烂笔头，主人也要一起加油呀！',
          '书中自有黄金屋，古人诚不欺我！',
          '萌哩在看很深奥的书哦，快来夸夸我！'
        ];
        break;
      case KanbanState.sleeping:
        quotes = [
          '呼局局……呼局局……',
          '晚安，做个甜甜的好梦吧~',
          '唔……好像听到主人叫我了……'
        ];
        break;
      case KanbanState.eating:
        quotes = [
          '嚼嚼嚼……这饲料真美味！',
          '主人，你要尝尝萌哩的口粮吗？',
          '干饭人，干饭魂，吃饱了才有力气陪伴！'
        ];
        break;
    }

    _currentBubbleText = (quotes..shuffle()).first;
    await save();
    notifyListeners();
  }

  /// Fetch cloud UTC time with multi-source fallback (Moely Official -> NTP Date header)
  Future<void> syncCloudTime() async {
    final sources = [
      'https://www.moely.link/',
      'https://www.baidu.com/',
    ];

    for (final urlStr in sources) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 2);
        final request = await client.headUrl(Uri.parse(urlStr));
        final response = await request.close();
        final dateHeader = response.headers.value(HttpHeaders.dateHeader);
        client.close();
        if (dateHeader != null) {
          final serverUtc = HttpDate.parse(dateHeader).toUtc();
          final localUtc = DateTime.now().toUtc();
          _serverTimeOffset = serverUtc.difference(localUtc);
          debugPrint('Cloud UTC time calibrated via $urlStr! Offset: ${_serverTimeOffset.inSeconds}s');
          return;
        }
      } catch (e) {
        debugPrint('Cloud time sync failed for $urlStr: $e');
      }
    }
  }

  /// Periodically check state progress (offline catch-up and real-time star generation)
  void checkProgress() {
    final now = nowTime;
    _stateStartTime ??= now;

    // Time rollback protection: recalibrate if system clock was moved backward
    if (now.isBefore(_stateStartTime!)) {
      _stateStartTime = now;
      return;
    }

    // Cap single offline catch-up duration to max 24 hours (86400 seconds)
    final elapsedSeconds = math.min(now.difference(_stateStartTime!).inSeconds, 86400);
    if (elapsedSeconds <= 0) return;

    bool stateChanged = false;

    if (_currentState == KanbanState.studying) {
      // Base: Every 2 hours (7200s) consumes 50g feed to yield 1 star ⭐ (speed boosted by level)
      // Each 0.1 star step takes (720 / speedMultiplier) seconds and consumes 5g feed
      final double stepSeconds = 720 / speedMultiplier;
      final int completedSteps = (elapsedSeconds / stepSeconds).floor();

      if (completedSteps > 0) {
        int maxStepsByFeed = _feedStock ~/ 5;
        int actualSteps = completedSteps < maxStepsByFeed ? completedSteps : maxStepsByFeed;

        if (actualSteps > 0) {
          _feedStock -= actualSteps * 5;
          _collectedStars += actualSteps * 0.1;
          _collectedStars = double.parse(_collectedStars.toStringAsFixed(1));
          _stateStartTime = _stateStartTime!.add(Duration(seconds: (actualSteps * stepSeconds).round()));
          final earnedStars = (actualSteps * 0.1).toStringAsFixed(1);
          _currentBubbleText = '萌哩正在刻苦学习，收获了 $earnedStars 颗星星 ⭐！';
          stateChanged = true;
        }

        // If feed is less than 5g, revert to idle
        if (_feedStock < 5) {
          _currentState = KanbanState.idle;
          _currentBubbleText = '饲料不足 5g，萌哩暂停了学习模式~';
          _stateStartTime = now;
          stateChanged = true;
        }
      }
    } else if (_currentState == KanbanState.sleeping) {
      // Base: Every 6 hours (21600s) yields 1 star ⭐ (no feed consumed)
      // Each 0.1 star step takes (2160 / speedMultiplier) seconds
      final double stepSeconds = 2160 / speedMultiplier;
      final int completedSteps = (elapsedSeconds / stepSeconds).floor();

      if (completedSteps > 0) {
        _collectedStars += completedSteps * 0.1;
        _collectedStars = double.parse(_collectedStars.toStringAsFixed(1));
        _stateStartTime = _stateStartTime!.add(Duration(seconds: (completedSteps * stepSeconds).round()));
        final earnedStars = (completedSteps * 0.1).toStringAsFixed(1);
        _currentBubbleText = '萌哩在美梦中收获了 $earnedStars 颗星星 ⭐！';
        stateChanged = true;
      }
    } else if (_currentState == KanbanState.eating) {
      if (_eatingEndTime != null && now.isAfter(_eatingEndTime!)) {
        _completeEating();
        stateChanged = true;
      }
    } else if (_currentState == KanbanState.idle && isHungry) {
      if (!_currentBubbleText.contains('肚子好饿')) {
        _currentBubbleText = '咕噜噜……萌哩玩耍了 4 个小时，肚子好饿呀！快给我喂点饲料吧 🥺';
        stateChanged = true;
      }
    }

    if (stateChanged) {
      save();
      notifyListeners();
    }
  }

  /// Change the current state of the mascot
  Future<void> updateState(KanbanState newState) async {
    checkProgress();
    if (_currentState == newState) return;

    if (_currentState == KanbanState.eating) {
      _currentBubbleText = '萌哩正在努力干饭，等吃完再做别的事吧！';
      notifyListeners();
      return;
    }

    if (newState == KanbanState.studying && _feedStock < 5) {
      _currentBubbleText = '饲料不足 5g，无法开启学习模式哦！快去完成任务领饲料吧~';
      notifyListeners();
      return;
    }

    _currentState = newState;
    _stateStartTime = nowTime;

    switch (newState) {
      case KanbanState.idle:
        _currentBubbleText = '萌哩休息好啦，主人有什么吩咐？';
        break;
      case KanbanState.studying:
        final double hoursNeeded = (2.0 / speedMultiplier);
        _currentBubbleText = '萌哩开启学习模式！每 ${hoursNeeded.toStringAsFixed(1)} 小时消耗 50g 饲料获得 1 颗星星 ⭐！';
        break;
      case KanbanState.sleeping:
        final double hoursNeeded = (6.0 / speedMultiplier);
        _currentBubbleText = '萌哩准备睡觉觉啦！每 ${hoursNeeded.toStringAsFixed(1)} 小时自动获得 1 颗星星 ⭐，晚安~';
        break;
      case KanbanState.eating:
        _currentBubbleText = '开饭啦！嚼嚼嚼……';
        break;
    }

    await save();
    notifyListeners();
  }

  // --- Moe Manor Game Actions ---

  bool get canClaimDailyFeed {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    return _lastClaimDate != todayStr;
  }

  /// Claim daily check-in feed
  Future<bool> claimDailyFeed() async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    if (_lastClaimDate == todayStr) {
      return false;
    }
    _feedStock += 100;
    _lastClaimDate = todayStr;
    _currentBubbleText = '签到成功！领取了 100g 优质饲料。';
    await save();
    notifyListeners();
    return true;
  }

  /// Feed the mascot (100g feed takes 1 hour to eat)
  Future<bool> feedMascot() async {
    checkProgress();
    if (_currentState == KanbanState.eating) {
      _currentBubbleText = '萌哩正在干饭中，等吃完再喂吧~';
      notifyListeners();
      return false;
    }
    if (_feedStock < 100) {
      _currentBubbleText = '啊咧，家里的饲料不够了……快去完成任务获取吧！';
      notifyListeners();
      return false;
    }

    _feedStock -= 100;
    _currentBowlFeed = 100;
    _currentState = KanbanState.eating;
    final duration = const Duration(hours: 1); // 1 hour eating duration
    _eatingEndTime = nowTime.add(duration);
    _stateStartTime = nowTime;
    _currentBubbleText = '大口大口吃饲料中……预计要吃 1 小时哦，嚼嚼嚼！';

    _startEatingTimer(duration);
    await save();
    notifyListeners();
    return true;
  }

  /// Earn feed from actions (e.g., downloading wallpaper)
  Future<void> earnFeed(int amount, String reason) async {
    _feedStock += amount;
    _currentBubbleText = '完成任务【$reason】：收获了 ${amount}g 饲料！';
    await save();
    notifyListeners();
  }

  void _startEatingTimer(Duration duration) {
    _eatingTimer?.cancel();
    _eatingTimer = Timer(duration, () {
      _completeEating();
    });
  }

  void _completeEating() {
    _currentState = KanbanState.idle;
    _currentBowlFeed = 0;
    _eatingEndTime = null;
    _stateStartTime = nowTime;

    // Add EXP and growth progress
    _exp += 10; // 100g feed yields 10 EXP
    _growthProgress += 0.2;
    if (_growthProgress >= 1.0) {
      _growthProgress = 0.0;
      _collectedHearts += 1;
    }

    _checkLevelUp();
    save();
    notifyListeners();
  }

  void _checkLevelUp() {
    bool leveledUp = false;
    while (_exp >= expToNextLevel) {
      _exp -= expToNextLevel;
      _level++;
      leveledUp = true;
    }
    if (leveledUp) {
      _currentBubbleText = '🎉 萌哩升级啦！升级到 LV $_level！学习/工作速度提升至 ${((speedMultiplier - 1.0) * 100).toInt()}%！';
    } else {
      _currentBubbleText = '呼，吃饱啦！经验值 +10，当前 LV $_level ($_exp/100)';
    }
  }

  /// Reset goodwill & stats (for debugging)
  Future<void> resetGoodwill() async {
    _goodwill = 0;
    _dailyTouches = 0;
    _feedStock = 200;
    _growthProgress = 0.0;
    _currentBowlFeed = 0;
    _collectedHearts = 0;
    _collectedStars = 0.0;
    _level = 1;
    _exp = 0;
    _lastClaimDate = '';
    _eatingEndTime = null;
    _stateStartTime = DateTime.now();
    _eatingTimer?.cancel();
    _currentState = KanbanState.idle;
    _currentSkin = 'capoo';
    _unlockedSkins = ['capoo', 'classic'];
    await save();
    notifyListeners();
  }

  /// Buy feed with goodwill points
  Future<bool> buyFeedWithGoodwill(int cost, int amount) async {
    if (_goodwill < cost) {
      _currentBubbleText = '亲密度不足，无法兑换饲料噢~';
      notifyListeners();
      return false;
    }
    _goodwill -= cost;
    _feedStock += amount;
    _currentBubbleText = '成功消耗 $cost 亲密度兑换了 ${amount}g 饲料！';
    await save();
    notifyListeners();
    return true;
  }

  /// Buy feed with love hearts
  Future<bool> buyFeedWithHearts(int cost, int amount) async {
    if (_collectedHearts < cost) {
      _currentBubbleText = '爱心不足，无法兑换饲料噢~';
      notifyListeners();
      return false;
    }
    _collectedHearts -= cost;
    _feedStock += amount;
    _currentBubbleText = '成功消耗 $cost 颗爱心兑换了 ${amount}g 饲料！';
    await save();
    notifyListeners();
    return true;
  }

  /// Unlock a new skin with hearts or stars
  Future<bool> unlockSkin(String skinId, num cost, {bool useStars = false}) async {
    if (_unlockedSkins.contains(skinId)) {
      return true; // Already unlocked
    }
    if (useStars) {
      if (_collectedStars < cost) {
        _currentBubbleText = '星星不足 $cost 颗，无法解锁新装扮噢~';
        notifyListeners();
        return false;
      }
      _collectedStars -= cost.toDouble();
      _collectedStars = double.parse(_collectedStars.toStringAsFixed(1));
    } else {
      if (_collectedHearts < cost) {
        _currentBubbleText = '爱心不足 $cost 颗，无法解锁新装扮噢~';
        notifyListeners();
        return false;
      }
      _collectedHearts -= cost.toInt();
    }
    _unlockedSkins.add(skinId);
    _currentBubbleText = '解锁成功！快给萌哩换上新装扮吧！';
    await save();
    notifyListeners();
    return true;
  }

  /// Select current active skin
  Future<bool> selectSkin(String skinId) async {
    if (!_unlockedSkins.contains(skinId)) {
      return false;
    }
    _currentSkin = skinId;
    _currentBubbleText = '换装成功！你看我好看吗？';
    await save();
    notifyListeners();
    return true;
  }

  /// Sync the current state text and emoji to native Android widget
  Future<void> _syncToNativeWidget() async {
    if (!WidgetService.isPlatformAndroid) return;
    try {
      await _widgetChannel.invokeMethod('updatePetStatus', {
        'emoji': stateEmoji,
        'bubbleText': _currentBubbleText,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to sync pet status to native widget: ${e.message}');
    }
  }

  @override
  void dispose() {
    _eatingTimer?.cancel();
    super.dispose();
  }
}

