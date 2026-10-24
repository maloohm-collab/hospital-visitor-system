import 'package:flutter/material.dart';

class OfficialHospitalHeader extends StatelessWidget {
  const OfficialHospitalHeader({super.key});

  static const _navy = Color(0xFF082B55);
  static const _muted = Color(0xFF526579);
  static const _line = Color(0xFFDCE5ED);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A082B55),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'مستشفى الزرقاء الحكومي',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _navy,
              fontSize: 17,
              height: 1.35,
              fontWeight: FontWeight.w900,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, thickness: 1, color: _line),
          ),
          Text(
            'الصخرة للخدمات والاستشارات الأمنية',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Rock',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _navy,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}