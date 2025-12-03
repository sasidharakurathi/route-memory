import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../data/route_repository.dart';
import '../logic/location_provider.dart';
import '../logic/tracking_provider.dart'; 
import 'constants.dart';

class SavedPlacesScreen extends ConsumerStatefulWidget {
  final Function(LatLng, String) onLocationSelected;

  const SavedPlacesScreen({super.key, required this.onLocationSelected});

  @override
  ConsumerState<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends ConsumerState<SavedPlacesScreen> {
  final Set<String> _selectedKeys = {};
  bool get _isSelectionMode => _selectedKeys.isNotEmpty;

  void _toggleSelection(String key) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  void _showRenameDialog(SavedLocation loc) {
    final controller = TextEditingController(text: loc.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename Place"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter new name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(repositoryProvider).updateLocationName(loc.id, controller.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Rename"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSingle(SavedLocation loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Place?"),
        content: Text("Remove '${loc.name}' from your saved places?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kDangerColor),
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

  void _confirmDeleteSelected(List<SavedLocation> locations) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Selected?"),
        content: Text("Permanently remove ${_selectedKeys.length} places?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kDangerColor),
            onPressed: () {
              ref.read(repositoryProvider).deleteLocations(_selectedKeys.toList());
              setState(() => _selectedKeys.clear());
              Navigator.pop(ctx);
            },
            child: const Text("Delete All"),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All Places?"),
        content: const Text("This will permanently delete ALL saved locations."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kDangerColor),
            onPressed: () {
              ref.read(repositoryProvider).clearAllLocations();
              Navigator.pop(ctx);
            },
            child: const Text("Clear All"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(savedLocationsProvider);
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text("${_selectedKeys.length} Selected", style: const TextStyle(fontWeight: FontWeight.bold))
            : const Text("Saved Places", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.cardColor,
        foregroundColor: theme.iconTheme.color,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedKeys.clear()))
            : const BackButton(),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: kDangerColor),
              onPressed: () => locationsAsync.whenData((d) => _confirmDeleteSelected(d)),
            )
          else
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: theme.iconTheme.color?.withOpacity(0.5)),
              tooltip: "Clear All",
              onPressed: _confirmClearAll,
            ),
        ],
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
                  Icon(Icons.bookmark_outline, size: 64, color: isDark ? Colors.grey[700] : Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("No saved places yet.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("Long press on the map to save one!", style: TextStyle(color: theme.textTheme.bodySmall?.color)),
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
                      style: TextStyle(color: theme.textTheme.bodySmall?.color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                    ),
                  ),
                  ...categoryLocations.map((loc) {
                    final isSelected = _selectedKeys.contains(loc.id);
                    return _buildLocationCard(loc, isSelected, theme);
                  }).toList(),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLocationCard(SavedLocation loc, bool isSelected, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? (isDark ? kPrimaryColor.withOpacity(0.2) : Colors.blue[50]) : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: kPrimaryColor, width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: () => _toggleSelection(loc.id),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(loc.id);
            } else {
              widget.onLocationSelected(LatLng(loc.latitude, loc.longitude), loc.name);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryColor : (isDark ? Colors.white.withOpacity(0.05) : Colors.blue[50]),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected ? Icons.check : Icons.place,
                    color: isSelected ? Colors.white : Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.bodyMedium?.color)),
                      const SizedBox(height: 4),
                      Text(
                        "${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}",
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (!_isSelectionMode)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: theme.iconTheme.color?.withOpacity(0.5)),
                        onPressed: () => _showRenameDialog(loc),
                        tooltip: "Rename",
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: theme.iconTheme.color?.withOpacity(0.5)),
                        onPressed: () => _confirmDeleteSingle(loc),
                        tooltip: "Delete",
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}