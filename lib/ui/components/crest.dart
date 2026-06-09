import 'package:flutter/material.dart';
import '../../core/models/team.dart';

class Crest extends StatelessWidget {
  final Team team;
  final double size;

  const Crest({super.key, required this.team, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        child: Image.asset(
          'assets/team_logos/${team.id}.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    // 国家队用真实国旗作图标（公共符号，无版权风险）；
    // 俱乐部/协会徽标受版权保护，不内置真实 logo 图片。
    if (team.flag != null && team.flag!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFF1F5F9),
        ),
        alignment: Alignment.center,
        child: Text(
          team.flag!,
          style: TextStyle(fontSize: size * 0.6, height: 1),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [team.primaryColor, team.accentColor],
        ),
      ),
      child: Center(
        child: Text(
          team.short3,
          style: TextStyle(
            fontSize: size * 0.28,
            fontWeight: FontWeight.w900,
            color: team.primaryColor.computeLuminance() > 0.4
                ? const Color(0xFF0F172A)
                : Colors.white,
            letterSpacing: 0.5,
            height: 1,
          ),
        ),
      ),
    );
  }
}
