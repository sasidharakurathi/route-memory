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
  bool _isLoading = true;

  // Search Logic Variables
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _showResults = false;

  @override 
  void initState() { 
    super.initState(); 
    _initLocation(); 
  }

  @override 
  void dispose() { 
    _positionStream?.cancel(); 
    _debounce?.cancel();
    _searchController.dispose(); 
    super.dispose(); 
  }

  Future<void> _initLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    const locationSettings = LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0);
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      if (mounted) { 
        final pos = LatLng(position.latitude, position.longitude);
        setState(() {
          _userLocation = pos;
          if (_isLoading) _isLoading = false; 
        });
        
        if ((!_hasCenteredOnce || _shouldAutoCenter) && _isMapReady) {
          _mapController.move(pos, 16.0);
          _hasCenteredOnce = true;
        }
      }
    });

    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted && _isLoading) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _isLoading = false;
        });
      }
    } catch (e) { /* Ignore */ }
  }

  void _onMapReady() {
    setState(() => _isMapReady = true);
    if (_userLocation != null && !_hasCenteredOnce) {
        _mapController.move(_userLocation!, 16.0);
        _hasCenteredOnce = true;
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _selectedAddress = "Selected Location"; 
      _shouldAutoCenter = false; 
      _showResults = false; // Close results on map tap
      FocusScope.of(context).unfocus(); // Dismiss keyboard
    });
  }

  void _recenterMap() {
    setState(() => _shouldAutoCenter = true);
    if (_userLocation != null) _mapController.move(_userLocation!, 16.0);
  }

  // --- Dynamic Search Logic ---

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
        _isSearching = false;
      });
      return;
    }

    // Debounce: Wait 1 second (1000ms) before calling API to respect rate limits
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final url = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query, 
        'format': 'json', 
        'limit': '5',
        'addressdetails': '1',
      });
      
      final request = await HttpClient().getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, 'RouteMemoryApp/1.0 (flutter_student_project)');
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final data = jsonDecode(jsonString) as List;
        if (mounted) {
          setState(() {
            _searchResults = data;
            _showResults = true;
          });
        }
      }
    } catch (e) { 
      debugPrint("Search error: $e"); 
    } finally { 
      if (mounted) setState(() => _isSearching = false); 
    }
  }

  void _selectSearchResult(dynamic place) {
    final lat = double.parse(place['lat']);
    final lon = double.parse(place['lon']);
    final pos = LatLng(lat, lon);
    final displayName = place['display_name'] ?? "Unknown";

    // Extract a shorter name (usually the first part before the comma)
    final shortName = displayName.split(',')[0];

    _mapController.move(pos, 16.0);
    setState(() {
      _selectedLocation = pos;
      _selectedAddress = shortName;
      _searchController.text = shortName; // Update text field
      _shouldAutoCenter = false;
      _showResults = false;
      _searchResults = [];
    });
    FocusScope.of(context).unfocus();
  }

  // --- End Dynamic Search Logic ---

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

  Widget _buildLoadingScreen(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Explore"), backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back, color: theme.iconTheme.color), onPressed: () => Navigator.pop(context))),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 50, height: 50, child: CircularProgressIndicator(strokeWidth: 3, color: kPrimaryColor)), const SizedBox(height: 24), Text("Finding You...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)), const SizedBox(height: 8), Text("Getting your location for exploration", style: TextStyle(color: theme.textTheme.bodySmall?.color))])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapSettings = ref.watch(settingsProvider);
    final savedLocationsAsync = ref.watch(savedLocationsProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading && _userLocation == null) return _buildLoadingScreen(theme);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false, // Prevents map resize when keyboard opens
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                onMapReady: _onMapReady,
                initialCenter: _userLocation ?? const LatLng(0,0),
                initialZoom: 16.0,
                onTap: _onMapTap,
                interactionOptions: InteractionOptions(flags: mapSettings.interactionFlags),
                onPositionChanged: (pos, hasGesture) {
                  if (hasGesture) setState(() => _shouldAutoCenter = false);
                }
              ),
              children: [
                if (isDark)
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.sasidharakurathi.routememory', retinaMode: mapSettings.retinaMode, panBuffer: mapSettings.panBuffer, tileBuilder: (context, widget, tile) => ColorFiltered(colorFilter: const ColorFilter.matrix([-1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0]), child: widget))
                else
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.sasidharakurathi.routememory', retinaMode: mapSettings.retinaMode, panBuffer: mapSettings.panBuffer),
                  
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
                                  decoration: BoxDecoration(color: _getCategoryColor(l.category), borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)), boxShadow: [BoxShadow(color: _getCategoryColor(l.category).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))], border: Border.all(color: Colors.white, width: 2)),
                                  child: Icon(Icons.location_on, color: Colors.white, size: 22),
                                ),
                                CustomPaint(size: const Size(40, 10), painter: _PinTipPainter(color: _getCategoryColor(l.category))),
                                if (l.name.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _getCategoryColor(l.category), width: 0.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]), child: Text(l.name, style: TextStyle(color: _getCategoryColor(l.category), fontSize: 11, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis), maxLines: 1))),
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
                  MarkerLayer(markers: [Marker(point: _selectedLocation!, width: 100, height: 100, alignment: const Alignment(0.0, 0.0), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: kPrimaryColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)), boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))], border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.location_on, color: Colors.white, size: 22)), CustomPaint(size: const Size(40, 10), painter: _PinTipPainter(color: kPrimaryColor))]))]),
                if (_userLocation != null)
                  MarkerLayer(markers: [Marker(point: _userLocation!, width: 60, height: 60, child: const UserLocationMarker())]),
              ],
            ),
            
            // --- Enhanced Search Bar & Results ---
            Positioned(
              top: MediaQuery.of(context).padding.top + 10, 
              left: 16, 
              right: 16, 
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12), boxShadow: kShadow), 
                    child: Row(
                      children: [
                        IconButton(icon: Icon(Icons.arrow_back, color: theme.iconTheme.color), onPressed: () => Navigator.pop(context)), 
                        Expanded(
                          child: TextField(
                            controller: _searchController, 
                            style: TextStyle(color: theme.textTheme.bodyMedium?.color), 
                            decoration: InputDecoration(
                              hintText: "Search places...", 
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38), 
                              border: InputBorder.none,
                              suffixIcon: _searchController.text.isNotEmpty 
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null
                            ), 
                            textInputAction: TextInputAction.search, 
                            onChanged: _onSearchChanged,
                            onSubmitted: (val) {
                                if (val.isNotEmpty) _performSearch(val);
                            },
                          )
                        ), 
                        if (_isSearching) 
                          const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) 
                        else 
                          IconButton(icon: const Icon(Icons.search, color: kPrimaryColor), onPressed: () => _performSearch(_searchController.text))
                      ]
                    )
                  ),
                  
                  // Dynamic Results List
                  if (_showResults && _searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: kShadow,
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (ctx, i) => Divider(height: 1, color: theme.dividerColor),
                        itemBuilder: (ctx, i) {
                          final place = _searchResults[i];
                          final name = place['display_name'] ?? 'Unknown';
                          final parts = name.toString().split(',');
                          final mainName = parts[0];
                          final subName = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';

                          return ListTile(
                            leading: const Icon(Icons.location_on_outlined, size: 20, color: kPrimaryColor),
                            title: Text(mainName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                            subtitle: subName.isNotEmpty ? Text(subName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)) : null,
                            dense: true,
                            onTap: () => _selectSearchResult(place),
                          );
                        },
                      ),
                    )
                ],
              )
            ),
            // --- End Enhanced Search ---
            
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