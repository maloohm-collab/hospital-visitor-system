import 'package:cloud_firestore/cloud_firestore.dart';

class TickerSettings {
  const TickerSettings({
    this.speedSeconds = 46,
    this.fontSize = 17,
    this.fontFamily = 'sans-serif',
    this.direction = 'left_to_right',
    this.bold = true,
  });

  final int speedSeconds;
  final double fontSize;
  final String fontFamily;
  final String direction;
  final bool bold;

  factory TickerSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const TickerSettings();
    return TickerSettings(
      speedSeconds: (data['speedSeconds'] as num?)?.toInt().clamp(12, 120) ?? 46,
      fontSize: (data['fontSize'] as num?)?.toDouble().clamp(12, 30) ?? 17,
      fontFamily: ['sans-serif', 'serif', 'monospace'].contains(data['fontFamily'])
          ? data['fontFamily'] as String : 'sans-serif',
      direction: data['direction'] == 'right_to_left' ? 'right_to_left' : 'left_to_right',
      bold: data['bold'] is bool ? data['bold'] as bool : true,
    );
  }

  Map<String, dynamic> toMap() => {
    'speedSeconds': speedSeconds,
    'fontSize': fontSize,
    'fontFamily': fontFamily,
    'direction': direction,
    'bold': bold,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  TextStyle get textStyle => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
  );
}
