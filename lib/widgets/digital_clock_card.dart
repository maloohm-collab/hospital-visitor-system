import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// A dependency-light Arabic digital clock shared by every role dashboard.
class DigitalClockCard extends StatelessWidget {
  const DigitalClockCard({super.key, this.adminStyle = false});

  final bool adminStyle;

  static const _navy = Color(0xFF082B55);
  static const _teal = Color(0xFF12B8B0);
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
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: adminStyle
                  ? const [Color(0xFFDCEEFF), Color(0xFFB9DCFA)]
                  : const [_navy, Color(0xFF14558A)],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: adminStyle ? const Color(0xFF8DBDE8) : _teal.withOpacity(0.45)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14082B55),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: adminStyle ? const Color(0xFFEAF5FF) : Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: adminStyle ? const Color(0xFF174A78) : Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _date(now),
                      style: const TextStyle(
                        color: adminStyle ? const Color(0xFF315675) : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (adminStyle)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF5FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF8DBDE8)),
                        ),
                        child: Text(
                          _time(now),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: Color(0xFF103B63),
                            fontSize: 22,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      )
                    else
                      Text(
                        _time(now),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
              const Text(
                'الوقت الحالي',
                style: TextStyle(
                  color: adminStyle ? const Color(0xFF315675) : const Color(0xFFB8F3EF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
