import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/um_theme.dart';
import '../../l10n/um_strings.dart';

class NotifyPill extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final double height;

  const NotifyPill({
    super.key,
    required this.active,
    required this.onTap,
    this.height = 30,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);

    return GestureDetector(
      onTap: () {
        if (!active) {
          HapticFeedback.mediumImpact();
        }
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        padding: EdgeInsets.symmetric(horizontal: height * 0.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UMRadius.pill),
          color: active ? UMColors.primary : Colors.transparent,
          border: Border.all(
            color: active ? UMColors.primary : UMColors.primary,
            width: 1.5,
          ),
          boxShadow: active ? UMShadows.ctaButton : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.notifications_active : Icons.notifications_outlined,
              size: height * 0.5,
              color: active ? Colors.white : UMColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              active ? s.notifyOn : s.notifyOff,
              style: TextStyle(
                fontSize: height * 0.4,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : UMColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
