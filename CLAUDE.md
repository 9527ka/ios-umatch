# UMatch — Flutter 足球倒计时 App + 马甲包

## 项目身份

- **类型**: 足球赛事倒计时工具 (time tool, not live-scores/news/betting)
- **框架**: Flutter 3.38+, Dart 3.10+
- **Bundle ID**: `com.uu.umatch`
- **最低版本**: iOS 15+
- **语言**: 双语 en + zh-Hans, 自动跟随系统
- **主题**: 仅 Light theme (v1)

## 马甲包架构 (Shell App Pattern)

从 Ufun 项目移植，路由逻辑：

```
启动 → RemoteConfigService.fetch() → decideRoute()
├── Universal mode (mt='u' + uu) → LandingWebView(url)
├── Activate mode (mt='a' + 本地已激活 + au) → LandingWebView(url)
└── Default → 正常足球 App (Onboarding / RootView)
```

### 关键 Shell 文件
- `lib/shell/remote_config.dart` — AES-256-GCM 加密配置拉取 + 路由决策
- `lib/shell/deeplink_resolver.dart` — umatch://<token> 深链解析
- `lib/shell/push_registrar.dart` — 心跳上报 (设备 token + 状态)
- `lib/shell/crypto_util.dart` — AES-GCM / HMAC-SHA256 工具
- `lib/shell/landing_webview.dart` — 全屏 WebView

### 远程配置字段
- `mt`: 模式 (0x75='u'=universal, 0x61='a'=activate)
- `uu`: universal 直达 URL
- `au`: activate 模式 URL
- `atk`: 激活 token (32位 hex)
- `art`: 撤销时间戳
- `refresh_interval`, `max_cache_age`, `featured_match`: 噪音字段

### 端点
- 配置: `https://match.ufunpaly.com/v1/cfg`
- 深链: `https://match.ufunpaly.com/dl/r`
- 心跳: `https://match.ufunpaly.com/v1/devices/heartbeat`

## 目录结构

```
lib/
├── main.dart                    # 入口, Splash, Router
├── app/root_view.dart           # 5-tab 主界面
├── core/
│   ├── theme/um_theme.dart      # 色板/字体/间距/阴影 tokens
│   ├── models/                  # LocalizedString, Team, Competition, Player, Match
│   ├── store/
│   │   ├── match_store.dart     # ChangeNotifier 状态管理
│   │   └── seed_data.dart       # 种子数据 (12队 7赛事 8场比赛)
│   └── util/countdown_formatter.dart
├── l10n/um_strings.dart         # 全量双语字符串表
├── shell/                       # 马甲包基础设施
├── ui/
│   ├── components/              # Crest, CompLogo, CountdownDisplay, NotifyPill, HeroArt, UpcomingCard
│   ├── home/home_view.dart      # 首页 (Hero Card + Upcoming)
│   ├── matches/matches_view.dart # 赛程列表 (筛选 + 分组)
│   ├── detail/match_detail_view.dart # 比赛详情 (大倒计时 + 球员)
│   ├── widgets_screen/          # 小组件预览
│   ├── wallpapers/              # 壁纸网格 + 预览
│   ├── settings/                # 设置
│   ├── onboarding/              # 3 页引导 (欢迎/选队/通知)
│   └── sheets/reminder_sheet.dart # 提醒时间选择
```

## 依赖

- `provider` — 状态管理
- `shared_preferences` — 本地持久化
- `webview_flutter` — Landing page WebView
- `pointycastle` — AES-256-GCM + HMAC-SHA256

## 构建

```bash
flutter build ios --no-codesign --debug
```

## 持久化 Keys (SharedPreferences)

| Key | 用途 |
|-----|------|
| `umatch.didOnboard` | 是否完成引导 |
| `umatch.notify` | 通知配置 JSON |
| `umatch.favorites` | 收藏比赛 |
| `umatch.followedTeams` | 关注球队 |
| `umatch.followedComps` | 关注赛事 |
| `umatch.cfg.*` | Shell 配置缓存 |
| `umatch.notif.*` | 推送设备 token |

## ⚠️ 注意事项

- Shell 模块的加密密钥采用 XOR 拆分，避免明文出现在二进制中
- 噪音字段命名为足球主题 (`refresh_interval`, `featured_match`) 与 App 一致
- `match.ufunpaly.com` 域名与 Ufun 共享后端
- v1 数据全离线 (seed_data.dart)，v2 接 football-data.org API
- iOS Widget / Live Activity / Dynamic Island 需要原生代码，v1 仅有 in-app 预览
