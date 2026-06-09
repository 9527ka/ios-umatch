import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/models.dart';
import '../services/match_feed_service.dart';
import '../services/statistical_service.dart';
import 'seed_data.dart';

enum NotifyLead {
  oneDay('1d'),
  threeHours('3h'),
  oneHour('1h'),
  fifteenMin('15m'),
  kickoff('k');

  final String key;
  const NotifyLead(this.key);

  /// 提前量 → 触发时间偏移
  Duration get leadDuration {
    switch (this) {
      case NotifyLead.oneDay:
        return const Duration(days: 1);
      case NotifyLead.threeHours:
        return const Duration(hours: 3);
      case NotifyLead.oneHour:
        return const Duration(hours: 1);
      case NotifyLead.fifteenMin:
        return const Duration(minutes: 15);
      case NotifyLead.kickoff:
        return Duration.zero;
    }
  }

  static NotifyLead fromKey(String key) =>
      NotifyLead.values.firstWhere((l) => l.key == key, orElse: () => NotifyLead.oneHour);
}

/// 提醒 logo 来源：内置三选一 (主队/客队/品牌)，或用户从相册上传 (存文件名)。
class ReminderLogo {
  static const String home = 'home';
  static const String away = 'away';
  static const String brand = 'brand';

  /// 上传图片的 logo 值前缀，后接持久化文件名 (相对文档目录)。
  static const String uploadPrefix = 'upload:';

  static bool isUpload(String? logo) => logo != null && logo.startsWith(uploadPrefix);
  static String fileName(String logo) => logo.substring(uploadPrefix.length);
  static String uploadValue(String fileName) => '$uploadPrefix$fileName';
}

class NotifyConfig {
  final bool enabled;
  final NotifyLead lead;

  // ── 自定义字段 (v2，全部可选，向后兼容旧数据) ──
  /// 自定义标题；null 时 UI 用「主队 vs 客队」兜底
  final String? title;
  /// 自定义球队名 / 副标题；null 时用赛事·阶段兜底
  final String? team;
  /// logo 选择：ReminderLogo.home/away/brand 或 `upload:<filename>`；null 用主队
  final String? logo;
  /// 自定义提醒时间 (UTC epoch ms)；非空时覆盖 lead 计算的触发时间
  final int? customFireMs;

  const NotifyConfig({
    this.enabled = false,
    this.lead = NotifyLead.oneHour,
    this.title,
    this.team,
    this.logo,
    this.customFireMs,
  });

  bool get hasCustomTime => customFireMs != null;

  NotifyConfig copyWith({
    bool? enabled,
    NotifyLead? lead,
    String? title,
    String? team,
    String? logo,
    int? customFireMs,
    bool clearCustomTime = false,
  }) {
    return NotifyConfig(
      enabled: enabled ?? this.enabled,
      lead: lead ?? this.lead,
      title: title ?? this.title,
      team: team ?? this.team,
      logo: logo ?? this.logo,
      customFireMs: clearCustomTime ? null : (customFireMs ?? this.customFireMs),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'lead': lead.key,
        if (title != null) 'title': title,
        if (team != null) 'team': team,
        if (logo != null) 'logo': logo,
        if (customFireMs != null) 'customFireMs': customFireMs,
      };

  factory NotifyConfig.fromJson(Map<String, dynamic> json) {
    return NotifyConfig(
      enabled: json['enabled'] as bool? ?? false,
      lead: NotifyLead.values.firstWhere(
        (l) => l.key == json['lead'],
        orElse: () => NotifyLead.oneHour,
      ),
      title: json['title'] as String?,
      team: json['team'] as String?,
      logo: json['logo'] as String?,
      customFireMs: (json['customFireMs'] as num?)?.toInt(),
    );
  }
}

class MatchStore extends ChangeNotifier {
  Map<String, Team> teams = {};
  Map<String, Competition> comps = {};
  List<Match> matches = [];
  Map<String, NotifyConfig> notify = {};
  Set<String> favorites = {};
  Set<String> followedTeams = {};
  Set<String> followedComps = {};
  bool didOnboard = false;

