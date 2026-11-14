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
    this.backgroundStart = 0xFF71303A,
    this.backgroundMid = 0xFF24191D,
    this.backgroundHighlight = 0xFF51252D,
    this.backgroundEnd = 0xFF24191D,
    this.urgentBackgroundStart = 0xFF4A1520,
    this.urgentBackgroundMid = 0xFF5C1B29,
    this.urgentBackgroundHighlight = 0xFF4A1520,
    this.urgentBackgroundEnd = 0xFF3A101A,
    this.urgentRedMode = true,
    this.textColor = 0xFFFFFFFF,
    this.secondaryTextColor = 0xFFB9C5DD,
    this.accentColor = 0xFFE3B95F,
    this.iconColor = 0xFF0F2347,
    this.stripColor = 0x1AFFFFFF,
    this.borderColor = 0x4DE3B95F,
    this.progressColor = 0xFFE3B95F,
    this.navigationColor = 0xFFFFFFFF,
    this.inactiveIndicatorColor = 0xA6B9C5DD,
    this.urgentAccentColor = 0xFFE24B4A,
    this.urgentIconColor = 0xFFFFFFFF,
    this.urgentChipBackground = 0xFFF7C1C1,
    this.urgentChipText = 0xFF501313,
    this.importantChipBackground = 0xFFFAC775,
    this.importantChipText = 0xFF412402,
    this.normalChipBackground = 0xFFF4C9CF,
    this.normalChipText = 0xFF5A1E28,
  });

  final int speedSeconds;
  final double fontSize;
  final String fontFamily;
  final String direction;
  final bool bold;
  final String backgroundPreset;
  final int backgroundStart, backgroundMid, backgroundHighlight, backgroundEnd;
  final int urgentBackgroundStart, urgentBackgroundMid, urgentBackgroundHighlight, urgentBackgroundEnd;
  final bool urgentRedMode;
  final int textColor, secondaryTextColor, accentColor, iconColor, stripColor;
  final int borderColor, progressColor, navigationColor, inactiveIndicatorColor;
  final int urgentAccentColor, urgentIconColor;
  final int urgentChipBackground, urgentChipText;
  final int importantChipBackground, importantChipText;
  final int normalChipBackground, normalChipText;

  static const Map<String, List<Color>> backgroundPresets = {
    'burgundy': [Color(0xFF71303A), Color(0xFF24191D), Color(0xFF51252D), Color(0xFF24191D)],
    'navy': [Color(0xFF174A78), Color(0xFF102A43), Color(0xFF23618C), Color(0xFF102A43)],
    'emerald': [Color(0xFF176B57), Color(0xFF123B35), Color(0xFF25836A), Color(0xFF123B35)],
    'purple': [Color(0xFF68428A), Color(0xFF302044), Color(0xFF8056A5), Color(0xFF302044)],
    'slate': [Color(0xFF526477), Color(0xFF263442), Color(0xFF687C90), Color(0xFF263442)],
    'amber': [Color(0xFF9A6425), Color(0xFF493018), Color(0xFFB47A32), Color(0xFF493018)],
  };

  static const Map<String, String> backgroundLabels = {
    'burgundy': 'خمري وفحمي', 'navy': 'أزرق ملكي', 'emerald': 'أخضر زمردي',
    'purple': 'بنفسجي أنيق', 'slate': 'رمادي داكن', 'amber': 'ذهبي دافئ',
  };

  Color get text => Color(textColor);
  Color get secondaryText => Color(secondaryTextColor);
  Color get accent => Color(accentColor);
  Color get icon => Color(iconColor);
  Color get strip => Color(stripColor);
  Color get border => Color(borderColor);
  Color get progress => Color(progressColor);
  Color get navigation => Color(navigationColor);
  Color get inactiveIndicator => Color(inactiveIndicatorColor);
  Color get urgentAccent => Color(urgentAccentColor);
  Color get urgentIcon => Color(urgentIconColor);
  Color get urgentChipBg => Color(urgentChipBackground);
  Color get urgentChipFg => Color(urgentChipText);
  Color get importantChipBg => Color(importantChipBackground);
  Color get importantChipFg => Color(importantChipText);
  Color get normalChipBg => Color(normalChipBackground);
  Color get normalChipFg => Color(normalChipText);

  List<Color> get backgroundColors => [Color(backgroundStart), Color(backgroundMid), Color(backgroundHighlight), Color(backgroundEnd)];
  List<Color> get urgentBackgroundColors => [Color(urgentBackgroundStart), Color(urgentBackgroundMid), Color(urgentBackgroundHighlight), Color(urgentBackgroundEnd)];

  TickerSettings copyWith({
    int? speedSeconds, double? fontSize, String? fontFamily, String? direction,
    bool? bold, String? backgroundPreset,
    int? backgroundStart, int? backgroundMid, int? backgroundHighlight, int? backgroundEnd,
    int? urgentBackgroundStart, int? urgentBackgroundMid, int? urgentBackgroundHighlight, int? urgentBackgroundEnd,
    bool? urgentRedMode, int? textColor, int? secondaryTextColor, int? accentColor,
    int? iconColor, int? stripColor, int? borderColor, int? progressColor,
    int? navigationColor, int? inactiveIndicatorColor, int? urgentAccentColor,
    int? urgentIconColor, int? urgentChipBackground, int? urgentChipText,
    int? importantChipBackground, int? importantChipText,
    int? normalChipBackground, int? normalChipText,
  }) => TickerSettings(
    speedSeconds: speedSeconds ?? this.speedSeconds, fontSize: fontSize ?? this.fontSize,
    fontFamily: fontFamily ?? this.fontFamily, direction: direction ?? this.direction,
    bold: bold ?? this.bold, backgroundPreset: backgroundPreset ?? this.backgroundPreset,
    backgroundStart: backgroundStart ?? this.backgroundStart, backgroundMid: backgroundMid ?? this.backgroundMid,
    backgroundHighlight: backgroundHighlight ?? this.backgroundHighlight, backgroundEnd: backgroundEnd ?? this.backgroundEnd,
    urgentBackgroundStart: urgentBackgroundStart ?? this.urgentBackgroundStart,
    urgentBackgroundMid: urgentBackgroundMid ?? this.urgentBackgroundMid,
    urgentBackgroundHighlight: urgentBackgroundHighlight ?? this.urgentBackgroundHighlight,
    urgentBackgroundEnd: urgentBackgroundEnd ?? this.urgentBackgroundEnd,
    urgentRedMode: urgentRedMode ?? this.urgentRedMode, textColor: textColor ?? this.textColor,
    secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor, accentColor: accentColor ?? this.accentColor,
    iconColor: iconColor ?? this.iconColor, stripColor: stripColor ?? this.stripColor,
    borderColor: borderColor ?? this.borderColor, progressColor: progressColor ?? this.progressColor,
    navigationColor: navigationColor ?? this.navigationColor, inactiveIndicatorColor: inactiveIndicatorColor ?? this.inactiveIndicatorColor,
    urgentAccentColor: urgentAccentColor ?? this.urgentAccentColor, urgentIconColor: urgentIconColor ?? this.urgentIconColor,
    urgentChipBackground: urgentChipBackground ?? this.urgentChipBackground, urgentChipText: urgentChipText ?? this.urgentChipText,
    importantChipBackground: importantChipBackground ?? this.importantChipBackground, importantChipText: importantChipText ?? this.importantChipText,
    normalChipBackground: normalChipBackground ?? this.normalChipBackground, normalChipText: normalChipText ?? this.normalChipText,
  );

  factory TickerSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const TickerSettings();
    final preset = backgroundPresets.containsKey(data['backgroundPreset']) ? data['backgroundPreset'] as String : 'burgundy';
    final oldBg = backgroundPresets[preset]!;
    int read(String key, int fallback) => data[key] is num ? (data[key] as num).toInt() : fallback;
    return TickerSettings(
      speedSeconds: (data['speedSeconds'] as num?)?.toInt().clamp(12, 120).toInt() ?? 46,
      fontSize: (data['fontSize'] as num?)?.toDouble().clamp(12, 30).toDouble() ?? 17,
      fontFamily: ['sans-serif', 'serif', 'monospace'].contains(data['fontFamily']) ? data['fontFamily'] as String : 'sans-serif',
      direction: data['direction'] == 'right_to_left' ? 'right_to_left' : 'left_to_right',
      bold: data['bold'] is bool ? data['bold'] as bool : true,
      backgroundPreset: preset,
      backgroundStart: read('backgroundStart', oldBg[0].value), backgroundMid: read('backgroundMid', oldBg[1].value),
      backgroundHighlight: read('backgroundHighlight', oldBg[2].value), backgroundEnd: read('backgroundEnd', oldBg[3].value),
      urgentBackgroundStart: read('urgentBackgroundStart', 0xFF4A1520), urgentBackgroundMid: read('urgentBackgroundMid', 0xFF5C1B29),
      urgentBackgroundHighlight: read('urgentBackgroundHighlight', 0xFF4A1520), urgentBackgroundEnd: read('urgentBackgroundEnd', 0xFF3A101A),
      urgentRedMode: data['urgentRedMode'] is bool ? data['urgentRedMode'] as bool : true,
      textColor: read('textColor', 0xFFFFFFFF), secondaryTextColor: read('secondaryTextColor', 0xFFB9C5DD),
      accentColor: read('accentColor', 0xFFE3B95F), iconColor: read('iconColor', 0xFF0F2347),
      stripColor: read('stripColor', 0x1AFFFFFF), borderColor: read('borderColor', 0x4DE3B95F),
      progressColor: read('progressColor', 0xFFE3B95F), navigationColor: read('navigationColor', 0xFFFFFFFF),
      inactiveIndicatorColor: read('inactiveIndicatorColor', 0xA6B9C5DD), urgentAccentColor: read('urgentAccentColor', 0xFFE24B4A),
      urgentIconColor: read('urgentIconColor', 0xFFFFFFFF), urgentChipBackground: read('urgentChipBackground', 0xFFF7C1C1),
      urgentChipText: read('urgentChipText', 0xFF501313), importantChipBackground: read('importantChipBackground', 0xFFFAC775),
      importantChipText: read('importantChipText', 0xFF412402), normalChipBackground: read('normalChipBackground', 0xFFF4C9CF),
      normalChipText: read('normalChipText', 0xFF5A1E28),
    );
  }

  Map<String, dynamic> toMap() => {
    'speedSeconds': speedSeconds, 'fontSize': fontSize, 'fontFamily': fontFamily,
    'direction': direction, 'bold': bold, 'backgroundPreset': backgroundPreset,
    'backgroundStart': backgroundStart, 'backgroundMid': backgroundMid,
    'backgroundHighlight': backgroundHighlight, 'backgroundEnd': backgroundEnd,
    'urgentBackgroundStart': urgentBackgroundStart, 'urgentBackgroundMid': urgentBackgroundMid,
    'urgentBackgroundHighlight': urgentBackgroundHighlight, 'urgentBackgroundEnd': urgentBackgroundEnd,
    'urgentRedMode': urgentRedMode, 'textColor': textColor, 'secondaryTextColor': secondaryTextColor,
    'accentColor': accentColor, 'iconColor': iconColor, 'stripColor': stripColor,
    'borderColor': borderColor, 'progressColor': progressColor, 'navigationColor': navigationColor,
    'inactiveIndicatorColor': inactiveIndicatorColor, 'urgentAccentColor': urgentAccentColor,
    'urgentIconColor': urgentIconColor, 'urgentChipBackground': urgentChipBackground,
    'urgentChipText': urgentChipText, 'importantChipBackground': importantChipBackground,
    'importantChipText': importantChipText, 'normalChipBackground': normalChipBackground,
    'normalChipText': normalChipText, 'updatedAt': FieldValue.serverTimestamp(),
  };

  TextStyle get textStyle => TextStyle(fontFamily: fontFamily, fontSize: fontSize, fontWeight: bold ? FontWeight.w800 : FontWeight.w500);
}
