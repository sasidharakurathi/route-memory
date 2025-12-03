import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../data/route_repository.dart';
import '../logic/location_provider.dart';
import '../logic/tracking_provider.dart';
import '../logic/settings_provider.dart';
import 'navigation_screen.dart';
import 'constants.dart';
import 'widgets/user_location_marker.dart';

Color _getCategoryColor(String category) {
  final colors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
    Colors.brown, Colors.cyan, Colors.deepOrange
  ];
  return colors[category.hashCode.abs() % colors.length];
}

class _PinTipPainter extends CustomPainter {
  final Color color;
  _PinTipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = ui.Path();
    path.moveTo(size.width / 2 - 8, 0);
    path.lineTo(size.width / 2 + 8, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
    final shadowPaint = Paint()..color = color.withOpacity(0.2)..style = PaintingStyle.fill;
    final shadowPath = ui.Path();
    shadowPath.moveTo(size.width / 2 - 8, 2);
    shadowPath.lineTo(size.width / 2 + 8, 2);
    shadowPath.lineTo(size.width / 2, size.height + 2);
    shadowPath.close();
    canvas.drawPath(shadowPath, shadowPaint);
  }
  @override
  bool shouldRepaint(_PinTipPainter oldDelegate) => oldDelegate.color != color;
}

class ExploreMapScreen extends ConsumerStatefulWidget {
  const ExploreMapScreen({super.key});
  @override
  ConsumerState<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends ConsumerState<ExploreMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _selectedLocation;
  String _selectedAddress = "Selected Location";
  
  bool _isMapReady = false;
  bool _isSearching = false;
  LatLng? _userLocation;
  StreamSubscription<Position>? _positionStream;
  
  bool _shouldAutoCenter = true; 
  bool _hasCenteredOnce = false;

  @override void initState() { super.initState(); _startLocationStream(); }
  @override void dispose() { _positionStream?.cancel(); _searchController.dispose(); super.dispose(); }

