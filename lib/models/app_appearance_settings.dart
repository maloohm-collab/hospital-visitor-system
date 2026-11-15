import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppAppearanceSettings {
  const AppAppearanceSettings({
    this.preset = 'navy',
    this.backgroundStart = 0xFF0B1C3A,
    this.backgroundEnd = 0xFF1C3766,
  });

  final String preset;
  final int backgroundStart;
  final int backgroundEnd;

  static const Map<String, Map<String, int>> presets = {
    'navy': {'start': 0xFF0B1C3A, 'end': 0xFF1C3766},
    'blue_gray': {'start': 0xFF0B1C3A, 'end': 0xFFB3C3DD},
    'sand': {'start': 0xFF0B1C3A, 'end': 0xFFE3D0A5},
  };

  static const Map<String, String> labels = {
    'navy': 'الأزرق الكحلي',
    'blue_gray': 'الأزرق الرمادي',
    'sand': 'الذهبي الرملي',
  };

  factory AppAppearanceSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const AppAppearanceSettings();
    final presetValue = data['preset'];
    final preset = presets.containsKey(presetValue) ? presetValue as String : 'navy';
    final fallback = presets[preset]!;
    return AppAppearanceSettings(
      preset: preset,
      backgroundStart: data['backgroundStart'] is num
          ? (data['backgroundStart'] as num).toInt()
          : fallback['start']!,
      backgroundEnd: data['backgroundEnd'] is num
          ? (data['backgroundEnd'] as num).toInt()
          : fallback['end']!,
    );
  }

  AppAppearanceSettings copyWith({
    String? preset,
    int? backgroundStart,
    int? backgroundEnd,
  }) => AppAppearanceSettings(
    preset: preset ?? this.preset,
    backgroundStart: backgroundStart ?? this.backgroundStart,
    backgroundEnd: backgroundEnd ?? this.backgroundEnd,
  );

  Map<String, dynamic> toMap() => {
    'preset': preset,
    'backgroundStart': backgroundStart,
    'backgroundEnd': backgroundEnd,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  List<Color> get gradientColors => [Color(backgroundStart), Color(backgroundEnd)];
}
