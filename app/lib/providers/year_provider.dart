import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The year selected on any of the year-scoped screens (Stats, Bingo,
/// Challenges, Bracket) — shared so picking a year on one carries over to
/// the others.
final selectedYearProvider = StateProvider<int>((ref) => DateTime.now().year);
