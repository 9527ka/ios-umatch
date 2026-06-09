import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/um_theme.dart';
import '../../core/store/match_store.dart';
import '../../l10n/um_strings.dart';
import '../components/crest.dart';
import '../components/comp_logo.dart';
import '../components/countdown_display.dart';
import '../components/hero_art.dart';
import '../components/upcoming_card.dart';
import '../components/notify_pill.dart';
import '../../app/root_view.dart';
import '../detail/match_detail_view.dart';
import '../reminders/reminders_view.dart';
import '../sheets/reminder_sheet.dart';
import '../../core/services/statistical_service.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MatchStore>();
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);
    final heroMatch = store.hero();
    final upcoming = store.upcomingOrRecent().where((m) => m.id != heroMatch?.id).take(4).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 12),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.brand, style: UMFont.display(size: 22, weight: FontWeight.w700)),
              Row(
                children: [
                  _HeaderButton(
                    icon: Icons.notifications_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RemindersView()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HeaderButton(
                    icon: Icons.settings_outlined,
                    onTap: () => const SwitchTabNotification(4).dispatch(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Hero card
          if (heroMatch != null) _buildHeroCard(context, heroMatch, store, locale, s),
          const SizedBox(height: UMSpace.xl),
          // Upcoming
          if (upcoming.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.upcoming, style: UMFont.display(size: 20, weight: FontWeight.w600)),
                GestureDetector(
                  onTap: () => const SwitchTabNotification(2).dispatch(context),
                  child: Text(s.seeAll, style: UMFont.body(size: 13).copyWith(color: UMColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...upcoming.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: UpcomingCard(
                match: m,
                onTap: () => _openDetail(context, m),
              ),
            )),
          ],
          // Empty state
          if (heroMatch == null && upcoming.isEmpty) _buildEmpty(s),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, match, MatchStore store, Locale locale, UMStrings s) {
    final home = store.team(match.homeTeamId);
    final away = store.team(match.awayTeamId);
    final comp = store.comp(match.competitionId);
    if (home == null || away == null || comp == null) return const SizedBox.shrink();

    final localKickoff = store.localize(match.kickoff);
    final dateStr = _formatFullDate(localKickoff, locale);

    // 自定义提醒：Hero 卡反映自定义标题/球队名，倒计时倒到自定义时间
    final cfg = store.notify[match.id];
    final customized = cfg != null && cfg.enabled;
    final customTitle = (customized && (cfg.title?.isNotEmpty ?? false)) ? cfg.title! : null;
    final subtitle = (customized && (cfg.team?.isNotEmpty ?? false))
        ? cfg.team!
        : '${comp.name.resolve(locale)} · ${match.stage.resolve(locale)}';
    final countdownTarget = (customized && cfg.customFireMs != null)
        ? DateTime.fromMillisecondsSinceEpoch(cfg.customFireMs!)
        : match.kickoff;

    return GestureDetector(
      onTap: () => _openDetail(context, match),
      child: Container(
        decoration: BoxDecoration(
          color: UMColors.surface,
          borderRadius: BorderRadius.circular(UMRadius.card),
          border: Border.all(color: UMColors.border),
          boxShadow: UMShadows.raised,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            HeroArt(homeTeam: home, awayTeam: away, height: 340),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Tag
                  Text(
                    s.nextBig,
                    style: UMFont.caption(size: 11, tracking: 0.15).copyWith(
                      color: UMColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  // 自定义标题
                  if (customTitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      customTitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: UMFont.display(size: 18, weight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Comp + stage (或自定义球队名)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UMFont.body(size: 13).copyWith(color: UMColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      CompLogo(comp: comp, size: 18),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Matchup
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Crest(team: home, size: 60),
                          const SizedBox(height: 8),
                          Text(
                            home.alias.resolve(locale),
                            style: UMFont.body(size: 14, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            color: UMColors.textPrimary.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Crest(team: away, size: 60),
                          const SizedBox(height: 8),
                          Text(
                            away.alias.resolve(locale),
                            style: UMFont.body(size: 14, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Countdown
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: CountdownDisplay(kickoff: countdownTarget, showSeconds: true, numSize: 54),
                  ),
                  const SizedBox(height: 20),
                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateStr,
                              style: UMFont.body(size: 12).copyWith(color: UMColors.textSecondary),
                            ),
                            Text(
                              match.venue.resolve(locale),
                              style: UMFont.body(size: 12).copyWith(color: UMColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: UMColors.textPrimary,
                          borderRadius: BorderRadius.circular(UMRadius.pill),
                        ),
                        child: Text(
                          '${s.viewBtn} →',
                          style: UMFont.body(size: 13, weight: FontWeight.w600).copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 自定义 / 提醒入口
            Positioned(
              top: 14,
              right: 14,
              child: NotifyPill(
                active: customized,
                onTap: () => showReminderSheet(context, match.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(UMStrings s) {
    return Column(
      children: [
        const SizedBox(height: 80),
        Image.asset('assets/brand/logo.png', width: 80, height: 80),
        const SizedBox(height: 20),
        Text(s.emptyTitle, style: UMFont.display(size: 22, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          s.emptyBody,
          textAlign: TextAlign.center,
          style: UMFont.body(size: 14).copyWith(color: UMColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(UMRadius.button),
            border: Border.all(color: UMColors.border),
          ),
          child: Text(s.emptyCta, style: UMFont.body(size: 14, weight: FontWeight.w600).copyWith(color: UMColors.textSecondary)),
        ),
      ],
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

  void _openDetail(BuildContext context, match) {
    HyStatistical.shared.track('view_match_detail', {
      'match_id': match.id,
      'comp': match.competitionId,
    });
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MatchDetailView(match: match)),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

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
