import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// دليل التواصل المباشر بين الموظفين النشطين.
class DirectContactScreen extends StatefulWidget {
  const DirectContactScreen({super.key});

  @override
  State<DirectContactScreen> createState() => _DirectContactScreenState();
}

class _DirectContactScreenState extends State<DirectContactScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _staffStream;

  @override
  void initState() {
    super.initState();
    _staffStream = FirebaseFirestore.instance
        .collection('users')
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  static const _navy = Color(0xFF16324F);
  static const _teal = Color(0xFF168C8C);

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'مسؤول الإدارة';
      case 'supervisor':
        return 'مشرف';
      case 'security_officer':
        return 'ضابط أمن';
      default:
        return 'موظف';
    }
  }

  String _phoneDigits(String value) =>
      value.replaceAll(RegExp(r'[^0-9+]'), '').replaceAll('+', '');

  String? _whatsAppNumber(String value) {
    var digits = _phoneDigits(value).replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    // أرقام الأردن المحلية: 07xxxxxxxx تتحول إلى 9627xxxxxxxx.
    if (digits.startsWith('0') && digits.length == 10) {
      digits = '962${digits.substring(1)}';
    } else if (digits.startsWith('7') && digits.length == 9) {
      digits = '962$digits';
    }
    if (digits.length < 8 || digits.length > 15) return null;
    return digits;
  }

  Future<void> _openPhone(BuildContext context, String phone) async {
    final digits = _phoneDigits(phone);
    if (digits.replaceAll(RegExp(r'\D'), '').length < 8) {
      _message(context, 'رقم الهاتف غير مكتمل. يرجى تحديثه من «حسابي».');
      return;
    }
    final uri = Uri(scheme: 'tel', path: digits);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _message(context, 'تعذر فتح تطبيق الاتصال على هذا الجهاز.');
      }
    } catch (_) {
      if (context.mounted) _message(context, 'تعذر فتح تطبيق الاتصال.');
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final number = _whatsAppNumber(phone);
    if (number == null) {
      _message(context, 'رقم الهاتف غير صالح لواتساب. حدّثه من «حسابي».');
      return;
    }
    final uri = Uri.https('wa.me', '/$number');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _message(context, 'تعذر فتح واتساب. تأكد من تثبيته أو جرّب الاتصال.');
      }
    } catch (_) {
      if (context.mounted) _message(context, 'تعذر فتح واتساب.');
    }
  }

  void _message(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Column(
          children: [
            Text('تواصل مباشر', style: TextStyle(fontWeight: FontWeight.w900)),
            Text('دليل الاتصال بموظفي المستشفى',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _staffStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'تعذر تحميل دليل التواصل. تأكد من اتصال الإنترنت وصلاحيات الحساب.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final query = _searchController.text.trim().toLowerCase();
            final staff = (snapshot.data?.docs ?? []).where((doc) {
              final data = doc.data();
              final name = (data['displayName'] ?? '').toString().trim().toLowerCase();
              return doc.id != currentUid &&
                  data['status'] == 'active' &&
                  ['admin', 'supervisor', 'security_officer']
                      .contains(data['role']) &&
                  (query.isEmpty || name.contains(query));
            }).toList()
              ..sort((a, b) {
                final aName = (a.data()['displayName'] ?? '').toString();
                final bName = (b.data()['displayName'] ?? '').toString();
                return aName.compareTo(bName);
              });

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5F5),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD2E9E8)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.contact_phone_rounded, color: _teal, size: 30),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'اختر الموظف للتواصل هاتفيًا أو عبر واتساب. تظهر هنا حسابات الموظفين النشطة فقط.',
                          style: TextStyle(
                            color: _navy,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن اسم الموظف...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                    filled: true,
                    fillColor: const Color(0xFFF6F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFD9E3EA)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFD9E3EA)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (staff.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.contacts_outlined, size: 46, color: Colors.blueGrey),
                        SizedBox(height: 12),
                        Text('لا يوجد موظفون نشطون آخرون في الدليل.'),
                      ],
                    ),
                  )
                else
                  ...staff.map((doc) {
                    final data = doc.data();
                    final name = (data['displayName'] ?? '').toString().trim();
                    final role = (data['role'] ?? '').toString();
                    final phone = (data['phone'] ?? '').toString().trim();
                    final shownName = name.isEmpty ? 'موظف بدون اسم' : name;
                    final hasPhone = phone.replaceAll(RegExp(r'\D'), '').length >= 8;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 11),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: const Color(0xFFE1E8EF)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF5F5),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  role == 'admin'
                                      ? Icons.admin_panel_settings_rounded
                                      : role == 'supervisor'
                                          ? Icons.supervisor_account_rounded
                                          : Icons.security_rounded,
                                  color: _teal,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      shownName,
                                      style: const TextStyle(
                                        color: _navy,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _roleLabel(role),
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F8FA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.phone_rounded,
                                    size: 18, color: _teal),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    phone.isEmpty ? 'لم يضف رقم الهاتف بعد' : phone,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      color: hasPhone
                                          ? _navy
                                          : const Color(0xFFB42318),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: hasPhone
                                      ? () => _openPhone(context, phone)
                                      : null,
                                  icon: const Icon(Icons.call_rounded),
                                  label: const Text('اتصال'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _teal,
                                    minimumSize: const Size(0, 44),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: hasPhone
                                      ? () => _openWhatsApp(context, phone)
                                      : null,
                                  icon: const Icon(Icons.chat_rounded),
                                  label: const Text('واتساب'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF218C55),
                                    minimumSize: const Size(0, 44),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                const Text(
                  'لإضافة رقمك أو تحديثه، افتح «حسابي» واحفظ رقم هاتف صحيحًا.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
