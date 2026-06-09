import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import '../../app/root_view.dart';
import '../../core/theme/um_theme.dart';
import '../../core/models/models.dart';
import '../../core/store/match_store.dart';
import '../../l10n/um_strings.dart';
import '../components/crest.dart';
import '../components/comp_logo.dart';
import '../components/countdown_display.dart';
import '../components/hero_art.dart';
import '../sheets/reminder_sheet.dart';

class MatchDetailView extends StatelessWidget {
  final Match match;

  const MatchDetailView({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MatchStore>();
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);
    final home = store.team(match.homeTeamId);
    final away = store.team(match.awayTeamId);
    final comp = store.comp(match.competitionId);
    if (home == null || away == null || comp == null) return const SizedBox.shrink();

    final localKickoff = store.localize(match.kickoff);

    return Scaffold(
      backgroundColor: UMColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 56),
                // Competition banner
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: UMColors.surface,
                      borderRadius: BorderRadius.circular(UMRadius.pill),
                      border: Border.all(color: UMColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CompLogo(comp: comp, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${comp.name.resolve(locale)} · ${match.stage.resolve(locale)}',
                          style: UMFont.body(size: 13).copyWith(color: UMColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Big matchup with hero art
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      HeroArt(homeTeam: home, awayTeam: away, height: 200),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Crest(team: home, size: 88),
                                const SizedBox(height: 8),
                                Text(home.alias.resolve(locale), style: UMFont.body(size: 14, weight: FontWeight.w600)),
                                if (home.rank != null)
                                  Text(home.rank!.resolve(locale), style: UMFont.caption(size: 11).copyWith(color: UMColors.textTertiary)),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                'VS',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w300,
                                  color: UMColors.textPrimary.withValues(alpha: 0.25),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Crest(team: away, size: 88),
                                const SizedBox(height: 8),
                                Text(away.alias.resolve(locale), style: UMFont.body(size: 14, weight: FontWeight.w600)),
                                if (away.rank != null)
                                  Text(away.rank!.resolve(locale), style: UMFont.caption(size: 11).copyWith(color: UMColors.textTertiary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Meta block
                Center(
                  child: Column(
                    children: [
                      Text(
                        _formatFullDate(localKickoff, locale),
                        style: UMFont.body(size: 14, weight: FontWeight.w600).copyWith(color: UMColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatTime(localKickoff)} · ${match.venue.resolve(locale)}',
                        style: UMFont.body(size: 13).copyWith(color: UMColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        match.city.resolve(locale),
                        style: UMFont.body(size: 13).copyWith(color: UMColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Mega countdown
                Center(child: CountdownDisplay(kickoff: match.kickoff, showSeconds: true, numSize: 54)),
                const SizedBox(height: 28),
                // Action row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: store.isNotifying(match.id) ? Icons.notifications_active : Icons.notifications_outlined,
                      label: s.actRemind,
                      onTap: () => showReminderSheet(context, match.id),
                    ),
                    _ActionButton(
                      icon: Icons.calendar_today_outlined,
                      label: s.actCal,
                      onTap: () => _addToCalendar(context, home, away, comp, match, locale),
                    ),
                    _ActionButton(
                      icon: Icons.widgets_outlined,
                      label: s.actWidget,
                      onTap: () {
                        Navigator.pop(context);
                        const SwitchTabNotification(1).dispatch(context);
                      },
                    ),
                    _ActionButton(
                      icon: Icons.share_outlined,
                      label: s.actShare,
                      onTap: () => _shareMatch(context, home, away, comp, match, locale),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Players to Watch
                if (match.keyPlayers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(s.playersToWatch, style: UMFont.display(size: 18, weight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: match.keyPlayers.length,
                      separatorBuilder: (_, i) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final player = match.keyPlayers[index];
                        return _PlayerCard(player: player, locale: locale);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 60),
              ],
            ),
            // Top nav
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                  Row(
                    children: [
                      _NavButton(icon: Icons.share_outlined, onTap: () => _shareMatch(context, home, away, comp, match, locale)),
                      const SizedBox(width: 8),
                      _NavButton(
                        icon: store.favorites.contains(match.id) ? Icons.favorite : Icons.favorite_border,
                        onTap: () => store.toggleFavorite(match.id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFullDate(DateTime d, Locale locale) {
    final isZh = locale.languageCode == 'zh';
    if (isZh) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return '${d.year}年${d.month}月${d.day}日 ${weekdays[d.weekday - 1]}';
    }
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatTime(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  bool _isZh(Locale locale) => locale.languageCode == 'zh';

  /// 调用 iOS 原生分享面板
  Future<void> _shareMatch(BuildContext context, Team home, Team away, Competition comp, Match match, Locale locale) async {
    final isZh = _isZh(locale);
    final tzKickoff = context.read<MatchStore>().localize(match.kickoff);
    final date = _formatFullDate(tzKickoff, locale);
    final time = _formatTime(tzKickoff);
    final subject = '${home.alias.resolve(locale)} vs ${away.alias.resolve(locale)}';
    final text = isZh
        ? '⚽ $subject\n${comp.name.resolve(locale)} · ${match.stage.resolve(locale)}\n📅 $date $time\n📍 ${match.venue.resolve(locale)}\n\n来自 UMatch'
        : '⚽ $subject\n${comp.name.resolve(locale)} · ${match.stage.resolve(locale)}\n📅 $date $time\n📍 ${match.venue.resolve(locale)}\n\nShared via UMatch';
    // iPad 必须提供 sharePositionOrigin，否则原生端会抛异常；iPhone 可选。
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await Share.share(text, subject: subject, sharePositionOrigin: origin);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isZh ? '无法打开分享面板' : 'Could not open share sheet'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 调用 iOS 日历添加事件
  Future<void> _addToCalendar(BuildContext context, Team home, Team away, Competition comp, Match match, Locale locale) async {
    final isZh = _isZh(locale);
    final event = cal.Event(
      title: '${home.alias.resolve(locale)} vs ${away.alias.resolve(locale)}',
      description: '${comp.name.resolve(locale)} · ${match.stage.resolve(locale)}',
      location: '${match.venue.resolve(locale)}, ${match.city.resolve(locale)}',
      startDate: match.kickoff.toLocal(),
      endDate: match.kickoff.toLocal().add(const Duration(hours: 2)),
      iosParams: const cal.IOSParams(reminder: Duration(hours: 1)),
    );
    final ok = await cal.Add2Calendar.addEvent2Cal(event);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? (isZh ? '已打开日历，请确认添加' : 'Calendar opened, please confirm')
            : (isZh ? '无法打开日历' : 'Could not open Calendar')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? UMColors.primary : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: UMColors.surface,
          border: Border.all(color: UMColors.border),
          boxShadow: UMShadows.card,
        ),
        child: Icon(icon, size: 20, color: UMColors.textSecondary),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: UMColors.surface,
              border: Border.all(color: UMColors.border),
              boxShadow: UMShadows.card,
            ),
            child: Icon(icon, size: 24, color: UMColors.primary),
          ),
          const SizedBox(height: 6),
          Text(label, style: UMFont.caption(size: 11).copyWith(color: UMColors.textSecondary)),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final Player player;
  final Locale locale;

  const _PlayerCard({required this.player, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UMColors.surface,
        borderRadius: BorderRadius.circular(UMRadius.small),
        border: Border.all(color: UMColors.border),
      ),
      child: Column(
        children: [
          ClipOval(
            child: Container(
              width: 56,
              height: 56,
              color: UMColors.bgAlt,
              child: player.photoSlug != null
                  ? Image.asset(
                      'assets/player_photos/${player.photoSlug}.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => Icon(Icons.person, size: 28, color: UMColors.textTertiary),
                    )
                  : Icon(Icons.person, size: 28, color: UMColors.textTertiary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            player.name.resolve(locale),
            style: UMFont.body(size: 12, weight: FontWeight.w700),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '#${player.number} · ${player.position.resolve(locale)}',
            style: UMFont.caption(size: 10).copyWith(color: UMColors.textSecondary),
          ),
          const Spacer(),
          Text(
            player.seasonStat.resolve(locale),
            style: UMFont.caption(size: 10).copyWith(color: UMColors.primary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
