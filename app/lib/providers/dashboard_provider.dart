import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard.dart';
import 'auth_provider.dart';

final dashboardYearProvider = StateProvider<int>((ref) => DateTime.now().year);

final dashboardProvider = FutureProvider<Dashboard>((ref) async {
  final api = ref.watch(apiClientProvider);
  final year = ref.watch(dashboardYearProvider);
  final json = await api.get('/dashboard', query: {'year': '$year'});
  return Dashboard.fromJson(json as Map<String, dynamic>);
});
