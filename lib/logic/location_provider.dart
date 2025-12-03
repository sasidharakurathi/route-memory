import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/route_repository.dart';
import 'tracking_provider.dart';

final savedLocationsProvider = StreamProvider<List<SavedLocation>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchLocations();
});

final categoriesProvider = Provider<List<String>>((ref) {
  final locationsAsync = ref.watch(savedLocationsProvider);
  
  return locationsAsync.when(
    data: (locations) {
      final categories = locations.map((l) => l.category).toSet().toList();
      categories.sort();
      return categories;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});