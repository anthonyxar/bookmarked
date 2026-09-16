class Challenge {
  final String id;
  final String title;
  final String description;
  final int progress;
  final int goal;
  final bool autoTracked;
  final List<bool>? letters;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.goal,
    required this.autoTracked,
    this.letters,
  });

  double get pct => goal == 0 ? 0.0 : (progress / goal).clamp(0, 1).toDouble();

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        progress: json['progress'] as int,
        goal: json['goal'] as int,
        autoTracked: json['auto_tracked'] as bool,
        letters: (json['letters'] as List?)?.map((l) => l as bool).toList(),
      );
}

class Challenges {
  final int year;
  final List<Challenge> challenges;

  Challenges({required this.year, required this.challenges});

  factory Challenges.fromJson(Map<String, dynamic> json) => Challenges(
        year: json['year'] as int,
        challenges: (json['challenges'] as List).map((c) => Challenge.fromJson(c as Map<String, dynamic>)).toList(),
      );
}
