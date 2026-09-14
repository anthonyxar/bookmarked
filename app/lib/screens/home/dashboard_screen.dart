import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dashboard.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme.dart';

const _monthLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).user;

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
                Text('Your Reading Dashboard', style: AppTheme.serif.copyWith(fontSize: 20)),
                const SizedBox(height: 2),
                Text("Hi ${user?.name ?? 'there'} — here's your reading year so far", style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
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
                              count: dash.byRating.firstWhere((e) => e.rating == r, orElse: () => RatingCount(r, 0)).count,
                              max: dash.byRating.map((e) => e.count).fold(1, (a, b) => a > b ? a : b),
                              color: AppColors.gold,
                              narrowLabel: true,
                            ),
                        ]),
                ),
                const SizedBox(height: 14),
                _Card(title: 'By Month', child: _MonthChart(dash: dash)),
              ],
            ),
          ),
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

class _MonthChart extends StatelessWidget {
  final Dashboard dash;
  const _MonthChart({required this.dash});

  @override
  Widget build(BuildContext context) {
    final maxCount = dash.byMonth.map((m) => m.count).fold(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        SizedBox(
          height: 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in dash.byMonth)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FractionallySizedBox(
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