  void _startLocationStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, 
      distanceFilter: 0 
    );
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      if (mounted) { 
        final pos = LatLng(position.latitude, position.longitude);
        setState(() => _userLocation = pos);
        
        if ((!_hasCenteredOnce || _shouldAutoCenter) && _isMapReady) {
          _mapController.move(pos, 16.0);
          _hasCenteredOnce = true;
        }
      }
    });
  }

  void _onMapReady() async {
    setState(() => _isMapReady = true);
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        final initialPos = LatLng(pos.latitude, pos.longitude);
        _mapController.move(initialPos, 16.0);
        setState(() => _userLocation = initialPos);
        _hasCenteredOnce = true;
      }
    } catch (e) {}
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _selectedAddress = "Selected Location"; 
      _shouldAutoCenter = false; 
    });
  }

  void _recenterMap() {
    setState(() => _shouldAutoCenter = true);
    if (_userLocation != null) _mapController.move(_userLocation!, 16.0);
  }

  Future<void> _searchPlaces() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();
    try {
      final url = Uri.https('nominatim.openstreetmap.org', '/search', {'q': query, 'format': 'json', 'limit': '5'});
      final request = await HttpClient().getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, 'RouteMemoryApp/1.0 (flutter_student_project)');
      final response = await request.close();
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final data = jsonDecode(jsonString) as List;
        if (mounted) {
          if (data.isNotEmpty) _showSearchResults(data);
          else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No places found.")));
        }
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Search failed: $e"))); }
    finally { if (mounted) setState(() => _isSearching = false); }
  }

  void _showSearchResults(List results) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Search Results", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
            const SizedBox(height: 10),
            Expanded(child: ListView.separated(
              itemCount: results.length, 
              separatorBuilder: (_,__) => Divider(color: theme.dividerColor), 
              itemBuilder: (context, index) { 
                final place = results[index];
                return ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.redAccent),
                  title: Text(
                    place['display_name'] ?? 'Unknown', 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    final lat = double.parse(place['lat']);
                    final lon = double.parse(place['lon']);
                    final pos = LatLng(lat, lon);

                    _mapController.move(pos, 16.0);
                    setState(() {
                      _selectedLocation = pos;
                      _selectedAddress = place['display_name']?.split(',')[0] ?? "Searched Place";
                      _shouldAutoCenter = false; 
                    });
                  }
                );
              }
            ))
          ])
        );
      }
    );
  }

  void _showAddLocationDialog() {
    if (_selectedLocation == null) return;
    _showAddLocationDialogBase(context, ref, _selectedLocation!, defaultName: _selectedAddress == "Selected Location" ? null : _selectedAddress); 
  }

  void _showNavigateDialog(SavedLocation loc) {
    showModalBottomSheet(context: context, backgroundColor: Theme.of(context).cardColor, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) {
      final theme = Theme.of(ctx);
      final isDark = theme.brightness == Brightness.dark;
      return SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.grey[700] : Colors.grey[300], borderRadius: BorderRadius.circular(2))), const SizedBox(height: 24), Text("Navigate to ${loc.name}?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)), const SizedBox(height: 8), Text("Start navigation from your current location to ${loc.name}.", textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 16)), const SizedBox(height: 32), Row(children: [Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))), const SizedBox(width: 16), Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: kPrimaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => NavigationScreen(target: LatLng(loc.latitude, loc.longitude), targetName: loc.name))); }, child: const Text("Start")))])])));
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapSettings = ref.watch(settingsProvider);
    final savedLocationsAsync = ref.watch(savedLocationsProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                onMapReady: _onMapReady,
                initialCenter: const LatLng(0,0),
                initialZoom: 16.0,
                onTap: _onMapTap,
                interactionOptions: InteractionOptions(flags: mapSettings.interactionFlags),
                onPositionChanged: (pos, hasGesture) {
                  if (hasGesture) setState(() => _shouldAutoCenter = false);
                }
              ),
              children: [
                
                if (isDark)
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.sasidharakurathi.routememory',
                    retinaMode: mapSettings.retinaMode,
                    panBuffer: mapSettings.panBuffer,
                    tileBuilder: (context, widget, tile) {
                      return ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          -1,  0,  0, 0, 255, 
                           0, -1,  0, 0, 255, 
                           0,  0, -1, 0, 255, 
                           0,  0,  0, 1,   0, 
                        ]),
                        child: widget,
                      );
                    },
                  )
                else
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.sasidharakurathi.routememory',
                    retinaMode: mapSettings.retinaMode,
                    panBuffer: mapSettings.panBuffer,
                  ),
                  
                savedLocationsAsync.when(
                    data: (locs) => MarkerLayer(
                      markers: locs.map((l) {
                        return Marker(
                          point: LatLng(l.latitude, l.longitude),
                          width: 100, height: 100,
                          alignment: const Alignment(0.0, 0.0),
                          child: GestureDetector(
                            onTap: () => _showNavigateDialog(l),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(l.category),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20), topRight: Radius.circular(20),
                                      bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12),
                                    ),
                                    boxShadow: [BoxShadow(color: _getCategoryColor(l.category).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(Icons.location_on, color: Colors.white, size: 22),
                                ),
                                CustomPaint(size: const Size(40, 10), painter: _PinTipPainter(color: _getCategoryColor(l.category))),
                                if (l.name.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _getCategoryColor(l.category), width: 0.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
                                      child: Text(l.name, style: TextStyle(color: _getCategoryColor(l.category), fontSize: 11, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis), maxLines: 1),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    loading: () => const MarkerLayer(markers: []),
                    error: (_,__) => const MarkerLayer(markers: []),
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 100, height: 100,
                        alignment: const Alignment(0.0, 0.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: kPrimaryColor,
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                                boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.location_on, color: Colors.white, size: 22),
                            ),
                            CustomPaint(size: const Size(40, 10), painter: _PinTipPainter(color: kPrimaryColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (_userLocation != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: _userLocation!, 
                      width: 60, height: 60, 
                      child: const UserLocationMarker()
                    )
                  ]),
              ],
            ),
            
            
            Positioned(top: MediaQuery.of(context).padding.top + 10, left: 16, right: 16, child: Container(decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12), boxShadow: kShadow), child: Row(children: [IconButton(icon: Icon(Icons.arrow_back, color: theme.iconTheme.color), onPressed: () => Navigator.pop(context)), Expanded(child: TextField(controller: _searchController, style: TextStyle(color: theme.textTheme.bodyMedium?.color), decoration: InputDecoration(hintText: "Search places...", hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38), border: InputBorder.none), textInputAction: TextInputAction.search, onSubmitted: (_) => _searchPlaces())), if (_isSearching) const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) else IconButton(icon: const Icon(Icons.search, color: kPrimaryColor), onPressed: _searchPlaces)]))),
            
            if (_userLocation != null)
              Positioned(
                bottom: (_selectedLocation != null ? 100 : 20) + bottomPadding, 
                right: 16, 
                child: FloatingActionButton(
                  heroTag: "recenter_explore",
                  backgroundColor: _shouldAutoCenter ? kPrimaryColor : theme.cardColor,
                  foregroundColor: _shouldAutoCenter ? Colors.white : theme.iconTheme.color,
                  onPressed: _recenterMap,
                  child: const Icon(Icons.my_location),
                )
              ),

            if (_selectedLocation != null)
              Positioned(
                bottom: 20 + bottomPadding, 
                left: 16, 
                right: 16, 
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), boxShadow: kShadow),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedAddress, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
                                const SizedBox(height: 4),
                                Text("${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            
                            backgroundColor: isDark ? kPrimaryColor : Colors.black87,
                            foregroundColor: Colors.white, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _showAddLocationDialog, 
                          icon: const Icon(Icons.bookmark_add),
                          label: const Text("Save This Spot"),
                        ),
                      ),
                    ],
                  ),
                )
              )
          ],
        ),
      ),
    );
  }
}

