import 'package:flutter/material.dart';
import '../data/fixed_instructions.dart';

class FixedInstructionsScreen extends StatelessWidget {
  const FixedInstructionsScreen({super.key});

  static const navy = Color(0xFF082B55);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text('التعليمات الثابتة'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        itemCount: FixedInstructions.rules.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFDCE5ED)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFFE8F1F7),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    FixedInstructions.rules[index],
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      color: Color(0xFF173653),
                      fontSize: 15,
                      height: 1.7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
