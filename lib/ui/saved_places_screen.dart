import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../data/route_repository.dart';
import '../logic/location_provider.dart';
import '../logic/tracking_provider.dart'; // For repository

class SavedPlacesScreen extends ConsumerWidget {
  final Function(LatLng, String) onLocationSelected;

  const SavedPlacesScreen({super.key, required this.onLocationSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(savedLocationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Saved Places", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: locationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (locations) {
          if (locations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("No saved places yet.", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text("Long press on the map to save one!", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final Map<String, List<SavedLocation>> grouped = {};
          for (var loc in locations) {
            if (!grouped.containsKey(loc.category)) grouped[loc.category] = [];
            grouped[loc.category]!.add(loc);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final category = grouped.keys.elementAt(index);
              final categoryLocations = grouped[category]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                    ),
                  ),
                  ...categoryLocations.map((loc) => _buildLocationCard(context, ref, loc)).toList(),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context, WidgetRef ref, SavedLocation loc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
          child: const Icon(Icons.place, color: Colors.blue),
        ),
        title: Text(loc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}"),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.grey),
          onPressed: () => _confirmDelete(context, ref, loc),
        ),
        onTap: () {
          Navigator.pop(context); // Close menu
          onLocationSelected(LatLng(loc.latitude, loc.longitude), loc.name); // Trigger nav
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SavedLocation loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Place?"),
        content: Text("Remove '${loc.name}' from your saved places?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(repositoryProvider).deleteLocation(loc.id);
              Navigator.pop(ctx);
            }, 
            child: const Text("Delete")
          ),
        ],
      ),
    );
  }
}