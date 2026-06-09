import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:home_widget/home_widget.dart';
import '../models/team.dart';
import '../store/match_store.dart';
import 'live_activity_service.dart';
import 'reminder_logo_store.dart';

/// 把"下一场比赛"推送到 iOS 主屏小组件 (WidgetKit)。
///
/// 数据经 App Group `group.com.uu.umatch` 共享，原生侧
/// (ios/widgets/widgets.swift) 用相同 key 读出并显示倒计时。
///
/// 若该比赛设置了自定义提醒(标题/球队名/logo/时间)，会一并同步：
/// - customTitle / customTeam：自定义文案
/// - targetEpoch：自定义提醒时间(秒)，>0 时小组件倒计时倒到该时间
/// - reminderLogo：渲染好的 logo PNG 在 App Group 容器内的绝对路径
///
/// 调用链: RootView.initState / 应用恢复前台 / 确认&取消提醒 → sync()
class WidgetSyncService {
  static const _appGroupId = 'group.com.uu.umatch';
  static const _iosWidgetName = 'widgets'; // 与 widgets.swift 中 kind 一致

  static Future<void> sync(MatchStore store, Locale locale) async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);

      // 小组件总开关关闭：清空所有 WidgetKit 数据 + 结束 Live Activity，
      // 灵动岛 / 主屏幕 / 锁屏小组件统一进入空状态。
      final match = store.widgetsEnabled ? store.hero() : null;
      if (match == null) {
        await HomeWidget.saveWidgetData<double>('kickoffEpoch', 0);
        await _clearCustom();
        await LiveActivityService.end();
        await HomeWidget.updateWidget(iOSName: _iosWidgetName);
        return;
      }

      final home = store.team(match.homeTeamId);
      final away = store.team(match.awayTeamId);
      final comp = store.comp(match.competitionId);
      final homeName = home?.alias.resolve(locale) ?? '';
      final awayName = away?.alias.resolve(locale) ?? '';
      final compName = comp?.short.resolve(locale) ?? '';
      final kickoffEpoch = match.kickoff.millisecondsSinceEpoch / 1000.0;
      await HomeWidget.saveWidgetData<String>('home', homeName);
      await HomeWidget.saveWidgetData<String>('away', awayName);
      await HomeWidget.saveWidgetData<String>('comp', compName);
      await HomeWidget.saveWidgetData<String>('stage', match.stage.resolve(locale));
      await HomeWidget.saveWidgetData<String>('venue', match.venue.resolve(locale));
      await HomeWidget.saveWidgetData<double>('kickoffEpoch', kickoffEpoch);

      // ── 自定义提醒同步 ──
      final cfg = store.notify[match.id];
      final customized = cfg != null && cfg.enabled;
      if (customized) {
        await HomeWidget.saveWidgetData<String>('customTitle', cfg.title ?? '');
        await HomeWidget.saveWidgetData<String>('customTeam', cfg.team ?? '');
        await HomeWidget.saveWidgetData<double>(
          'targetEpoch',
          cfg.customFireMs != null ? cfg.customFireMs! / 1000.0 : 0,
        );
        await _syncLogo(cfg.logo ?? ReminderLogo.home, home, away);
      } else {
        await _clearCustom();
      }

      // 灵动岛 / 锁屏实时活动：自动跟随下一场 (原生侧幂等)
      await LiveActivityService.start(
        home: homeName,
        away: awayName,
        comp: compName,
        kickoffEpoch: kickoffEpoch,
      );

      await HomeWidget.updateWidget(iOSName: _iosWidgetName);
    } catch (_) {
      // 小组件未配置 App Group 或非 iOS 平台时静默忽略
    }
  }

  static Future<void> _clearCustom() async {
    await HomeWidget.saveWidgetData<String>('customTitle', '');
    await HomeWidget.saveWidgetData<String>('customTeam', '');
    await HomeWidget.saveWidgetData<double>('targetEpoch', 0);
    await HomeWidget.saveWidgetData<String>('reminderLogo', '');
  }

  /// 把选中的 logo 渲染成 PNG 写入 App Group 容器，路径存到 `reminderLogo` key。
  static Future<void> _syncLogo(String logo, Team? home, Team? away) async {
    final bytes = await _logoPngBytes(logo, home, away);
    if (bytes != null) {
      await HomeWidget.saveFile('reminderLogo', bytes, extension: 'png', appGroupId: _appGroupId);
    } else {
      await HomeWidget.saveWidgetData<String>('reminderLogo', '');
    }
  }

  static Future<Uint8List?> _logoPngBytes(String logo, Team? home, Team? away) async {
    try {
      if (ReminderLogo.isUpload(logo)) {
        final path = ReminderLogoStore.pathFor(ReminderLogo.fileName(logo));
        if (path != null && await File(path).exists()) {
          return await File(path).readAsBytes();
        }
        return null;
      }
      if (logo == ReminderLogo.brand) {
        final data = await rootBundle.load('assets/brand/logo.png');
        return data.buffer.asUint8List();
      }
      final team = logo == ReminderLogo.away ? away : home;
      if (team == null) return null;
      return await _renderCrestPng(team);
    } catch (_) {
      return null;
    }
  }

  /// 用 dart:ui 直接画出与 App 内 Crest 一致的徽标 (国旗 emoji 或 渐变+缩写)，
  /// 避免依赖图片资源/BuildContext，渲染同步可靠。
  static Future<Uint8List> _renderCrestPng(Team team) async {
    const size = 144.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);
    const radius = size / 2;

    if (team.flag != null && team.flag!.isNotEmpty) {
      canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFF1F5F9));
      _drawCenteredText(canvas, team.flag!, size * 0.6, const Color(0xFF0F172A), size);
    } else {
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(size, size),
          [team.primaryColor, team.accentColor],
        );
      canvas.drawCircle(center, radius, paint);
      final textColor = team.primaryColor.computeLuminance() > 0.4
          ? const Color(0xFF0F172A)
          : const Color(0xFFFFFFFF);
      _drawCenteredText(canvas, team.short3, size * 0.28, textColor, size, bold: true);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static void _drawCenteredText(
    Canvas canvas,
    String text,
    double fontSize,
    Color color,
    double box, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w400,
          letterSpacing: bold ? 0.5 : 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((box - tp.width) / 2, (box - tp.height) / 2));
  }
}
