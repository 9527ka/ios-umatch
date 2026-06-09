import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/um_theme.dart';
import '../../core/util/countdown_formatter.dart';
import '../../l10n/um_strings.dart';

class CountdownDisplay extends StatefulWidget {
  final DateTime kickoff;
  final bool showSeconds;
  final double numSize;

  const CountdownDisplay({
    super.key,
    required this.kickoff,
    this.showSeconds = false,
    this.numSize = 60,
  });

  @override
  State<CountdownDisplay> createState() => _CountdownDisplayState();
}

class _CountdownDisplayState extends State<CountdownDisplay> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.kickoff.difference(DateTime.now());
    final interval = widget.showSeconds ? const Duration(seconds: 1) : const Duration(seconds: 30);
    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      setState(() {
        _remaining = widget.kickoff.difference(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);
    final c = CountdownFormatter.components(_remaining);

    final segments = <_Segment>[
      _Segment(c['d']!.toString().padLeft(2, '0'), s.unitDays),
      _Segment(c['h']!.toString().padLeft(2, '0'), s.unitHrs),
      _Segment(c['m']!.toString().padLeft(2, '0'), s.unitMin),
    ];
    if (widget.showSeconds) {
      segments.add(_Segment(c['s']!.toString().padLeft(2, '0'), s.unitSec, isSeconds: true));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < segments.length; i++) ...[
          if (i > 0) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              ':',
              style: TextStyle(
                fontSize: widget.numSize * 0.6,
                fontWeight: FontWeight.w300,
                color: UMColors.textPrimary.withValues(alpha: 0.15),
                height: 1,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (segments[i].isSeconds)
                // 秒数每秒变化，不做翻动动画，直接刷新数字
                Text(
                  segments[i].value,
                  style: UMFont.countdown(size: widget.numSize),
                )
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    segments[i].value,
                    key: ValueKey('${i}_${segments[i].value}'),
                    style: UMFont.countdown(size: widget.numSize),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                segments[i].label,
                style: UMFont.caption(size: 11, weight: FontWeight.w700).copyWith(
                  color: UMColors.textTertiary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Segment {
  final String value;
  final String label;
  final bool isSeconds;
  _Segment(this.value, this.label, {this.isSeconds = false});
}
