import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Plays one short system alert whenever a new notification document is
/// delivered to the signed-in user while the app is running.
class NotificationSoundListener extends StatefulWidget {
  const NotificationSoundListener({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationSoundListener> createState() =>
      _NotificationSoundListenerState();
}

class _NotificationSoundListenerState extends State<NotificationSoundListener>
    with WidgetsBindingObserver {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _receivedInitialSnapshot = false;
  String? _listeningUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startListening();
  }

  @override
  void didUpdateWidget(covariant NotificationSoundListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startListening();
  }

  void _startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || uid == _listeningUid) return;

    _subscription?.cancel();
    _listeningUid = uid;
    _receivedInitialSnapshot = false;

    _subscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .snapshots()
        .listen(
      (snapshot) {
        // Do not play sounds for old notifications loaded on app startup.
        if (!_receivedInitialSnapshot) {
          _receivedInitialSnapshot = true;
          return;
        }

        for (final change in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final notification = change.doc.data();
          if (notification['recipientUid'] != uid) continue;
          _playMessageSound();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Notification sound listener failed: $error');
      },
    );
  }

  void _playMessageSound() {
    // Uses the platform's short alert tone; no extra package or paid service.
    SystemSound.play(SystemSoundType.alert).catchError((Object error) {
      debugPrint('Notification alert sound failed: $error');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
