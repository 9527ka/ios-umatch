import 'package:flutter/services.dart';

/// 灵动岛 / 锁屏 Live Activity 桥接 (iOS 16.1+)。
///
/// 调用链: WidgetSyncService.sync() → start/end。
/// 原生侧 ios/Runner/AppDelegate.swift 的 MethodChannel `com.uu.umatch/liveactivity`
/// 用 ActivityKit 开启/结束活动；倒计时由 kickoffEpoch 在原生侧用 Text(.timer) 实时渲染。
class LiveActivityService {
  static const _ch = MethodChannel('com.uu.umatch/liveactivity');

  /// 系统是否允许实时活动（用户可在设置中关闭）。非 iOS / 旧系统返回 false。
  static Future<bool> isEnabled() async {
    try {
      return (await _ch.invokeMethod<bool>('isEnabled')) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 为下一场比赛开启活动（原生侧幂等：同 kickoff 已在则跳过）。
  static Future<void> start({
    required String home,
    required String away,
    required String comp,
    required double kickoffEpoch,
  }) async {
    try {
      await _ch.invokeMethod('start', {
        'home': home,
        'away': away,
        'comp': comp,
        'kickoffEpoch': kickoffEpoch,
      });
    } catch (_) {
      // 旧系统 / 非 iOS / 未授权：静默忽略
    }
  }

  /// 结束所有 UMatch 活动。
  static Future<void> end() async {
    try {
      await _ch.invokeMethod('end');
    } catch (_) {}
  }
}
