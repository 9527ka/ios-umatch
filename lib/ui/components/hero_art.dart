import 'package:flutter/material.dart';
import '../../core/models/team.dart';

class HeroArt extends StatelessWidget {
  final Team homeTeam;
  final Team awayTeam;
  final double height;

  const HeroArt({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _HeroArtPainter(homeTeam, awayTeam),
      ),
    );
  }
}

class _HeroArtPainter extends CustomPainter {
  final Team homeTeam;
  final Team awayTeam;

  _HeroArtPainter(this.homeTeam, this.awayTeam);

  @override
  void paint(Canvas canvas, Size size) {
    // Home team radial gradient (left)
    final homeGradient = RadialGradient(
      center: const Alignment(-0.7, 0.0),
      radius: 0.8,
      colors: [
        homeTeam.primaryColor.withValues(alpha: 0.12),
        homeTeam.primaryColor.withValues(alpha: 0.0),
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = homeGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Away team radial gradient (right)
    final awayGradient = RadialGradient(
      center: const Alignment(0.7, 0.0),
      radius: 0.8,
      colors: [
        awayTeam.primaryColor.withValues(alpha: 0.12),
        awayTeam.primaryColor.withValues(alpha: 0.0),
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = awayGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Concentric stadium tier ellipses
    final center = Offset(size.width / 2, size.height * 0.6);
    final ellipsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.04);

    for (var i = 1; i <= 5; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width * 0.3 * i,
          height: size.height * 0.2 * i,
        ),
        ellipsePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_HeroArtPainter oldDelegate) =>
      homeTeam.id != oldDelegate.homeTeam.id || awayTeam.id != oldDelegate.awayTeam.id;
}
