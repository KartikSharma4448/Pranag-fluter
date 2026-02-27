import "dart:async";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:connectivity_plus/connectivity_plus.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../models/app_models.dart";
import "../firebase/firebase_service.dart";
import "../notifications/notification_service.dart";
import "../storage/local_health_db.dart";

class AppRepository {
  AppRepository._();

  static final AppRepository instance = AppRepository._();

  static const String _lastSyncKey = "sync_last_ms";
  static const String _offlineLoginKey = "offline_logged_in";
  static const String _notificationsKey = "settings_notifications";

  final LocalHealthDb _db = LocalHealthDb.instance;
  final FirebaseService _firebase = FirebaseService.instance;
  final Connectivity _connectivity = Connectivity();

  SharedPreferences? _prefs;
  Timer? _syncTimer;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _db.initialize();
    try {
      await _firebase.initialize();
      await NotificationService.instance.initialize();
    } catch (_) {
      // Firebase not configured; allow offline-only usage.
    }

    _connectivity.onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) return;
      unawaited(syncNow());
    });

    _syncTimer ??= Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(syncNow()),
    );
  }

  bool get isLoggedIn {
    final offline = _prefs?.getBool(_offlineLoginKey) ?? false;
    if (offline) return true;
    if (_firebase.isAvailable) {
      return _firebase.auth.currentUser != null;
    }
    return false;
  }

  String? get userId => _firebase.isAvailable ? _firebase.auth.currentUser?.uid : null;

  Future<void> setOfflineLogin(bool value) async {
    await _prefs?.setBool(_offlineLoginKey, value);
  }

  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_firebase.isAvailable) return null;
    try {
      final credential = await _firebase.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await setOfflineLogin(false);
      return credential;
    } on FirebaseAuthException catch (e) {
      if (e.code == "user-not-found") {
        final credential = await _firebase.auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await setOfflineLogin(false);
        return credential;
      }
      rethrow;
    }
  }

  Future<String> requestPhoneOtp(String phone) async {
    if (!_firebase.isAvailable) {
      throw StateError("Firebase not available on this platform.");
    }

    final completer = Completer<String>();

    await _firebase.auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (credential) async {
        await _firebase.auth.signInWithCredential(credential);
        await setOfflineLogin(false);
        if (!completer.isCompleted) {
          completer.complete("AUTO");
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
    );

    return completer.future;
  }

  Future<UserCredential?> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    if (!_firebase.isAvailable) return null;
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCredential = await _firebase.auth.signInWithCredential(credential);
    await setOfflineLogin(false);
    return userCredential;
  }

  Future<void> signOut() async {
    if (_firebase.isAvailable) {
      await _firebase.auth.signOut();
    }
    await setOfflineLogin(false);
  }

  Future<void> saveDeviceToken() async {
    final uid = userId;
    if (uid == null) return;
    await NotificationService.instance.registerDeviceToken(uid: uid);
  }

  Future<List<Cattle>> getLocalCattle() async {
    final rows = await _db.getCachedCattleRows();
    return rows.map((row) => row.cattle).toList();
  }

  Future<List<FarmAlert>> getLocalAlerts() async {
    final rows = await _db.getCachedAlertRows();
    return rows.map((row) => row.alert).toList();
  }

  Future<UserProfile?> getLocalProfile() async {
    final row = await _db.getCachedProfileRow();
    return row?.user;
  }

  Future<void> seedIfEmpty({
    required List<Cattle> cattle,
    required List<FarmAlert> alerts,
    required UserProfile user,
  }) async {
    final existingCattle = await _db.getCachedCattleRows();
    final existingAlerts = await _db.getCachedAlertRows();
    final existingUser = await _db.getCachedProfileRow();

    if (existingCattle.isEmpty) {
      for (final c in cattle) {
        await _db.upsertCachedCattle(c);
      }
    }
    if (existingAlerts.isEmpty) {
      for (final a in alerts) {
        await _db.upsertCachedAlert(a);
      }
    }
    if (existingUser == null) {
      await _db.upsertCachedUser(user);
    }
  }

  Future<void> upsertCattle(Cattle cattle) async {
    await _db.upsertCachedCattle(cattle);
    await _db.enqueueSync(
      entityType: "cattle",
      action: "upsert",
      payload: _cattleToMap(cattle),
    );
    unawaited(syncNow());
  }

  Future<void> deleteCattle(String id) async {
    await _db.markCattleDeleted(id);
    await _db.enqueueSync(
      entityType: "cattle",
      action: "delete",
      payload: <String, dynamic>{"id": id},
    );
    unawaited(syncNow());
  }

  Future<void> upsertAlert(FarmAlert alert) async {
    await _db.upsertCachedAlert(alert);
    await _db.enqueueSync(
      entityType: "alerts",
      action: "upsert",
      payload: _alertToMap(alert),
    );
    unawaited(syncNow());
  }

  Future<void> markAlertRead(String id, bool read) async {
    final alerts = await _db.getCachedAlertRows(includeDeleted: true);
    final match = alerts.where((a) => a.alert.id == id).firstOrNull;
    if (match == null) return;
    final updated = match.alert.copyWith(read: read);
    await _db.upsertCachedAlert(updated, updatedAt: DateTime.now().millisecondsSinceEpoch);
    await _db.enqueueSync(
      entityType: "alerts",
      action: "read",
      payload: <String, dynamic>{"id": id, "read": read},
    );
    unawaited(syncNow());
  }

  Future<void> deleteAlert(String id) async {
    await _db.markAlertDeleted(id);
    await _db.enqueueSync(
      entityType: "alerts",
      action: "delete",
      payload: <String, dynamic>{"id": id},
    );
    unawaited(syncNow());
  }

  Future<void> upsertProfile(UserProfile profile) async {
    await _db.upsertCachedUser(profile);
    await _db.enqueueSync(
      entityType: "profile",
      action: "upsert",
      payload: _profileToMap(profile),
    );
    unawaited(syncNow());
  }

  String _syncKeyFor(String uid) => "${_lastSyncKey}_$uid";

  Future<void> syncNow() async {
    if (!_firebase.isAvailable) return;
    final uid = userId;
    if (uid == null) return;

    final connectivity = await _connectivity.checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    await _flushQueue(uid);
    await _pullRemoteUpdates(uid);
    await _prefs?.setInt(_syncKeyFor(uid), DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _flushQueue(String uid) async {
    final queue = await _db.getSyncQueue();
    for (final item in queue) {
      try {
        await _applyQueueItem(uid, item);
        await _db.deleteSyncQueueItem(item.id);
      } catch (_) {
        break;
      }
    }
  }

  Future<void> _applyQueueItem(String uid, SyncQueueItem item) async {
    final firestore = _firebase.firestore;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (item.entityType == "cattle") {
      final id = item.payload["id"]?.toString() ?? "";
      if (id.isEmpty) return;
      final ref = firestore.collection("users").doc(uid).collection("cattle").doc(id);
      if (item.action == "delete") {
        await ref.set({"deleted": true, "updatedAt": now}, SetOptions(merge: true));
      } else {
        await ref.set({...item.payload, "updatedAt": now}, SetOptions(merge: true));
      }
      return;
    }

    if (item.entityType == "alerts") {
      final id = item.payload["id"]?.toString() ?? "";
      if (id.isEmpty) return;
      final ref = firestore.collection("users").doc(uid).collection("alerts").doc(id);
      if (item.action == "delete") {
        await ref.set({"deleted": true, "updatedAt": now}, SetOptions(merge: true));
      } else if (item.action == "read") {
        await ref.set({
          "read": item.payload["read"] ?? true,
          "updatedAt": now,
        }, SetOptions(merge: true));
      } else {
        await ref.set({...item.payload, "updatedAt": now}, SetOptions(merge: true));
      }
      return;
    }

    if (item.entityType == "profile") {
      final ref = firestore.collection("users").doc(uid).collection("profile").doc("me");
      await ref.set({...item.payload, "updatedAt": now}, SetOptions(merge: true));
    }
  }

  Future<void> _pullRemoteUpdates(String uid) async {
    final firestore = _firebase.firestore;
    final lastSync = _prefs?.getInt(_syncKeyFor(uid)) ?? 0;

    final cattleSnap = await firestore
        .collection("users")
        .doc(uid)
        .collection("cattle")
        .where("updatedAt", isGreaterThan: lastSync)
        .get();
    await _mergeRemoteCattle(cattleSnap.docs);

    final alertSnap = await firestore
        .collection("users")
        .doc(uid)
        .collection("alerts")
        .where("updatedAt", isGreaterThan: lastSync)
        .get();
    await _mergeRemoteAlerts(alertSnap.docs);

    final profileSnap = await firestore
        .collection("users")
        .doc(uid)
        .collection("profile")
        .doc("me")
        .get();
    if (profileSnap.exists) {
      await _mergeRemoteProfile(profileSnap.data() ?? <String, dynamic>{});
    }
  }

  Future<void> _mergeRemoteCattle(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final localRows = await _db.getCachedCattleRows(includeDeleted: true);
    final localById = {
      for (final row in localRows) row.cattle.id: row,
    };

    for (final doc in docs) {
      final data = doc.data();
      final updatedAt = (data["updatedAt"] as num?)?.toInt() ?? 0;
      final local = localById[doc.id];
      if (local != null && local.updatedAt >= updatedAt) {
        continue;
      }

      final deleted = data["deleted"] == true;
      if (deleted) {
        await _db.markCattleDeleted(doc.id);
        continue;
      }

      final cattle = Cattle(
        id: doc.id,
        name: (data["name"] ?? "").toString(),
        breed: (data["breed"] ?? "").toString(),
        age: (data["age"] as num?)?.toInt() ?? 0,
        muzzleId: (data["muzzleId"] ?? "").toString(),
        healthScore: (data["healthScore"] as num?)?.toInt() ?? 0,
        status: (data["status"] ?? "healthy").toString(),
        location: (data["location"] ?? "").toString(),
        lastScan: (data["lastScan"] ?? "").toString(),
        digitalTwinActive: data["digitalTwinActive"] == true,
        alerts: (data["alerts"] as num?)?.toInt() ?? 0,
      );
      await _db.upsertCachedCattle(cattle, updatedAt: updatedAt);
    }
  }

  Future<void> _mergeRemoteAlerts(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final localRows = await _db.getCachedAlertRows(includeDeleted: true);
    final localById = {
      for (final row in localRows) row.alert.id: row,
    };

    for (final doc in docs) {
      final data = doc.data();
      final updatedAt = (data["updatedAt"] as num?)?.toInt() ?? 0;
      final local = localById[doc.id];
      if (local != null && local.updatedAt >= updatedAt) {
        continue;
      }

      final deleted = data["deleted"] == true;
      if (deleted) {
        await _db.markAlertDeleted(doc.id);
        continue;
      }

      final alert = FarmAlert(
        id: doc.id,
        cattleId: (data["cattleId"] ?? "").toString(),
        cattleName: (data["cattleName"] ?? "").toString(),
        cattleBreed: (data["cattleBreed"] ?? "").toString(),
        type: (data["type"] ?? "warning").toString(),
        title: (data["title"] ?? "").toString(),
        description: (data["description"] ?? "").toString(),
        time: (data["time"] ?? "").toString(),
        read: data["read"] == true,
        actionRequired: data["actionRequired"] == true,
      );
      await _db.upsertCachedAlert(alert, updatedAt: updatedAt);

      final notificationsEnabled = _prefs?.getBool(_notificationsKey) ?? true;
      if (notificationsEnabled && !alert.read) {
        await NotificationService.instance.showAlertNotification(
          title: alert.title,
          body: alert.description,
        );
      }
    }
  }

  Future<void> _mergeRemoteProfile(Map<String, dynamic> data) async {
    final updatedAt = (data["updatedAt"] as num?)?.toInt() ?? 0;
    final local = await _db.getCachedProfileRow();
    if (local != null && local.updatedAt >= updatedAt) return;

    final profile = UserProfile(
      name: (data["name"] ?? "").toString(),
      role: (data["role"] ?? "").toString(),
      phone: (data["phone"] ?? "").toString(),
      location: (data["location"] ?? "").toString(),
      email: (data["email"] ?? "").toString(),
      membership: (data["membership"] ?? "").toString(),
      totalCattle: (data["totalCattle"] as num?)?.toInt() ?? 0,
      totalScans: (data["totalScans"] as num?)?.toInt() ?? 0,
      totalAlerts: (data["totalAlerts"] as num?)?.toInt() ?? 0,
    );
    await _db.upsertCachedUser(profile, updatedAt: updatedAt);
  }

  Map<String, dynamic> _cattleToMap(Cattle cattle) {
    return <String, dynamic>{
      "id": cattle.id,
      "name": cattle.name,
      "breed": cattle.breed,
      "age": cattle.age,
      "muzzleId": cattle.muzzleId,
      "healthScore": cattle.healthScore,
      "status": cattle.status,
      "location": cattle.location,
      "lastScan": cattle.lastScan,
      "digitalTwinActive": cattle.digitalTwinActive,
      "alerts": cattle.alerts,
    };
  }

  Map<String, dynamic> _alertToMap(FarmAlert alert) {
    return <String, dynamic>{
      "id": alert.id,
      "cattleId": alert.cattleId,
      "cattleName": alert.cattleName,
      "cattleBreed": alert.cattleBreed,
      "type": alert.type,
      "title": alert.title,
      "description": alert.description,
      "time": alert.time,
      "read": alert.read,
      "actionRequired": alert.actionRequired,
    };
  }

  Map<String, dynamic> _profileToMap(UserProfile user) {
    return <String, dynamic>{
      "name": user.name,
      "role": user.role,
      "phone": user.phone,
      "location": user.location,
      "email": user.email,
      "membership": user.membership,
      "totalCattle": user.totalCattle,
      "totalScans": user.totalScans,
      "totalAlerts": user.totalAlerts,
    };
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
