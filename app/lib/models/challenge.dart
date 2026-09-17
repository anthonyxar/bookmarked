class Challenge {
  final String id;
  final String title;
  final String description;
  final int progress;
  final int goal;
  final List<bool>? letters;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.goal,
    this.letters,
  });

  double get pct => goal == 0 ? 0.0 : (progress / goal).clamp(0, 1).toDouble();
}

class Challenges {
  final int year;
  final List<Challenge> challenges;

  Challenges({required this.year, required this.challenges});
}
