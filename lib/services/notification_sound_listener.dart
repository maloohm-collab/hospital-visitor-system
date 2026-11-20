import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    hide NotificationVisibility;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Rings the phone (sound + heads-up banner) for every new in-app notification
/// addressed to the signed-in user, for as long as the app process is alive
/// (foreground, background, or local-lock screen).
///
/// Free by design: it listens to the same Firestore `notifications` query the
/// app already uses and raises a *local* notification. It does NOT work after
/// the app is force-closed/swiped away; that needs server-side FCM push, which
/// requires Cloud Functions (Firebase Blaze plan).
class NotificationSoundListener {
  NotificationSoundListener._();
  static final NotificationSoundListener instance = NotificationSoundListener._();

  static const _channelId = 'staff_alerts';
  static const _channelName = 'تنبيهات الإشعارات';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationsSub;
  bool _initialized = false;
  String? _activeUid;
  final Set<String> _seen = <String>{};
  bool _baselineReady = false;

  /// Call once from `main()` after `Firebase.initializeApp()`.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'تنبيه صوتي عند وصول أي إشعار جديد',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
      await androidPlugin?.requestNotificationsPermission();
    } catch (error, stackTrace) {
      debugPrint('Notification sound setup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    _initForegroundService();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      (user) => user == null ? _stop() : _start(user.uid),
    );
  }

  /// Keeps the app process alive in the background (Android) so the Firestore
  /// listener keeps running. Shows one persistent, silent notification.
  void _initForegroundService() {
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'staff_alerts_service',
          channelName: 'خدمة استقبال التنبيهات',
          channelDescription: 'تبقي التطبيق جاهزاً لاستقبال التنبيهات',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          autoRunOnBoot: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    } catch (error) {
      debugPrint('Foreground service init failed: $error');
    }
  }

  Future<void> _startForegroundService() async {
    try {
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        serviceTypes: [ForegroundServiceTypes.remoteMessaging],
        notificationTitle: 'التنبيهات فعّالة',
        notificationText: 'التطبيق جاهز لاستقبال الإشعارات',
      );
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (error) {
      debugPrint('Foreground service start failed: $error');
    }
  }

  Future<void> _stopForegroundService() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (error) {
      debugPrint('Foreground service stop failed: $error');
    }
  }

  void _start(String uid) {
    if (_activeUid == uid) return;
    _stop();
    _activeUid = uid;
    _baselineReady = false;
    _startForegroundService();
    _notificationsSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .snapshots()
        .listen(_onSnapshot, onError: (Object error) {
      // Permission errors are expected while an account is not yet approved.
      debugPrint('Notification sound listener error: $error');
    });
  }

  void _stop() {
    if (_activeUid != null) _stopForegroundService();
    _notificationsSub?.cancel();
    _notificationsSub = null;
    _activeUid = null;
    _seen.clear();
    _baselineReady = false;
  }

  Future<void> _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) async {
    // First snapshot = what already exists; never ring for old notifications.
    if (!_baselineReady) {
      _seen.addAll(snapshot.docs.map((d) => d.id));
      _baselineReady = true;
      return;
    }
    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final doc = change.doc;
      if (!_seen.add(doc.id)) continue;
      final data = doc.data();
      if (data == null || data['read'] == true) continue;
      if (data['senderUid'] == _activeUid) continue; // do not ring for own sends
      await _ring(doc.id, data);
    }
  }

  Future<void> _ring(String id, Map<String, dynamic> data) async {
    final title = (data['title'] ?? 'إشعار جديد').toString();
    final body = (data['body'] ?? '').toString();
    final urgent = data['priority'] == 'urgent';
    try {
      await _plugin.show(
        id.hashCode & 0x7fffffff,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.max,
            priority: urgent ? Priority.max : Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.message,
            visibility: NotificationVisibility.public,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
      );
    } catch (error) {
      debugPrint('Could not show notification alert: $error');
    }
  }

  Future<void> dispose() async {
    _stop();
    await _authSub?.cancel();
    _authSub = null;
    _initialized = false;
  }
}
