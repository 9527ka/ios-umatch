class CountdownFormatter {
  static Map<String, int> components(Duration d) {
    if (d.isNegative) return {'d': 0, 'h': 0, 'm': 0, 's': 0};
    return {
      'd': d.inDays,
      'h': d.inHours % 24,
      'm': d.inMinutes % 60,
      's': d.inSeconds % 60,
    };
  }

  static String compact(Duration d, {bool isZh = false}) {
    final c = components(d);
    if (c['d']! > 0) {
      if (isZh) return '${c['d']}天 ${c['h']}时';
      return '${c['d']}d ${c['h']}h';
    }
    if (c['h']! > 0) {
      if (isZh) return '${c['h']}时 ${c['m']}分';
      return '${c['h']}h ${c['m']}m';
    }
    if (isZh) return '${c['m']}分 ${c['s']}秒';
    return '${c['m']}m ${c['s']}s';
  }
}
