import 'package:flutter/material.dart';
import '../../core/models/competition.dart';

class CompLogo extends StatelessWidget {
  final Competition comp;
  final double size;

  const CompLogo({super.key, required this.comp, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/comp_logos/${comp.id}.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, e, s) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: comp.accentColor,
      ),
      child: Center(
        child: Text(
          comp.glyph,
          style: TextStyle(
            fontSize: size * 0.5,
            color: Colors.white,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
