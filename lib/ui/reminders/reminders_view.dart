import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/um_theme.dart';
import '../../core/models/models.dart';
import '../../core/store/match_store.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/widget_sync_service.dart';
import '../../l10n/um_strings.dart';
import '../components/reminder_logo_view.dart';
import '../sheets/reminder_sheet.dart';

/// 「我的提醒」列表：展示所有已开启的提醒卡片 (自定义标题/球队名/logo/时间)。
/// 入口：首页右上角通知按钮。点击卡片可重新编辑，右侧可删除。
class RemindersView extends StatelessWidget {
  const RemindersView({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);
    final store = context.watch<MatchStore>();
    final reminders = store.activeReminders();

    return Scaffold(
      backgroundColor: UMColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: UMColors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(s.myReminders, style: UMFont.display(size: 22, weight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: reminders.isEmpty
                  ? _empty(s)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: reminders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final entry = reminders[i];
                        return _ReminderCard(matchId: entry.key, cfg: entry.value);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(UMStrings s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded, size: 56, color: UMColors.textQuaternary),
            const SizedBox(height: 16),
            Text(s.noReminders, style: UMFont.display(size: 18, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              s.noRemindersSub,
              textAlign: TextAlign.center,
              style: UMFont.body(size: 14).copyWith(color: UMColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final String matchId;
  final NotifyConfig cfg;

  const _ReminderCard({required this.matchId, required this.cfg});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);
    final store = context.read<MatchStore>();

    final idx = store.matches.indexWhere((m) => m.id == matchId);
    final Match? match = idx >= 0 ? store.matches[idx] : null;
    final home = match != null ? store.team(match.homeTeamId) : null;
    final away = match != null ? store.team(match.awayTeamId) : null;
    final comp = match != null ? store.comp(match.competitionId) : null;

    final title = (cfg.title != null && cfg.title!.isNotEmpty)
        ? cfg.title!
        : (home != null && away != null
            ? '${home.alias.resolve(locale)} vs ${away.alias.resolve(locale)}'
            : 'UMatch');

    String teamLine;
    if (cfg.team != null && cfg.team!.isNotEmpty) {
      teamLine = cfg.team!;
    } else if (comp != null && match != null) {
      final stage = match.stage.resolve(locale);
      final c = comp.name.resolve(locale);
      teamLine = stage.isEmpty ? c : '$c · $stage';
    } else {
      teamLine = '';
    }

    final fireAt = store.reminderFireAt(matchId, cfg);
    final rel = store.relativeDay(fireAt, locale);
    final hm = '${fireAt.hour.toString().padLeft(2, '0')}:${fireAt.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => showReminderSheet(context, matchId),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UMColors.surface,
          borderRadius: BorderRadius.circular(UMRadius.card),
          border: Border.all(color: UMColors.border),
          boxShadow: UMShadows.card,
        ),
        child: Row(
          children: [
            ReminderLogoView(logo: cfg.logo, home: home, away: away, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UMFont.body(size: 16, weight: FontWeight.w700),
                  ),
                  if (teamLine.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      teamLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UMFont.body(size: 13).copyWith(color: UMColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, size: 13, color: UMColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$rel · $hm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UMFont.caption(size: 12, weight: FontWeight.w600).copyWith(color: UMColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: UMColors.textTertiary),
              tooltip: s.delete,
              onPressed: () async {
                store.disableNotify(matchId);
                await NotificationService.shared.cancelMatchReminder(matchId);
                await WidgetSyncService.sync(store, locale);
              },
            ),
          ],
        ),
      ),
    );
  }
}
