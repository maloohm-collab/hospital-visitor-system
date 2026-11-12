import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WorkSiteNotesScreen extends StatefulWidget {
  const WorkSiteNotesScreen({super.key});
  @override
  State<WorkSiteNotesScreen> createState() => _WorkSiteNotesScreenState();
}

class _WorkSiteNotesScreenState extends State<WorkSiteNotesScreen> {
  static const navy = Color(0xFF0A1B33);
  static const green = Color(0xFF16845B);
  final db = FirebaseFirestore.instance;
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool busy = false;

  void notice(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String dateText(dynamic value) => value is Timestamp
      ? DateFormat('yyyy/MM/dd  HH:mm').format(value.toDate().toLocal())
      : 'جارٍ تسجيل الوقت...';

  Future<Set<String>?> chooseRecipients() async {
    final snapshot = await db.collection('users').where('status', isEqualTo: 'active').get();
    final users = snapshot.docs.where((d) => d.id != uid &&
      (d.data()['role'] == 'admin' || d.data()['role'] == 'supervisor')).toList();
    if (users.isEmpty) {
      notice('لا يوجد مشرفون أو إداريون نشطون لاستلام الملاحظة.');
      return null;
    }
    users.sort((a,b) {
      final ar = a.data()['role'] == 'admin' ? 0 : 1;
      final br = b.data()['role'] == 'admin' ? 0 : 1;
      return ar != br ? ar.compareTo(br) :
        (a.data()['displayName'] as String? ?? '').compareTo(b.data()['displayName'] as String? ?? '');
    });
    final selected = <String>{};
    return showDialog<Set<String>>(context: context, builder: (dc) => StatefulBuilder(
      builder: (context, refresh) => AlertDialog(
        title: const Text('تحديد مستلمي الملاحظة'),
        content: SizedBox(width: double.maxFinite, height: MediaQuery.of(context).size.height * .55,
          child: Column(children: [
            const Text('اختر الإدارة أو مشرفًا واحدًا أو أكثر (حتى خمسة مستلمين).'),
            Expanded(child: ListView(children: users.map((d) {
              final data=d.data();
              return CheckboxListTile(
                dense:true, contentPadding:EdgeInsets.zero, value:selected.contains(d.id),
                title:Text(data['displayName'] as String? ?? 'مستخدم'),
                subtitle:Text(data['role']=='admin'?'الإدارة':'المشرف'),
                onChanged:(v)=>refresh(() {
                  if(v==true) {
                    if(selected.length<5) { selected.add(d.id); }
                    else { notice('الحد الأقصى خمسة مستلمين.'); }
                  } else { selected.remove(d.id); }
                }),
              );
            }).toList())),
          ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dc),child:const Text('إلغاء')),
          FilledButton(onPressed:selected.isEmpty?null:()=>Navigator.pop(dc,Set<String>.from(selected)),child:const Text('متابعة')),
        ],
      ),
    ));
  }

  Future<void> compose(String shiftId, String site, {String? noteId, Map<String,dynamic>? old}) async {
    if (busy) return;
    final controller=TextEditingController(text:old?['body'] as String? ?? '');
    final body=await showDialog<String>(context:context,builder:(dc)=>AlertDialog(
      title:Text(old==null?'إضافة ملاحظة للموقع':'تعديل الملاحظة'),
      content:SizedBox(width:double.maxFinite,child:TextField(
        controller:controller, autofocus:true, minLines:4, maxLines:8, maxLength:1000,
        textDirection:Directionality.of(context),
        decoration:const InputDecoration(hintText:'اكتب الملاحظة المتعلقة بموقع عملك...',border:OutlineInputBorder()),
      )),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dc),child:const Text('إلغاء')),
        FilledButton(onPressed:()=>controller.text.trim().length<2?null:Navigator.pop(dc,controller.text.trim()),
          child:Text(old==null?'اختيار المستلمين':'حفظ التعديل')),
      ],
    ));
    controller.dispose();
    if(body==null || !mounted) return;
    Set<String>? recipients;
    if(old==null) {
      recipients=await chooseRecipients();
      if(recipients==null || recipients.isEmpty || !mounted) return;
    }
    setState(()=>busy=true);
    try {
      if(old==null) {
        final profile=await db.collection('users').doc(uid).get();
        final ref=db.collection('work_shift_notes').doc();
        final officerName = (profile.data()?['displayName'] as String? ?? 'ضابط الأمن').trim();
        await ref.set({
          'noteId':ref.id, 'shiftId':shiftId, 'officerUid':uid,
          'officerName':officerName,
          'locationName':site, 'body':body, 'recipientUids':recipients!.toList(),
          'createdAt':FieldValue.serverTimestamp(), 'hiddenFromOfficer':false,
        });
        var notified = 0;
        for (final recipientUid in recipients) {
          try {
            final recipient = await db.collection('users').doc(recipientUid).get();
            final recipientData = recipient.data() ?? <String, dynamic>{};
            final notificationRef = db.collection('notifications').doc('work_site_note_${ref.id}_$recipientUid');
            await notificationRef.set({
              'notificationId':notificationRef.id,
              'recipientUid':recipientUid,
              'recipientRole':recipientData['role'] ?? '',
              'senderUid':uid,
              'senderEmail':FirebaseAuth.instance.currentUser?.email ?? '',
              'senderName':officerName,
              'title':'ملاحظة جديدة من موقع العمل',
              'body':'ملاحظة من $officerName في موقع $site: $body',
              'priority':'normal',
              'read':false,
              'kind':'work_site_note',
              'relatedId':ref.id,
              'createdAt':FieldValue.serverTimestamp(),
            });
            notified++;
          } catch (_) {}
        }
        notice(notified == recipients.length
          ? 'تم إرسال الملاحظة وإشعار المستلمين.'
          : 'تم إرسال الملاحظة، وتعذر إنشاء بعض الإشعارات ($notified من ${recipients.length}).');
      } else {
        await db.collection('work_shift_notes').doc(noteId).update({
          'body':body, 'updatedAt':FieldValue.serverTimestamp(),
        });
        notice('تم تعديل الملاحظة، وظهر التعديل لدى المستلمين.');
      }
    } on FirebaseException catch(e) {
      notice('تعذر حفظ الملاحظة ('+e.code+').');
    } catch (_) { notice('حدث خطأ أثناء حفظ الملاحظة.'); }
    finally { if(mounted) setState(()=>busy=false); }
  }

  Future<void> removeNote(String id) async {
    if(busy) return;
    final yes=await showDialog<bool>(context:context,builder:(dc)=>AlertDialog(
      title:const Text('حذف الملاحظة؟'),
      content:const Text('سيتم حذفها من قائمة المستلمين أيضًا.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dc,false),child:const Text('إلغاء')),
        FilledButton(style:FilledButton.styleFrom(backgroundColor:Colors.red),
          onPressed:()=>Navigator.pop(dc,true),child:const Text('حذف')),
      ],
    ));
    if(yes!=true) return;
    setState(()=>busy=true);
    try {
      await db.collection('work_shift_notes').doc(id).delete();
      notice('تم حذف الملاحظة.');
    } on FirebaseException catch(e) { notice('تعذر حذف الملاحظة ('+e.code+').'); }
    finally { if(mounted) setState(()=>busy=false); }
  }

  Widget notesList() => StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
    stream:db.collection('work_shift_notes').where('officerUid',isEqualTo:uid)
      .where('hiddenFromOfficer',isEqualTo:false).snapshots(),
    builder:(context,snap) {
      if(snap.hasError) return const Center(child:Text('تعذر تحميل ملاحظاتك السابقة.'));
      if(snap.connectionState==ConnectionState.waiting) return const Center(child:CircularProgressIndicator());
      final docs=[...snap.data!.docs]..sort((a,b) {
        final x=a.data()['createdAt'], y=b.data()['createdAt'];
        return x is Timestamp && y is Timestamp ? y.compareTo(x) : 0;
      });
      if(docs.isEmpty) return const Center(child:Text('لا توجد ملاحظات مرسلة حتى الآن.'));
      return ListView.separated(
        padding:const EdgeInsets.fromLTRB(16,8,16,22), itemCount:docs.length,
        separatorBuilder:(_,__)=>const SizedBox(height:10),
        itemBuilder:(context,index) {
          final doc=docs[index], data=doc.data();
          final edited=data['updatedAt'] is Timestamp;
          return Card(color:Colors.white,elevation:0,
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15),side:const BorderSide(color:Color(0xFFDCE5ED))),
            child:Padding(padding:const EdgeInsets.all(14),child:Column(
              crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                Row(children:[
                  const Icon(Icons.location_on_outlined,color:green),
                  const SizedBox(width:6),
                  Expanded(child:Text(data['locationName'] as String? ?? 'موقع غير محدد',
                    style:const TextStyle(color:navy,fontWeight:FontWeight.w900))),
                  if(edited) const Chip(label:Text('معدّلة'),visualDensity:VisualDensity.compact),
                ]),
                const SizedBox(height:7),
                Text(data['body'] as String? ?? '',style:const TextStyle(color:Color(0xFF26384A),fontSize:15,height:1.5)),
                const SizedBox(height:8),
                Text('أُرسلت: '+dateText(data['createdAt']),style:const TextStyle(color:Color(0xFF64748B),fontSize:12)),
                if(edited) Text('آخر تعديل: '+dateText(data['updatedAt']),style:const TextStyle(color:Color(0xFF64748B),fontSize:12)),
                const Divider(height:18),
                Wrap(alignment:WrapAlignment.end,spacing:8,children:[
                  OutlinedButton.icon(onPressed:busy?null:()=>compose(
                    data['shiftId'] as String? ?? '',data['locationName'] as String? ?? '',
                    noteId:doc.id,old:data),
                    icon:const Icon(Icons.edit_outlined,size:18),label:const Text('تعديل')),
                  TextButton.icon(onPressed:busy?null:()=>removeNote(doc.id),
                    style:TextButton.styleFrom(foregroundColor:Colors.red),
                    icon:const Icon(Icons.delete_outline,size:18),label:const Text('حذف')),
                ]),
              ],
            )),
          );
        },
      );
    },
  );

  Widget activeSite(String shiftId, Map<String,dynamic> shift) {
    final site=(shift['activeLocationName'] as String? ?? '').trim();
    if(site.isEmpty) return const Center(child:Text('لا يوجد موقع نشط. حدّد موقعك من شاشة مباشرة العمل أولًا.'));
    return Column(children:[
      Container(margin:const EdgeInsets.fromLTRB(16,14,16,8),padding:const EdgeInsets.all(14),
        decoration:BoxDecoration(color:const Color(0xFFEAF6F0),borderRadius:BorderRadius.circular(15),
          border:Border.all(color:const Color(0xFFB8E0CB))),
        child:Row(children:[
          const Icon(Icons.location_on_rounded,color:green,size:28),
          const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('موقع مباشرتك الحالي',style:TextStyle(color:green,fontSize:12,fontWeight:FontWeight.w700)),
            Text(site,style:const TextStyle(color:navy,fontSize:18,fontWeight:FontWeight.w900)),
          ])),
        ])),
      Padding(padding:const EdgeInsets.fromLTRB(16,4,16,12),child:SizedBox(width:double.infinity,
        child:FilledButton.icon(
          onPressed:busy?null:()=>compose(shiftId,site),
          icon:const Icon(Icons.send_rounded),label:const Text('إرسال ملاحظة عن هذا الموقع'),
          style:FilledButton.styleFrom(backgroundColor:navy,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:14)),
        ))),
      const Divider(height:1),
      const Padding(padding:EdgeInsets.fromLTRB(16,12,16,4),
        child:Align(alignment:Alignment.centerRight,child:Text('ملاحظاتي السابقة',
          style:TextStyle(color:navy,fontSize:16,fontWeight:FontWeight.w900)))),
      Expanded(child:notesList()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if(uid.isEmpty) return const Scaffold(body:Center(child:Text('يرجى تسجيل الدخول أولًا.')));
    return Scaffold(
      backgroundColor:const Color(0xFFF3F6FA),
      appBar:AppBar(title:const Text('ملاحظات مواقع العمل'),backgroundColor:navy,foregroundColor:Colors.white),
      body:StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
        stream:db.collection('active_work_shifts').doc(uid).snapshots(),
        builder:(context,pointer) {
          if(pointer.hasError) return const Center(child:Text('تعذر تحميل حالة المباشرة.'));
          if(pointer.connectionState==ConnectionState.waiting) return const Center(child:CircularProgressIndicator());
          final shiftId=pointer.data?.data()?['shiftId'] as String?;
          if(shiftId==null) return const Center(child:Padding(padding:EdgeInsets.all(28),
            child:Text('يجب تسجيل مباشرة العمل واختيار موقعك أولًا حتى تتمكن من إرسال ملاحظة مرتبطة بالموقع.')));
          return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
            stream:db.collection('work_shifts').doc(shiftId).snapshots(),
            builder:(context,shiftSnap) {
              if(shiftSnap.hasError) return const Center(child:Text('تعذر تحميل موقع المناوبة.'));
              if(shiftSnap.connectionState==ConnectionState.waiting) return const Center(child:CircularProgressIndicator());
              final shift=shiftSnap.data?.data();
              if(shift==null || shift['status']!='active') return const Center(child:Text('لا توجد مباشرة نشطة حاليًا.'));
              return activeSite(shiftId,shift);
            },
          );
        },
      ),
    );
  }
}
