import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/widget_sync_service.dart';
import '../../core/store/match_store.dart';
import '../../core/theme/um_theme.dart';
import '../../l10n/um_strings.dart';

/// 真实品牌 logo 图标，统一替换原先的占位足球图标。
Widget _brandLogo(double size) => Image.asset(
      'assets/brand/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

/// Resolved snapshot of the "next match" used to render the in-app
/// previews of the iOS Home Screen widget. `null` => empty-state preview.
class _WidgetData {
  const _WidgetData({
    required this.home,
    required this.away,
    required this.comp,
    required this.venue,
    required this.countdown,
    required this.countdownShort,
  });

  final String home;
  final String away;
  final String comp;
  final String venue;
  final String countdown;
  final String countdownShort;

  static _WidgetData? from(MatchStore store, Locale locale, bool isZh) {
    final match = store.hero();
    if (match == null) return null;
    final home = store.team(match.homeTeamId)?.alias.resolve(locale) ?? '—';
    final away = store.team(match.awayTeamId)?.alias.resolve(locale) ?? '—';
    final comp = store.comp(match.competitionId)?.short.resolve(locale) ?? '';
    final stage = match.stage.resolve(locale);
    final diff = match.kickoff.difference(DateTime.now());
    final String countdown;
    final String countdownShort;
    if (diff.isNegative) {
      countdown = isZh ? '开赛' : 'Kickoff';
      countdownShort = isZh ? '开赛' : 'LIVE';
    } else {
      final hh = (diff.inHours % 24).toString().padLeft(2, '0');
      final mm = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final ss = (diff.inSeconds % 60).toString().padLeft(2, '0');
      if (diff.inDays > 0) {
        countdown = '${diff.inDays}d $hh:$mm:$ss';
        countdownShort = '${diff.inDays}d';
      } else {
        // 小时 / 分钟内都显示到秒，让小组件每秒跳动
        countdown = '$hh:$mm:$ss';
        countdownShort = diff.inHours > 0 ? '${diff.inHours}h' : '${diff.inMinutes}m';
      }
    }
    return _WidgetData(
      home: home,
      away: away,
      comp: stage.isEmpty ? comp : (comp.isEmpty ? stage : '$comp · $stage'),
      venue: match.venue.resolve(locale),
      countdown: countdown,
      countdownShort: countdownShort,
    );
  }
}

class WidgetsView extends StatefulWidget {
  const WidgetsView({super.key});

  @override
  State<WidgetsView> createState() => _WidgetsViewState();
}

class _WidgetsViewState extends State<WidgetsView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 每秒刷新一次，让预览中的倒计时跟着秒数跳动
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);
    final isZh = locale.languageCode == 'zh';
    final store = context.watch<MatchStore>();
    final enabled = store.widgetsEnabled;
    final data = enabled ? _WidgetData.from(store, locale, isZh) : null;

    final steps = isZh
        ? ['长按主屏幕空白处，进入编辑状态', '点击左上角的 "+"', '搜索 "UMatch"', '选择小号或中号，点"添加小组件"']
        : [
            'Long-press an empty area of the Home Screen',
            'Tap "+" in the top-left',
            'Search for "UMatch"',
            'Pick Small or Medium, then "Add Widget"',
          ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 12),
          Text(s.widgetsTitle, style: UMFont.display(size: 32, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(s.widgetsLead, style: UMFont.body(size: 14).copyWith(color: UMColors.textSecondary)),
          const SizedBox(height: 16),
          // 小组件总开关：关闭后灵动岛 / 主屏幕 / 锁屏小组件全部停用
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UMColors.border),
              boxShadow: UMShadows.card,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: UMColors.primaryTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.widgets_outlined, size: 20, color: UMColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.widgetEnable, style: UMFont.body(size: 15, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(s.widgetEnableSub,
                          style: UMFont.caption(size: 11).copyWith(color: UMColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: enabled,
                  activeTrackColor: UMColors.primary,
                  onChanged: (v) async {
                    final st = context.read<MatchStore>();
                    st.setWidgetsEnabled(v);
                    await WidgetSyncService.sync(st, locale);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 总开关关闭时：预览整体置灰且不可交互
          IgnorePointer(
            ignoring: !enabled,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: enabled ? 1 : 0.4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          // How-to tip card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UMColors.primaryTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UMColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: UMColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      isZh ? '如何添加小组件' : 'How to Add a Widget',
                      style: UMFont.body(size: 14, weight: FontWeight.w600).copyWith(color: UMColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(steps.length, (i) => Padding(
                  padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20, height: 20,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: UMColors.primary),
                        child: Center(
                          child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(steps[i], style: UMFont.body(size: 13).copyWith(color: UMColors.textSecondary))),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Home Screen section
          Text(
            isZh ? '主屏幕小组件' : 'Home Screen Widgets',
            style: UMFont.body(size: 16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  SizedBox(width: 148, height: 148, child: _WidgetPreview(data: data, isZh: isZh, compact: true)),
                  const SizedBox(height: 6),
                  Text(s.widgetSmall, style: UMFont.caption(size: 11).copyWith(color: UMColors.textTertiary)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(height: 148, child: _WidgetPreview(data: data, isZh: isZh, compact: false)),
                    const SizedBox(height: 6),
                    Text(s.widgetMed, style: UMFont.caption(size: 11).copyWith(color: UMColors.textTertiary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Lock Screen section
          Text(
            isZh ? '锁屏小组件' : 'Lock Screen Widgets',
            style: UMFont.body(size: 16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _LockScreenDemo(data: data, isZh: isZh, s: s),
          const SizedBox(height: 24),
          // Dynamic Island section
          Text(
            isZh ? '灵动岛' : 'Dynamic Island',
            style: UMFont.body(size: 16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _IslandDemo(data: data, isZh: isZh, s: s),
                ],
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

/// In-app mock of the native WidgetKit card.
/// `compact` = small (2×2) layout; otherwise the medium (4×2) layout.
class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({required this.data, required this.isZh, required this.compact});
  final _WidgetData? data;
  final bool isZh;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFAF8F3)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: UMColors.border),
        boxShadow: UMShadows.card,
      ),
      child: data == null ? _empty() : (compact ? _small(data!) : _medium(data!)),
    );
  }

  Widget _compLabel(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _brandLogo(22),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: UMFont.caption(size: 10, weight: FontWeight.w600).copyWith(color: UMColors.primary)),
        ),
      ],
    );
  }

  Widget _small(_WidgetData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _compLabel(d.comp),
        const Spacer(),
        Text(d.home, maxLines: 1, overflow: TextOverflow.ellipsis, style: UMFont.body(size: 13, weight: FontWeight.w700)),
        Text(isZh ? '对' : 'vs', style: UMFont.caption(size: 9).copyWith(color: UMColors.textSecondary)),
        Text(d.away, maxLines: 1, overflow: TextOverflow.ellipsis, style: UMFont.body(size: 13, weight: FontWeight.w700)),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(d.countdown, maxLines: 1, style: UMFont.display(size: 20, weight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _medium(_WidgetData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _compLabel(d.comp),
        const Spacer(),
        Row(
          children: [
            Flexible(child: Text(d.home, maxLines: 1, overflow: TextOverflow.ellipsis, style: UMFont.body(size: 15, weight: FontWeight.w700))),
            const SizedBox(width: 8),
            Text(isZh ? '对' : 'vs', style: UMFont.caption(size: 11).copyWith(color: UMColors.textSecondary)),
            const SizedBox(width: 8),
            Flexible(child: Text(d.away, maxLines: 1, overflow: TextOverflow.ellipsis, style: UMFont.body(size: 15, weight: FontWeight.w700))),
          ],
        ),
        if (d.venue.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(d.venue, maxLines: 1, overflow: TextOverflow.ellipsis, style: UMFont.caption(size: 11).copyWith(color: UMColors.textSecondary)),
          ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(d.countdown, maxLines: 1, style: UMFont.display(size: 22, weight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _brandLogo(48),
          const SizedBox(height: 6),
          Text(isZh ? '暂无比赛' : 'No match',
              style: UMFont.caption(size: 11).copyWith(color: UMColors.textTertiary)),
        ],
      ),
    );
  }
}

/// 锁屏小组件演示 (圆形 / 矩形 / 内嵌)。锁屏附件由系统单色着色，
/// 这里用深色"锁屏"底 + 白色内容近似呈现。
class _LockScreenDemo extends StatelessWidget {
  const _LockScreenDemo({required this.data, required this.isZh, required this.s});
  final _WidgetData? data;
  final bool isZh;
  final UMStrings s;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2D34), Color(0xFF15171C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _labeled(s.widgetCirc, _circular(d)),
              const SizedBox(width: 16),
              Expanded(child: _labeled(s.widgetRect, _rectangular(d))),
            ],
          ),
          const SizedBox(height: 16),
          _labeled(s.widgetInline, _inline(d), alignStart: true),
        ],
      ),
    );
  }

  Widget _labeled(String label, Widget child, {bool alignStart = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        child,
        const SizedBox(height: 6),
        Text(label, style: UMFont.caption(size: 10).copyWith(color: Colors.white54)),
      ],
    );
  }

  Widget _circular(_WidgetData? d) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _brandLogo(26),
          const SizedBox(height: 1),
          Text(d?.countdownShort ?? '—',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
        ],
      ),
    );
  }

  Widget _rectangular(_WidgetData? d) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _brandLogo(22),
            const SizedBox(width: 4),
            Flexible(
              child: Text(d?.comp ?? 'UMatch',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 2),
          Text(d != null ? '${d.home} vs ${d.away}' : (isZh ? '暂无比赛' : 'No match'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 1),
          Text(d?.countdown ?? '',
              maxLines: 1,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _inline(_WidgetData? d) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _brandLogo(26),
        const SizedBox(width: 5),
        Text(d != null ? '${d.home} – ${d.away}' : 'UMatch',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
  }
}

/// 灵动岛演示 (紧凑 / 展开)，用黑色胶囊近似呈现。
class _IslandDemo extends StatelessWidget {
  const _IslandDemo({required this.data, required this.isZh, required this.s});
  final _WidgetData? data;
  final bool isZh;
  final UMStrings s;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Column(
      children: [
        // Compact pill
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(22)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _brandLogo(32),
                const SizedBox(width: 20),
                Text(d?.countdownShort ?? '—',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(s.widgetCompact, style: UMFont.caption(size: 10).copyWith(color: UMColors.textTertiary)),
        const SizedBox(height: 16),
        // Expanded
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(28)),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(children: [
                      _brandLogo(28),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(d?.home ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ]),
                  ),
                  Text(d?.comp ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  Expanded(
                    child: Text(d?.away ?? '—',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(d?.countdown ?? (isZh ? '暂无比赛' : 'No match'),
                    maxLines: 1,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(s.widgetExp, style: UMFont.caption(size: 10).copyWith(color: UMColors.textTertiary)),
      ],
    );
  }
}