void _showAddLocationDialogBase(BuildContext context, WidgetRef ref, LatLng point, {String? defaultName}) {
  final nameCtrl = TextEditingController(text: defaultName);
  final catCtrl = TextEditingController();
  String selectedCat = "General";
  final existingCategories = ref.read(categoriesProvider);
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text("Save Location", style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, style: TextStyle(color: theme.textTheme.bodyMedium?.color), decoration: InputDecoration(labelText: "Name", hintText: "e.g. Secret Park", labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54), hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38)), autofocus: true),
          const SizedBox(height: 16),
          Text("Category", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ...existingCategories.map((c) => ChoiceChip(
                label: Text(c, style: TextStyle(color: selectedCat == c ? Colors.white : (isDark ? Colors.white : Colors.black))),
                selected: selectedCat == c,
                selectedColor: kPrimaryColor,
                backgroundColor: isDark ? Colors.grey[700] : null,
                onSelected: (b) { if(b) { selectedCat = c; (ctx as Element).markNeedsBuild(); } },
              )),
              ActionChip(
                label: const Text("+ New"), 
                backgroundColor: isDark ? Colors.grey[700] : null,
                labelStyle: TextStyle(color: isDark ? Colors.white : Colors.black),
                onPressed: () {}
              )
            ],
          ),
          const SizedBox(height: 8),
          TextField(controller: catCtrl, style: TextStyle(color: theme.textTheme.bodyMedium?.color), decoration: InputDecoration(labelText: "Or type new category", hintText: "e.g. Hiking", labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54), hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        FilledButton(
          onPressed: () {
            final finalName = nameCtrl.text.isEmpty ? "Pinned Location" : nameCtrl.text;
            final finalCat = catCtrl.text.isNotEmpty ? catCtrl.text : selectedCat;
            final newLoc = SavedLocation(id: '', name: finalName, category: finalCat, latitude: point.latitude, longitude: point.longitude);
            ref.read(repositoryProvider).addLocation(newLoc);
            Navigator.pop(ctx);
          }, 
          child: const Text("Save")
        ),
      ],
    ),
  );
}