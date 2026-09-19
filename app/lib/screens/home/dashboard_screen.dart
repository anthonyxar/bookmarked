import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dashboard.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/year_provider.dart';
import '../../theme.dart';
import 'bracket_screen.dart';

const _monthLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).user;
    final selectedYear = ref.watch(selectedYearProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.green,
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: dashboardAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green)),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Text('$e'))]),
            data: (dash) => ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Your Reading Dashboard', style: AppTheme.serif.copyWith(fontSize: 20)),
                    ),
                    _YearDropdown(
                      years: dash.availableYears,
                      selected: selectedYear,
                      onChanged: (y) => ref.read(selectedYearProvider.notifier).state = y,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Hi ${user?.name ?? 'there'} — here's your $selectedYear in books",
                  style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _StatTile(value: '${dash.totalRead}', label: 'Books Read', color: AppColors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatTile(value: dash.avgRating.toStringAsFixed(1), label: 'Avg Rating', color: AppColors.gold)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatTile(value: '${dash.pagesRead}', label: 'Pages Read', color: AppColors.terra)),
                  ],
                ),
                if (user != null && user.readingGoal > 0) ...[
                  const SizedBox(height: 14),
                  _ReadingGoalCard(totalRead: dash.totalRead, goal: user.readingGoal, year: dash.year),
                ],
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BracketScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events_outlined, size: 20, color: AppColors.gold),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Book of the Year Bracket', style: AppTheme.serif.copyWith(fontSize: 14)),
                              const Text('Pick a favourite each month, crown a champion', style: TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.lineStrong),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Card(
                  title: 'By Genre',
                  child: dash.byGenre.isEmpty
                      ? const _EmptyStat(text: 'Finish a book to see your genre breakdown.')
                      : Column(children: [for (final g in dash.byGenre) _BarRow(label: g.genre, count: g.count, max: dash.byGenre.first.count, color: AppColors.green)]),
                ),
                const SizedBox(height: 14),
                _Card(
                  title: 'By Rating',
                  child: dash.byRating.isEmpty
                      ? const _EmptyStat(text: 'Rate a book to see your rating spread.')
                      : Column(children: [
                          for (final r in [5, 4, 3, 2, 1])
                            _BarRow(
                              label: '$r ★',
                              count: dash.byRating.where((e) => e.rating.round() == r).fold(0, (sum, e) => sum + e.count),
                              max: dash.byRating.map((e) => e.count).fold(1, (a, b) => a > b ? a : b),
                              color: AppColors.gold,
                              narrowLabel: true,
                            ),
                        ]),
                ),
                const SizedBox(height: 14),
                _Card(title: 'By Month', child: MonthChart(dash: dash)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YearDropdown extends StatelessWidget {
  final List<int> years;
  final int selected;
  final ValueChanged<int> onChanged;
  const _YearDropdown({required this.years, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = years.contains(selected) ? years : [selected, ...years];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.paperSoft,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selected,
          isDense: true,
          items: [for (final y in options) DropdownMenuItem(value: y, child: Text('$y'))],
          onChanged: (y) {
            if (y != null) onChanged(y);
          },
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatTile({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: AppTheme.serif.copyWith(fontSize: 22, color: color)),
          const SizedBox(height: 3),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: AppColors.inkSoft, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

class _ReadingGoalCard extends StatelessWidget {
  final int totalRead;
  final int goal;
  final int year;
  const _ReadingGoalCard({required this.totalRead, required this.goal, required this.year});

  @override
  Widget build(BuildContext context) {
    final pct = goal == 0 ? 0.0 : (totalRead / goal).clamp(0, 1).toDouble();
    final isCurrentYear = year == DateTime.now().year;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('READING GOAL', style: labelCapsStyle),
              Text('${(pct * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.creamDark,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCurrentYear ? '$totalRead of $goal books this year' : '$totalRead of $goal books in $year',
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.paperSoft, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: labelCapsStyle),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyStat extends StatelessWidget {
  final String text;
  const _EmptyStat({required this.text});
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 12, color: AppColors.lineStrong, fontStyle: FontStyle.italic));
}

class _BarRow extends StatelessWidget {
  final String label;
  final int count;
  final int max;
  final Color color;
  final bool narrowLabel;
  const _BarRow({required this.label, required this.count, required this.max, required this.color, this.narrowLabel = false});

  @override
  Widget build(BuildContext context) {
    final pct = max == 0 ? 0.0 : count / max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: narrowLabel ? 28 : 90,
            child: Text(label, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 7,
                backgroundColor: AppColors.creamDark,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 20, child: Text('$count', style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

/// Books finished per month, as a 12-bar chart. Public only so it can be
/// widget-tested.
class MonthChart extends StatelessWidget {
  final Dashboard dash;
  const MonthChart({super.key, required this.dash});

  @override
  Widget build(BuildContext context) {
    final maxCount = dash.byMonth.map((m) => m.count).fold(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        SizedBox(
          height: 84,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in dash.byMonth)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (m.count > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text('${m.count}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                          ),
                        SizedBox(
                          height: 56,
                          // widthFactor matters: the bar is a childless box, which
                          // otherwise collapses to zero width in a loose Column.
                          child: FractionallySizedBox(
                            widthFactor: 1.0,
                            heightFactor: m.count == 0 ? 0.02 : (m.count / maxCount).clamp(0.08, 1.0),
                            alignment: Alignment.bottomCenter,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: m.count == 0 ? AppColors.creamDark : AppColors.green,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [for (final l in _monthLabels) Expanded(child: Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: AppColors.inkSoft)))],
        ),
      ],
    );
  }
}
