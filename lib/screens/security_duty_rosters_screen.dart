
import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../data/duty_roster_pdf.dart';
import '../widgets/app_search_field.dart';

class SecurityDutyRostersScreen extends StatefulWidget {
  const SecurityDutyRostersScreen({super.key, this.archive = false, this.initialDateKey, this.initialShift, this.embedded = false});
  final bool archive;
  final bool embedded;
  final String? initialDateKey;
  final String? initialShift;
  @override
  State<SecurityDutyRostersScreen> createState() => _SecurityDutyRostersScreenState();
}

class _SecurityDutyRostersScreenState extends State<SecurityDutyRostersScreen> {
  static const navy = Color(0xFF123B63);
  static const teal = Color(0xFF087E78);
  static const page = Color(0xFFF1F6FC);
  static const border = Color(0xFFD9E4EF);
  static const archiveAfter = Duration(hours: 22);
  final db = FirebaseFirestore.instance;
  String searchTerm = '';
  bool _openingInitial = false;
  bool _autoCleanupRunning = false;
  Timer? _expiryTimer;
  DateTime? _scheduledExpiryAt;
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  CollectionReference<Map<String, dynamic>> get preferences => db.collection('users').doc(uid).collection('duty_roster_preferences');

  @override
  void initState() {
    super.initState();
    if (widget.initialDateKey != null && widget.initialShift != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialRoster());
    }
  }

  static String _dayName(DateTime date) => const ['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'][date.weekday - 1];
  static DateTime _actualDate(String key) {
    final date = DateTime.tryParse(key) ?? DateTime.now();
    return date;
  }
  static String _hours(String shift) => shift == 'A' ? '08:00 – 16:00' : shift == 'B' ? '16:00 – 00:00' : '00:00 – 08:00';
  static String _id(String key, String shift) => key + '_' + shift;
  DateTime? _publishedAt(Map<String, dynamic> block, Map<String, dynamic> roster) {
    final value = block['publishedAt'] ?? roster['updatedAt'];
    return value is Timestamp ? value.toDate() : null;
  }

  void _scheduleNextExpiry(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final now = DateTime.now();
    DateTime? nextExpiry;
    for (final doc in snapshot.docs) {
      final roster = doc.data();
      final shifts = Map<String, dynamic>.from(roster['shifts'] ?? {});
      for (final shift in const ['A', 'B', 'C']) {
        final raw = shifts[shift];
        if (raw is! Map) continue;
        final block = Map<String, dynamic>.from(raw);
        final published = block['status'] == 'published' ||
            (block['status'] == null && roster['status'] == 'published');
        final sentAt = published ? _publishedAt(block, roster) : null;
        if (sentAt == null) continue;
        final expiry = sentAt.add(archiveAfter);
        if (expiry.isAfter(now) &&
            (nextExpiry == null || expiry.isBefore(nextExpiry))) {
          nextExpiry = expiry;
        }
      }
    }
    if (nextExpiry == _scheduledExpiryAt) return;
    _expiryTimer?.cancel();
    _scheduledExpiryAt = nextExpiry;
    if (nextExpiry == null) return;
    final delay = nextExpiry.difference(now) + const Duration(milliseconds: 100);
    _expiryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (mounted) setState(() {});
    });
  }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value), behavior: SnackBarBehavior.floating));
  }

  Future<void> _openInitialRoster() async {
    if (_openingInitial || !mounted) return;
    _openingInitial = true;
    try {
      final key = widget.initialDateKey!;
      final shift = widget.initialShift!;
      if (!['A','B','C'].contains(shift)) {
        _message('تعذر تحديد الشفت المرتبط بالإشعار.');
        return;
      }
      final snap = await db.collection('daily_duty_rosters').doc(key).get();
      if (!snap.exists || !mounted) {
        _message('لم يعد كشف المناوبة المرتبط بهذا الإشعار متاحاً.');
        return;
      }
      final roster = snap.data() ?? <String,dynamic>{};
      final shifts = Map<String,dynamic>.from(roster['shifts'] ?? {});
      final raw = shifts[shift];
      if (raw is! Map) {
        _message('لا توجد بيانات للشفت في الكشف المرتبط بالإشعار.');
        return;
      }
      final block = Map<String,dynamic>.from(raw);
      final published = block['status'] == 'published' || (block['status'] == null && roster['status'] == 'published');
      if (!published) {
        _message('الكشف المرتبط بالإشعار لم يعد منشوراً.');
        return;
      }
      final at = _publishedAt(block, roster) ?? DateTime.now();
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => SecurityDutyRosterPdfScreen(dateKey: key, shift: shift, block: block, publishedAt: at)));
    } catch (_) {
      _message('تعذر فتح كشف المناوبة المرتبط بالإشعار.');
    } finally {
      _openingInitial = false;
    }
  }

  Future<void> _openPdf(_RosterItem item) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SecurityDutyRosterPdfScreen(
      dateKey: item.dateKey, shift: item.shift, block: item.block, publishedAt: item.publishedAt)));
  }

  Future<void> _hideOne(_RosterItem item) async {
    final yes = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('حذف الكشف من أرشيفك؟'),
      content: const Text('سيختفي هذا الكشف من أرشيف حسابك فقط. لن يتأثر الكشف الأصلي أو أرشيف بقية الضباط.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(d, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)), child: const Text('حذف من أرشيفي')),
      ],
    ));
    if (yes != true) return;
    try {
      await preferences.doc(_id(item.dateKey,item.shift)).set({
        'ownerUid': uid, 'rosterKey': item.dateKey, 'shift': item.shift,
        'action': 'hidden', 'reason': 'manual', 'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('تم حذف الكشف من أرشيفك الشخصي فقط.');
    } catch (_) { _message('تعذر حذف الكشف. تحقق من الاتصال.'); }
  }

  Future<void> _hideAll(List<_RosterItem> items) async {
    if (items.isEmpty) return;
    final yes = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('حذف جميع كشوفات الأرشيف؟'),
      content: Text('سيتم إخفاء ' + items.length.toString() + ' كشفاً من أرشيفك فقط، ولن تتأثر نسخ الإدارة أو بقية الضباط.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('تراجع')),
        FilledButton(onPressed: () => Navigator.pop(d, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)), child: const Text('تأكيد حذف الكل')),
      ],
    ));
    if (yes != true) return;
    try {
      for (var start = 0; start < items.length; start += 400) {
        final batch = db.batch();
        for (final item in items.skip(start).take(400)) {
          batch.set(preferences.doc(_id(item.dateKey,item.shift)), {
            'ownerUid': uid, 'rosterKey': item.dateKey, 'shift': item.shift,
            'action': 'hidden', 'reason': 'manual_all', 'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
      _message('تم إخفاء جميع الكشوفات من أرشيفك الشخصي.');
    } catch (_) { _message('تعذر إكمال حذف الأرشيف. حاول مرة أخرى.'); }
  }

  Future<void> _archiveSettings(Map<String,dynamic> current) async {
    var enabled = current['autoDeleteEnabled'] == true;
    var unit = 'days';
    final daysNow = (current['retentionDays'] as num?)?.toInt() ?? 30;
    var amount = daysNow;
    if (daysNow % 30 == 0) { amount = (daysNow ~/ 30).clamp(1,36).toInt(); unit = 'months'; }
    else if (daysNow % 7 == 0) { amount = (daysNow ~/ 7).clamp(1,156).toInt(); unit = 'weeks'; }
    else { amount = daysNow.clamp(1,3650).toInt(); }
    final controller = TextEditingController(text: amount.toString());
    await showDialog<void>(context: context, builder: (d) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: const Text('إعدادات الحذف التلقائي'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('تفعيل الحذف التلقائي'),
          subtitle: const Text('إخفاء الكشوفات من أرشيفك عند انتهاء مدة الاحتفاظ.'),
          value: enabled, onChanged: (v) => refresh(() => enabled = v)),
        const SizedBox(height: 8),
        const Text('مدة الاحتفاظ', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العدد'))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(value: unit, decoration: const InputDecoration(labelText: 'الوحدة'),
            items: const [
              DropdownMenuItem(value: 'days', child: Text('أيام')),
              DropdownMenuItem(value: 'weeks', child: Text('أسابيع')),
              DropdownMenuItem(value: 'months', child: Text('أشهر')),
            ], onChanged: (v) { if (v != null) refresh(() => unit = v); })),
        ]),
        const SizedBox(height: 8),
        const Text('الحد الأقصى 10 سنوات. الإعداد خاص بأرشيف حسابك.', style: TextStyle(fontSize: 12, color: Color(0xFF65788A))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
        FilledButton(onPressed: () async {
          final amountValue = int.tryParse(controller.text.trim());
          if (amountValue == null || amountValue < 1) {
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('أدخل مدة صحيحة أكبر من صفر.')));
            return;
          }
          final days = unit == 'weeks' ? amountValue * 7 : unit == 'months' ? amountValue * 30 : amountValue;
          if (days > 3650) {
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('مدة الاحتفاظ لا تتجاوز 10 سنوات.')));
            return;
          }
          try {
            await preferences.doc('settings').set({
              'ownerUid': uid, 'autoDeleteEnabled': enabled, 'retentionDays': days,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            if (d.mounted) Navigator.pop(d);
            _message(enabled ? 'تم تفعيل الحذف التلقائي بعد ' + amountValue.toString() + ' ' + (unit == 'days' ? 'يوم' : unit == 'weeks' ? 'أسبوع' : 'شهر') + '.' : 'تم إيقاف الحذف التلقائي.');
          } catch (_) { _message('تعذر حفظ إعدادات الأرشيف.'); }
        }, child: const Text('حفظ الإعدادات')),
      ],
    )));
    controller.dispose();
  }

  List<_RosterItem> _readItems(QuerySnapshot<Map<String,dynamic>> snapshot, Set<String> hidden,
      bool archive, int retentionDays, bool autoDelete) {
    final now = DateTime.now();
    final items = <_RosterItem>[];
    for (final doc in snapshot.docs) {
      final roster = doc.data();
      final shifts = Map<String,dynamic>.from(roster['shifts'] ?? {});
      for (final shift in const ['A','B','C']) {
        final raw = shifts[shift];
        if (raw is! Map) continue;
        final block = Map<String,dynamic>.from(raw);
        final published = block['status'] == 'published' || (block['status'] == null && roster['status'] == 'published');
        if (!published) continue;
        final at = _publishedAt(block,roster);
        if (at == null) continue;
        final elapsed = now.difference(at);
        if (archive != (elapsed >= archiveAfter)) continue;
        if (hidden.contains(_id(doc.id,shift))) continue;
        if (archive && autoDelete && elapsed >= archiveAfter + Duration(days: retentionDays)) continue;
        items.add(_RosterItem(dateKey: doc.id, shift: shift, block: block,
          actualDate: _actualDate(doc.id), publishedAt: at));
      }
    }
    items.sort((a,b) {
      final date = b.actualDate.compareTo(a.actualDate);
      return date != 0 ? date : b.publishedAt.compareTo(a.publishedAt);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = widget.archive ? 'المناوبات السابقة' : 'مناوبات اليوم';
    return Scaffold(
      backgroundColor: page,
      appBar: widget.embedded ? null : AppBar(title: Text(pageTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: navy, foregroundColor: Colors.white, centerTitle: true),
      body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream: db.collection('daily_duty_rosters').where('status',isEqualTo:'published').snapshots(),
        builder: (context, rosterSnap) {
          if (rosterSnap.hasError) return const _RosterMessage(icon: Icons.cloud_off_rounded,
            title: 'تعذر تحميل كشوف المناوبات', subtitle: 'تحقق من الاتصال وقواعد Firestore ثم أعد المحاولة.');
          if (rosterSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          _scheduleNextExpiry(rosterSnap.data!);
          return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
            stream: preferences.snapshots(),
            builder: (context,prefSnap) {
              if (prefSnap.hasError) return const _RosterMessage(icon: Icons.lock_outline_rounded,
                title: 'تعذر تحميل إعدادات الأرشيف', subtitle: 'تحقق من قواعد Firestore.');
              if (prefSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final prefDocs = prefSnap.data?.docs ?? [];
              Map<String,dynamic> settings = {};
              final hidden = <String>{};
              for (final doc in prefDocs) {
                if (doc.id == 'settings') settings = doc.data();
                else if (doc.data()['action'] == 'hidden') hidden.add(doc.id);
              }
              final days = (settings['retentionDays'] as num?)?.toInt() ?? 30;
              final auto = settings['autoDeleteEnabled'] == true;
              final archiveItems = _readItems(rosterSnap.data!,hidden,true,days,auto);
              final visible = _readItems(rosterSnap.data!,hidden,widget.archive,days,auto);
              final items = visible.where((item) {
                final date = DateFormat('dd/MM/yyyy').format(item.actualDate);
                final isoDate = DateFormat('yyyy-MM-dd').format(item.actualDate);
                final term = searchTerm.trim();
                final shortDate = DateFormat('d/M/yyyy').format(item.actualDate);
                return term.isEmpty || matchesSearchText(term, [
                  item.shift,
                  'شفت ' + item.shift,
                  date,
                  shortDate,
                  isoDate,
                  _dayName(item.actualDate),
                ]);
              }).toList();

              if (widget.archive && auto && !_autoCleanupRunning) {
                final expired = <_RosterItem>[];
                for (final doc in rosterSnap.data!.docs) {
                  final roster = doc.data();
                  final shifts = Map<String,dynamic>.from(roster['shifts'] ?? {});
                  for (final shift in const ['A','B','C']) {
                    final raw = shifts[shift];
                    if (raw is! Map) continue;
                    final block = Map<String,dynamic>.from(raw);
                    final published = block['status'] == 'published' || (block['status'] == null && roster['status'] == 'published');
                    final at = published ? _publishedAt(block,roster) : null;
                    if (!published || at == null || DateTime.now().difference(at) < archiveAfter + Duration(days:days)) continue;
                    if (hidden.contains(_id(doc.id,shift))) continue;
                    expired.add(_RosterItem(dateKey:doc.id,shift:shift,block:block,actualDate:_actualDate(doc.id),publishedAt:at));
                  }
                }
                if (expired.isNotEmpty) {
                  _autoCleanupRunning = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    try {
                      for (var start=0; start<expired.length; start+=400) {
                        final batch = db.batch();
                        for (final item in expired.skip(start).take(400)) {
                          batch.set(preferences.doc(_id(item.dateKey,item.shift)),{
                            'ownerUid':uid,'rosterKey':item.dateKey,'shift':item.shift,
                            'action':'hidden','reason':'automatic','updatedAt':FieldValue.serverTimestamp(),
                          });
                        }
                        await batch.commit();
                      }
                    } catch (_) { if (mounted) _message('تعذر إكمال الحذف التلقائي للأرشيف.'); }
                    finally { _autoCleanupRunning = false; }
                  });
                }
              }

              return Column(children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(14,14,14,10),
                  padding: const EdgeInsets.fromLTRB(16,17,16,15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors:[Color(0xFF174A75),Color(0xFF087E78)],
                      begin:Alignment.topRight,end:Alignment.bottomLeft),
                    borderRadius: BorderRadius.circular(20)),
                  child: Column(children: [
                    Text(widget.archive ? 'أرشيف كشوف المناوبات' : 'كشوف المناوبات المرسلة',
                      textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),
                    const SizedBox(height:7),
                    Text(widget.archive ? 'ابحث حسب الشفت أو التاريخ أو اليوم' : 'تظهر الكشوفات لمدة 22 ساعة من وقت إرسالها',
                      textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFFEAF4FC),fontSize:13)),
                    if (widget.archive) ...[
                      const SizedBox(height:12),
                      Row(children:[
                        Expanded(child:OutlinedButton.icon(onPressed:()=>_archiveSettings(settings),
                          icon:const Icon(Icons.settings_rounded,size:19),label:const Text('إعدادات الحذف التلقائي'),
                          style:OutlinedButton.styleFrom(foregroundColor:Colors.white,side:const BorderSide(color:Colors.white70),
                            minimumSize:const Size.fromHeight(46),textStyle:const TextStyle(fontWeight:FontWeight.w800)))),
                        const SizedBox(width:8),
                        IconButton.filledTonal(tooltip:'حذف جميع الكشوفات',
                          onPressed:archiveItems.isEmpty?null:()=>_hideAll(archiveItems),
                          icon:const Icon(Icons.delete_sweep_rounded),
                          style:IconButton.styleFrom(foregroundColor:Colors.white,backgroundColor:Colors.white24,minimumSize:const Size(48,48))),
                      ]),
                      const SizedBox(height:7),
                      Align(alignment:Alignment.centerRight,child:Text(auto
                        ? 'الحذف التلقائي مفعّل • الاحتفاظ ' + days.toString() + ' يوم'
                        : 'الحذف التلقائي متوقف',
                        style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w700))),
                    ],
                  ]),
                ),
                Padding(padding:const EdgeInsets.symmetric(horizontal:14),
                  child:AppSearchField(hint:widget.archive?'ابحث بالشفت أو التاريخ أو اليوم...':'ابحث في كشوف اليوم...',
                    onChanged:(v)=>setState(()=>searchTerm=v))),
                const SizedBox(height:8),
                Expanded(child:items.isEmpty
                  ? _RosterMessage(icon:widget.archive?Icons.archive_outlined:Icons.picture_as_pdf_outlined,
                      title:widget.archive?'لا توجد كشوفات سابقة':'لا توجد كشوفات مرسلة حالياً',
                      subtitle:widget.archive?'ستظهر هنا الكشوفات بعد مرور 22 ساعة على إرسالها.':'عند نشر الإدارة كشف المناوبة سيظهر هنا تلقائياً.')
                  : ListView.separated(padding:const EdgeInsets.fromLTRB(14,4,14,24),itemCount:items.length,
                      separatorBuilder:(_,__)=>const SizedBox(height:10),
                      itemBuilder:(context,index) {
                        final item=items[index];
                        final date=DateFormat('dd/MM/yyyy').format(item.actualDate);
                        final time=DateFormat('HH:mm').format(item.publishedAt);
                        return Material(color:Colors.white,borderRadius:BorderRadius.circular(17),
                          child:InkWell(borderRadius:BorderRadius.circular(17),onTap:()=>_openPdf(item),
                            child:Container(padding:const EdgeInsets.all(14),
                              decoration:BoxDecoration(borderRadius:BorderRadius.circular(17),border:Border.all(color:border)),
                              child:Row(children:[
                                Container(width:52,height:58,decoration:BoxDecoration(color:const Color(0xFFFFEEEE),borderRadius:BorderRadius.circular(13)),
                                  child:const Icon(Icons.picture_as_pdf_rounded,color:Color(0xFFB42318),size:31)),
                                const SizedBox(width:12),
                                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                                  Text('كشف المناوبة • شفت ' + item.shift,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900,color:navy)),
                                  const SizedBox(height:6),
                                  Text(_dayName(item.actualDate) + ' • ' + date,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:Color(0xFF344E67))),
                                  const SizedBox(height:3),
                                  Text('وقت الإرسال: ' + time + ' • ' + _hours(item.shift),
                                    style:const TextStyle(fontSize:12,color:Color(0xFF65788A),fontWeight:FontWeight.w600)),
                                ])),
                                if(widget.archive)
                                  IconButton(tooltip:'حذف من أرشيفي',onPressed:()=>_hideOne(item),
                                    icon:const Icon(Icons.delete_outline_rounded,color:Color(0xFFB42318)))
                                else const Icon(Icons.open_in_new_rounded,color:teal,size:23),
                              ])),
                          ),
                        );
                      })),
              ]);
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }
}

