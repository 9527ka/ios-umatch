import 'localized_string.dart';

class Player {
  final String teamId;
  final LocalizedString name;
  final LocalizedString position;
  final int number;
  final LocalizedString seasonStat;
  final String? photoSlug;

  const Player({
    required this.teamId,
    required this.name,
    required this.position,
    required this.number,
    required this.seasonStat,
    this.photoSlug,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      teamId: json['team'] as String,
      name: LocalizedString.fromJson(json['name']),
      position: LocalizedString.fromJson(json['pos']),
      number: json['num'] as int,
      seasonStat: LocalizedString.fromJson(json['stat']),
      photoSlug: json['photo'] as String?,
    );
  }
}
