import 'dart:ui';

class UMStrings {
  final Locale locale;
  late final bool _isZh;

  UMStrings(this.locale) {
    _isZh = locale.languageCode == 'zh';
  }

  String get brand => 'UMatch';
  String get nextBig => _isZh ? '即将开战' : 'NEXT BIG MATCH';
  String get upcoming => _isZh ? '即将开始' : 'Upcoming';
  String get seeAll => _isZh ? '查看全部' : 'See all';
  String get viewBtn => _isZh ? '查看' : 'View';
  String get vs => 'vs';

  String get notifyOff => _isZh ? '提醒我' : 'Notify Me';
  String get notifyOn => _isZh ? '已提醒' : 'Notifying';

  String get matches => _isZh ? '赛程' : 'Matches';

  String get playersToWatch => _isZh ? '焦点球员' : 'Players to Watch';
  String get actRemind => _isZh ? '提醒' : 'Remind';
  String get actCal => _isZh ? '日历' : 'Calendar';
  String get actWidget => _isZh ? '小组件' : 'Widget';
  String get actShare => _isZh ? '分享' : 'Share';
  String get startsIn => _isZh ? '距离开赛' : 'STARTS IN';

  String get remindTitle => _isZh ? '提前何时提醒我' : 'Remind Me Before';
  String get remindSub => _isZh ? '我们会在比赛开始前安静地通知你。' : "We'll send a quiet notification before kickoff.";

  List<List<String>> get remindOpts => _isZh
      ? [['1d', '提前 1 天'], ['3h', '提前 3 小时'], ['1h', '提前 1 小时'], ['15m', '提前 15 分钟'], ['k', '开赛时']]
      : [['1d', '1 Day Before'], ['3h', '3 Hours Before'], ['1h', '1 Hour Before'], ['15m', '15 Minutes Before'], ['k', 'At Kickoff']];

  String get confirm => _isZh ? '确认' : 'Confirm';

  // ── 自定义提醒 ──
  String get customizeTitle => _isZh ? '自定义提醒' : 'Customize Reminder';
  String get fieldTitle => _isZh ? '标题' : 'Title';
  String get fieldTeam => _isZh ? '球队名' : 'Team Name';
  String get fieldLogo => _isZh ? 'Logo' : 'Logo';
  String get fieldTime => _isZh ? '提醒时间' : 'Reminder Time';
  String get logoHome => _isZh ? '主队' : 'Home';
  String get logoAway => _isZh ? '客队' : 'Away';
  String get logoBrand => _isZh ? '品牌' : 'Brand';
  String get logoUpload => _isZh ? '上传' : 'Upload';
  String get timeCustom => _isZh ? '自定义' : 'Custom';
  String get pickDateTime => _isZh ? '选择提醒时间' : 'Pick reminder time';
  String get reminderPreview => _isZh ? '预览' : 'Preview';
  String get myReminders => _isZh ? '我的提醒' : 'My Reminders';
  String get noReminders => _isZh ? '还没有设置任何提醒' : 'No reminders yet';
  String get noRemindersSub => _isZh
      ? '在比赛卡片上点「提醒」即可创建。'
      : 'Tap “Remind” on any match to create one.';
  String get edit => _isZh ? '编辑' : 'Edit';
  String get delete => _isZh ? '删除' : 'Delete';
  String get titleTooLong => _isZh ? '标题过长' : 'Title is too long';

