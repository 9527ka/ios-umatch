# UMatch — App Store 审核提交资料

> 版本 1.0.0 (build 1) · Bundle `com.uu.umatch` · Team `R6MBR8SQQU` · 免费 · 分类 Sports
> 直接复制到 App Store Connect 对应字段。中英双语商店文案均在下方。

---

## 1. App 基本信息 (App Information)

| 字段 | 值 |
|------|----|
| App Name (商店名) | `UMatch-tool` |
| 设备显示名 (CFBundleDisplayName) | UMatch |
| Bundle ID | com.uu.umatch |
| Primary Category | Sports |
| Secondary Category | Utilities (可留空) |
| Content Rights | 不含第三方版权内容（球队用国旗 emoji，无俱乐部徽标）|
| Age Rating | 4+ （所有内容项均选 None / 无）|
| Price | Free |
| Languages | English (主) / 简体中文 |
| Support URL | https://（待托管）/support |
| Marketing URL | （可留空）|
| Privacy Policy URL | https://（待托管）/privacy — **必填，见 §6** |

---

## 2. 商店文案（英文）

**Subtitle (≤30 chars)**
```
Beautiful match countdowns
```

**Promotional Text (≤170 chars)**
```
A calm, beautiful countdown to every kickoff. Follow your teams, add reminders, and keep the next big match on your Home Screen and Lock Screen.
```

**Description**
```
UMatch is a clean, focused countdown for football fans. No noise, no clutter — just a beautiful timer to every kickoff.

• Live countdowns to upcoming matches, down to the second
• Follow your favourite national teams and competitions
• Home Screen, Lock Screen widgets and Dynamic Island / Live Activity countdowns
• Quiet kickoff reminders — pick how early you want to be notified
• Match details: stage, venue and date in your local time zone
• Light, distraction-free design in English and Chinese

UMatch is a schedule and countdown tool. It does not show live scores, betting odds or news — just the calm anticipation before every match.
```

**Keywords (≤100 chars, 逗号分隔无空格)**
```
football,soccer,countdown,match,fixtures,schedule,timer,widget,reminder,world cup,kickoff,sports
```

**What's New (1.0.0)**
```
Initial release. Beautiful match countdowns, team following, Home/Lock Screen widgets, Live Activities and kickoff reminders.
```

---

## 3. 商店文案（简体中文 zh-Hans）

**副标题 (≤30)**
```
精致的比赛倒计时
```

**宣传文本 (≤170)**
```
为每一场开球提供平静而精致的倒计时。关注你的球队、设置提醒，把下一场重要比赛放到主屏与锁屏小组件上。
```

**描述**
```
UMatch 是一款简洁专注的足球比赛倒计时工具。没有干扰、没有杂讯——只有通往每一次开球的精美计时。

• 实时倒计时到即将开始的比赛，精确到秒
• 关注你喜爱的国家队与赛事
• 主屏、锁屏小组件以及灵动岛 / 实时活动倒计时
• 安静的开球提醒——自选提前通知时间
• 比赛详情：阶段、球场与本地时区时间
• 简洁无干扰的设计，支持中英文

UMatch 是赛程与倒计时工具，不提供实时比分、博彩赔率或新闻——只保留每场比赛前那份平静的期待。
```

**关键词 (≤100)**
```
足球,比赛,倒计时,赛程,世界杯,提醒,小组件,计时,球队,开球,体育,赛事
```

**新功能 (1.0.0)**
```
首次发布。精美的比赛倒计时、球队关注、主屏/锁屏小组件、实时活动与开球提醒。
```

---

## 4. App Review Information（审核备注 — 重要）

**Sign-in required?** No（无需登录 / 无账号体系）
**Demo account:** 不适用

**Notes (复制给审核员):**
```
UMatch is an offline football match countdown and schedule utility. No account or login is required; all features are available immediately.

- The app shows countdowns to scheduled matches, team info (national flags), widgets, Live Activities and local kickoff reminders.
- It does NOT provide live scores, betting/odds, or news.
- Match schedule data is loaded from a bundled offline dataset and may optionally refresh from our own HTTPS endpoint; the app works fully offline.
- Push notifications are used only for optional match reminders.
- Photo Library access (add-only) is used solely to save wallpaper images the user chooses to save.
- Encryption: the app uses standard AES-256-GCM only to protect its own configuration data; it qualifies for the export exemption (ITSAppUsesNonExemptEncryption = false).

Contact: support@futurofun.cc
```