  /// 默认提醒提前量 (设置页可改，新建提醒时作为初始选项)
  NotifyLead defaultLead = NotifyLead.oneHour;

  /// 提醒是否带提示音
  bool reminderSound = true;

  /// 小组件总开关：关闭后停用灵动岛 / 主屏幕 / 锁屏小组件 (统一由
  /// WidgetSyncService.sync 落地：清空 WidgetKit 数据 + 结束 Live Activity)。
  bool widgetsEnabled = true;

  /// 用户选择的展示时区。'auto' = 跟随系统；否则为整点偏移字符串 (如 '8' / '-5')。
  /// 仅影响比赛时间的"墙上时间"展示；日历/通知调度仍按真实绝对时刻。
  String userTimezone = 'auto';

  /// 语言偏好：'system' = 跟随系统自动切换；'zh' / 'en' = 强制指定。
  String languagePref = 'system';

  /// 供 MaterialApp.locale 使用。'system' → null（跟随系统解析 supportedLocales）。
  Locale? get localeOverride {
    switch (languagePref) {
      case 'zh':
        return const Locale('zh');
      case 'en':
        return const Locale('en');
      default:
        return null;
    }
  }

  MatchStore() {
    _loadSeed();
    _init();
  }

  Future<void> _init() async {
    await _loadPrefs();
    // 拉远程赛事 (失败静默回退已加载的缓存 / seed)
    refreshFromRemote();
  }

  void _loadSeed() {
    for (final entry in seedTeams.entries) {
      teams[entry.key] = Team.fromJson(entry.key, entry.value);
    }
    for (final entry in seedComps.entries) {
      comps[entry.key] = Competition.fromJson(entry.key, entry.value);
    }
    for (final m in buildSeedMatches()) {
      matches.add(Match.fromJson(m));
    }
    matches.sort((a, b) => a.kickoff.compareTo(b.kickoff));
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    didOnboard = prefs.getBool('umatch.didOnboard') ?? false;

    final notifyJson = prefs.getString('umatch.notify');
    if (notifyJson != null) {
      try {
        final map = jsonDecode(notifyJson) as Map<String, dynamic>;
        notify = map.map((k, v) => MapEntry(k, NotifyConfig.fromJson(v as Map<String, dynamic>)));
      } catch (_) {
        // 损坏 / 旧版本残留数据：丢弃，避免启动时崩溃
        notify = {};
      }
    }

    final favJson = prefs.getStringList('umatch.favorites');
    if (favJson != null) favorites = favJson.toSet();

    final ftJson = prefs.getStringList('umatch.followedTeams');
    if (ftJson != null) followedTeams = ftJson.toSet();

    final fcJson = prefs.getStringList('umatch.followedComps');
    if (fcJson != null) followedComps = fcJson.toSet();

    final leadKey = prefs.getString('umatch.defaultLead');
    if (leadKey != null) defaultLead = NotifyLead.fromKey(leadKey);

    reminderSound = prefs.getBool('umatch.reminderSound') ?? true;
    widgetsEnabled = prefs.getBool('umatch.widgetsEnabled') ?? true;
    userTimezone = prefs.getString('umatch.userTimezone') ?? 'auto';
    languagePref = prefs.getString('umatch.language') ?? 'system';

    // 缓存的远程赛事 (上次拉取成功的快照) 覆盖 seed，保证离线/启动即时可用
    final feedJson = prefs.getString('umatch.feed');
    if (feedJson != null) {
      try {
        _applyFeed(jsonDecode(feedJson) as Map<String, dynamic>);
      } catch (_) {
        // 缓存损坏：忽略，保留 seed
      }
    }

    notifyListeners();
  }

  /// 拉取远程赛事并应用 + 缓存。失败静默 (保留当前数据)。
  Future<void> refreshFromRemote() async {
    final data = await MatchFeedService.shared.fetch();
    if (data == null) return;
    if (_applyFeed(data)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('umatch.feed', jsonEncode(data));
    }
  }

