import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/um_theme.dart';
import '../../core/models/models.dart';
import '../../core/store/match_store.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/reminder_logo_store.dart';
import '../../core/services/statistical_service.dart';
import '../../core/services/widget_sync_service.dart';
import '../../l10n/um_strings.dart';
import '../components/reminder_logo_view.dart';

/// 统一入口：打开提醒设置底部弹窗（首页卡片 / 赛程列表 / 详情页 / 我的提醒共用）。
/// 内部走 [ReminderSheet] 的真实调度 + 权限 + 取消逻辑，支持自定义
/// 标题 / 球队名 / logo / 时间。
Future<void> showReminderSheet(BuildContext context, String matchId) {
  return showModalBottomSheet(
    context: context,
    // 内容随选项数量变化，用 scroll-controlled 让弹窗按内容高度展开
    // (默认上限约屏高 9/16，选项较多时会底部溢出)。
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(UMRadius.sheet)),
    ),
    builder: (_) => ReminderSheet(matchId: matchId),
  );
}

class ReminderSheet extends StatefulWidget {
  final String matchId;

  const ReminderSheet({super.key, required this.matchId});

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  NotifyLead _selected = NotifyLead.oneHour;
  DateTime? _customTime; // 非空 → 使用自定义具体时间，覆盖 _selected
  String _logo = ReminderLogo.home;
  bool _busy = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _teamCtrl;

  Match? _match;
  Team? _home;
  Team? _away;
  Competition? _comp;

