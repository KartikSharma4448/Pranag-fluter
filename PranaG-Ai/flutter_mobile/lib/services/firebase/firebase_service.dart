import "dart:io";

import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_messaging/firebase_messaging.dart";

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;
  bool _available = false;

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseMessaging? _messaging;

  bool get isAvailable => _available;
  FirebaseAuth get auth => _auth!;
  FirebaseFirestore get firestore => _firestore!;
  FirebaseMessaging? get messaging => _messaging;

  Future<void> initialize() async {
    if (_initialized) return;

    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (!isMobile) {
      _initialized = true;
      _available = false;
      return;
    }

    await Firebase.initializeApp();
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    _messaging = FirebaseMessaging.instance;
    _available = true;
    _initialized = true;
  }
}