> ⚠️ 马甲包注意：远程配置端点 `match.ufunpaly.com` 当前不解析，App 始终回退到正常足球倒计时形态——审核期保持此状态，**勿在审核窗口开启 universal/activate 切量**。（详见 [[project-uucar-review-strategy]] 同套策略。）

---

## 5. App Privacy（数据收集申报 — App Store Connect → App Privacy）

> 客户端实际采集：`statistical_service.dart`（埋点）+ APNs 推送 token。无账号、无 IDFA、无第三方广告 SDK。

整体声明：**"Data Not Linked to You"**，且 **不用于追踪 (No Tracking)**。

| Data Type | 类别 | 是否采集 | 用途 (Purpose) | Linked? | Tracking? |
|-----------|------|----------|----------------|---------|-----------|
| Identifiers → User ID | App 生成的随机 device_id（非 IDFA/IDFV，重装即重置）| 是 | Analytics, App Functionality | No | No |
| Usage Data → Product Interaction | 事件埋点（打开、关注球队、设提醒、看详情等）| 是 | Analytics | No | No |
| Diagnostics → 其他 (app_version / os_version) | 版本与系统版本 | 是 | Analytics | No | No |

- **未采集**：姓名、邮箱、电话、精确/粗略位置、通讯录、健康、财务、照片内容、浏览历史。
- APNs token 仅用于推送送达（App Functionality），不关联身份。
- 填表要点：Tracking 问题全部选 **No**（不调用 App Tracking Transparency，因为不跨 App/网站追踪）。

---

## 6. 隐私政策 / 支持页（必须托管为可访问 URL）

ASC 强制要求 Privacy Policy URL。**UMatch 专属页面已生成**（与共享 UUCar 页面分离，互不影响）：

- `legal/umatch/index.html` · `legal/umatch/privacy.html` · `legal/umatch/support.html`

**待办：**
1. 把 `legal/umatch/` 整个目录托管到可公开访问的 HTTPS（与现有页面同域子路径即可，如 `https://<你的域名>/umatch/`）。
2. 填入 ASC：
   - Privacy Policy URL → `https://<你的域名>/umatch/privacy.html`
   - Support URL → `https://<你的域名>/umatch/support.html`
3. 联系邮箱已统一 `support@futurofun.cc`（页面内已写）。

---

## 7. 截图（无法自动生成，需手动出图）

App Store Connect 当前必传尺寸：

| 设备 | 尺寸 (px) | 必需 |
|------|-----------|------|
| iPhone 6.9" (15/16 Pro Max) | 1290 × 2796 | ✅ 必需 |
| iPhone 6.5" (11 Pro Max 等) | 1242 × 2688 | 可选（6.9 可向下复用）|
| iPad 13"（如未声明 iPad 支持则不需要）| 2064 × 2752 | 仅 iPad 版需要 |

**建议 5 张：** ① 首页 Hero 大倒计时 ② 赛程列表 ③ 比赛详情 ④ 主屏+锁屏小组件 ⑤ 设置/关注球队。
出图法：iPhone 16 Pro Max 模拟器跑 release，`xcrun simctl io booted screenshot`，或 Xcode 自带截图。

---

## 8. 构建与提交前检查清单

- [x] `ITSAppUsesNonExemptEncryption = false` 已写入 `ios/Runner/Info.plist`
- [ ] **签名**：Release 配置下 `aps-environment` 必须为 **`production`**（当前 entitlements 写的是 `development`，仅适用于真机调试）。Archive 前确认 Xcode 自动签名用的是 App Store / production profile，否则推送在线上失效。
- [ ] App Group `group.com.uu.umatch`、Push、Live Activities 三项 capability 已在 Team R6MBR8SQQU 的 App ID 上启用并随 profile 下发（与 §「真机打不开」排查同源）。
- [ ] 版本号 `CFBundleShortVersionString`=1.0.0，`CFBundleVersion`=1。
- [ ] 用 **Release** 归档：`flutter build ipa --release`，再用 Xcode Organizer / Transporter 上传。
- [ ] App icon 1024×1024（无 alpha）已配 AppIcon。
- [ ] 隐私政策 URL 已托管可访问（§6）。
- [ ] App Privacy 表已按 §5 填写。
```
