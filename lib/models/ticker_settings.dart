import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TickerSettings {
  const TickerSettings({
    this.speedSeconds = 46,
    this.fontSize = 17,
    this.fontFamily = 'sans-serif',
    this.direction = 'left_to_right',
    this.bold = true,
    this.backgroundPreset = 'burgundy',
  });

  final int speedSeconds;
  final double fontSize;
  final String fontFamily;
  final String direction;
  final bool bold;
  final String backgroundPreset;

  static const Map<String, List<Color>> backgroundPresets = {
    'burgundy': [Color(0xFF71303A), Color(0xFF24191D), Color(0xFF51252D), Color(0xFF24191D)],
    'navy': [Color(0xFF174A78), Color(0xFF102A43), Color(0xFF23618C), Color(0xFF102A43)],
    'emerald': [Color(0xFF176B57), Color(0xFF123B35), Color(0xFF25836A), Color(0xFF123B35)],
    'purple': [Color(0xFF68428A), Color(0xFF302044), Color(0xFF8056A5), Color(0xFF302044)],
    'slate': [Color(0xFF526477), Color(0xFF263442), Color(0xFF687C90), Color(0xFF263442)],
    'amber': [Color(0xFF9A6425), Color(0xFF493018), Color(0xFFB47A32), Color(0xFF493018)],
  };

  static const Map<String, String> backgroundLabels = {
    'burgundy': 'خمري وفحمي',
    'navy': 'أزرق ملكي',
    'emerald': 'أخضر زمردي',
    'purple': 'بنفسجي أنيق',
    'slate': 'رمادي داكن',
    'amber': 'ذهبي دافئ',
  };

  List<Color> get backgroundColors =>
      backgroundPresets[backgroundPreset] ?? backgroundPresets['burgundy']!;

  factory TickerSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const TickerSettings();
    return TickerSettings(
      speedSeconds: (data['speedSeconds'] as num?)?.toInt().clamp(12, 120).toInt() ?? 46,
      fontSize: (data['fontSize'] as num?)?.toDouble().clamp(12, 30).toDouble() ?? 17,
      fontFamily: ['sans-serif', 'serif', 'monospace'].contains(data['fontFamily'])
          ? data['fontFamily'] as String : 'sans-serif',
      direction: data['direction'] == 'right_to_left' ? 'right_to_left' : 'left_to_right',
      bold: data['bold'] is bool ? data['bold'] as bool : true,
      backgroundPreset: backgroundPresets.containsKey(data['backgroundPreset'])
          ? data['backgroundPreset'] as String : 'burgundy',
    );
  }

  Map<String, dynamic> toMap() => {
    'speedSeconds': speedSeconds,
    'fontSize': fontSize,
    'fontFamily': fontFamily,
    'direction': direction,
    'bold': bold,
    'backgroundPreset': backgroundPreset,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  TextStyle get textStyle => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
  );
}
