import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';

enum PerformanceMode { batterySaver, balanced, highFidelity }
enum DistanceUnit { metric, imperial }

class MapSettings {
  final PerformanceMode mode;
  final bool retinaMode;
  final int panBuffer;
  final int interactionFlags;
  final DistanceUnit distanceUnit;
  
  final ThemeMode themeMode;

  const MapSettings({
    required this.mode,
    required this.retinaMode,
    required this.panBuffer,
    required this.interactionFlags,
    required this.distanceUnit,
    required this.themeMode,
  });

  
  factory MapSettings.balanced() {
    return const MapSettings(
      mode: PerformanceMode.balanced,
      retinaMode: false,
      panBuffer: 1,
      interactionFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      distanceUnit: DistanceUnit.metric,
      
      themeMode: ThemeMode.system, 
    );
  }

  MapSettings copyWith({
    PerformanceMode? mode,
    bool? retinaMode,
    int? panBuffer,
    int? interactionFlags,
    DistanceUnit? distanceUnit,
    ThemeMode? themeMode,
  }) {
    return MapSettings(
      mode: mode ?? this.mode,
      retinaMode: retinaMode ?? this.retinaMode,
      panBuffer: panBuffer ?? this.panBuffer,
      interactionFlags: interactionFlags ?? this.interactionFlags,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<MapSettings> {
  SettingsNotifier() : super(MapSettings.balanced());

  void setUnit(DistanceUnit unit) {
    state = state.copyWith(distanceUnit: unit);
  }

  
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setMode(PerformanceMode mode) {
    switch (mode) {
      case PerformanceMode.batterySaver:
        state = state.copyWith(
          mode: PerformanceMode.batterySaver,
          retinaMode: false,
          panBuffer: 0,
          interactionFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        );
        break;
      case PerformanceMode.balanced:
        state = state.copyWith(
          mode: PerformanceMode.balanced,
          retinaMode: false,
          panBuffer: 1,
          interactionFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        );
        break;
      case PerformanceMode.highFidelity:
        state = state.copyWith(
          mode: PerformanceMode.highFidelity,
          retinaMode: true,
          panBuffer: 2,
          interactionFlags: InteractiveFlag.all,
        );
        break;
    }
  }

  String getFormattedDistance(double meters) {
    if (state.distanceUnit == DistanceUnit.metric) {
      if (meters >= 1000) {
        return "${(meters / 1000).toStringAsFixed(2)} km";
      } else {
        return "${meters.toStringAsFixed(0)} m";
      }
    } else {
      final feet = meters * 3.28084;
      if (feet >= 5280 / 10) {
        final miles = feet / 5280;
        return "${miles.toStringAsFixed(2)} mi";
      } else {
        return "${feet.toStringAsFixed(0)} ft";
      }
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, MapSettings>((ref) {
  return SettingsNotifier();
});