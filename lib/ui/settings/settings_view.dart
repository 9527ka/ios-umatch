import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/um_theme.dart';
import '../../core/store/match_store.dart';
import '../../l10n/um_strings.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool get _isZh => Localizations.localeOf(context).languageCode == 'zh';

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? UMColors.primary : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showOptionSheet({
    required String title,
    required List<List<String>> options,
    required String currentKey,
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: UMColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: UMFont.display(size: 18, weight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              ...options.map((opt) => ListTile(
                title: Text(opt[1], style: UMFont.body(size: 15)),
                trailing: opt[0] == currentKey
                    ? const Icon(Icons.check_circle, color: UMColors.primary)
                    : null,
                onTap: () {
                  onSelect(opt[0]);
                  Navigator.pop(ctx);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showFavTeamsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer<MatchStore>(
        builder: (consumerCtx, store, _) {
          final locale = Localizations.localeOf(consumerCtx);
          final teams = store.allTeams();
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (sheetCtx, scrollController) => Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: UMColors.border, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_isZh ? '关注球队' : 'Favorite Teams', style: UMFont.display(size: 18, weight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: teams.length,
                    itemBuilder: (itemCtx, i) {
                      final team = teams[i];
                      final followed = store.followedTeams.contains(team.id);
                      return ListTile(
                        leading: team.flag != null
                            ? Text(team.flag!, style: const TextStyle(fontSize: 24))
                            : const SizedBox(width: 24),
                        title: Text(team.name.resolve(locale), style: UMFont.body(size: 15)),
                        trailing: Icon(
                          followed ? Icons.check_circle : Icons.circle_outlined,
                          color: followed ? UMColors.primary : UMColors.textQuaternary,
                        ),
                        onTap: () => store.toggleFollowTeam(team.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFavCompsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer<MatchStore>(
        builder: (consumerCtx, store, _) {
          final locale = Localizations.localeOf(consumerCtx);
          final comps = store.allComps();
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (sheetCtx, scrollController) => Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: UMColors.border, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_isZh ? '关注赛事' : 'Favorite Competitions', style: UMFont.display(size: 18, weight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: comps.length,
                    itemBuilder: (itemCtx, i) {
                      final comp = comps[i];
                      final followed = store.followedComps.contains(comp.id);
                      return ListTile(
                        title: Text(comp.name.resolve(locale), style: UMFont.body(size: 15)),
                        trailing: Icon(
                          followed ? Icons.check_circle : Icons.circle_outlined,
                          color: followed ? UMColors.primary : UMColors.textQuaternary,
                        ),
                        onTap: () => store.toggleFollowComp(comp.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 调起系统原生评分 (SKStoreReviewController)，无可用时提示
  Future<void> _rateApp() async {
    final inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
    } else if (mounted) {
      _snack(_isZh ? '当前无法评分，请稍后再试' : 'Rating unavailable right now');
    }
  }

  /// 外部浏览器打开隐私政策 / 服务条款链接
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _snack(_isZh ? '无法打开链接' : 'Unable to open link');
    }
  }

  /// 调起 iOS 原生分享面板
  void _shareApp() {
    final shareText = _isZh
        ? '推荐一个超棒的足球倒计时 App —— UMatch！再也不会错过任何比赛了 ⚽'
        : 'Check out UMatch — a beautiful football countdown app! Never miss a match again ⚽';
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);
    final store = context.watch<MatchStore>();

    final reminderOptions = s.remindOpts;
    final reminderKey = store.defaultLead.key;
    final currentReminder =
        reminderOptions.firstWhere((o) => o[0] == reminderKey, orElse: () => reminderOptions[2])[1];

    final soundOptions = _isZh
        ? [['on', '默认'], ['off', '无']]
        : [['on', 'Default'], ['off', 'None']];
    final soundKey = store.reminderSound ? 'on' : 'off';
    final currentSound = soundOptions.firstWhere((o) => o[0] == soundKey, orElse: () => soundOptions[0])[1];

    final teamCount = store.followedTeams.length;
    final compCount = store.followedComps.length;
    final favTeamsVal = _isZh ? '已关注 $teamCount 支' : '$teamCount teams';
    final favCompVal = _isZh ? '已选 $compCount 项' : '$compCount selected';

    final langOptions = s.languageOptions;
    final langKey = store.languagePref;
    final langVal = langOptions.firstWhere((o) => o[0] == langKey, orElse: () => langOptions[0])[1];

    final tzOptions = s.tzOptions;
    final tzKey = store.userTimezone;
    final dev = DateTime.now().timeZoneOffset;
    final devSign = dev.inHours >= 0 ? '+' : '';
    final autoVal = s.tzAutoVal('GMT$devSign${dev.inHours}');
    final tzVal = tzKey == 'auto'
        ? autoVal
        : tzOptions.firstWhere((o) => o[0] == tzKey, orElse: () => tzOptions[0])[1];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 12),
          Text(s.settings, style: UMFont.display(size: 32, weight: FontWeight.w700)),
          const SizedBox(height: 16),
          // Brand header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF1FAF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: UMColors.border),
              boxShadow: UMShadows.card,
            ),
            child: Row(
              children: [
                Image.asset('assets/brand/logo.png', width: 52, height: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('UMatch', style: UMFont.display(size: 19, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        _isZh ? '足球赛事倒计时' : 'Football match countdown',
                        style: UMFont.body(size: 13).copyWith(color: UMColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: UMColors.primaryTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'v1.0.0',
                    style: UMFont.body(size: 12, weight: FontWeight.w700).copyWith(color: UMColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _Section(
            title: s.setNotif,
            rows: [
              _Row(
                icon: Icons.notifications_active_outlined,
                iconColor: const Color(0xFF047857),
                label: s.setNotifDefault,
                trailing: currentReminder,
                onTap: () => _showOptionSheet(
                  title: s.setNotifDefault,
                  options: reminderOptions,
                  currentKey: reminderKey,
                  onSelect: (k) {
                    store.setDefaultLead(NotifyLead.fromKey(k));
                    _snack(_isZh ? '默认提醒已更新' : 'Default reminder updated', success: true);
                  },
                ),
              ),
              _Row(
                icon: Icons.volume_up_outlined,
                iconColor: const Color(0xFFF59E0B),
                label: s.setNotifSound,
                trailing: currentSound,
                onTap: () => _showOptionSheet(
                  title: s.setNotifSound,
                  options: soundOptions,
                  currentKey: soundKey,
                  onSelect: (k) {
                    store.setReminderSound(k == 'on');
                    _snack(_isZh ? '提示音已更新' : 'Sound updated', success: true);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: s.setPref,
            rows: [
              _Row(
                icon: Icons.flag_outlined,
                iconColor: const Color(0xFF3B82F6),
                label: s.setPrefFavTeams,
                trailing: favTeamsVal,
                onTap: _showFavTeamsSheet,
              ),
              _Row(
                icon: Icons.emoji_events_outlined,
                iconColor: const Color(0xFFEAB308),
                label: s.setPrefFavComp,
                trailing: favCompVal,
                onTap: _showFavCompsSheet,
              ),
              _Row(
                icon: Icons.public,
                iconColor: const Color(0xFF14B8A6),
                label: s.setPrefTz,
                trailing: tzVal,
                onTap: () => _showOptionSheet(
                  title: s.setPrefTz,
                  options: tzOptions,
                  currentKey: tzKey,
                  onSelect: (k) {
                    store.setUserTimezone(k);
                    _snack(_isZh ? '时区已更新' : 'Timezone updated', success: true);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: s.setApp,
            rows: [
              _Row(
                icon: Icons.translate,
                iconColor: const Color(0xFF6366F1),
                label: s.setAppLanguage,
                trailing: langVal,
                onTap: () => _showOptionSheet(
                  title: s.setAppLanguage,
                  options: langOptions,
                  currentKey: langKey,
                  onSelect: (k) {
                    store.setLanguage(k);
                    _snack(_isZh ? '语言已更新' : 'Language updated', success: true);
                  },
                ),
              ),
              _Row(
                icon: Icons.brightness_6_outlined,
                iconColor: const Color(0xFF8B5CF6),
                label: s.setAppTheme,
                trailing: _isZh ? '浅色' : 'Light',
                onTap: () => _snack(_isZh ? '深色模式即将推出' : 'Dark mode coming soon'),
              ),
              _Row(
                icon: Icons.apps_outlined,
                iconColor: const Color(0xFFEC4899),
                label: s.setAppIcon,
                trailing: _isZh ? '默认' : 'Default',
                onTap: () => _snack(_isZh ? '更多图标即将推出' : 'More icons coming soon'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: s.setAbout,
            rows: [
              _Row(
                icon: Icons.star_outline_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: s.setRate,
                onTap: _rateApp,
              ),
              _Row(
                icon: Icons.ios_share,
                iconColor: const Color(0xFF3B82F6),
                label: s.setShare,
                onTap: _shareApp,
              ),
              _Row(
                icon: Icons.lock_outline,
                iconColor: const Color(0xFF10B981),
                label: s.setPrivacy,
                onTap: () => _openUrl('https://api.umatchai.com/umatch/privacy.html'),
              ),
              _Row(
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF64748B),
                label: s.setTerms,
                onTap: () => _openUrl('https://api.umatchai.com/umatch/terms.html'),
              ),
              _Row(
                icon: Icons.info_outline_rounded,
                iconColor: const Color(0xFF64748B),
                label: s.setVersion,
                trailing: '1.0.1',
                showChevron: false,
              ),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ── Section card ──
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> rows;

  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: UMFont.caption(size: 12, tracking: 0.08).copyWith(
              color: UMColors.textTertiary,
              letterSpacing: 1,
            ),
          ),
        ),
        Material(
          color: UMColors.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: UMColors.border),
              boxShadow: UMShadows.card,
            ),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i < rows.length - 1)
                    Divider(height: 1, indent: 56, endIndent: 16, color: UMColors.border),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tappable row ──
class _Row extends StatelessWidget {
  final String label;
  final String? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? iconColor;

  const _Row({
    required this.label,
    this.trailing,
    this.showChevron = true,
    this.onTap,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? UMColors.primary;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UMFont.body(size: 15),
                ),
              ),
              if (trailing != null && trailing!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  trailing!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UMFont.body(size: 14).copyWith(color: UMColors.textTertiary),
                ),
              ],
              if (showChevron && onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 20, color: UMColors.textQuaternary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
