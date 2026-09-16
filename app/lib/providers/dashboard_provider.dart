import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard.dart';
import 'auth_provider.dart';
import 'year_provider.dart';

final dashboardProvider = FutureProvider<Dashboard>((ref) async {
  final api = ref.watch(apiClientProvider);
  final year = ref.watch(selectedYearProvider);
  final json = await api.get('/dashboard', query: {'year': '$year'});
  return Dashboard.fromJson(json as Map<String, dynamic>);
});
