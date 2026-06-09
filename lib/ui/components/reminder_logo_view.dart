import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/models/team.dart';
import '../../core/store/match_store.dart';
import '../../core/services/reminder_logo_store.dart';
import 'crest.dart';

/// 按 [logo] 选择渲染提醒图标：
/// - ReminderLogo.home / away → 对应球队徽标 (Crest)
/// - ReminderLogo.brand       → App 品牌 logo
/// - `upload:<filename>`      → 用户上传并持久化的图片
/// - 其它/null                → 主队徽标兜底
class ReminderLogoView extends StatelessWidget {
  final String? logo;
  final Team? home;
  final Team? away;
  final double size;

  const ReminderLogoView({
    super.key,
    required this.logo,
    required this.home,
    required this.away,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    if (ReminderLogo.isUpload(logo)) {
      final path = ReminderLogoStore.pathFor(ReminderLogo.fileName(logo!));
      if (path != null && File(path).existsSync()) {
        return ClipOval(
          child: Image.file(
            File(path),
            width: size,
            height: size,
            fit: BoxFit.cover,
            // 文件读取失败时退回主队徽标
            errorBuilder: (_, _, _) => _builtin(ReminderLogo.home),
          ),
        );
      }
      return _builtin(ReminderLogo.home);
    }
    return _builtin(logo ?? ReminderLogo.home);
  }

  Widget _builtin(String which) {
    switch (which) {
      case ReminderLogo.brand:
        return ClipOval(
          child: Container(
            width: size,
            height: size,
            color: Colors.white,
            padding: EdgeInsets.all(size * 0.12),
            child: Image.asset('assets/brand/logo.png', fit: BoxFit.contain),
          ),
        );
      case ReminderLogo.away:
        return away != null
            ? Crest(team: away!, size: size)
            : _placeholder();
      case ReminderLogo.home:
      default:
        return home != null
            ? Crest(team: home!, size: size)
            : _placeholder();
    }
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFF1F5F9),
        ),
        child: Icon(Icons.sports_soccer, size: size * 0.5, color: const Color(0xFF94A3B8)),
      );
}
