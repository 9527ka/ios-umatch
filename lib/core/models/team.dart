import 'package:flutter/material.dart';
import 'localized_string.dart';

class Team {
  final String id;
  final LocalizedString name;
  final LocalizedString alias;
  final String short3;
  final Color primaryColor;
  final Color accentColor;
  final Color subColor;
  final LocalizedString city;
  final String leagueId;
  final LocalizedString? rank;
  final String? flag;

  const Team({
    required this.id,
    required this.name,
    required this.alias,
    required this.short3,
    required this.primaryColor,
    required this.accentColor,
    required this.subColor,
    required this.city,
    required this.leagueId,
    this.rank,
    this.flag,
  });

  factory Team.fromJson(String id, Map<String, dynamic> json) {
    return Team(
      id: id,
      name: LocalizedString.fromJson(json['name']),
      alias: LocalizedString.fromJson(json['alias']),
      short3: json['short'] as String,
      primaryColor: _parseColor(json['primary'] as String),
      accentColor: _parseColor(json['accent'] as String),
      subColor: _parseColor(json['sub'] as String),
      city: LocalizedString.fromJson(json['city']),
      leagueId: json['leagueId'] as String? ?? '',
      rank: json['rank'] != null ? LocalizedString.fromJson(json['rank']) : null,
      flag: json['flag'] as String?,
    );
  }

  static Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
