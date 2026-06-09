import 'package:flutter/material.dart';

class UMColors {
  static const bg = Color(0xFFF5F4F0);
  static const bgAlt = Color(0xFFEFEEE8);
  static const surface = Color(0xFFFFFFFF);
  static final border = const Color(0xFF0F172A).withValues(alpha: 0.08);
  static final borderHi = const Color(0xFF0F172A).withValues(alpha: 0.14);
  static const primary = Color(0xFF047857);
  static const primaryHi = Color(0xFF065F46);
  static final primaryTint = const Color(0xFF047857).withValues(alpha: 0.10);
  static const secondary = Color(0xFF1E40AF);
  static const warm = Color(0xFFC2410C);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textTertiary = Color(0xFF94A3B8);
  static const textQuaternary = Color(0xFFCBD5E1);
  static const success = Color(0xFF047857);
  static const warning = Color(0xFFD97706);
}

class UMSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 32;
}

class UMRadius {
  static const double card = 24;
  static const double button = 16;
  static const double pill = 999;
  static const double small = 12;
  static const double sheet = 28;
}

class UMFont {
  static TextStyle display({double size = 28, FontWeight weight = FontWeight.w600}) {
    return TextStyle(
      fontFamily: '.SF Pro Display',
      fontSize: size,
      fontWeight: weight,
      color: UMColors.textPrimary,
    );
  }

  static TextStyle countdown({double size = 60}) {
    return TextStyle(
      fontFamily: '.SF Pro Rounded',
      fontSize: size,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: UMColors.textPrimary,
    );
  }

  static TextStyle body({double size = 14, FontWeight weight = FontWeight.w400}) {
    return TextStyle(
      fontFamily: '.SF Pro Text',
      fontSize: size,
      fontWeight: weight,
      color: UMColors.textPrimary,
    );
  }

  static TextStyle caption({double size = 11, FontWeight weight = FontWeight.w700, double tracking = 0.08}) {
    return TextStyle(
      fontFamily: '.SF Pro Display',
      fontSize: size,
      fontWeight: weight,
      letterSpacing: size * tracking,
      color: UMColors.textSecondary,
    );
  }
}

class UMShadows {
  static List<BoxShadow> card = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 1, offset: const Offset(0, 1)),
    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 22, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> raised = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 1)),
    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 50, offset: const Offset(0, 18)),
  ];

  static List<BoxShadow> ctaButton = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 1, offset: const Offset(0, 1)),
    BoxShadow(color: UMColors.primary.withValues(alpha: 0.30), blurRadius: 22, offset: const Offset(0, 8)),
  ];
}
