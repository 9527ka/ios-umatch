import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/um_theme.dart';
import '../../core/models/models.dart';
import '../../core/store/match_store.dart';
import '../../l10n/um_strings.dart';
import '../components/crest.dart';
import '../detail/match_detail_view.dart';
import '../sheets/reminder_sheet.dart';
import '../../core/services/statistical_service.dart';

class MatchesView extends StatefulWidget {
  const MatchesView({super.key});

  @override
  State<MatchesView> createState() => _MatchesViewState();
}

class _MatchesViewState extends State<MatchesView> {

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MatchStore>();
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);

    final matches = store.upcoming();
    final grouped = store.groupedByDay(matches, locale);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(s.matches, style: UMFont.display(size: 32, weight: FontWeight.w700)),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          for (final entry in grouped.entries) ...[
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                color: UMColors.bg.withValues(alpha: 0.9),
                child: Text(
                  entry.key.toUpperCase(),
                  style: UMFont.caption(size: 12, tracking: 0.1).copyWith(
                    color: UMColors.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final m = entry.value[index];
                  return _CompactMatchRow(match: m, store: store, locale: locale);
                },
                childCount: entry.value.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _CompactMatchRow extends StatelessWidget {
  final Match match;
  final MatchStore store;
  final Locale locale;

  const _CompactMatchRow({required this.match, required this.store, required this.locale});

  @override
  Widget build(BuildContext context) {
    final home = store.team(match.homeTeamId);
    final away = store.team(match.awayTeamId);
    final comp = store.comp(match.competitionId);
    if (home == null || away == null || comp == null) return const SizedBox.shrink();

    final localKickoff = store.localize(match.kickoff);
    final time = '${localKickoff.hour.toString().padLeft(2, '0')}:${localKickoff.minute.toString().padLeft(2, '0')}';
    final notifying = store.isNotifying(match.id);

    return GestureDetector(
      onTap: () {
        HyStatistical.shared.track('view_match_detail', {
          'match_id': match.id,
          'comp': match.competitionId,
        });
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MatchDetailView(match: match)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Time stack
            SizedBox(
              width: 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(time, style: UMFont.countdown(size: 16)),
                  Text(comp.short.resolve(locale), style: UMFont.caption(size: 10).copyWith(color: UMColors.textTertiary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Matchup
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Crest(team: home, size: 44),
                      const SizedBox(width: 8),
                      Text(home.alias.resolve(locale), style: UMFont.body(size: 14, weight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Crest(team: away, size: 44),
                      const SizedBox(width: 8),
                      Text(away.alias.resolve(locale), style: UMFont.body(size: 14, weight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            // Bell button
            GestureDetector(
              onTap: () => showReminderSheet(context, match.id),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: notifying ? UMColors.primaryTint : Colors.transparent,
                ),
                child: Icon(
                  notifying ? Icons.notifications : Icons.notifications_outlined,
                  size: 20,
                  color: notifying ? UMColors.primary : UMColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
