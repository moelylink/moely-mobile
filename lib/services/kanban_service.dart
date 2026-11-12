import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widget_service.dart';
import 'auth_service.dart';
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
  final SupabaseClient _supabase = Supabase.instance.client;

  KanbanState _currentState = KanbanState.idle;
  int _dailyTouches = 0;
  int _dailyTouchExp = 0;
  String _lastTouchDate = '';
  String _currentBubbleText = '你好呀，今天又是美好的一天！';

  // Moe Manor properties
  int _feedStock = 200; // Default starter feed
  int _currentBowlFeed = 0; // Current feed in bowl (0, 100, or 200)
  int _speedCardCount = 0; // Speed-up cards in bag
  int _doubleFeedCardCount = 0; // Double-feed cards in bag
  double _collectedStars = 0.0;
  int _level = 1;
  int _exp = 0;
  String _lastClaimDate = '';
  DateTime? _eatingEndTime;
  DateTime? _stateStartTime;
  Timer? _eatingTimer;
  Duration _serverTimeOffset = Duration.zero;
  bool _isSyncingWithCloud = false;

  /// Get true current DateTime calibrated with cloud UTC time when available
  DateTime get nowTime => DateTime.now().add(_serverTimeOffset);

  String _currentSkin = 'capoo';
  List<String> _unlockedSkins = ['capoo', 'siamese', 'salary'];

  String get currentSkin => _currentSkin;
  List<String> get unlockedSkins => _unlockedSkins;

  KanbanState get currentState => _currentState;
  int get dailyTouches => _dailyTouches;
  int get dailyTouchExp => _dailyTouchExp;
  String get currentBubbleText => _currentBubbleText;

  int get feedStock => _feedStock;
  int get currentBowlFeed => _currentBowlFeed;
  int get speedCardCount => _speedCardCount;
  int get doubleFeedCardCount => _doubleFeedCardCount;
  double get collectedStars => double.parse(_collectedStars.toStringAsFixed(1));
  int get level => _level;
  int get exp => _exp;
  int get expToNextLevel => 100; // Fixed 100 EXP needed per level
  double get speedMultiplier => 1.0 + (_level - 1) * 0.05; // +5% speed boost per level
  DateTime? get eatingEndTime => _eatingEndTime;

  /// Check if pet is hungry (been in idle state for >= 4 hours)
  bool get isHungry => _currentState == KanbanState.idle && _stateStartTime != null && nowTime.difference(_stateStartTime!).inSeconds >= 14400;

  static const int sleepStartHour = 20; // 晚上 20:00 (8:00 PM) 开放入睡
  static const int sleepEndHour = 6;    // 早上 06:00 (6:00 AM) 自动醒来

  /// 检查当前是否在允许睡觉的时间段（晚上 20:00 ~ 早上 06:00）
  bool get isSleepTime => isHourInSleepWindow(nowTime.hour);

  static bool isHourInSleepWindow(int hour) {
    return hour >= sleepStartHour || hour < sleepEndHour;
  }

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
        if (data['currentState'] != null) {
          _currentState = KanbanState.values[data['currentState'] as int];
        }
        if (data['dailyTouches'] != null) {
          _dailyTouches = data['dailyTouches'] as int;
        }
        if (data['dailyTouchExp'] != null) {
          _dailyTouchExp = data['dailyTouchExp'] as int;
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
        if (data['currentBowlFeed'] != null) {
          _currentBowlFeed = data['currentBowlFeed'] as int;
        }
        if (data['speedCardCount'] != null) {
          _speedCardCount = data['speedCardCount'] as int;
        }
        if (data['doubleFeedCardCount'] != null) {
          _doubleFeedCardCount = data['doubleFeedCardCount'] as int;
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
          final loadedSkin = data['currentSkin'] as String;
          _currentSkin = ['capoo', 'siamese', 'salary'].contains(loadedSkin) ? loadedSkin : 'capoo';
        }
        if (data['unlockedSkins'] != null) {
          final loadedSkins = (data['unlockedSkins'] as List<dynamic>).map((e) => e.toString()).toList();
          _unlockedSkins = loadedSkins.isNotEmpty ? loadedSkins : ['capoo'];
        }
      }

      // Sync cloud UTC time asynchronously
      syncCloudTime().then((_) => checkProgress());

      // Check if we need to reset daily touches
      final todayStr = nowTime.toIso8601String().substring(0, 10);
      if (_lastTouchDate != todayStr) {
        _dailyTouches = 0;
        _dailyTouchExp = 0;
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

      // Auto sync from cloud if logged in, and listen to future login changes
      if (AuthService.instance.isLoggedIn) {
        pullFromCloud();
      }
      AuthService.instance.addListener(_onAuthStatusChanged);
      notifyListeners();
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
        'currentState': _currentState.index,
        'dailyTouches': _dailyTouches,
        'dailyTouchExp': _dailyTouchExp,
        'lastTouchDate': _lastTouchDate,
        'currentBubbleText': _currentBubbleText,
        // Moe Manor properties
        'feedStock': _feedStock,
        'currentBowlFeed': _currentBowlFeed,
        'speedCardCount': _speedCardCount,
        'doubleFeedCardCount': _doubleFeedCardCount,
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
    final todayStr = nowTime.toIso8601String().substring(0, 10);
    if (_lastTouchDate != todayStr) {
      _dailyTouches = 0;
      _dailyTouchExp = 0;
      _lastTouchDate = todayStr;
    }

    // Touch feedback based on state
    List<String> touchQuotes;

    if (isHungry) {
      _currentBubbleText = '咕噜噜……萌哩肚子好饿呀，快给我喂点饲料吧~';
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
        break;
      case KanbanState.studying:
        touchQuotes = [
          '呜……正在努力看书呢，别挠我痒痒呀~',
          '嘘，等我把这页看完再陪你玩哦！',
          '呀，头发都被揉乱啦~'
        ];
        break;
      case KanbanState.sleeping:
        touchQuotes = [
          '唔……呼……主人，别捏我脸蛋呀……',
          'zZZ……萌哩要抱抱……',
          '哼咪……梦到吃大餐了嘛……'
        ];
        break;
      case KanbanState.eating:
        touchQuotes = [
          '呜头头……主人揉揉我，吃得更香了！',
          '别挠我呀，萌哩正在认真干饭呢！',
          '唔！嘴里塞满啦，没法说话啦……'
        ];
        break;
    }

    _currentBubbleText = (touchQuotes..shuffle()).first;

    _dailyTouches++;

    // 测试模式：每次摸头均可获得经验，便于测试升级成长逻辑
    final randomExp = math.Random().nextInt(2) + 1;
    _dailyTouchExp += randomExp;
    _exp += randomExp;

    _checkLevelUp();
    if (!_currentBubbleText.startsWith('萌哩升级啦')) {
      _currentBubbleText += '（成长值 +$randomExp，摸头总计经验 $_dailyTouchExp）';
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
      DateTime sleepEndTime = now;
      bool shouldWakeUp = false;

      // 检查当前是否已过早晨醒来时间（即不在睡眠时间窗口内）
      if (!isSleepTime) {
        shouldWakeUp = true;
        // 计算早晨自动醒来的具体时间点 (当天 06:00)
        final morningWakeUp = DateTime(now.year, now.month, now.day, sleepEndHour);
        if (_stateStartTime!.isBefore(morningWakeUp) && now.isAfter(morningWakeUp)) {
          sleepEndTime = morningWakeUp;
        }
      }

      final sleepDuration = math.min(sleepEndTime.difference(_stateStartTime!).inSeconds, 86400);
      if (sleepDuration > 0) {
        final double stepSeconds = 2160 / speedMultiplier;
        final int completedSteps = (sleepDuration / stepSeconds).floor();

        if (completedSteps > 0) {
          _collectedStars += completedSteps * 0.1;
          _collectedStars = double.parse(_collectedStars.toStringAsFixed(1));
          _stateStartTime = _stateStartTime!.add(Duration(seconds: (completedSteps * stepSeconds).round()));
          final earnedStars = (completedSteps * 0.1).toStringAsFixed(1);
          _currentBubbleText = '萌哩在美梦中收获了 $earnedStars 颗星星 ⭐！';
          stateChanged = true;
        }
      }

      if (shouldWakeUp) {
        _currentState = KanbanState.idle;
        _stateStartTime = sleepEndTime;
        _currentBubbleText = '早上好呀！天亮啦，萌哩伸个懒腰醒来啦~';
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
  Future<bool> updateState(KanbanState newState) async {
    checkProgress();
    if (_currentState == newState) return true;

    if (_currentState == KanbanState.eating) {
      _currentBubbleText = '萌哩正在努力干饭，等吃完再做别的事吧！';
      notifyListeners();
      return false;
    }

    if (newState == KanbanState.studying && _feedStock < 5) {
      _currentBubbleText = '饲料不足 5g，无法开启学习模式哦！快去完成任务领饲料吧~';
      notifyListeners();
      return false;
    }

    if (newState == KanbanState.sleeping && !isSleepTime) {
      _currentBubbleText = '现在还是白天呢，萌哩还不困哦~（晚上 20:00 后才开放睡觉）';
      notifyListeners();
      return false;
    }

    _currentState = newState;
    _stateStartTime = nowTime;

    switch (newState) {
      case KanbanState.idle:
        _currentBubbleText = '萌哩来到客厅休息玩耍啦，主人有什么吩咐？';
        break;
      case KanbanState.studying:
        final double hoursNeeded = (2.0 / speedMultiplier);
        _currentBubbleText = '萌哩去书桌学习啦！每 ${hoursNeeded.toStringAsFixed(1)} 小时消耗 50g 饲料获得 1 颗星星 ⭐！';
        break;
      case KanbanState.sleeping:
        final double hoursNeeded = (6.0 / speedMultiplier);
        _currentBubbleText = '萌哩去床上睡觉觉啦！每 ${hoursNeeded.toStringAsFixed(1)} 小时自动获得 1 颗星星 ⭐，晚安~';
        break;
      case KanbanState.eating:
        _currentBubbleText = '开饭啦！嚼嚼嚼……';
        break;
    }

    await save();
    notifyListeners();
    return true;
  }

  // --- Moe Manor Game Actions ---

  bool get canClaimDailyFeed => _lastClaimDate != nowTime.toIso8601String().substring(0, 10);

  /// Claim daily check-in feed with instant cloud sync
  Future<bool> claimDailyFeed() async {
    final todayStr = nowTime.toIso8601String().substring(0, 10);
    if (!canClaimDailyFeed) {
      _currentBubbleText = '今天已经签到过了，明天再来吧~';
      notifyListeners();
      return false;
    }
    _feedStock += 100;
    _lastClaimDate = todayStr;
    _currentBubbleText = '签到成功！领取了 100g 优质饲料。';
    await save();
    notifyListeners();

    // Instant sync to cloud
    _syncClaimToCloud(todayStr);
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
    final wasDoubleFeed = _currentBowlFeed >= 200;
    _currentState = KanbanState.idle;
    _currentBowlFeed = 0;
    _eatingEndTime = null;
    _stateStartTime = nowTime;

    // Add EXP (100g feed yields 10 EXP, 200g double-feed yields 20 EXP)
    final expReward = wasDoubleFeed ? 20 : 10;
    _exp += expReward;

    _checkLevelUp();
    if (_currentState == KanbanState.idle && !_currentBubbleText.contains('升级啦')) {
      _currentBubbleText = wasDoubleFeed
          ? '呼，双倍大餐吃得太满足啦！经验值 +20，当前 LV $_level ($_exp/100)'
          : '呼，吃饱啦！经验值 +10，当前 LV $_level ($_exp/100)';
    }
    save();
    notifyListeners();
  }

  /// 使用加速卡，立即完成 1 小时的事情（干饭、学习或睡觉）
  Future<bool> useSpeedCard() async {
    checkProgress();
    if (_speedCardCount <= 0) {
      _currentBubbleText = '背包里没有加速卡啦，快去商店兑换吧！';
      notifyListeners();
      return false;
    }

    if (_currentState == KanbanState.idle) {
      _currentBubbleText = '萌哩当前正在闲逛休息，没有进行中的活动，快带它去干饭、学习或睡觉再加速吧~';
      notifyListeners();
      return false;
    }

    _speedCardCount--;

    if (_currentState == KanbanState.eating) {
      if (_eatingEndTime != null) {
        final remaining = _eatingEndTime!.difference(nowTime);
        if (remaining.inSeconds <= 3600) {
          // 剩余时间不超过1小时，直接干饭完成！
          _eatingTimer?.cancel();
          _completeEating();
          _currentBubbleText = '使用了加速卡！萌哩瞬间吃完了美味大餐，成长值飙升！';
        } else {
          // 减少1小时
          _eatingEndTime = _eatingEndTime!.subtract(const Duration(hours: 1));
          final newRemaining = _eatingEndTime!.difference(nowTime);
          _startEatingTimer(newRemaining);
          final leftMinutes = newRemaining.inMinutes;
          _currentBubbleText = '使用了加速卡！干饭时间缩短了 1 小时，还剩 $leftMinutes 分钟吃完！';
        }
      }
    } else if (_currentState == KanbanState.studying) {
      // 学习加速 1 小时
      _stateStartTime = (_stateStartTime ?? nowTime).subtract(const Duration(hours: 1));
      checkProgress();
      _currentBubbleText = '使用了加速卡！刻苦攻读推进了 1 个小时，学业大丰收！';
    } else if (_currentState == KanbanState.sleeping) {
      // 睡觉加速 1 小时
      _stateStartTime = (_stateStartTime ?? nowTime).subtract(const Duration(hours: 1));
      checkProgress();
      _currentBubbleText = '使用了加速卡！萌哩在甜美梦乡中睡足了 1 小时，精力充沛！';
    }

    await save();
    notifyListeners();
    return true;
  }

  /// 使用加饭卡，在饭碗里面放两倍饲料 (200g)
  Future<bool> useDoubleFeedCard() async {
    checkProgress();
    if (_doubleFeedCardCount <= 0) {
      _currentBubbleText = '背包里没有加饭卡啦，快去商店兑换吧！';
      notifyListeners();
      return false;
    }

    if (_currentState == KanbanState.idle) {
      if (_feedStock < 200) {
        _currentBubbleText = '家里的饲料不足 200g，无法倒入双倍饲料哦，快去赚饲料吧！';
        notifyListeners();
        return false;
      }
      _doubleFeedCardCount--;
      _feedStock -= 200;
      _currentBowlFeed = 200;
      _currentState = KanbanState.eating;
      final duration = const Duration(hours: 2); // 2 小时干饭
      _eatingEndTime = nowTime.add(duration);
      _stateStartTime = nowTime;
      _currentBubbleText = '使用了加饭卡！饭碗装了 200g 双倍大餐，预计吃 2 小时，吃完经验翻倍！';
      _startEatingTimer(duration);
      await save();
      notifyListeners();
      return true;
    } else if (_currentState == KanbanState.eating) {
      if (_currentBowlFeed >= 200) {
        _currentBubbleText = '饭碗里已经是 200g 双倍大餐啦，萌哩吃得超级香呢！';
        notifyListeners();
        return false;
      }
      // 当前是 100g 状态，给饭碗加饭追加至 200g！
      if (_feedStock < 100) {
        _currentBubbleText = '饲料库存不足 100g，无法追加双倍饲料哦！';
        notifyListeners();
        return false;
      }
      _doubleFeedCardCount--;
      _feedStock -= 100;
      _currentBowlFeed = 200;
      _eatingEndTime = (_eatingEndTime ?? nowTime).add(const Duration(hours: 1));
      final remaining = _eatingEndTime!.difference(nowTime);
      _startEatingTimer(remaining);
      _currentBubbleText = '使用了加饭卡！向饭碗追加了 100g 饲料，升级为 200g 双倍大餐！';
      await save();
      notifyListeners();
      return true;
    } else {
      _currentBubbleText = '萌哩正在忙别的事情，等回到空闲或干饭时再使用加饭卡吧~';
      notifyListeners();
      return false;
    }
  }

  void _checkLevelUp() {
    bool leveledUp = false;
    while (_exp >= expToNextLevel) {
      _exp -= expToNextLevel;
      _level++;
      leveledUp = true;
    }
    if (leveledUp) {
      _currentBubbleText = '萌哩升级啦！升级到 LV $_level！学习/工作速度提升至 ${((speedMultiplier - 1.0) * 100).toInt()}%！';
    } else if (_currentState == KanbanState.eating) {
      _currentBubbleText = '呼，吃饱啦！当前 LV $_level ($_exp/100)';
    }
  }

  /// Reset manor & stats (for debugging)
  Future<void> resetManor() async {
    _dailyTouches = 0;
    _dailyTouchExp = 0;
    _feedStock = 99999;
    _currentBowlFeed = 0;
    _speedCardCount = 99;
    _doubleFeedCardCount = 99;
    _collectedStars = 9999.0;
    _level = 1;
    _exp = 0;
    _lastClaimDate = '';
    _eatingEndTime = null;
    _stateStartTime = DateTime.now();
    _eatingTimer?.cancel();
    _currentState = KanbanState.idle;
    _currentSkin = 'capoo';
    _unlockedSkins = ['capoo', 'siamese', 'salary'];
    await save();
    notifyListeners();
  }

  /// Buy speed card with stars
  Future<bool> buySpeedCardWithStars(double starsCost, int count) async {
    if (_collectedStars < starsCost) {
      _currentBubbleText = '星星不足，无法兑换加速卡噢~';
      notifyListeners();
      return false;
    }
    _collectedStars -= starsCost;
    _collectedStars = double.parse(_collectedStars.toStringAsFixed(1));
    _speedCardCount += count;
    _currentBubbleText = '成功消耗 ${starsCost.toStringAsFixed(1)} 颗星星兑换了 $count 张加速卡！';
    await save();
    notifyListeners();
    _syncShopPurchaseToCloud();
    return true;
  }

  /// Buy double-feed card with stars
  Future<bool> buyDoubleFeedCardWithStars(double starsCost, int count) async {
    if (_collectedStars < starsCost) {
      _currentBubbleText = '星星不足，无法兑换加饭卡噢~';
      notifyListeners();
      return false;
    }
    _collectedStars -= starsCost;
    _collectedStars = double.parse(_collectedStars.toStringAsFixed(1));
    _doubleFeedCardCount += count;
    _currentBubbleText = '成功消耗 ${starsCost.toStringAsFixed(1)} 颗星星兑换了 $count 张加饭卡！';
    await save();
    notifyListeners();
    _syncShopPurchaseToCloud();
    return true;
  }

  /// Buy feed with collected stars
  Future<bool> buyFeedWithStars(double starsCost, int amount) async {
    if (_collectedStars < starsCost) {
      _currentBubbleText = '星星不足，无法兑换饲料噢~';
      notifyListeners();
      return false;
    }
    _collectedStars -= starsCost;
    _collectedStars = double.parse(_collectedStars.toStringAsFixed(1));
    _feedStock += amount;
    _currentBubbleText = '成功消耗 ${starsCost.toStringAsFixed(1)} 颗星星兑换了 ${amount}g 饲料！';
    await save();
    notifyListeners();
    _syncShopPurchaseToCloud();
    return true;
  }

  /// Unlock a new skin with stars
  Future<bool> unlockSkin(String skinId, double starsCost) async {
    if (_unlockedSkins.contains(skinId)) {
      return true; // Already unlocked
    }
    if (_collectedStars < starsCost) {
      _currentBubbleText = '星星不足 ${starsCost.toStringAsFixed(1)} 颗，无法解锁新装扮噢~';
      notifyListeners();
      return false;
    }
    _collectedStars -= starsCost;
    _collectedStars = double.parse(_collectedStars.toStringAsFixed(1));
    _unlockedSkins.add(skinId);
    _currentBubbleText = '解锁成功！快给萌哩换上新装扮吧！';
    await save();
    notifyListeners();
    _syncUnlockSkinToCloud(skinId);
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
    _syncSelectSkinToCloud(skinId);
    return true;
  }

  /// 趣味大转盘 8 种奖品定义
  static const List<Map<String, dynamic>> wheelPrizes = [
    {'id': 'thanks', 'name': '谢谢惠顾', 'weight': 10},
    {'id': 'feed_50', 'name': '50g饲料', 'weight': 20, 'feed': 50},
    {'id': 'feed_100', 'name': '100g饲料', 'weight': 15, 'feed': 100},
    {'id': 'feed_150', 'name': '150g饲料', 'weight': 15, 'feed': 150},
    {'id': 'feed_200', 'name': '200g饲料', 'weight': 10, 'feed': 200},
    {'id': 'star_1', 'name': '星星*1', 'weight': 10, 'star': 1.0},
    {'id': 'card_speed', 'name': '加速卡', 'weight': 10, 'speedCard': 1},
    {'id': 'card_double', 'name': '加饭卡', 'weight': 10, 'doubleCard': 1},
  ];

  /// 趣味大转盘抽奖：每次消耗 100g 饲料并计算抽取结果（转盘转动结束前暂不下发奖品）
  Future<Map<String, dynamic>?> spinLuckyWheel() async {
    if (_feedStock < 100) {
      _currentBubbleText = '饲料不足 100g，无法参与转盘抽奖噢~';
      notifyListeners();
      return null;
    }

    _feedStock -= 100;
    await save();
    notifyListeners();

    // 根据权重随机抽取
    final totalWeight = wheelPrizes.fold<int>(0, (sum, p) => sum + (p['weight'] as int));
    final randomVal = math.Random().nextInt(totalWeight);
    int currentSum = 0;
    int targetIndex = 0;

    for (int i = 0; i < wheelPrizes.length; i++) {
      currentSum += wheelPrizes[i]['weight'] as int;
      if (randomVal < currentSum) {
        targetIndex = i;
        break;
      }
    }

    final prize = wheelPrizes[targetIndex];

    return {
      'index': targetIndex,
      'prize': prize,
    };
  }

  /// 转盘停止转动后，正式下发抽奖奖励与更新气泡
  Future<void> claimWheelPrize(Map<String, dynamic> prize) async {
    switch (prize['id']) {
      case 'thanks':
        _currentBubbleText = '差一点点就中大奖啦，下次一定会更幸运的~';
        break;
      case 'feed_50':
        _feedStock += 50;
        _currentBubbleText = '恭喜抽中了 50g 饲料！';
        break;
      case 'feed_100':
        _feedStock += 100;
        _currentBubbleText = '恭喜抽中了 100g 饲料，本轮免费！';
        break;
      case 'feed_150':
        _feedStock += 150;
        _currentBubbleText = '太棒啦！抽中了 150g 丰厚饲料！';
        break;
      case 'feed_200':
        _feedStock += 200;
        _currentBubbleText = '大吉大利！抽中了 200g 超级饲料大礼包！';
        break;
      case 'star_1':
        _collectedStars += 1.0;
        _collectedStars = double.parse(_collectedStars.toStringAsFixed(1));
        _currentBubbleText = '金光闪闪！抽中了 1 颗珍贵的庄园星星！';
        break;
      case 'card_speed':
        _speedCardCount += 1;
        _currentBubbleText = '好运连连！抽中了 1 张时光加速卡！';
        break;
      case 'card_double':
        _doubleFeedCardCount += 1;
        _currentBubbleText = '欧气满满！抽中了 1 张超级加饭卡！';
        break;
    }

    await save();
    notifyListeners();
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

  // --- Cloud Sync Implementations (Hybrid Cloud-Save) ---

  void _onAuthStatusChanged() {
    if (AuthService.instance.isLoggedIn) {
      pullFromCloud();
    }
  }

  /// Pull manor data from Supabase and safely merge with local cache
  Future<void> pullFromCloud() async {
    if (_isSyncingWithCloud) return;
    final userId = AuthService.instance.userId;
    if (userId.isEmpty) return;

    _isSyncingWithCloud = true;
    try {
      final response = await _supabase
          .from('user_manor')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Cloud record doesn't exist yet: initialize it with current local baseline
        await _supabase.from('user_manor').insert({
          'user_id': userId,
          'collected_stars': _collectedStars,
          'feed_stock': _feedStock,
          'speed_card_count': _speedCardCount,
          'double_feed_card_count': _doubleFeedCardCount,
          'level': _level,
          'exp': _exp,
          'current_skin': _currentSkin,
          'unlocked_skins': _unlockedSkins,
          'last_claim_date': _lastClaimDate,
        });
        debugPrint('[KanbanService] Initialized user_manor cloud record for $userId');
      } else {
        // Merge cloud data safely
        final cloudStars = (response['collected_stars'] as num?)?.toDouble() ?? 0.0;
        final cloudFeed = (response['feed_stock'] as int?) ?? 200;
        final cloudSpeedCards = (response['speed_card_count'] as int?) ?? 0;
        final cloudDoubleCards = (response['double_feed_card_count'] as int?) ?? 0;
        final cloudLevel = (response['level'] as int?) ?? 1;
        final cloudExp = (response['exp'] as int?) ?? 0;
        final cloudSkin = (response['current_skin'] as String?) ?? 'capoo';
        final cloudClaimDate = (response['last_claim_date'] as String?) ?? '';
        
        List<String> cloudUnlockedSkins = ['capoo'];
        if (response['unlocked_skins'] != null) {
          cloudUnlockedSkins = (response['unlocked_skins'] as List<dynamic>).map((e) => e.toString()).toList();
        }

        // Merge policy: union unlocked skins, take max progression/assets
        final mergedSkins = {..._unlockedSkins, ...cloudUnlockedSkins}.toList();
        _unlockedSkins = mergedSkins;
        _collectedStars = math.max(_collectedStars, cloudStars);
        _feedStock = math.max(_feedStock, cloudFeed);
        _speedCardCount = math.max(_speedCardCount, cloudSpeedCards);
        _doubleFeedCardCount = math.max(_doubleFeedCardCount, cloudDoubleCards);

        if (cloudLevel > _level || (cloudLevel == _level && cloudExp > _exp)) {
          _level = cloudLevel;
          _exp = cloudExp;
        }

        if (cloudSkin.isNotEmpty && _unlockedSkins.contains(cloudSkin)) {
          _currentSkin = cloudSkin;
        }

        // If claimed today in cloud, respect it locally
        final todayStr = nowTime.toIso8601String().substring(0, 10);
        if (cloudClaimDate == todayStr) {
          _lastClaimDate = todayStr;
        }

        await save();
        notifyListeners();
        debugPrint('[KanbanService] Synced and merged manor data from cloud.');
      }
    } catch (e) {
      debugPrint('[KanbanService] Cloud pull skipped or failed (graceful degradation): $e');
    } finally {
      _isSyncingWithCloud = false;
    }
  }

  /// Push current local snapshot to cloud (called on backgrounding or closing)
  Future<void> pushToCloud() async {
    final userId = AuthService.instance.userId;
    if (userId.isEmpty) return;

    try {
      await _supabase.from('user_manor').upsert({
        'user_id': userId,
        'collected_stars': _collectedStars,
        'feed_stock': _feedStock,
        'speed_card_count': _speedCardCount,
        'double_feed_card_count': _doubleFeedCardCount,
        'level': _level,
        'exp': _exp,
        'current_skin': _currentSkin,
        'unlocked_skins': _unlockedSkins,
        'last_claim_date': _lastClaimDate,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('[KanbanService] Snapshot pushed to user_manor successfully.');
    } catch (e) {
      debugPrint('[KanbanService] Cloud push failed (graceful degradation): $e');
    }
  }

  /// Instant sync for daily claim
  Future<void> _syncClaimToCloud(String todayStr) async {
    final userId = AuthService.instance.userId;
    if (userId.isEmpty) return;

    try {
      await _supabase.from('user_manor').upsert({
        'user_id': userId,
        'last_claim_date': todayStr,
        'feed_stock': _feedStock,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[KanbanService] Failed to sync daily claim to cloud: $e');
    }
  }

  /// Instant sync for unlocking skin
  Future<void> _syncUnlockSkinToCloud(String skinId) async {
    final userId = AuthService.instance.userId;
    if (userId.isEmpty) return;

    try {
      await _supabase.from('user_manor').upsert({
        'user_id': userId,
        'unlocked_skins': _unlockedSkins,
        'collected_stars': _collectedStars,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[KanbanService] Failed to sync skin unlock to cloud: $e');
    }
  }

  /// Instant sync for changing skin
  Future<void> _syncSelectSkinToCloud(String skinId) async {
    final userId = AuthService.instance.userId;
    if (userId.isEmpty) return;

    try {
      await _supabase.from('user_manor').upsert({
        'user_id': userId,
        'current_skin': skinId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[KanbanService] Failed to sync skin selection to cloud: $e');
    }
  }

  /// Instant sync for shop purchases
  Future<void> _syncShopPurchaseToCloud() async {
    final userId = AuthService.instance.userId;
    if (userId.isEmpty) return;

    try {
      await _supabase.from('user_manor').upsert({
        'user_id': userId,
        'collected_stars': _collectedStars,
        'feed_stock': _feedStock,
        'speed_card_count': _speedCardCount,
        'double_feed_card_count': _doubleFeedCardCount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[KanbanService] Failed to sync shop purchase to cloud: $e');
    }
  }

  @override
  void dispose() {
    _eatingTimer?.cancel();
    AuthService.instance.removeListener(_onAuthStatusChanged);
    super.dispose();
  }
}

