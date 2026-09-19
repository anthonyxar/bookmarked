import 'package:bookmarked/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user({Map<int, int> goals = const {}, int? legacy}) =>
    AppUser(id: 'u1', name: 'Alex', genres: const [], readingGoals: goals, legacyGoal: legacy);

final _in2026 = DateTime(2026, 9, 19);

void main() {
  group('goalFor', () {
    test('an explicit goal for the year wins over the legacy goal', () {
      expect(_user(goals: {2026: 52}, legacy: 40).goalFor(2026, now: _in2026), 52);
    });

    test('an older account keeps its single goal for the current year only', () {
      final user = _user(legacy: 40);
      expect(user.goalFor(2026, now: _in2026), 40);
      expect(user.goalFor(2025, now: _in2026), isNull);
      expect(user.goalFor(2027, now: _in2026), isNull);
    });

    test('a new account has no goal until one is set', () {
      expect(_user().goalFor(2026, now: _in2026), isNull);
    });

    test('goals are per year', () {
      final user = _user(goals: {2025: 30, 2026: 50});
      expect(user.goalFor(2025, now: _in2026), 30);
      expect(user.goalFor(2026, now: _in2026), 50);
      expect(user.goalFor(2024, now: _in2026), isNull);
    });
  });

  group('suggestedGoalFor', () {
    test('uses the most recent earlier year, not a later one', () {
      final user = _user(goals: {2024: 20, 2025: 30, 2027: 99});
      expect(user.suggestedGoalFor(2026), 30);
    });

    test('falls back to the legacy goal, then the default', () {
      expect(_user(legacy: 25).suggestedGoalFor(2026), 25);
      expect(_user().suggestedGoalFor(2026), AppUser.defaultGoal);
    });

    test('never suggests the year being set from itself or a later year', () {
      expect(_user(goals: {2026: 50}).suggestedGoalFor(2026), AppUser.defaultGoal);
    });
  });
}
