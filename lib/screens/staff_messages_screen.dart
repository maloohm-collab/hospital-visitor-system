import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class StaffMessagesScreen extends StatefulWidget {
  const StaffMessagesScreen({super.key, required this.userRole, this.initialMessageId, this.initialRecipientUid, this.openComposerOnStart = false, this.embedded = false});
  final String userRole;
  final String? initialMessageId;
  final String? initialRecipientUid;
  final bool openComposerOnStart;
  final bool embedded;
  @override
  State<StaffMessagesScreen> createState() => _StaffMessagesScreenState();
}

class _StaffMessagesScreenState extends State<StaffMessagesScreen> with SingleTickerProviderStateMixin {
  static const navy = Color(0xFF082B55), teal = Color(0xFF087E78);
  static const bool _storageFeaturesEnabled = false;
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  late final TabController tabs;
  String search = '';
  final Set<String> selectedMessageIds = <String>{};
  Timer? archiveRefreshTimer;
  String get uid => auth.currentUser?.uid ?? '';
  bool get admin => widget.userRole == 'admin';
  bool get supervisor => widget.userRole == 'supervisor';

  String personName(Map<String, dynamic> data) {
    for (final key in ['displayName', 'fullName', 'name', 'username']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty && !value.contains('@')) {
        return value.trim();
      }
    }
    return 'مستخدم';
  }

  String roleSignature(String? role, Map<String, dynamic> data) {
    final designation = [
      data['jobTitle'], data['position'], data['accountTitle'],
      data['displayRole'], data['specialization'], data['unit'],
    ].whereType<String>().join(' ').toLowerCase();
    final isSwat = role == 'swat' ||
        data['isSwat'] == true ||
        data['swat'] == true ||
        designation.contains('سوات') ||
        designation.contains('swat');
    if (role == 'admin') return 'مدير الموقع';
    if (isSwat) return 'سوات/SWAT';
    if (role == 'supervisor') return 'المشرف';
    if (role == 'security_officer') return 'ضابط الأمن';
    return 'مستخدم';
  }

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this);
    archiveRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
    final messageId = widget.initialMessageId;
    if (widget.openComposerOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) compose();
      });
    } else if (messageId != null && messageId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final doc = await db.collection('staff_messages').doc(messageId).get();
          if (mounted && doc.exists) await openMessage(doc);
        } catch (_) { toast('تعذر فتح الملاحظة المرتبطة بالإشعار.'); }
      });
    }
  }
  @override
  void dispose() { archiveRefreshTimer?.cancel(); tabs.dispose(); super.dispose(); }
  void toast(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _attachmentContentType(XFile file) {
    final supplied = (file.mimeType ?? '').toLowerCase().trim();
    if (supplied == 'image/jpg') return 'image/jpeg';
    if (supplied.isNotEmpty) return supplied;
    final extension = file.name.split('.').last.toLowerCase();
    const types = <String, String>{
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'webp': 'image/webp', 'heic': 'image/heic', 'gif': 'image/gif',
      'pdf': 'application/pdf', 'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt': 'text/plain', 'csv': 'text/csv', 'mp3': 'audio/mpeg',
      'wav': 'audio/wav', 'm4a': 'audio/mp4', 'mp4': 'video/mp4',
      'mov': 'video/quicktime', 'zip': 'application/zip',
    };
    return types[extension] ?? 'application/octet-stream';
  }

  bool _isAllowedAttachmentType(String type) {
    return const {
      'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/gif',
      'application/pdf', 'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'text/plain', 'text/csv', 'audio/mpeg', 'audio/wav', 'audio/mp4',
      'video/mp4', 'video/quicktime', 'application/zip',
      'application/octet-stream',
    }.contains(type);
  }

  Future<void> _showComingSoonFeature(String feature) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ستتوفر هذه الخدمة قريباً'),
        content: Text('ميزة ' + feature + ' قيد التجهيز. ستصبح متاحة بعد تفعيل خدمة التخزين المطلوبة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('حسناً')),
        ],
      ),
    );
  }

  Future<void> _contactEmployee(String phone, {required bool whatsapp}) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 9) { toast('رقم الهاتف غير مكتمل.'); return; }
    var international = digits;
    if (international.startsWith('0')) {
      international = '962' + international.substring(1);
    } else if (international.startsWith('7') && international.length == 9) {
      international = '962' + international;
    }
    final uri = whatsapp
        ? Uri.parse('https://wa.me/' + international)
        : Uri(scheme: 'tel', path: phone.trim());
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) toast(whatsapp ? 'تعذر فتح واتساب على هذا الجهاز.' : 'تعذر فتح تطبيق الاتصال.');
    } catch (_) {
      toast(whatsapp ? 'تعذر فتح واتساب.' : 'تعذر بدء الاتصال.');
    }
  }

  Future<void> _contactMessageSender(String senderUid) async {
    if (senderUid.isEmpty) {
      toast('تعذر تحديد صاحب الملاحظة.');
      return;
    }
    try {
      // Query active profiles so Firestore's active-user list rule applies;
      // direct get() of another employee's document is intentionally restricted.
      final profiles = await db.collection('users')
          .where(FieldPath.documentId, isEqualTo: senderUid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      if (profiles.docs.isEmpty) {
        toast('تعذر العثور على ملف صاحب الملاحظة أو أن حسابه غير نشط.');
        return;
      }
      final phone = (profiles.docs.first.data()['phone'] ?? '').toString().trim();
      if (phone.isEmpty) {
        toast('لا يوجد رقم هاتف مسجل لصاحب الملاحظة.');
        return;
      }
      await _contactEmployee(phone, whatsapp: false);
    } on FirebaseException catch (e) {
      toast('تعذر تحميل رقم الهاتف (${e.code}).');
    } catch (_) {
      toast('تعذر تحميل بيانات صاحب الملاحظة.');
    }
  }

  Future<void> _likeMessage(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final message = doc.data() ?? <String, dynamic>{};
    if (message['recipientUid'] != uid) {
      toast('الإعجاب متاح لمستلم الملاحظة فقط.');
      return;
    }
    if (message['liked'] == true) {
      toast('سبق تسجيل إعجابك بهذه الملاحظة.');
      return;
    }
    try {
      final profile = await db.collection('users').doc(uid).get();
      final profileData = profile.data() ?? <String, dynamic>{};
      final senderUid = (message['senderUid'] ?? '').toString();
      if (senderUid.isEmpty) throw StateError('تعذر تحديد مرسل الملاحظة.');
      final notificationRef = db.collection('notifications').doc();
      final batch = db.batch();
      batch.update(doc.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
        'liked': true,
        'likedAt': FieldValue.serverTimestamp(),
        'likedByUid': uid,
        'likedByName': personName(profileData),
      });
      batch.set(notificationRef, {
        'notificationId': notificationRef.id,
        'recipientUid': senderUid,
        'recipientRole': (message['senderRole'] ?? '').toString(),
        'senderUid': uid,
        'senderEmail': auth.currentUser?.email ?? '',
        'senderName': personName(profileData),
        'title': 'تم الاطلاع على ملاحظتك',
        'body': 'اطّلع ' + personName(profileData) + ' على ملاحظتك وأعجب بها 👍',
        'priority': 'normal',
        'read': false,
        'kind': 'staff_message_liked',
        'relatedId': doc.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (mounted) toast('تم تسجيل الإعجاب وإشعار صاحب الملاحظة.');
    } on FirebaseException catch (e) {
      toast('تعذر تسجيل الإعجاب (${e.code}).');
    } catch (e) {
      toast(e.toString().replaceFirst('Bad state: ', ''));
    }
  }


    final title = TextEditingController();
    final body = TextEditingController();
    final selected = <String>{};
    final initialRecipient = widget.initialRecipientUid;
    if (initialRecipient != null && users.any((d) => d.id == initialRecipient)) {
      selected.add(initialRecipient);
    }
    final pickedImages = <XFile>[];
    String messageType = widget.userRole == 'security_officer' ? 'note' : 'instruction';
    String priority = 'normal';
    bool requestReply = false;
    bool customTickerStyle = false;
    double tickerFontSize = 17;
    String tickerFontFamily = 'sans-serif';
    bool tickerBold = true;
    bool busy = false;
    String employeeSearch = '';
    String shiftFilter = 'all';
    int currentStep = 0;

    const pastelBg = Color(0xFFF5F7FB);
    const pastelBlue = Color(0xFF7898B8);
    const pastelMint = Color(0xFF8FB9AD);
    const pastelInk = Color(0xFF43566D);
    const pastelLine = Color(0xFFE2E9F1);
    const stepNames = ['نوع الرسالة', 'المستلمون', 'المحتوى', 'المرفقات', 'المراجعة'];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (sheet) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: pastelBg,
        child: SizedBox.expand(
          child: StatefulBuilder(
            builder: (ctx, refresh) {
              final pageWidgets = <Widget>[
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF0F7),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Row(children: [
                          Icon(Icons.mark_email_unread_rounded, color: pastelBlue, size: 30),
                          SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('اختر نوع الرسالة', style: TextStyle(
                                color: pastelInk, fontSize: 19, fontWeight: FontWeight.w800)),
                              SizedBox(height: 4),
                              Text('حدد طبيعة الرسالة قبل اختيار المستلمين.',
                                style: TextStyle(color: Color(0xFF8291A3), fontSize: 13)),
                            ],
                          )),
                        ]),
                      ),
                      const SizedBox(height: 18),
                if (admin || supervisor)
                  DropdownButtonFormField<String>(
                    value: messageType,
                    decoration: const InputDecoration(labelText: 'نوع الرسالة'),
                    items: const [
                      DropdownMenuItem(value: 'instruction', child: Text('تعليمة')),
                      DropdownMenuItem(value: 'note', child: Text('ملاحظة')),
                    ],
                    onChanged: (value) => refresh(() => messageType = value ?? 'instruction'),
                  )
                else
                  const Text('نوع الرسالة: ملاحظة ميدانية'),

                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF5F3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(children: [
                          const Icon(Icons.groups_2_rounded, color: pastelMint, size: 30),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('تحديد المستلمين', style: TextStyle(
                                color: pastelInk, fontSize: 19, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('تم اختيار ${selected.length} مستلم',
                                style: const TextStyle(color: Color(0xFF8291A3), fontSize: 13)),
                            ],
                          )),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                            child: Text('${selected.length}', style: const TextStyle(
                              color: pastelInk, fontWeight: FontWeight.w800)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                Text(supervisor
                    ? 'اختر ضباط الأمن — نسخة الإدارة تُرسل تلقائياً مع التعليمات فقط: ${selected.length}'
                    : 'اختر المستلمين — المختار: ${selected.length}'),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'ابحث بالاسم الرباعي أو رقم الهاتف',
                    prefixIcon: Icon(Icons.search_rounded), isDense: true),
                  onChanged: (value) => refresh(() => employeeSearch = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: shiftFilter,
                  decoration: const InputDecoration(labelText: 'فلترة إضافية حسب الشفت'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('جميع الشفتات')),
                    DropdownMenuItem(value: 'A', child: Text('الشفت A')),
                    DropdownMenuItem(value: 'B', child: Text('الشفت B')),
                    DropdownMenuItem(value: 'C', child: Text('الشفت C')),
                  ],
                  onChanged: (value) => refresh(() => shiftFilter = value ?? 'all'),
                ),
                Wrap(spacing: 6, children: [
                  TextButton(
                    onPressed: () => refresh(() => selected.addAll(
                      users.where((u) => !supervisor ||
                        u.data()['role'] == 'security_officer').map((u) => u.id))),
                    child: Text(supervisor ? 'جميع ضباط الأمن' : 'اختيار الجميع')),
                  if (admin) TextButton(
                    onPressed: () => refresh(() => selected.addAll(
                      users.where((u) => u.data()['role'] == 'security_officer').map((u) => u.id))),
                    child: const Text('جميع ضباط الأمن')),
                  if (admin) TextButton(
                    onPressed: () => refresh(() => selected.addAll(
                      users.where((u) => u.data()['role'] == 'supervisor').map((u) => u.id))),
                    child: const Text('جميع المشرفين')),
                  TextButton(onPressed: () => refresh(selected.clear), child: const Text('إلغاء التحديد')),
                ]),
                SizedBox(height: 300, child: Builder(builder: (listContext) {
                  final filteredUsers = users.where((d) {
                    final data = d.data();
                    final name = (data['displayName'] ?? data['fullName'] ?? '').toString().toLowerCase();
                    final phone = (data['phone'] ?? '').toString().toLowerCase();
                    final matchesText = employeeSearch.isEmpty || name.contains(employeeSearch) || phone.contains(employeeSearch);
                    final shift = (data['currentShift'] ?? '').toString();
                    return matchesText && (shiftFilter == 'all' || shift == shiftFilter);
                  }).toList();
                  if (filteredUsers.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج مطابقة لخيارات البحث.'));
                  }
                  return ListView(children: filteredUsers.map((d) {
                    final data = d.data();
                    final role = data['role'] == 'admin' ? 'الإدارة' :
                      data['role'] == 'supervisor' ? 'مشرف' : 'ضابط أمن';
                    final phone = (data['phone'] ?? '').toString().trim();
                    final shift = (data['currentShift'] ?? 'غير محدد').toString();
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(children: [
                          CheckboxListTile(
                            dense: true,
                            value: selected.contains(d.id),
                            title: Text(personName(data), style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('$role • الشفت $shift • ${phone.isEmpty ? 'لا يوجد رقم هاتف' : phone}'),
                            onChanged: (v) => refresh(() {
                              if (v == true) selected.add(d.id);
                              if (v == false) selected.remove(d.id);
                            }),
                          ),
                          if (phone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: Row(children: [
                                Expanded(child: OutlinedButton.icon(
                                  onPressed: () => _contactEmployee(phone, whatsapp: false),
                                  icon: const Icon(Icons.call_outlined, size: 18),
                                  label: const Text('اتصال مباشر'))),
                                const SizedBox(width: 8),
                                Expanded(child: OutlinedButton.icon(
                                  onPressed: () => _contactEmployee(phone, whatsapp: true),
                                  icon: const Icon(Icons.chat_outlined, size: 18),
                                  label: const Text('واتساب'))),
                              ]),
                            ),
                        ]),
                      ),
                    );
                  }).toList());
                })),

                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(children: [
                        Icon(Icons.edit_note_rounded, color: Color(0xFF9C91B5), size: 30),
                        SizedBox(width: 10),
                        Text('اكتب تفاصيل الرسالة', style: TextStyle(
                          color: pastelInk, fontSize: 19, fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 18),
                TextField(controller: title,
                  decoration: const InputDecoration(labelText: 'عنوان الملاحظة')),
                const SizedBox(height: 8),
                TextField(controller: body, minLines: 3, maxLines: 5,
                  decoration: const InputDecoration(labelText: 'التفاصيل النصية')),

                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(children: [
                        Icon(Icons.attach_file_rounded, color: pastelBlue, size: 28),
                        SizedBox(width: 10),
                        Text('المرفقات وخيارات الرسالة', style: TextStyle(
                          color: pastelInk, fontSize: 19, fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 14),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (!_storageFeaturesEnabled) {
                          await _showComingSoonFeature('إرفاق أي ملف من الهاتف');
                          return;
                        }
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            withData: true,
                            type: FileType.any,
                          );
                          if (result == null) return;
                          var added = 0;
                          for (final file in result.files) {
                            if (pickedImages.length >= 5) break;
                            if (file.size > 25 * 1024 * 1024) {
                              toast('الملف ${file.name} أكبر من 25 ميغابايت ولم تتم إضافته.');
                              continue;
                            }
                            final bytes = file.bytes;
                            final XFile selectedFile;
                            if (bytes != null) {
                              selectedFile = XFile.fromData(
                                bytes,
                                name: file.name,
                              );
                            } else if (file.path != null) {
                              selectedFile = XFile(file.path!);
                            } else {
                              continue;
                            }
                            if (!_isAllowedAttachmentType(_attachmentContentType(selectedFile))) {
                              toast('نوع الملف ${file.name} غير مدعوم حالياً.');
                              continue;
                            }
                            pickedImages.add(selectedFile);
                            added++;
                          }
                          refresh(() {});
                          if (added > 0) toast('تمت إضافة $added مرفق.');
                        } catch (_) {
                          toast('تعذر اختيار الملفات من الهاتف.');
                        }
                      },
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('إرفاق ملف من الهاتف'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (!_storageFeaturesEnabled) {
                          await _showComingSoonFeature('فتح كاميرا الهاتف مباشرة');
                          return;
                        }
                        try {
                          final photo = await ImagePicker().pickImage(
                            source: ImageSource.camera,
                            imageQuality: 85,
                            maxWidth: 1800,
                          );
                          if (photo == null) return;
                          if (await photo.length() > 25 * 1024 * 1024) {
                            toast('الصورة أكبر من 25 ميغابايت.');
                            return;
                          }
                          if (pickedImages.length >= 5) {
                            toast('الحد الأقصى خمسة مرفقات للرسالة الواحدة.');
                            return;
                          }
                          pickedImages.add(photo);
                          refresh(() {});
                        } catch (_) {
                          toast('تعذر فتح كاميرا الهاتف. تحقق من صلاحية الكاميرا.');
                        }
                      },
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('فتح الكاميرا مباشرة'),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (!_storageFeaturesEnabled) {
                      await _showComingSoonFeature('إرفاق الصور من المعرض');
                      return;
                    }
                    try {
                      final remaining = 5 - pickedImages.length;
                      if (remaining <= 0) {
                        toast('الحد الأقصى خمس صور للملاحظة الواحدة.');
                        return;
                      }
                      final images = await ImagePicker().pickMultiImage(
                        imageQuality: 85,
                        maxWidth: 1800,
                      );
                      if (images.isEmpty) return;
                      var added = 0;
                      for (final image in images) {
                        if (pickedImages.length >= 5) break;
                        final size = await image.length();
                        if (size > 25 * 1024 * 1024) {
                          toast('تم تجاوز مرفق أكبر من 25 ميغابايت؛ لم تتم إضافته.');
                          continue;
                        }
                        pickedImages.add(image);
                        added++;
                      }
                      refresh(() {});
                      if (images.length > remaining) {
                        toast('تمت إضافة $added صور فقط؛ الحد الأقصى خمس صور.');
                      }
                    } catch (_) {
                      toast('تعذر فتح معرض الصور.');
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text('إرفاق صور أو ملفات (${pickedImages.length}/5)'),
                ),
                if (pickedImages.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: pickedImages.asMap().entries.map((entry) => InputChip(
                      avatar: const Icon(Icons.attach_file_rounded, size: 18),
                      label: SizedBox(
                        width: 125,
                        child: Text(entry.value.name, overflow: TextOverflow.ellipsis),
                      ),
                      onDeleted: () => refresh(() => pickedImages.removeAt(entry.key)),
                    )).toList(),
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'الأهمية'),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('عادية')),
                    DropdownMenuItem(value: 'important', child: Text('مهمة')),
                    DropdownMenuItem(value: 'urgent', child: Text('عاجلة')),
                  ],
                  onChanged: (v) => refresh(() => priority = v ?? 'normal'),
                ),
                if (supervisor) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تخصيص تنسيق هذه الملاحظة على الشريط'),
                    subtitle: const Text('يُطبّق عند تعميم المشرف على جميع ضباط الأمن فقط، ولا يغيّر الإعدادات العامة.'),
                    value: customTickerStyle,
                    onChanged: (v) => refresh(() => customTickerStyle = v),
                  ),
                  if (customTickerStyle) ...[
                    Text('حجم خط هذه الملاحظة: ${tickerFontSize.round()}'),
                    Slider(
                      min: 12, max: 30, divisions: 18, value: tickerFontSize,
                      onChanged: (v) => refresh(() => tickerFontSize = v),
                    ),
                    DropdownButtonFormField<String>(
                      value: tickerFontFamily,
                      decoration: const InputDecoration(labelText: 'نوع الخط لهذه الملاحظة'),
                      items: const [
                        DropdownMenuItem(value: 'sans-serif', child: Text('خط واضح')),
                        DropdownMenuItem(value: 'serif', child: Text('خط كلاسيكي')),
                        DropdownMenuItem(value: 'monospace', child: Text('خط ثابت العرض')),
                      ],
                      onChanged: (v) => refresh(() => tickerFontFamily = v ?? 'sans-serif'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('خط عريض للملاحظة'),
                      value: tickerBold,
                      onChanged: (v) => refresh(() => tickerBold = v),
                    ),
                  ],
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('طلب الرد على الملاحظة'),
                  value: requestReply,
                  onChanged: (v) => refresh(() => requestReply = v),
                ),

                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3EF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Column(children: [
                          Icon(Icons.fact_check_rounded, color: pastelMint, size: 38),
                          SizedBox(height: 8),
                          Text('راجع رسالتك قبل الإرسال', style: TextStyle(
                            color: pastelInk, fontSize: 19, fontWeight: FontWeight.w800)),
                          SizedBox(height: 4),
                          Text('تأكد من صحة المستلمين والمحتوى والخيارات.',
                            style: TextStyle(color: Color(0xFF8291A3), fontSize: 13)),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      _reviewTile(Icons.description_outlined, 'نوع الرسالة',
                        messageType == 'instruction' ? 'تعليمة إدارية' : 'ملاحظة ميدانية'),
                      _reviewTile(Icons.people_alt_outlined, 'المستلمون',
                        '${selected.length} مستلم'),
                      _reviewTile(Icons.title_rounded, 'العنوان',
                        title.text.trim().isEmpty ? 'غير مكتمل' : title.text.trim()),
                      _reviewTile(Icons.notes_rounded, 'التفاصيل',
                        body.text.trim().isEmpty ? 'غير مكتملة' : body.text.trim()),
                      _reviewTile(Icons.attach_file_rounded, 'المرفقات',
                        '${pickedImages.length} من 5'),
                      _reviewTile(Icons.flag_outlined, 'الأهمية',
                        priority == 'urgent' ? 'عاجلة' : priority == 'important' ? 'مهمة' : 'عادية'),
                      _reviewTile(Icons.reply_rounded, 'طلب الرد',
                        requestReply ? 'مطلوب' : 'غير مطلوب'),
                      if (supervisor && customTickerStyle)
                        _reviewTile(Icons.tune_rounded, 'تنسيق الشريط',
                          'حجم ${tickerFontSize.round()} • ${tickerBold ? 'عريض' : 'عادي'}'),
                    ],
                  ),
                ),
              ];

              return SafeArea(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: pastelLine)),
                      ),
                      child: Column(children: [
                        Row(children: [
                          IconButton(
                            tooltip: 'إغلاق',
                            onPressed: busy ? null : () => Navigator.pop(sheet),
                            icon: const Icon(Icons.close_rounded, color: pastelInk),
                          ),
                          const Expanded(child: Text('إنشاء رسالة جديدة', textAlign: TextAlign.center,
                            style: TextStyle(color: pastelInk, fontSize: 18, fontWeight: FontWeight.w800))),
                          const SizedBox(width: 48),
                        ]),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(stepNames.length, (index) {
                            final active = index == currentStep;
                            final completed = index < currentStep;
                            return Expanded(child: Column(children: [
                              Row(children: [
                                Expanded(child: Container(height: 3,
                                  color: index == 0 ? Colors.transparent :
                                    (completed || active ? pastelBlue : pastelLine))),
                                Container(
                                  width: 29, height: 29,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: completed ? pastelMint : active ? pastelBlue : const Color(0xFFE9EEF4),
                                  ),
                                  child: Center(child: completed
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
                                    : Text('${index + 1}', style: TextStyle(
                                      color: active ? Colors.white : const Color(0xFF94A1B0),
                                      fontWeight: FontWeight.w800, fontSize: 12))),
                                ),
                                Expanded(child: Container(height: 3,
                                  color: index == stepNames.length - 1 ? Colors.transparent :
                                    (completed ? pastelBlue : pastelLine))),
                              ]),
                              const SizedBox(height: 5),
                              Text(stepNames[index], maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10,
                                  color: active ? pastelInk : const Color(0xFF98A4B2),
                                  fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
                            ]));
                          }),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: (currentStep + 1) / stepNames.length,
                            minHeight: 4,
                            backgroundColor: const Color(0xFFEDF1F5),
                            valueColor: const AlwaysStoppedAnimation<Color>(pastelBlue),
                          ),
                        ),
                      ]),
                    ),
                    Expanded(
                      child: Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                            primary: pastelBlue,
                            secondary: pastelMint,
                            surface: Colors.white,
                          ),
                          inputDecorationTheme: InputDecorationTheme(
                            filled: true,
                            fillColor: Colors.white,
                            labelStyle: const TextStyle(color: Color(0xFF8492A3)),
                            hintStyle: const TextStyle(color: Color(0xFFA1ACB9)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(17),
                              borderSide: const BorderSide(color: pastelLine),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(17),
                              borderSide: const BorderSide(color: pastelLine),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(17),
                              borderSide: const BorderSide(color: pastelBlue, width: 1.4),
                            ),
                          ),
                          cardTheme: CardTheme(
                            color: Colors.white,
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                              side: const BorderSide(color: pastelLine),
                            ),
                          ),
                        ),
                        child: IndexedStack(index: currentStep, children: pageWidgets),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: pastelLine)),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy || currentStep == 0 ? null :
                              () => refresh(() => currentStep--),
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: const Text('السابق'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: pastelInk,
                              side: const BorderSide(color: pastelLine),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: currentStep < 4
                            ? FilledButton.icon(
                                onPressed: () {
                                  if (currentStep == 1 && selected.isEmpty) {
                                    toast('اختر مستلماً واحداً على الأقل للمتابعة.');
                                    return;
                                  }
                                  if (currentStep == 2 &&
                                      (title.text.trim().length < 3 || body.text.trim().length < 3)) {
                                    toast('أدخل عنواناً وتفاصيل نصية لا تقل عن ثلاثة أحرف.');
                                    return;
                                  }
                                  refresh(() => currentStep++);
                                },
                                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                label: const Text('التالي'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: pastelBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              )
                            :                 FilledButton.icon(
                  onPressed: busy ? null : () async {
                    if (selected.isEmpty) {
                      toast('اختر مستلماً واحداً على الأقل.');
                      return;
                    }
                    if (selected.length > 450) {
                      toast('يمكن إرسال الرسالة إلى 450 مستلماً كحد أقصى في المرة الواحدة.');
                      return;
                    }
                    if (title.text.trim().length < 3 || body.text.trim().length < 3) {
                      toast('أدخل عنواناً وتفاصيل نصية لا تقل عن ثلاثة أحرف.');
                      return;
                    }
                    refresh(() => busy = true);
                    final uploadedRefs = <Reference>[];
                    try {
                      final senderSnap = await db.collection('users').doc(uid).get();
                      final sender = senderSnap.data() ?? <String, dynamic>{};
                      final senderRole = (sender['role'] ?? '').toString();
                      if (!['admin', 'supervisor', 'security_officer'].contains(senderRole)) {
                        throw StateError('تعذر التحقق من دور حساب المرسل. أعد تسجيل الدخول ثم حاول مجدداً.');
                      }
                      if (senderRole == 'security_officer' && messageType != 'note') {
                        throw StateError('ضابط الأمن يستطيع إرسال الملاحظات الميدانية فقط.');
                      }
                      String currentLocation = '';
                      if (senderRole == 'security_officer') {
                        final pointer = await db.collection('active_work_shifts').doc(uid).get();
                        final shiftId = pointer.data()?['shiftId'];
                        if (shiftId is String && shiftId.isNotEmpty) {
                          final shift = await db.collection('work_shifts').doc(shiftId).get();
                          currentLocation = (shift.data()?['activeLocationName'] ?? '').toString();
                        }
                      }
                      final selectedRecipients =
                          users.where((d) => selected.contains(d.id)).toList();
                      final adminCopies = senderRole == 'supervisor' && messageType == 'instruction'
                          ? activeUsers.where((d) => d.data()['role'] == 'admin').toList()
                          : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      if (senderRole == 'supervisor' &&
                          messageType == 'instruction' &&
                          adminCopies.isEmpty) {
                        throw StateError('لا يوجد حساب إداري نشط لاستلام نسخة من التعليمة.');
                      }
                      final recipientsByUid = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
                      for (final recipient in selectedRecipients) {
                        recipientsByUid[recipient.id] = recipient;
                      }
                      for (final recipient in adminCopies) {
                        recipientsByUid[recipient.id] = recipient;
                      }
                      final messageRecipients = recipientsByUid.values.toList();
                      final threadId = db.collection('staff_messages').doc().id;
                      final uploadedAttachments = <Map<String, dynamic>>[];
                      if (pickedImages.isNotEmpty) {
                        try {
                          for (var index = 0; index < pickedImages.length; index++) {
                            final image = pickedImages[index];
                            final safeName = image.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
                            final shortName = safeName.length > 120
                                ? safeName.substring(safeName.length - 120)
                                : safeName;
                            final fileName = '${DateTime.now().microsecondsSinceEpoch}_${index}_$shortName';
                            final contentType = _attachmentContentType(image);
                            if (!_isAllowedAttachmentType(contentType)) {
                              throw StateError('نوع الملف غير مدعوم: ' + image.name);
                            }
                            if (await image.length() > 25 * 1024 * 1024) {
                              throw StateError('حجم المرفق يتجاوز 25 ميغابايت.');
                            }
                            final storageRef = FirebaseStorage.instance
                                .ref()
                                .child('staff_message_media/$threadId/$uid/$fileName');
                            uploadedRefs.add(storageRef);
                            await storageRef.putData(
                              await image.readAsBytes(),
                              SettableMetadata(contentType: contentType),
                            );
                            uploadedAttachments.add({
                              'storagePath': storageRef.fullPath,
                              'downloadUrl': await storageRef.getDownloadURL(),
                              'fileName': fileName,
                              'contentType': contentType,
                              'sizeBytes': await image.length(),
                            });
                          }
                        } catch (_) {
                          for (final uploaded in uploadedRefs) {
                            try { await uploaded.delete(); } catch (_) {}
                          }
                          final sendWithoutImages = await showDialog<bool>(
                            context: ctx,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('تعذر إرفاق الملفات'),
                              content: const Text(
                                'خدمة تخزين الصور غير متاحة حالياً أو تعذر رفع إحدى الصور. '
                                'يمكنك إرسال الرسالة نصياً الآن دون مرفقات، أو إلغاء الإرسال والمحاولة لاحقاً.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  child: const Text('إلغاء الإرسال'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  child: const Text('إرسال دون مرفقات'),
                                ),
                              ],
                            ),
                          );
                          if (sendWithoutImages != true) {
                            throw StateError('تم إلغاء الإرسال؛ لم يتم إرسال الملاحظة.');
                          }
                          uploadedRefs.clear();
                          uploadedAttachments.clear();
                          pickedImages.clear();
                          refresh(() {});
                        }
                      }
                      final activeOfficerIds = users
                          .where((d) => d.data()['role'] == 'security_officer')
                          .map((d) => d.id)
                          .toSet();
                      final isSupervisorBroadcastToAllOfficers =
                          senderRole == 'supervisor' &&
                          activeOfficerIds.isNotEmpty &&
                          activeOfficerIds.every(selected.contains);
                      final refs = <DocumentReference<Map<String, dynamic>>>[];
                      final messageBatch = db.batch();
                      for (final recipient in messageRecipients) {
                        final isAdminCopy = senderRole == 'supervisor' &&
                            messageType == 'instruction' &&
                            recipient.data()['role'] == 'admin';
                        final recipientRequestsReply = requestReply && !isAdminCopy;
                        final ref = db.collection('staff_messages').doc(threadId + '_' + recipient.id);
                        refs.add(ref);
                        messageBatch.set(ref, {
                          'messageId': ref.id,
                          'threadId': threadId,
                          'senderUid': uid,
                          'senderName': personName(sender),
                          'senderRole': senderRole,
                          'senderLabel': roleSignature(senderRole, sender),
                          'recipientUid': recipient.id,
                          'recipientName': personName(recipient.data()),
                          'recipientRole': recipient.data()['role'],
                          'recipientLabel': roleSignature(recipient.data()['role']?.toString(), recipient.data()),
                          'locationName': currentLocation,
                          'title': title.text.trim(),
                          'body': body.text.trim(),
                          'messageType': messageType,
                          'isAdminCopy': isAdminCopy,
                          'priority': priority,
                          'requestReply': recipientRequestsReply,
                          'replyStatus': recipientRequestsReply ? 'pending' : 'not_required',
                          'attachments': uploadedAttachments,
                          'read': false,
                          'hiddenFor': <String>[],
                          'showOnTicker': isSupervisorBroadcastToAllOfficers &&
                              recipient.data()['role'] == 'security_officer',
                          if (supervisor && customTickerStyle && isSupervisorBroadcastToAllOfficers &&
                              recipient.data()['role'] == 'security_officer')
                            'tickerStyle': {
                              'fontSize': tickerFontSize,
                              'fontFamily': tickerFontFamily,
                              'bold': tickerBold,
                            },
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      }
                      await messageBatch.commit();
                      var notificationFailures = 0;
                      for (final recipient in messageRecipients) {
                        final messageId = threadId + '_' + recipient.id;
                        final notificationRef = db.collection('notifications')
                            .doc('staff_message_$messageId');
                        try {
                          await notificationRef.set({
                            'notificationId': notificationRef.id,
                            'recipientUid': recipient.id,
                            'recipientRole': recipient.data()['role'] ?? '',
                            'senderUid': uid,
                            'senderEmail': auth.currentUser?.email ?? '',
                            'senderName': personName(sender),
                            'title': title.text.trim(),
                            'body': body.text.trim(),
                            'priority': priority,
                            'read': false,
                            'kind': 'staff_message',
                            'relatedId': messageId,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        } catch (_) {
                          notificationFailures++;
                        }
                      }
                      if (ctx.mounted) Navigator.pop(sheet);
                      final copySummary = adminCopies.isEmpty
                          ? ''
                          : '، مع إرسال نسخة للإدارة (' + adminCopies.length.toString() + ')';
                      toast(notificationFailures == 0
                        ? 'تم إرسال ' + (messageType == 'instruction' ? 'التعليمة' : 'الملاحظة') +
                          ' إلى ' + selectedRecipients.length.toString() + ' مستلم' + copySummary + '.'
                        : 'تم إرسال الرسالة إلى ' + refs.length.toString() +
                          ' مستلم، لكن تعذر إنشاء ' + notificationFailures.toString() + ' إشعار.');
                    } on FirebaseException catch (e) {
                      for (final uploaded in uploadedRefs) {
                        try { await uploaded.delete(); } catch (_) {}
                      }
                      refresh(() => busy = false);
                      toast('تعذر الإرسال (${e.code}). تحقق من قواعد Firestore أو إعداد التخزين.');
                    } catch (e) {
                      for (final uploaded in uploadedRefs) {
                        try { await uploaded.delete(); } catch (_) {}
                      }
                      refresh(() => busy = false);
                      toast(e.toString().replaceFirst('Bad state: ', ''));
                    }
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: Text(busy ? 'جارٍ إرسال الرسالة...' : 'إرسال الرسالة النصية'),
                ),
                        ),
                      ]),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    title.dispose();
    body.dispose();
  }

  Widget _reviewTile(IconData icon, String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E9F1)),
    ),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF8CA5BC), size: 21),
      const SizedBox(width: 11),
      Expanded(child: Text(label, style: const TextStyle(
        color: Color(0xFF7D8B9B), fontWeight: FontWeight.w600))),
      const SizedBox(width: 8),
      Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(
        color: Color(0xFF43566D), fontWeight: FontWeight.w800))),
    ]),
  );

  bool archived(Map<String, dynamic> d) {
    final ts = d['createdAt'];
    return ts is Timestamp && DateTime.now().isAfter(ts.toDate().add(const Duration(hours: 24)));
  }

  Future<void> markRead(DocumentSnapshot<Map<String, dynamic>> doc) async {
    if (doc.data()?['read'] == true || doc.data()?['recipientUid'] != uid) return;
    try { await doc.reference.update({'read': true, 'readAt': FieldValue.serverTimestamp()}); }
    catch (_) { toast('تعذر تحديث حالة القراءة.'); }
  }

  Future<void> reply(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final message = doc.data() ?? {};
    if (message['replyStatus'] == 'replied' ||
        message['recipientUid'] != uid) {
      toast('لا يمكن الرد على هذه الملاحظة من هذا الحساب.');
      return;
    }

    final body = TextEditingController();
    bool busy = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (ctx, refresh) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * .48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('الرد على الملاحظة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
                const SizedBox(height: 12),
                TextField(controller: body, minLines: 4, maxLines: 7,
                  decoration: const InputDecoration(labelText: 'اكتب الرد النصي')),
                const Spacer(),
                FilledButton.icon(
                  onPressed: busy ? null : () async {
                    if (body.text.trim().isEmpty) {
                      toast('اكتب نص الرد قبل الإرسال.');
                      return;
                    }
                    refresh(() => busy = true);
                    try {
                      final profile = await db.collection('users').doc(uid).get();
                      final profileData = profile.data() ?? <String, dynamic>{};
                      final replySenderRole = (profileData['role'] ?? '').toString();
                      if (!['admin', 'supervisor', 'security_officer'].contains(replySenderRole)) {
                        throw StateError('تعذر التحقق من دور حسابك لإرسال الرد.');
                      }
                      final replyRef = doc.reference.collection('replies').doc();
                      await replyRef.set({
                        'replyId': replyRef.id,
                        'senderUid': uid,
                        'senderName': personName(profileData),
                        'senderRole': replySenderRole,
                        'senderLabel': roleSignature(replySenderRole, profileData),
                        'body': body.text.trim(),
                        'attachments': <Map<String, dynamic>>[],
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      await doc.reference.update({
                        'replyStatus': 'replied',
                        'lastReplyAt': FieldValue.serverTimestamp(),
                      });
                      var replyNotificationSent = false;
                      final originalSenderUid = (message['senderUid'] ?? '').toString();
                      if (originalSenderUid.isNotEmpty) {
                        final notificationRef = db.collection('notifications')
                            .doc('staff_reply_' + replyRef.id);
                        try {
                          await notificationRef.set({
                            'notificationId': notificationRef.id,
                            'recipientUid': originalSenderUid,
                            'recipientRole': (message['senderRole'] ?? '').toString(),
                            'senderUid': uid,
                            'senderEmail': auth.currentUser?.email ?? '',
                            'senderName': personName(profileData),
                            'title': 'رد جديد على الملاحظة',
                            'body': body.text.trim(),
                            'priority': 'normal',
                            'read': false,
                            'kind': 'staff_message_reply',
                            'relatedId': doc.id,
                            'replyId': replyRef.id,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          replyNotificationSent = true;
                        } catch (_) {
                          replyNotificationSent = false;
                        }
                      }
                      if (ctx.mounted) Navigator.pop(sheet);
                      toast(replyNotificationSent
                        ? 'تم إرسال الرد وإشعار صاحب الملاحظة.'
                        : 'تم إرسال الرد، لكن تعذر إنشاء إشعار لصاحب الملاحظة.');
                    } on FirebaseException catch (e) {
                      refresh(() => busy = false);
                      toast('تعذر إرسال الرد (${e.code}).');
                    } catch (e) {
                      refresh(() => busy = false);
                      toast(e.toString());
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: Text(busy ? 'جارٍ إرسال الرد...' : 'إرسال الرد'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    body.dispose();
  }

  Future<void> _saveImageToGallery(String url, String fileName) async {
    if (url.isEmpty) {
      toast('رابط الصورة غير متاح.');
      return;
    }
    HttpClient? client;
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
        if (!await Gal.hasAccess()) {
          toast('لم يتم منح الإذن لحفظ الصور في الاستوديو.');
          return;
        }
      }
      client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final bytes = await response.fold<BytesBuilder>(
        BytesBuilder(copy: false),
        (builder, chunk) { builder.add(chunk); return builder; },
      );
      final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      await Gal.putImageBytes(
        Uint8List.fromList(bytes.takeBytes()),
        name: safeName.isEmpty ? 'staff_note_image' : safeName,
      );
      toast('تم حفظ الصورة في استوديو الهاتف.');
    } on GalException catch (e) {
      toast('تعذر الحفظ في الاستوديو: ${e.type.message}');
    } catch (_) {
      toast('تعذر تنزيل الصورة أو حفظها. تحقق من الاتصال بالإنترنت.');
    } finally {
      client?.close(force: true);
    }
  }

  Future<void> openMessage(DocumentSnapshot<Map<String, dynamic>> doc) async {
    await markRead(doc);
    if (!mounted) return;
    final d = doc.data() ?? {};
    final senderUid = (d['senderUid'] ?? '').toString();
    final attachments = (d['attachments'] as List<dynamic>?) ?? const [];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * .82,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text((d['title'] ?? 'ملاحظة').toString(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
              Text('من: ' + (d['senderName'] ?? 'مستخدم').toString() + ' — ' +
                (d['senderLabel'] ?? roleSignature(d['senderRole']?.toString(), d)).toString(),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if ((d['locationName'] ?? '').toString().isNotEmpty)
                Text('موقع المناوبة: ' + d['locationName'].toString()),
              const Divider(),
              Expanded(
                child: ListView(children: [
                  SelectableText((d['body'] ?? '').toString(),
                    style: const TextStyle(fontSize: 17, height: 1.8, fontWeight: FontWeight.w700, color: Color(0xFF172B45))),
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('المرفقات (${attachments.length})',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: navy)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: attachments.map<Widget>((item) {
                        final attachment = item is Map
                            ? Map<String, dynamic>.from(item)
                            : <String, dynamic>{};
                        final url = (attachment['url'] ?? attachment['downloadUrl'] ?? '').toString();
                        if (url.isEmpty) return const SizedBox.shrink();
                        final fileName = (attachment['fileName'] ?? 'مرفق').toString();
                        final contentType = (attachment['contentType'] ?? '').toString();
                        if (!contentType.startsWith('image/')) {
                          return SizedBox(
                            width: 150,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.insert_drive_file_outlined, size: 34, color: navy),
                                    Text(fileName, maxLines: 2, overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center),
                                    TextButton.icon(
                                      onPressed: () async {
                                        final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                        if (!opened) toast('تعذر فتح المرفق.');
                                      },
                                      icon: const Icon(Icons.open_in_new, size: 16),
                                      label: const Text('فتح الملف'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        return Stack(
                          children: [
                            InkWell(
                              onTap: () => _saveImageToGallery(url, fileName),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(url, width: 120, height: 100, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 120, height: 100, color: const Color(0xFFE8EEF5),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image_outlined)),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Material(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                                child: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                                  padding: EdgeInsets.zero,
                                  tooltip: 'عرض الصورة بالحجم الكامل',
                                  icon: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                                  onPressed: () => showDialog<void>(
                                    context: ctx,
                                    builder: (imageContext) => Dialog(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxHeight: MediaQuery.of(ctx).size.height * .72,
                                            ),
                                            child: InteractiveViewer(
                                              child: Image.network(url, fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) => const Padding(
                                                  padding: EdgeInsets.all(24),
                                                  child: Text('تعذر تحميل الصورة.')),
                                              ),
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => _saveImageToGallery(url, fileName),
                                            icon: const Icon(Icons.download_for_offline_outlined),
                                            label: const Text('حفظ في الاستوديو'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Positioned(
                              left: 4,
                              bottom: 4,
                              child: Icon(Icons.download_for_offline, color: Colors.white, size: 20),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                  const Divider(),
                  const Text('الردود', style: TextStyle(fontWeight: FontWeight.w900)),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: doc.reference.collection('replies').orderBy('createdAt').snapshots(),
                    builder: (_, snap) {
                      if (snap.hasError) return const Text('تعذر تحميل الردود.');
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      if (snap.data!.docs.isEmpty) return const Text('لا توجد ردود حتى الآن.');
                      return Column(children: snap.data!.docs.map((r) {
                        final replyData = r.data();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.reply),
                          title: Text((replyData['senderName'] ?? 'مستخدم').toString() + ' — ' +
                            (replyData['senderLabel'] ?? roleSignature(replyData['senderRole']?.toString(), replyData)).toString(),
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text((replyData['body'] ?? '').toString(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.6)),
                        );
                      }).toList());
                    },
                  ),
                ]),
              ),
              if (d['recipientUid'] == uid) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _contactMessageSender(senderUid),
                        icon: const Icon(Icons.call_outlined),
                        label: const Text('اتصال مباشر'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: d['replyStatus'] == 'replied'
                            ? null
                            : () { Navigator.pop(ctx); reply(doc); },
                        icon: const Icon(Icons.reply_rounded),
                        label: const Text('رد'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: d['liked'] == true ? 'تم تسجيل الإعجاب' : 'إعجاب وإشعار المرسل',
                      onPressed: d['liked'] == true ? null : () => _likeMessage(doc),
                      icon: const Icon(Icons.thumb_up_alt_outlined),
                    ),
                  ],
                ),
              ] else if (d['liked'] == true)
                const Text('اطّلع المستلم على الملاحظة وأعجب بها 👍',
                  style: TextStyle(color: teal, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> archiveSettings() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الحذف التلقائي للأرشيف'),
        content: const Text(
          'الأرشفة بعد 24 ساعة تعمل داخل التطبيق. أما الحذف التلقائي بعد مدة الاحتفاظ '
          'فمؤجل حالياً لأنه يحتاج إلى Cloud Functions وخطة Blaze. '
          'يمكنك إخفاء الرسائل من أرشيف حسابك يدوياً في الوقت الحالي.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> hideAllArchive() async {
    final sent = await db.collection('staff_messages').where('senderUid', isEqualTo: uid).get();
    final received = await db.collection('staff_messages').where('recipientUid', isEqualTo: uid).get();
    final all = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in sent.docs) { all[doc.id] = doc; }
    for (final doc in received.docs) { all[doc.id] = doc; }
    final expired = all.values.where((doc) {
      final d = doc.data();
      return archived(d) && !((d['hiddenFor'] as List<dynamic>? ?? []).contains(uid));
    }).toList();
    if (expired.isEmpty) { toast('لا توجد رسائل في الأرشيف لإخفائها.'); return; }
    if (!mounted) return;
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إخفاء كامل الأرشيف؟'),
      content: Text('سيتم إخفاء ' + expired.length.toString() + ' رسالة من حسابك فقط. تبقى محفوظة لدى بقية المستلمين.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إخفاء الكل')),
      ],
    ));
    if (yes != true) return;
    try {
      for (var start = 0; start < expired.length; start += 400) {
        final batch = db.batch();
        for (final doc in expired.skip(start).take(400)) {
          batch.update(doc.reference, {'hiddenFor': FieldValue.arrayUnion([uid])});
        }
        await batch.commit();
      }
      toast('تم إخفاء الأرشيف من حسابك.');
    } on FirebaseException catch (e) { toast('تعذر إخفاء الأرشيف (' + e.code + ').'); }
  }

  Future<void> hideFromArchive(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إخفاء من الأرشيف؟'),
      content: const Text('سيختفي من أرشيف حسابك فقط ولن يُحذف من حساب الطرف الآخر.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إخفاء')),
      ],
    ));
    if (yes != true) return;
    try { await doc.reference.update({'hiddenFor': FieldValue.arrayUnion([uid])}); toast('تم الإخفاء من أرشيفك.'); }
    on FirebaseException catch (e) { toast('تعذر الإخفاء (' + e.code + ').'); }
  }

  Future<void> _deleteManagedNotes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> candidates, {
    required bool deleteAll,
  }) async {
    if (!admin && !supervisor) {
      toast('لا تملك صلاحية حذف هذا المحتوى.');
      return;
    }
    final eligible = candidates.where((doc) {
      final data = doc.data();
      return data['recipientUid'] == uid && (admin || data['messageType'] == 'note');
    }).toList();
    final targets = deleteAll
        ? eligible
        : eligible.where((doc) => selectedMessageIds.contains(doc.id)).toList();
    if (targets.isEmpty) {
      toast('لا توجد عناصر محددة للحذف.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(deleteAll ? 'حذف جميع العناصر الواردة؟' : 'حذف العناصر المحددة؟'),
        content: Text('سيتم حذف ${targets.length} عنصر من صندوق الوارد الخاص بك. لا يمكن التراجع عن هذه العملية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      // Firestore does not cascade-delete subcollections or Storage objects.
      var storageCleanupFailed = false;
      for (final message in targets) {
        final replies = await message.reference.collection('replies').get();
        for (var start = 0; start < replies.docs.length; start += 400) {
          final batch = db.batch();
          for (final replyDoc in replies.docs.skip(start).take(400)) {
            batch.delete(replyDoc.reference);
          }
          await batch.commit();
        }
        final attachments = message.data()['attachments'];
        if (attachments is List) {
          for (final item in attachments) {
            if (item is! Map) continue;
            final storagePath = (item['storagePath'] ?? '').toString();
            if (storagePath.isEmpty) continue;
            try {
              await FirebaseStorage.instance.ref().child(storagePath).delete();
            } catch (_) {
              storageCleanupFailed = true;
            }
          }
        }
      }
      for (var start = 0; start < targets.length; start += 400) {
        final batch = db.batch();
        for (final message in targets.skip(start).take(400)) {
          batch.delete(message.reference);
        }
        await batch.commit();
      }
      setState(() {
        selectedMessageIds.removeAll(targets.map((doc) => doc.id));
      });
      toast(storageCleanupFailed
          ? 'تم حذف ${targets.length} عنصر، لكن تعذر حذف بعض الملفات من التخزين.'
          : 'تم حذف ${targets.length} عنصر بنجاح.');
    } on FirebaseException catch (e) {
      toast('تعذر حذف العناصر (${e.code}). تحقق من صلاحيات Firestore.');
    } catch (_) {
      toast('تعذر إكمال حذف العناصر.');
    }
  }

  Widget messageCards(List<QueryDocumentSnapshot<Map<String, dynamic>>> source, {required bool archive}) {
    final docs = source.where((doc) {
      final d = doc.data();
      final hidden = (d['hiddenFor'] as List<dynamic>? ?? []).contains(uid);
      final text = (d['title'] ?? '').toString() + ' ' + (d['body'] ?? '').toString() + ' ' +
          (d['senderName'] ?? '').toString() + ' ' + (d['recipientName'] ?? '').toString();
      return !hidden && archived(d) == archive && text.toLowerCase().contains(search.toLowerCase());
    }).toList()..sort((a, b) {
      final x = a.data()['createdAt'], y = b.data()['createdAt'];
      return x is Timestamp && y is Timestamp ? y.compareTo(x) : 0;
    });
    final canManageNotes = (admin || supervisor) && !archive;
    final canManageArchive = admin && archive;
    final canManageContent = canManageNotes || canManageArchive;
    final deletableNotes = canManageContent
        ? source.where((doc) {
            final data = doc.data();
            return data['recipientUid'] == uid &&
                (admin || data['messageType'] == 'note') &&
                archived(data) == archive &&
                !((data['hiddenFor'] as List<dynamic>? ?? []).contains(uid));
          }).toList()
        : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final validIds = deletableNotes.map((doc) => doc.id).toSet();
    final selectedCount = selectedMessageIds.where(validIds.contains).length;
    return Column(
      children: [
        if (canManageContent)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: deletableNotes.isEmpty
                      ? null
                      : () => setState(() {
                            if (selectedCount == deletableNotes.length) {
                              selectedMessageIds.clear();
                            } else {
                              selectedMessageIds
                                ..clear()
                                ..addAll(deletableNotes.map((doc) => doc.id));
                            }
                          }),
                  icon: const Icon(Icons.select_all, size: 18),
                  label: Text(selectedCount == deletableNotes.length && deletableNotes.isNotEmpty
                      ? 'إلغاء تحديد الكل'
                      : 'تحديد الكل'),
                ),
                OutlinedButton.icon(
                  onPressed: deletableNotes.isEmpty
                      ? null
                      : () => _deleteManagedNotes(deletableNotes, deleteAll: true),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: Text(archive ? 'حذف الأرشيف نهائياً' : 'حذف كل الوارد'),
                ),
                if (selectedCount > 0)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => _deleteManagedNotes(deletableNotes, deleteAll: false),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text('حذف المحدد (${selectedCount})'),
                  ),
              ],
            ),
          ),
        Expanded(
          child: docs.isEmpty
              ? Center(child: Text(archive ? 'الأرشيف فارغ.' : 'لا توجد مراسلات حديثة.'))
              : ListView.builder(
      padding: const EdgeInsets.all(12), itemCount: docs.length,
      itemBuilder: (_, i) {
        final doc = docs[i], d = doc.data();
        final sent = d['senderUid'] == uid;
        final canDeleteThis = canManageContent && !sent && (admin || d['messageType'] == 'note');
        final read = d['read'] == true, created = d['createdAt'];
        return Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
          onTap: () {
            if (canDeleteThis && selectedMessageIds.isNotEmpty) {
              setState(() {
                if (!selectedMessageIds.add(doc.id)) selectedMessageIds.remove(doc.id);
              });
            } else {
              openMessage(doc);
            }
          },
          leading: canDeleteThis
              ? Checkbox(
                  value: selectedMessageIds.contains(doc.id),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      selectedMessageIds.add(doc.id);
                    } else {
                      selectedMessageIds.remove(doc.id);
                    }
                  }),
                )
              : CircleAvatar(
                  backgroundColor: d['priority'] == 'urgent' ? const Color(0xFFFFE5E5) : const Color(0xFFE4F5F2),
                  child: Icon(d['priority'] == 'urgent' ? Icons.priority_high : Icons.mark_email_unread,
                    color: d['priority'] == 'urgent' ? Colors.red : teal),
                ),
          title: Text((d['title'] ?? 'ملاحظة').toString(),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: navy)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d['messageType'] == 'instruction'
                ? (d['isAdminCopy'] == true ? 'تعليمة إشرافية — نسخة للإدارة' : 'تعليمة')
                : 'ملاحظة',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: d['messageType'] == 'instruction' ? const Color(0xFF9A6A13) : teal,
              )),
            Text(sent
              ? 'إلى: ' + (d['recipientName'] ?? 'مستخدم').toString() + ' — ' +
                (d['recipientLabel'] ?? roleSignature(d['recipientRole']?.toString(), d)).toString()
              : 'من: ' + (d['senderName'] ?? 'مستخدم').toString() + ' — ' +
                (d['senderLabel'] ?? roleSignature(d['senderRole']?.toString(), d)).toString(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF263B55))),
            Text((d['body'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF172B45), height: 1.5)),
            if (created is Timestamp) Text(DateFormat('yyyy/MM/dd HH:mm').format(created.toDate())),
            if (d['requestReply'] == true) Text(d['replyStatus'] == 'replied' ? 'تم الرد' : 'بانتظار الرد',
              style: TextStyle(color: d['replyStatus'] == 'replied' ? Colors.green : Colors.deepOrange)),
            if (sent) ...[
              Text(
                read ? 'تمت القراءة ✓✓' : 'تم الإرسال ✓',
                style: TextStyle(
                  color: read ? const Color(0xFF16845B) : const Color(0xFF64748B),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (read && d['readAt'] is Timestamp)
                Text('وقت القراءة: ' + DateFormat('yyyy/MM/dd HH:mm').format((d['readAt'] as Timestamp).toDate()),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF526579))),
            ],
            if (sent && d['liked'] == true)
              const Text('اطّلع المستلم على الملاحظة وأعجب بها 👍',
                style: TextStyle(color: teal, fontWeight: FontWeight.w800)),
          ]),
          trailing: archive
              ? (admin && !sent
                  ? IconButton(
                      tooltip: 'حذف الرسالة نهائياً',
                      icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                      onPressed: () => _deleteManagedNotes([doc], deleteAll: true),
                    )
                  : IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => hideFromArchive(doc)))
              : (!read && !sent ? const Icon(Icons.circle, size: 9, color: teal) : null),
              ),
              if (!archive && !sent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _contactMessageSender((d['senderUid'] ?? '').toString()),
                          icon: const Icon(Icons.call_outlined, size: 18),
                          label: const Text('اتصال مباشر'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: d['replyStatus'] == 'replied'
                              ? null
                              : () => reply(doc),
                          icon: const Icon(Icons.reply_rounded, size: 18),
                          label: const Text('رد'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: d['liked'] == true ? 'تم تسجيل الإعجاب' : 'إعجاب',
                        onPressed: d['liked'] == true ? null : () => _likeMessage(doc),
                        icon: const Icon(Icons.thumb_up_alt_outlined),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
        ),
      ],
    );
  }

  Widget messageList({required bool sent, required bool archive}) {
    if (archive) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('staff_messages').where('senderUid', isEqualTo: uid).snapshots(),
        builder: (context, sentSnap) {
          if (sentSnap.hasError) return const Center(child: Text('تعذر تحميل الأرشيف.'));
          if (!sentSnap.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('staff_messages').where('recipientUid', isEqualTo: uid).snapshots(),
            builder: (context, receivedSnap) {
              if (receivedSnap.hasError) return const Center(child: Text('تعذر تحميل الأرشيف.'));
              if (!receivedSnap.hasData) return const Center(child: CircularProgressIndicator());
              final combined = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
              for (final doc in sentSnap.data!.docs) { combined[doc.id] = doc; }
              for (final doc in receivedSnap.data!.docs) { combined[doc.id] = doc; }
              return messageCards(combined.values.toList(), archive: true);
            },
          );
        },
      );
    }
    final stream = db.collection('staff_messages')
        .where(sent ? 'senderUid' : 'recipientUid', isEqualTo: uid).snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: stream, builder: (context, snap) {
      if (snap.hasError) return const Center(child: Text('تعذر تحميل المراسلات. تحقق من قواعد Firestore.'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      return messageCards(snap.data!.docs, archive: false);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded ? null : AppBar(title: const Text('المراسلات والتنبيهات'),
      actions: [
        IconButton(tooltip: 'معلومة حول الحذف التلقائي', onPressed: archiveSettings, icon: const Icon(Icons.settings_outlined)),
        IconButton(tooltip: 'إخفاء كل الأرشيف', onPressed: hideAllArchive, icon: const Icon(Icons.delete_sweep_outlined)),
      ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: compose, backgroundColor: teal, foregroundColor: Colors.white,
      icon: const Icon(Icons.edit_notifications), label: Text(widget.userRole == 'security_officer' ? 'إرسال بلاغ' : 'إرسال ملاحظة')),
    body: Column(children: [
      Container(
        width: double.infinity,
        color: navy,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(children: [
          Expanded(child: TabBar(
            controller: tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white,
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            indicatorColor: const Color(0xFFE8CB84),
            indicatorWeight: 3,
            tabs: const [Tab(text: 'الوارد'), Tab(text: 'الصادر'), Tab(text: 'الأرشيف')],
          )),
          IconButton(tooltip: 'إعدادات الأرشيف', onPressed: archiveSettings,
            icon: const Icon(Icons.settings_outlined, color: Colors.white)),
          IconButton(tooltip: 'إخفاء كل الأرشيف', onPressed: hideAllArchive,
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white)),
        ]),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 4), child: TextField(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث في المراسلات...'),
        onChanged: (v) => setState(() => search=v))),
      Expanded(child: TabBarView(controller: tabs, children: [
        messageList(sent: false, archive: false),
        messageList(sent: true, archive: false),
        messageList(sent: false, archive: true),
      ])),
    ]),
  );
}
