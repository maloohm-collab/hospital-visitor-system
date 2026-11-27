import 'package:cloud_firestore/cloud_firestore.dart';
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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('app_settings')
            .doc('fixed_instructions')
            .snapshots(),
        builder: (context, snapshot) {
          final stored = snapshot.data?.data()?['rules'];
          final rules = stored is List
              ? stored.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList()
              : FixedInstructions.rules;
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (rules.isEmpty) {
            return const Center(child: Text('لا توجد تعليمات ثابتة حالياً.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            itemCount: rules.length + (snapshot.hasError ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (snapshot.hasError && index == 0) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'تعذر تحديث القائمة من الخادم؛ المعروض حالياً هو الإصدار الأساسي من التعليمات.',
                    style: TextStyle(color: Colors.deepOrange, fontSize: 12),
                  ),
                );
              }
              final ruleIndex = index - (snapshot.hasError ? 1 : 0);
              return Card(
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
                        '${ruleIndex + 1}',
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        rules[ruleIndex],
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
            );
            },
          );
        },
      ),
    );
  }
}
