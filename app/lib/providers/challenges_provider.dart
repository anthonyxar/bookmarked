import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge.dart';
import 'auth_provider.dart';
import 'year_provider.dart';

final challengesProvider = FutureProvider<Challenges>((ref) async {
  final api = ref.watch(apiClientProvider);
  final year = ref.watch(selectedYearProvider);
  final json = await api.get('/challenges', query: {'year': '$year'});
  return Challenges.fromJson(json as Map<String, dynamic>);
});