  String get widgetsTitle => _isZh ? '小组件' : 'Widgets';
  String get widgetsLead => _isZh ? '把下一场比赛的倒计时放上主屏幕。' : 'Put the next match countdown on your Home Screen.';
  String get widgetsHow => _isZh ? '长按主屏幕 → 点击 "+" → 搜索 UMatch。' : 'Long-press your home screen → tap "+" → search "UMatch".';
  String get widgetSmall => _isZh ? '小尺寸 · 2×2' : 'Small · 2×2';
  String get widgetMed => _isZh ? '中尺寸 · 4×2' : 'Medium · 4×2';
  String get widgetLarge => _isZh ? '大尺寸 · 4×4' : 'Large · 4×4';
  String get widgetRect => _isZh ? '矩形' : 'Rectangular';
  String get widgetCirc => _isZh ? '圆形' : 'Circular';
  String get widgetInline => _isZh ? '内嵌' : 'Inline';
  String get widgetCompact => _isZh ? '紧凑' : 'Compact';
  String get widgetExp => _isZh ? '展开' : 'Expanded';
  String get widgetHowAdd => _isZh ? '如何添加 →' : 'How to add this →';
  String get widgetUcl => _isZh ? '欧冠决赛' : 'UCL FINAL';
  String get widgetNext => _isZh ? '下一场' : 'NEXT MATCH';
  String get widgetUpcoming => _isZh ? '即将开始' : 'Upcoming';
  String get widgetEnable => _isZh ? '启用小组件' : 'Enable Widgets';
  String get widgetEnableSub => _isZh
      ? '关闭后将停用灵动岛、主屏幕及锁屏小组件。'
      : 'Turn off to disable Dynamic Island, Home Screen and Lock Screen widgets.';
  String get widgetDaysLeft => _isZh ? '距离开赛' : 'DAYS LEFT';
  List<List<String>> get widgetTabs => _isZh
      ? [['home', '主屏幕'], ['lock', '锁屏'], ['island', '灵动岛']]
      : [['home', 'Home Screen'], ['lock', 'Lock Screen'], ['island', 'Dynamic Island']];

  String get wallpapers => _isZh ? '壁纸' : 'Wallpapers';
  String get wallpapersSub => _isZh ? '用足球美学装点你的锁屏。' : 'Football art for your lock screen.';
  List<String> get wallCats => _isZh
      ? ['全部', '球场', '足球', '球队', '霓虹', '极简', '复古', '暗调']
      : ['All', 'Stadiums', 'Footballs', 'Teams', 'Neon', 'Minimal', 'Retro', 'Dark'];
  String get wallSave => _isZh ? '保存到相册' : 'Save to Photos';

  String get settings => _isZh ? '设置' : 'Settings';
  String get setNotif => _isZh ? '通知' : 'Notifications';
  String get setNotifDefault => _isZh ? '默认提醒时间' : 'Default Reminder Time';
  String get setNotifSound => _isZh ? '提示音' : 'Sound';
  String get setNotifLive => _isZh ? '进球实时提醒' : 'Notify Live Goals';
  String get setNotifDefVal => _isZh ? '提前 1 小时' : '1 Hour Before';
  String get setNotifSoundVal => _isZh ? '默认' : 'Default';
  String get setPref => _isZh ? '偏好' : 'Preferences';
  String get setPrefFavTeams => _isZh ? '关注球队' : 'Favorite Teams';
  String get setPrefFavTeamsVal => _isZh ? '已关注 3 支' : '3 teams';
  String get setPrefFavComp => _isZh ? '关注赛事' : 'Favorite Competitions';
  String get setPrefFavCompVal => _isZh ? '已选 5 项' : '5 selected';
  String get setPrefTz => _isZh ? '时区' : 'Timezone';
  String get setPrefTzVal => _isZh ? '自动 (GMT+8)' : 'Auto (GMT+8)';
  String tzAutoVal(String gmt) => _isZh ? '自动 ($gmt)' : 'Auto ($gmt)';
  List<List<String>> get tzOptions => _isZh
      ? [
          ['auto', '自动'],
          ['-8', 'GMT-8 洛杉矶'],
          ['-5', 'GMT-5 纽约'],
          ['-3', 'GMT-3 圣保罗'],
          ['0', 'GMT 伦敦'],
          ['1', 'GMT+1 马德里'],
          ['2', 'GMT+2 开罗'],
          ['3', 'GMT+3 莫斯科'],
          ['8', 'GMT+8 北京'],
          ['9', 'GMT+9 东京'],
        ]
      : [
          ['auto', 'Auto'],
          ['-8', 'GMT-8 Los Angeles'],
          ['-5', 'GMT-5 New York'],
          ['-3', 'GMT-3 São Paulo'],
          ['0', 'GMT London'],
          ['1', 'GMT+1 Madrid'],
          ['2', 'GMT+2 Cairo'],
          ['3', 'GMT+3 Moscow'],
          ['8', 'GMT+8 Beijing'],
          ['9', 'GMT+9 Tokyo'],
        ];
  String get setApp => _isZh ? '外观' : 'Appearance';
  String get setAppLanguage => _isZh ? '语言' : 'Language';
  List<List<String>> get languageOptions => [
        ['system', _isZh ? '跟随系统' : 'System'],
        ['zh', '简体中文'],
        ['en', 'English'],
      ];
  String get setAppTheme => _isZh ? '主题' : 'Theme';
  String get setAppThemeVal => _isZh ? '浅色' : 'Light';
  String get setAppIcon => _isZh ? '应用图标' : 'App Icon';
  String get setAbout => _isZh ? '关于' : 'About';
  String get setRate => _isZh ? '为 UMatch 评分' : 'Rate UMatch';
  String get setShare => _isZh ? '分享 UMatch' : 'Share UMatch';
  String get setPrivacy => _isZh ? '隐私政策' : 'Privacy Policy';
  String get setTerms => _isZh ? '服务条款' : 'Terms of Service';
  String get setVersion => _isZh ? '版本' : 'Version';

