import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

const kPrimaryColor = Color(0xFF2563EB);
const kAccentColor = Color(0xFF10B981);
const kDangerColor = Color(0xFFEF4444);
const kSurfaceColor = Color(0xFFFAFAFA);

const kCardRadius = BorderRadius.all(Radius.circular(16));
const kShadow = [
  BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];



TileLayer buildStandardTileLayer({
  required bool retinaMode,
  required int panBuffer,
}) {
  return TileLayer(
    
    
    
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    
    
    userAgentPackageName: 'com.sasidharakurathi.routememory',
    
    
    retinaMode: retinaMode,
    panBuffer: panBuffer,
    maxNativeZoom: 19,
    
    
    additionalOptions: const {
      'headers': 'Cache-Control: max-age=604800', 
    },
  );
}