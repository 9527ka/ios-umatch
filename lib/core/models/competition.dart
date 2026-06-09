import 'package:flutter/material.dart';
import 'localized_string.dart';

class Competition {
  final String id;
  final LocalizedString name;
  final LocalizedString short;
  final Color accentColor;
  final String glyph;

  const Competition({
    required this.id,
    required this.name,
    required this.short,
    required this.accentColor,
    required this.glyph,
  });

  factory Competition.fromJson(String id, Map<String, dynamic> json) {
    final hex = (json['accent'] as String).replaceFirst('#', '');
    return Competition(
      id: id,
      name: LocalizedString.fromJson(json['name']),
      short: LocalizedString.fromJson(json['short']),
      accentColor: Color(int.parse('FF$hex', radix: 16)),
      glyph: json['glyph'] as String,
    );
  }
}
