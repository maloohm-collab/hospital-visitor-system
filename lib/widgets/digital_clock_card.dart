import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// A shared, full-width Arabic digital clock for all dashboard roles.
class DigitalClockCard extends StatelessWidget {
  const DigitalClockCard({super.key, this.adminStyle = false});

  // Kept for API compatibility with existing dashboard callers.
  final bool adminStyle;

  static const _navy = Color(0xFF082B55);
  static const _muted = Color(0xFF49647D);
  static const _weekdays = <String>[
    'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس',
    'الجمعة', 'السبت', 'الأحد',
  ];
  static const _months = <String>[
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  String _two(int value) => value.toString().padLeft(2, '0');

  String _time(DateTime value) =>
      '${_two(value.hour)}:${_two(value.minute)}:${_two(value.second)}';

  String _date(DateTime value) =>
      '${_weekdays[value.weekday - 1]}، ${value.day} ${_months[value.month - 1]} ${value.year}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEAF4FC), Color(0xFFDCEBFA)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD3E3F1), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D082B55),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: _navy, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _date(now),
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Text(
                    'الوقت الحالي',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _time(now),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 42,
                    height: 1.18,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