class _RosterItem {
  const _RosterItem({required this.dateKey,required this.shift,required this.block,required this.actualDate,required this.publishedAt});
  final String dateKey;
  final String shift;
  final Map<String,dynamic> block;
  final DateTime actualDate;
  final DateTime publishedAt;
}

class _RosterMessage extends StatelessWidget {
  const _RosterMessage({required this.icon,required this.title,required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Center(child:Padding(padding:const EdgeInsets.all(28),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Icon(icon,size:58,color:const Color(0xFF8296A9)),
      const SizedBox(height:14),
      Text(title,textAlign:TextAlign.center,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:Color(0xFF123B63))),
      const SizedBox(height:7),
      Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(fontSize:14,height:1.6,color:Color(0xFF65788A))),
    ])));
}

class SecurityDutyRosterPdfScreen extends StatefulWidget {
  const SecurityDutyRosterPdfScreen({super.key,required this.dateKey,required this.shift,required this.block,required this.publishedAt});
  final String dateKey;
  final String shift;
  final Map<String,dynamic> block;
  final DateTime publishedAt;
  @override
  State<SecurityDutyRosterPdfScreen> createState()=>_SecurityDutyRosterPdfScreenState();
}

class _SecurityDutyRosterPdfScreenState extends State<SecurityDutyRosterPdfScreen> {
  static const navy=Color(0xFF123B63);
  static const page=Color(0xFFF1F6FC);
  late final Future<Uint8List> pdfFuture;
  bool _savingPdf = false;
  bool _savingImage = false;
  DateTime get actualDate {
    final date=DateTime.tryParse(widget.dateKey)??DateTime.now();
    return date;
  }
  @override
  void initState() {
    super.initState();
    pdfFuture=DutyRosterPdf.build(date:DateFormat('yyyy-MM-dd').format(actualDate),
      shifts:{widget.shift:widget.block},onlyShift:widget.shift).then((v)=>Uint8List.fromList(v));
  }
  Future<void> _save({required bool image}) async {
    if (image ? _savingImage : _savingPdf) return;
    setState(() { if (image) { _savingImage = true; } else { _savingPdf = true; } });
    try {
      final pdf=await pdfFuture;
      final Uint8List bytes;
      late final String extension;
      if(image) {
        final raster=await Printing.raster(pdf,pages:const [0],dpi:220).first;
        bytes=Uint8List.fromList(await raster.toPng());
        extension='png';
      } else { bytes=pdf; extension='pdf'; }
      final name='كشف_المناوبة_' + widget.shift + '_' + DateFormat('yyyyMMdd').format(actualDate) + '.' + extension;
      final saved=await FilePicker.platform.saveFile(dialogTitle:image?'حفظ صورة كشف المناوبة':'حفظ كشف المناوبة PDF',
        fileName:name,bytes:bytes);
      if(saved!=null&&mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text(image?'تم حفظ صورة الكشف على الهاتف.':'تم حفظ ملف PDF على الهاتف.'),behavior:SnackBarBehavior.floating));
    } catch(_) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذر حفظ الكشف. حاول مرة أخرى.')));
    } finally {
      if (mounted) setState(() { if (image) { _savingImage = false; } else { _savingPdf = false; } });
    }
  }
  @override
  Widget build(BuildContext context) {
    final day=const ['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'][actualDate.weekday-1];
    final date=DateFormat('dd/MM/yyyy').format(actualDate);
    final time=DateFormat('HH:mm').format(widget.publishedAt);
    final hours=widget.shift=='A'?'08:00 – 16:00':widget.shift=='B'?'16:00 – 00:00':'00:00 – 08:00';
    return Scaffold(backgroundColor:page,appBar:AppBar(title:Text('كشف المناوبة • شفت '+widget.shift,
      style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),backgroundColor:navy,foregroundColor:Colors.white,centerTitle:true),
      body:Column(children:[
        Container(width:double.infinity,margin:const EdgeInsets.fromLTRB(12,12,12,10),padding:const EdgeInsets.all(15),
          decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF174A75),Color(0xFF087E78)],
            begin:Alignment.topRight,end:Alignment.bottomLeft),borderRadius:BorderRadius.circular(17)),
          child:Column(children:[
            const Text('كشف المناوبة المعتمد',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),
            const SizedBox(height:8),
            Text(day+' • '+date,style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w800)),
            const SizedBox(height:5),
            Text('وقت الإرسال '+time+' • '+hours,style:const TextStyle(color:Color(0xFFE8F3FA),fontSize:13,fontWeight:FontWeight.w600)),
          ])),
        Padding(padding:const EdgeInsets.fromLTRB(12,0,12,10),child:Row(children:[
          Expanded(child:FilledButton.icon(onPressed:_savingPdf?null:()=>_save(image:false),icon:const Icon(Icons.picture_as_pdf_rounded),
            label:Text(_savingPdf?'جارٍ حفظ PDF...':'حفظ PDF'),style:FilledButton.styleFrom(backgroundColor:navy,foregroundColor:Colors.white,
              minimumSize:const Size.fromHeight(48),textStyle:const TextStyle(fontSize:14,fontWeight:FontWeight.w900)))),
          const SizedBox(width:9),
          Expanded(child:FilledButton.icon(onPressed:_savingImage?null:()=>_save(image:true),icon:const Icon(Icons.image_rounded),
            label:Text(_savingImage?'جارٍ حفظ الصورة...':'حفظ صورة'),style:FilledButton.styleFrom(backgroundColor:const Color(0xFF087E78),foregroundColor:Colors.white,
              minimumSize:const Size.fromHeight(48),textStyle:const TextStyle(fontSize:14,fontWeight:FontWeight.w900)))),
        ])),
        Expanded(child:Container(margin:const EdgeInsets.fromLTRB(8,0,8,8),
          decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(13),border:Border.all(color:const Color(0xFFD9E4EF))),
          clipBehavior:Clip.antiAlias,
          child:FutureBuilder<Uint8List>(future:pdfFuture,builder:(context,snapshot){
            if(snapshot.hasError) return const _RosterMessage(icon:Icons.picture_as_pdf_outlined,title:'تعذر تجهيز ملف PDF',subtitle:'أعد فتح الكشف أو تحقق من بيانات المناوبة.');
            if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
            return PdfPreview(build:(_)async=>snapshot.data!,canChangeOrientation:false,canChangePageFormat:false,
              allowPrinting:false,allowSharing:false);
          }))),
      ]));
  }
}


class SecurityDutyRostersHubScreen extends StatelessWidget {
  const SecurityDutyRostersHubScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      backgroundColor: const Color(0xFFF1F6FC),
      appBar: AppBar(
        title: const Text('كشوف المناوبات'),
        backgroundColor: const Color(0xFF123B63),
        foregroundColor: Colors.white,
        centerTitle: true,
        bottom: const TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Color(0xFFE8CB84),
          tabs: [
            Tab(icon: Icon(Icons.today_rounded), text: 'الحالية'),
            Tab(icon: Icon(Icons.archive_rounded), text: 'السابقة'),
          ],
        ),
      ),
      body: const TabBarView(children: [
        SecurityDutyRostersScreen(embedded: true),
        SecurityDutyRostersScreen(archive: true, embedded: true),
      ]),
    ),
  );
}