  @override
  void initState() {
    super.initState();
    final store = context.read<MatchStore>();
    final idx = store.matches.indexWhere((m) => m.id == widget.matchId);
    _match = idx >= 0 ? store.matches[idx] : null;
    if (_match != null) {
      _home = store.team(_match!.homeTeamId);
      _away = store.team(_match!.awayTeamId);
      _comp = store.comp(_match!.competitionId);
    }

    final current = store.notify[widget.matchId];
    _selected = (current != null && current.enabled) ? current.lead : store.defaultLead;
    _logo = current?.logo ?? ReminderLogo.home;
    if (current?.customFireMs != null) {
      _customTime = DateTime.fromMillisecondsSinceEpoch(current!.customFireMs!);
    }
    _titleCtrl = TextEditingController(text: current?.title ?? '');
    _teamCtrl = TextEditingController(text: current?.team ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _teamCtrl.dispose();
    super.dispose();
  }

  // ── 兜底文案 ──
  String _defaultTitle(Locale locale) {
    if (_home != null && _away != null) {
      return '${_home!.alias.resolve(locale)} vs ${_away!.alias.resolve(locale)}';
    }
    return 'UMatch';
  }

  String _defaultTeam(Locale locale) {
    if (_comp != null && _match != null) {
      final stage = _match!.stage.resolve(locale);
      final comp = _comp!.name.resolve(locale);
      return stage.isEmpty ? comp : '$comp · $stage';
    }
    if (_home != null && _away != null) {
      return '${_home!.alias.resolve(locale)} · ${_away!.alias.resolve(locale)}';
    }
    return '';
  }

  /// 实际触发时间：自定义优先，否则 开赛 - 提前量。
  DateTime _resolveFireAt() {
    if (_customTime != null) return _customTime!;
    final kickoff = _match?.kickoff.toLocal() ?? DateTime.now();
    return kickoff.subtract(_selected.leadDuration);
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      final fileName = await ReminderLogoStore.save(picked.path, widget.matchId);
      if (!mounted) return;
      if (fileName != null) {
        setState(() => _logo = ReminderLogo.uploadValue(fileName));
      }
    } catch (_) {
      if (!mounted) return;
      final isZh = Localizations.localeOf(context).languageCode == 'zh';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isZh ? '无法读取所选图片' : 'Could not load the selected image'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickCustomTime() async {
    final now = DateTime.now();
    final lastDate = now.add(const Duration(days: 365));
    final base = _customTime ?? _resolveFireAt();
    var initial = base.isAfter(now) ? base : now.add(const Duration(minutes: 5));
    if (initial.isAfter(lastDate)) initial = lastDate; // 远期开赛时间夹回上限，避免 picker 断言
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: lastDate,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _customTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _confirm() async {
    if (_busy) return;
    final locale = Localizations.localeOf(context);
    final isZh = locale.languageCode == 'zh';

    final titleText = _titleCtrl.text.trim();
    if (titleText.length > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(UMStrings.of(locale).titleTooLong),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final teamText = _teamCtrl.text.trim();

    setState(() => _busy = true);
    final store = context.read<MatchStore>();

    final fireAt = _resolveFireAt();
    final kickoffLocal = _match != null ? store.localize(_match!.kickoff) : DateTime.now();
    final timeStr =
        '${kickoffLocal.hour.toString().padLeft(2, '0')}:${kickoffLocal.minute.toString().padLeft(2, '0')}';

    // 系统通知文案：用自定义标题(若有)，正文仍用比赛信息；logo/球队名仅作用于 App 内卡片
    final pushTitle = titleText.isNotEmpty ? titleText : _defaultTitle(locale);
    final venueName = _match?.venue.resolve(locale) ?? '';
    final body = isZh
        ? '$timeStr 在 $venueName 开赛，记得观看 ⚽'
        : 'Kicks off at $timeStr · $venueName ⚽';

    // 先持久化偏好 (含自定义字段)，再调度真实通知
    store.setNotify(
      widget.matchId,
      lead: _selected,
      title: titleText.isEmpty ? null : titleText,
      team: teamText.isEmpty ? null : teamText,
      logo: _logo,
      customFireMs: _customTime?.millisecondsSinceEpoch,
    );
    final ok = await NotificationService.shared.scheduleMatchReminder(
      matchId: widget.matchId,
      title: pushTitle,
      body: body,
      fireAt: fireAt,
      playSound: store.reminderSound,
    );

    // 同步到桌面小组件 (该比赛若为下一场，会反映自定义标题/球队名/logo/时间)
    await WidgetSyncService.sync(store, locale);

    if (!mounted) return;
    Navigator.pop(context);

    String msg;
    if (ok) {
      HyStatistical.shared.track('set_reminder', {
        'match_id': widget.matchId,
        'lead': _selected.key,
        'custom_time': _customTime != null,
        'logo': _logo,
      });
      msg = isZh ? '提醒已设置' : 'Reminder set';
    } else if (!fireAt.isAfter(DateTime.now())) {
      msg = isZh ? '该提醒时间已过' : 'That reminder time has passed';
    } else {
      // 权限被拒：偏好仍保存，但无法弹出系统通知
      store.disableNotify(widget.matchId);
      msg = isZh ? '请在系统设置中开启通知权限' : 'Enable notifications in Settings';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? UMColors.primary : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _cancel() async {
    final store = context.read<MatchStore>();
    final locale = Localizations.localeOf(context);
    final isZh = locale.languageCode == 'zh';
    store.disableNotify(widget.matchId);
    await NotificationService.shared.cancelMatchReminder(widget.matchId);
    await WidgetSyncService.sync(store, locale);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isZh ? '提醒已关闭' : 'Reminder removed'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatFireAt(DateTime t, Locale locale, MatchStore store) {
    final rel = store.relativeDay(t, locale);
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '$rel · $hm';
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);
    final isZh = locale.languageCode == 'zh';
    final store = context.read<MatchStore>();
    final isNotifying = store.isNotifying(widget.matchId);

    final leadToKey = {
      NotifyLead.oneDay: '1d',
      NotifyLead.threeHours: '3h',
      NotifyLead.oneHour: '1h',
      NotifyLead.fifteenMin: '15m',
      NotifyLead.kickoff: 'k',
    };

    return Container(
      decoration: const BoxDecoration(
        color: UMColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(UMRadius.sheet)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            // Drag handle —— 固定在顶部、非滚动区域，下拉此处即可关闭弹窗
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: UMColors.textQuaternary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(child: Text(s.customizeTitle, style: UMFont.display(size: 20, weight: FontWeight.w600))),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                // 给底部留出键盘高度，输入标题/球队名时不被遮挡
                padding: EdgeInsets.fromLTRB(24, 0, 24, 40 + MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 实时预览卡片 ──
                    _previewCard(locale, s, store),
            const SizedBox(height: 24),

            // ── 标题 ──
            _label(s.fieldTitle),
            const SizedBox(height: 8),
            _textField(_titleCtrl, _defaultTitle(locale)),
            const SizedBox(height: 16),

            // ── 球队名 ──
            _label(s.fieldTeam),
            const SizedBox(height: 8),
            _textField(_teamCtrl, _defaultTeam(locale)),
            const SizedBox(height: 16),

            // ── Logo ──
            _label(s.fieldLogo),
            const SizedBox(height: 10),
            _logoRow(s),
            const SizedBox(height: 16),

            // ── 时间 ──
            _label(s.fieldTime),
            const SizedBox(height: 10),
            _timeChips(s, leadToKey),
            const SizedBox(height: 24),

            // Confirm
            GestureDetector(
              onTap: _busy ? null : _confirm,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _busy ? UMColors.textQuaternary : UMColors.primary,
                  borderRadius: BorderRadius.circular(UMRadius.button),
                  boxShadow: UMShadows.ctaButton,
                ),
                child: _busy
                    ? const Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : Text(
                        s.confirm,
                        textAlign: TextAlign.center,
                        style: UMFont.body(size: 16, weight: FontWeight.w600).copyWith(color: Colors.white),
                      ),
              ),
            ),
            if (isNotifying) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _cancel,
                child: Text(
                  isZh ? '关闭提醒' : 'Remove Reminder',
                  style: UMFont.body(size: 14).copyWith(color: UMColors.textTertiary),
                ),
              ),
            ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: UMFont.caption(size: 12, weight: FontWeight.w700).copyWith(
          color: UMColors.textTertiary,
          letterSpacing: 0.8,
        ),
      );

  Widget _previewCard(Locale locale, UMStrings s, MatchStore store) {
    final titleText = _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : _defaultTitle(locale);
    final teamText = _teamCtrl.text.trim().isNotEmpty ? _teamCtrl.text.trim() : _defaultTeam(locale);
    final fireAt = _resolveFireAt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UMColors.primaryTint,
        borderRadius: BorderRadius.circular(UMRadius.card),
        border: Border.all(color: UMColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          ReminderLogoView(logo: _logo, home: _home, away: _away, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UMFont.body(size: 16, weight: FontWeight.w700),
                ),
                if (teamText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    teamText,
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
                        _formatFireAt(fireAt, locale, store),
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
        ],
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      onChanged: (_) => setState(() {}), // 实时更新预览
      maxLength: 60,
      style: UMFont.body(size: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: UMFont.body(size: 15).copyWith(color: UMColors.textQuaternary),
        counterText: '',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: UMColors.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UMRadius.small),
          borderSide: BorderSide(color: UMColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UMRadius.small),
          borderSide: const BorderSide(color: UMColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _logoRow(UMStrings s) {
    final uploaded = ReminderLogo.isUpload(_logo);
    return Row(
      children: [
        _logoOption(ReminderLogo.home, s.logoHome,
            ReminderLogoView(logo: ReminderLogo.home, home: _home, away: _away, size: 48)),
        const SizedBox(width: 12),
        _logoOption(ReminderLogo.away, s.logoAway,
            ReminderLogoView(logo: ReminderLogo.away, home: _home, away: _away, size: 48)),
        const SizedBox(width: 12),
        _logoOption(ReminderLogo.brand, s.logoBrand,
            ReminderLogoView(logo: ReminderLogo.brand, home: _home, away: _away, size: 48)),
        const SizedBox(width: 12),
        // 上传：选中态用 _logo 是否为 upload 判断；展示已上传缩略图或上传图标
        _logoTile(
          selected: uploaded,
          label: s.logoUpload,
          onTap: _pickLogo,
          child: uploaded
              ? ReminderLogoView(logo: _logo, home: _home, away: _away, size: 48)
              : Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF1F5F9),
                  ),
                  child: const Icon(Icons.add_a_photo_outlined, size: 20, color: UMColors.textTertiary),
                ),
        ),
      ],
    );
  }

  Widget _logoOption(String value, String label, Widget child) {
    return _logoTile(
      selected: _logo == value,
      label: label,
      onTap: () => setState(() => _logo = value),
      child: child,
    );
  }

  Widget _logoTile({
    required bool selected,
    required String label,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? UMColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: child,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UMFont.caption(size: 11, weight: selected ? FontWeight.w700 : FontWeight.w400)
                  .copyWith(color: selected ? UMColors.primary : UMColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeChips(UMStrings s, Map<NotifyLead, String> leadToKey) {
    final opts = s.remindOpts; // [[key, label], ...]
    NotifyLead leadOf(String key) => leadToKey.entries
        .firstWhere((e) => e.value == key, orElse: () => const MapEntry(NotifyLead.oneHour, '1h'))
        .key;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final opt in opts)
          _chip(
            label: opt[1],
            selected: _customTime == null && _selected == leadOf(opt[0]),
            onTap: () => setState(() {
              _customTime = null;
              _selected = leadOf(opt[0]);
            }),
          ),
        // 自定义具体时间
        _chip(
          label: _customTime != null
              ? '${s.timeCustom} · ${_customTime!.month}/${_customTime!.day} '
                  '${_customTime!.hour.toString().padLeft(2, '0')}:${_customTime!.minute.toString().padLeft(2, '0')}'
              : s.timeCustom,
          selected: _customTime != null,
          icon: Icons.event_outlined,
          onTap: _pickCustomTime,
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UMRadius.pill),
          border: Border.all(color: selected ? UMColors.primary : UMColors.border),
          color: selected ? UMColors.primaryTint : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? UMColors.primary : UMColors.textTertiary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: UMFont.body(size: 14, weight: selected ? FontWeight.w600 : FontWeight.w400)
                  .copyWith(color: selected ? UMColors.primary : UMColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
