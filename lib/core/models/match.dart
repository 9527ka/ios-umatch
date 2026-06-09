import 'player.dart';
import 'localized_string.dart';

class Match {
  final String id;
  final String competitionId;
  final LocalizedString stage;
  final String homeTeamId;
  final String awayTeamId;
  final DateTime kickoff;
  final LocalizedString venue;
  final LocalizedString city;
  final bool featured;
  final List<Player> keyPlayers;

  const Match({
    required this.id,
    required this.competitionId,
    required this.stage,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.kickoff,
    required this.venue,
    required this.city,
    this.featured = false,
    this.keyPlayers = const [],
  });

  bool get isUpcoming => kickoff.isAfter(DateTime.now());

  Duration get timeUntilKickoff => kickoff.difference(DateTime.now());

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'] as String,
      competitionId: json['comp'] as String,
      stage: LocalizedString.fromJson(json['stage']),
      homeTeamId: json['home'] as String,
      awayTeamId: json['away'] as String,
      kickoff: DateTime.fromMillisecondsSinceEpoch(json['kickoff'] as int, isUtc: true),
      venue: LocalizedString.fromJson(json['venue']),
      city: LocalizedString.fromJson(json['city']),
      featured: json['featured'] as bool? ?? false,
      keyPlayers: (json['players'] as List<dynamic>?)
              ?.map((p) => Player.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
