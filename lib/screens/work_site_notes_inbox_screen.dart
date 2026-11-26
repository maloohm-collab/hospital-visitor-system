import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Inbox for work-site notes addressed to the signed-in supervisor/admin.
class WorkSiteNotesInboxScreen extends StatefulWidget {
  const WorkSiteNotesInboxScreen({super.key, required this.userRole});
  final String userRole;

  @override
  State<WorkSiteNotesInboxScreen> createState() => _WorkSiteNotesInboxScreenState();
}

class _WorkSiteNotesInboxScreenState extends State<WorkSiteNotesInboxScreen> {
  static const navy = Color(0xFF0A1B33);
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final Set<String> deleting = <String>{};
  final Set<String> markingRead = <String>{};
  bool get isAdmin => widget.userRole == 'admin';

  String dateText(dynamic value) => value is Timestamp
      ? DateFormat('yyyy/MM/dd  HH:mm').format(value.toDate().toLocal())
      : 'جارٍ تسجيل الوقت...';

  Future<void> deleteNote(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الملاحظة من الوارد؟'),
        content: const Text('سيتم حذف الملاحظة نهائيًا من قائمة جميع مستلميها.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => deleting.add(doc.id));
    try {
      final reads = await doc.reference.collection('reads').get();
      for (var start = 0; start < reads.docs.length; start += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final readDoc in reads.docs.skip(start).take(400)) {
          batch.delete(readDoc.reference);
        }
        await batch.commit();
      }
      await doc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الملاحظة من الوارد.')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف الملاحظة (${e.code}).')),
        );
      }
    } finally {
      if (mounted) setState(() => deleting.remove(doc.id));
    }
  }

  Future<void> markRead(DocumentSnapshot<Map<String, dynamic>> doc) async {
    if (markingRead.contains(doc.id)) return;
    setState(() => markingRead.add(doc.id));
    try {
      await doc.reference.collection('reads').doc(uid).set({
        'readerUid': uid,
        'readAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تسجيل القراءة (${error.code}).')),
        );
      }
    } finally {
      if (mounted) setState(() => markingRead.remove(doc.id));
    }
  }

  Future<void> deleteAllNotes(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (!isAdmin || docs.isEmpty) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف جميع الملاحظات الواردة؟'),
        content: Text('سيتم حذف ${docs.length} ملاحظة نهائياً من قاعدة البيانات، وبالتالي ستختفي من صناديق وارد جميع مستلميها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف الجميع'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      for (final doc in docs) {
        final reads = await doc.reference.collection('reads').get();
        for (var readStart = 0; readStart < reads.docs.length; readStart += 400) {
          final readBatch = FirebaseFirestore.instance.batch();
          for (final readDoc in reads.docs.skip(readStart).take(400)) {
            readBatch.delete(readDoc.reference);
          }
          await readBatch.commit();
        }
      }
      for (var start = 0; start < docs.length; start += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in docs.skip(start).take(400)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف ${docs.length} ملاحظة.')),
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف جميع الملاحظات (${error.code}).')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Scaffold(body: Center(child: Text('يرجى تسجيل الدخول أولًا.')));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text('ملاحظات مواقع العمل الواردة'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('work_shift_notes')
            .where('recipientUids', arrayContains: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'تعذر تحميل الملاحظات الواردة. تحقق من اتصال Firestore وصلاحيات القراءة.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = [...?snapshot.data?.docs]
            ..sort((a, b) {
              final aTime = a.data()['createdAt'];
              final bTime = b.data()['createdAt'];
              if (aTime is Timestamp && bTime is Timestamp) {
                return bTime.compareTo(aTime);
              }
              return 0;
            });
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sticky_note_2_outlined, size: 54, color: Color(0xFF8796A5)),
                    SizedBox(height: 12),
                    Text(
                      'لا توجد ملاحظات مواقع عمل واردة.',
                      style: TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length + (isAdmin ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (isAdmin && index == 0) {
                return Card(
                  color: const Color(0xFFFFF7F5),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'تنظيف صندوق الوارد',
                            style: TextStyle(color: navy, fontWeight: FontWeight.w800),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: docs.isEmpty ? null : () => deleteAllNotes(docs),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: const Text('حذف الكل'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final doc = docs[index - (isAdmin ? 1 : 0)];
              final data = doc.data();
              final edited = data['updatedAt'] is Timestamp;
              final isDeleting = deleting.contains(doc.id);
              return Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFDCE5ED)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Color(0xFF16845B)),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              data['locationName'] as String? ?? 'موقع غير محدد',
                              style: const TextStyle(
                                color: navy,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (edited)
                            const Chip(
                              label: Text('معدّلة'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['body'] as String? ?? '',
                        style: const TextStyle(
                          color: Color(0xFF172B45),
                          fontSize: 16,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'المرسل: ${data['officerName'] ?? 'ضابط الأمن'}',
                        style: const TextStyle(
                          color: Color(0xFF33485C),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: doc.reference.collection('reads').doc(uid).snapshots(),
                        builder: (context, readSnapshot) {
                          final isRead = readSnapshot.data?.exists == true;
                          final isMarking = markingRead.contains(doc.id);
                          return Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: isRead
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.done_all_rounded, color: Color(0xFF16845B), size: 18),
                                      SizedBox(width: 5),
                                      Text('تم الاطلاع على الملاحظة', style: TextStyle(color: Color(0xFF16845B), fontWeight: FontWeight.w800)),
                                    ],
                                  )
                                : TextButton.icon(
                                    onPressed: isMarking ? null : () => markRead(doc),
                                    icon: isMarking
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.mark_email_read_outlined),
                                    label: const Text('تأكيد الاطلاع'),
                                  ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تاريخ الإرسال: ${dateText(data['createdAt'])}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      if (edited)
                        Text(
                          'آخر تعديل: ${dateText(data['updatedAt'])}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: isDeleting ? null : () => deleteNote(doc),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          icon: isDeleting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.delete_outline_rounded),
                          label: const Text('حذف الملاحظة'),
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