  String get onbWelcomeTag => _isZh ? '欢迎使用' : 'WELCOME TO';
  String get onbWelcomeBody => _isZh
      ? '不再错过任何一场比赛。\n一份安静、克制的开赛倒计时。'
      : "Never miss another match.\nA calm, beautiful countdown to every kickoff.";
  String get onbStart => _isZh ? '开始使用' : 'Get Started';
  String onbStepLabel(int n, int total) => _isZh ? '第 $n 步 · 共 $total 步' : 'STEP $n OF $total';
  String get onbTeamsTitle => _isZh ? '选择你最关注的球队' : 'Pick your favorite clubs.';
  String get onbTeamsSub => _isZh ? '我们会在主页优先展示他们的比赛。' : "We'll prioritize their matches in your timeline.";
  String get onbContinue => _isZh ? '继续' : 'Continue';
  String get onbSkip => _isZh ? '暂时跳过' : 'Skip for now';
  String get onbSelectAll => _isZh ? '全选' : 'Select all';
  String get onbDeselectAll => _isZh ? '取消全选' : 'Deselect all';
  String get onbNotifTitle => _isZh ? '不再错过开赛时刻' : 'Never miss kickoff.';
  String get onbNotifSub => _isZh
      ? '我们会在每场比赛前发送一条安静的提醒。\n你可以在 "设置" 中调整提前时间。'
      : "Get a calm, quiet reminder before every match.\nAdjust how early in Settings.";
  String get onbNotifEnable => _isZh ? '开启通知' : 'Enable Notifications';
  String get onbNotifNot => _isZh ? '暂不开启' : 'Not now';
  String get onbNotifFakeTitle => _isZh ? 'UMatch · 现在' : 'UMatch · now';
  String get onbNotifFakeBody => _isZh ? '皇家马德里 vs 巴塞罗那 将于 1 小时后开赛' : 'Real Madrid vs Barcelona kicks off in 1 hour';
  String onbPage(int n, int total) => '$n / $total';
  String get wallMonth => _isZh ? '5月30日 星期六' : 'Saturday, May 30';
  String get setVersionVal => '1.0.0';

  String get emptyTitle => _isZh ? '球场暂时安静' : 'The pitch is quiet.';
  String get emptyBody => _isZh
      ? '最近几天没有需要关注的比赛。\n关注更多球队或赛事,让 UMatch 帮你守候。'
      : 'No matches on your radar for the next few days.\nPick more clubs or competitions to follow.';
  String get emptyCta => _isZh ? '添加关注球队' : 'Add Teams to Follow';

  String get today => _isZh ? '今天' : 'Today';
  String get tomorrow => _isZh ? '明天' : 'Tomorrow';
  String get unitDays => _isZh ? '天' : 'DAYS';
  String get unitHrs => _isZh ? '时' : 'HRS';
  String get unitMin => _isZh ? '分' : 'MIN';
  String get unitSec => _isZh ? '秒' : 'SEC';

  // Tabs
  String get tabHome => _isZh ? '首页' : 'Home';
  String get tabMatches => _isZh ? '赛程' : 'Matches';
  String get tabWidgets => _isZh ? '小组件' : 'Widgets';
  String get tabWallpapers => _isZh ? '壁纸' : 'Wallpapers';
  String get tabSettings => _isZh ? '设置' : 'Settings';

  static UMStrings of(Locale locale) => UMStrings(locale);
}
