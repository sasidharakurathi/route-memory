import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/route_repository.dart';
import 'tracking_provider.dart'; // To access the repo provider

// 1. Stream of ALL Saved Locations
final savedLocationsProvider = StreamProvider<List<SavedLocation>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchLocations();
});

// 2. Provider to get UNIQUE Categories
final categoriesProvider = Provider<List<String>>((ref) {
  final locationsAsync = ref.watch(savedLocationsProvider);
  
  return locationsAsync.when(
    data: (locations) {
      final categories = locations.map((l) => l.category).toSet().toList();
      categories.sort(); // Alphabetical
      return categories;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});