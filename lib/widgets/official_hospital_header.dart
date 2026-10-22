import 'package:flutter/material.dart';

class OfficialHospitalHeader extends StatelessWidget {
  const OfficialHospitalHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD5E7F0)),
      ),
      child: const Column(
        children: [
          Text(
            'مستشفى الزرقاء الحكومي',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF082B55),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'شركة الصخرة للأمن والحماية',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF35516B),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}