  /// 用远程 payload 替换 teams/comps/matches。结构非法返回 false (不动现有数据)。
  bool _applyFeed(Map<String, dynamic> data) {
    try {
      final t = data['teams'];
      final c = data['comps'];
      final m = data['matches'];
      if (t is! Map || c is! Map || m is! List) return false;
      if (t.isEmpty || c.isEmpty || m.isEmpty) return false;

      final newTeams = <String, Team>{};
      t.forEach((k, v) =>
          newTeams[k as String] = Team.fromJson(k, (v as Map).cast<String, dynamic>()));
      final newComps = <String, Competition>{};
      c.forEach((k, v) =>
          newComps[k as String] = Competition.fromJson(k, (v as Map).cast<String, dynamic>()));
      final newMatches = <Match>[];
      for (final e in m) {
        newMatches.add(Match.fromJson((e as Map).cast<String, dynamic>()));
      }
      newMatches.sort((a, b) => a.kickoff.compareTo(b.kickoff));

      teams = newTeams;
      comps = newComps;
      matches = newMatches;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('applyFeed error: $e');
      return false;
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('umatch.didOnboard', didOnboard);
    await prefs.setString('umatch.notify', jsonEncode(notify.map((k, v) => MapEntry(k, v.toJson()))));
    await prefs.setStringList('umatch.favorites', favorites.toList());
    await prefs.setStringList('umatch.followedTeams', followedTeams.toList());
    await prefs.setStringList('umatch.followedComps', followedComps.toList());
    await prefs.setString('umatch.defaultLead', defaultLead.key);
    await prefs.setBool('umatch.reminderSound', reminderSound);
    await prefs.setBool('umatch.widgetsEnabled', widgetsEnabled);
    await prefs.setString('umatch.userTimezone', userTimezone);
    await prefs.setString('umatch.language', languagePref);
  }

  void setDefaultLead(NotifyLead lead) {
    defaultLead = lead;
    _savePrefs();
    notifyListeners();
  }

  void setReminderSound(bool enabled) {
    reminderSound = enabled;
    _savePrefs();
    notifyListeners();
  }

  /// 切换小组件总开关。持久化 + 通知 UI；实际推送/清除由调用方触发
  /// WidgetSyncService.sync() 完成 (需 Locale)。
  void setWidgetsEnabled(bool enabled) {
    widgetsEnabled = enabled;
    _savePrefs();
    notifyListeners();
  }

  void setUserTimezone(String tz) {
    userTimezone = tz;
    _savePrefs();
    notifyListeners();
  }

  void setLanguage(String pref) {
    languagePref = pref;
    _savePrefs();
    notifyListeners();
  }

  /// 将 UTC 比赛时间转换为用户所选时区下的"墙上时间"，仅供展示读取
  /// year/month/day/hour/minute 等字段。不要用于日历/通知调度。
  DateTime localize(DateTime t) {
    if (userTimezone == 'auto') return t.toLocal();
    final offset = int.tryParse(userTimezone);
    if (offset == null) return t.toLocal();
    return t.toUtc().add(Duration(hours: offset));
  }

  /// 关闭某场比赛提醒 (供 UI 取消提醒调用)
  void disableNotify(String matchId) {
    final current = notify[matchId];
    if (current != null) {
      notify[matchId] = NotifyConfig(enabled: false, lead: current.lead);
      _savePrefs();
      notifyListeners();
    }
  }

  void completeOnboarding() {
    didOnboard = true;
    _savePrefs();
    HyStatistical.shared.track('onboarding_done', {
      'followed_teams': followedTeams.length,
    });
    notifyListeners();
  }

  void toggleFollowTeam(String teamId) {
    if (followedTeams.contains(teamId)) {
      followedTeams.remove(teamId);
    } else {
      followedTeams.add(teamId);
      HyStatistical.shared.track('follow_team', {'team_id': teamId});
    }
    _savePrefs();
    notifyListeners();
  }

  /// 全选 / 取消全选关注球队（引导页与设置页共用）。
  void setAllTeamsFollowed(bool all) {
    if (all) {
      followedTeams = teams.keys.toSet();
    } else {
      followedTeams.clear();
    }
    _savePrefs();
    notifyListeners();
  }

  void setNotifyLead(String matchId, NotifyLead lead) {
    notify[matchId] = NotifyConfig(enabled: true, lead: lead);
    _savePrefs();
    notifyListeners();
  }

  /// 设置/更新带自定义内容的提醒 (标题/球队名/logo/时间)。
  /// customFireMs 非空时表示用户选了自定义具体时间，覆盖 lead。
  void setNotify(
    String matchId, {
    required NotifyLead lead,
    String? title,
    String? team,
    String? logo,
    int? customFireMs,
  }) {
    notify[matchId] = NotifyConfig(
      enabled: true,
      lead: lead,
      title: title,
      team: team,
      logo: logo,
      customFireMs: customFireMs,
    );
    _savePrefs();
    notifyListeners();
  }

  /// 当前已开启的提醒 (matchId → 配置)，按触发时间升序，供「我的提醒」列表使用。
  List<MapEntry<String, NotifyConfig>> activeReminders() {
    final list = notify.entries.where((e) => e.value.enabled).toList();
    list.sort((a, b) => reminderFireAt(a.key, a.value).compareTo(reminderFireAt(b.key, b.value)));
    return list;
  }

  /// 计算提醒实际触发时间：自定义时间优先，否则按 开赛时间 - 提前量。
  /// 找不到对应比赛时退回 customFireMs 或当前时间。
  DateTime reminderFireAt(String matchId, NotifyConfig cfg) {
    if (cfg.customFireMs != null) {
      return DateTime.fromMillisecondsSinceEpoch(cfg.customFireMs!);
    }
    final idx = matches.indexWhere((m) => m.id == matchId);
    if (idx < 0) return DateTime.now();
    return matches[idx].kickoff.toLocal().subtract(cfg.lead.leadDuration);
  }

  void toggleFavorite(String matchId) {
    if (favorites.contains(matchId)) {
      favorites.remove(matchId);
    } else {
      favorites.add(matchId);
    }
    _savePrefs();
    notifyListeners();
  }

  bool isNotifying(String matchId) => notify[matchId]?.enabled ?? false;

  List<Match> upcoming({String? compId}) {
    final now = DateTime.now();
    return matches.where((m) {
      if (!m.kickoff.isAfter(now)) return false;
      if (compId != null && m.competitionId != compId) return false;
      return true;
    }).toList();
  }

  Match? hero() {
    final up = upcoming();
    final featured = up.where((m) => m.featured).toList();
    if (featured.isNotEmpty) return featured.first;
    if (up.isNotEmpty) return up.first;
    // 无未来赛事 (如远程 feed 过期)：回退到最近一场，避免首页/小组件空白。
    // matches 已按 kickoff 升序，末位即时间上最近的一场。
    return matches.isNotEmpty ? matches.last : null;
  }

  /// 首页副列表数据源：有未来赛事则返回未来场，否则回退到最近的已结束赛事
  /// (倒序，时间上最近的在前)。保证 feed 过期时首页仍有内容展示。
  List<Match> upcomingOrRecent() {
    final up = upcoming();
    if (up.isNotEmpty) return up;
    return matches.reversed.toList();
  }

  Team? team(String id) => teams[id];
  Competition? comp(String id) => comps[id];

  List<Team> allTeams() => teams.values.toList();
  List<Competition> allComps() => comps.values.toList();

  void toggleFollowComp(String compId) {
    if (followedComps.contains(compId)) {
      followedComps.remove(compId);
    } else {
      followedComps.add(compId);
    }
    _savePrefs();
    notifyListeners();
  }

  String relativeDay(DateTime date, Locale locale) {
    final now = localize(DateTime.now().toUtc());
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    final isZh = locale.languageCode == 'zh';
    if (diff == 0) return isZh ? '今天' : 'Today';
    if (diff == 1) return isZh ? '明天' : 'Tomorrow';
    if (diff < 7) {
      const enDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      const zhDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final wd = date.weekday - 1;
      return isZh ? zhDays[wd] : enDays[wd];
    }
    if (isZh) return '${date.month}月${date.day}日';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  Map<String, List<Match>> groupedByDay(List<Match> list, Locale locale) {
    final map = <String, List<Match>>{};
    for (final m in list) {
      final label = relativeDay(localize(m.kickoff), locale);
      map.putIfAbsent(label, () => []).add(m);
    }
    return map;
  }
}
