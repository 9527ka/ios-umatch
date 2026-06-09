import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/um_theme.dart';
import '../../core/models/models.dart';
import '../../core/store/match_store.dart';
import '../sheets/reminder_sheet.dart';
import 'crest.dart';
import 'comp_logo.dart';
import 'notify_pill.dart';

class UpcomingCard extends StatelessWidget {
  final Match match;
  final VoidCallback? onTap;

  const UpcomingCard({super.key, required this.match, this.onTap});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MatchStore>();
    final locale = Localizations.localeOf(context);
    final home = store.team(match.homeTeamId);
    final away = store.team(match.awayTeamId);
    final comp = store.comp(match.competitionId);
    if (home == null || away == null || comp == null) return const SizedBox.shrink();

    final localKickoff = store.localize(match.kickoff);
    final relDay = store.relativeDay(localKickoff, locale);
    final time = '${localKickoff.hour.toString().padLeft(2, '0')}:${localKickoff.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UMColors.surface,
          borderRadius: BorderRadius.circular(UMRadius.card),
          border: Border.all(color: UMColors.border),
          boxShadow: UMShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: comp logo + comp name · stage
            Row(
              children: [
                CompLogo(comp: comp, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${comp.name.resolve(locale)} · ${match.stage.resolve(locale)}',
                  style: UMFont.caption(size: 11).copyWith(color: UMColors.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Middle: matchup
            Row(
              children: [
                Crest(team: home, size: 36),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    home.alias.resolve(locale),
                    style: UMFont.body(size: 14, weight: FontWeight.w600),
                  ),
                ),
                Text(
                  'vs',
                  style: UMFont.body(size: 13, weight: FontWeight.w300).copyWith(
                    color: UMColors.textPrimary.withValues(alpha: 0.3),
                  ),
                ),
                Expanded(
                  child: Text(
                    away.alias.resolve(locale),
                    textAlign: TextAlign.right,
                    style: UMFont.body(size: 14, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Crest(team: away, size: 36),
              ],
            ),
            const SizedBox(height: 12),
            // Bottom: date/time + notify pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$relDay · $time',
                  style: UMFont.body(size: 13).copyWith(color: UMColors.textSecondary),
                ),
                NotifyPill(
                  active: store.isNotifying(match.id),
                  onTap: () => showReminderSheet(context, match.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
