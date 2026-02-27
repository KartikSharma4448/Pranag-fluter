import "dart:async";

import "package:flutter/foundation.dart";

import "../data/mock_data.dart";
import "../models/app_models.dart";
import "../services/data/app_repository.dart";

class AppState extends ChangeNotifier {
  AppState() {
    _initialize();
  }

  final AppRepository _repo = AppRepository.instance;
  bool _isReady = false;
  bool _isLoggedIn = false;
  List<Cattle> _cattle = List<Cattle>.from(MockData.cattle);
  List<FarmAlert> _alerts = List<FarmAlert>.from(MockData.alerts);
  UserProfile _user = MockData.user;

  bool get isReady => _isReady;
  bool get isLoggedIn => _isLoggedIn;
  List<Cattle> get cattle => List<Cattle>.unmodifiable(_cattle);
  List<FarmAlert> get alerts => List<FarmAlert>.unmodifiable(_alerts);
  UserProfile get user => _user;
  int get unreadAlerts => _alerts.where((a) => !a.read).length;
  Map<String, String> get cattleNameByMuzzleId => {
        for (final c in _cattle) c.muzzleId: c.name,
      };

  Future<void> _initialize() async {
    try {
      await _repo.initialize();
      await _repo.seedIfEmpty(
        cattle: MockData.cattle,
        alerts: MockData.alerts,
        user: MockData.user,
      );
      _isLoggedIn = _repo.isLoggedIn;
      if (_isLoggedIn) {
        unawaited(_repo.saveDeviceToken());
      }
      await _refreshFromLocal();
      unawaited(_repo.syncNow().then((_) => _refreshFromLocal()));
    } catch (_) {
      _cattle = List<Cattle>.from(MockData.cattle);
      _alerts = List<FarmAlert>.from(MockData.alerts);
      _user = MockData.user;
      _isLoggedIn = false;
    } finally {
      _isReady = true;
      notifyListeners();
    }
  }

  Future<void> _refreshFromLocal() async {
    final cattle = await _repo.getLocalCattle();
    final alerts = await _repo.getLocalAlerts();
    final profile = await _repo.getLocalProfile();

    if (cattle.isNotEmpty) {
      _cattle = cattle;
    }
    if (alerts.isNotEmpty) {
      _alerts = alerts;
    }
    if (profile != null) {
      _user = profile;
    }
    _recomputeUserStats();
    notifyListeners();
  }

  void _recomputeUserStats() {
    _user = _user.copyWith(
      totalCattle: _cattle.length,
      totalAlerts: unreadAlerts,
    );
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  String _generateMuzzleId() {
    final now = DateTime.now().millisecondsSinceEpoch % 1000;
    final scorePart = (70 + (_cattle.length * 3 % 30)).toDouble();
    return "MZL-${scorePart.toStringAsFixed(1)}-$now";
  }

  Future<void> demoLogin() async {
    await _repo.setOfflineLogin(true);
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<String> requestPhoneOtp(String phone) async {
    final verificationId = await _repo.requestPhoneOtp("+91$phone");
    if (verificationId == "AUTO") {
      _isLoggedIn = true;
      await _repo.saveDeviceToken();
      unawaited(_repo.syncNow().then((_) => _refreshFromLocal()));
      notifyListeners();
    }
    return verificationId;
  }

  Future<void> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    await _repo.verifyPhoneOtp(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    _isLoggedIn = true;
    await _repo.saveDeviceToken();
    unawaited(_repo.syncNow().then((_) => _refreshFromLocal()));
    notifyListeners();
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _repo.signInWithEmail(email: email, password: password);
    _isLoggedIn = true;
    await _repo.saveDeviceToken();
    unawaited(_repo.syncNow().then((_) => _refreshFromLocal()));
    notifyListeners();
  }

  Future<void> logout() async {
    await _repo.signOut();
    _isLoggedIn = false;
    notifyListeners();
  }

  void dismissAlert(String id) {
    _alerts = _alerts.where((a) => a.id != id).toList();
    _recomputeUserStats();
    unawaited(_repo.deleteAlert(id));
    unawaited(_repo.upsertProfile(_user));
    notifyListeners();
  }

  void markAlertRead(String id) {
    _alerts = _alerts
        .map((a) => a.id == id ? a.copyWith(read: true) : a)
        .toList();
    _recomputeUserStats();
    unawaited(_repo.markAlertRead(id, true));
    unawaited(_repo.upsertProfile(_user));
    notifyListeners();
  }

  void removeCattle(String id) {
    _cattle = _cattle.where((c) => c.id != id).toList();
    _recomputeUserStats();
    unawaited(_repo.deleteCattle(id));
    unawaited(_repo.upsertProfile(_user));
    notifyListeners();
  }

  void addCattle({
    required String name,
    required String breed,
    required int age,
    required String location,
    required int healthScore,
    required String status,
    required bool digitalTwinActive,
    String? muzzleId,
  }) {
    final cattleItem = Cattle(
      id: _generateId(),
      name: name,
      breed: breed,
      age: age,
      muzzleId: muzzleId ?? _generateMuzzleId(),
      healthScore: healthScore,
      status: status,
      location: location,
      lastScan: "Just now",
      digitalTwinActive: digitalTwinActive,
      alerts: status == "critical" ? 2 : (status == "attention" ? 1 : 0),
    );
    _cattle = [..._cattle, cattleItem];
    _recomputeUserStats();
    unawaited(_repo.upsertCattle(cattleItem));
    unawaited(_repo.upsertProfile(_user));
    notifyListeners();
  }

  Cattle? findCattleByMuzzleId(String muzzleId) {
    for (final cattle in _cattle) {
      if (cattle.muzzleId == muzzleId) {
        return cattle;
      }
    }
    return null;
  }

  void incrementScanCount() {
    _user = _user.copyWith(totalScans: _user.totalScans + 1);
    unawaited(_repo.upsertProfile(_user));
    notifyListeners();
  }

  void createAlert({
    required String cattleName,
    required String cattleBreed,
    required String type,
    required String title,
    required String description,
    bool actionRequired = true,
  }) {
    final newAlert = FarmAlert(
      id: _generateId(),
      cattleId: "",
      cattleName: cattleName,
      cattleBreed: cattleBreed,
      type: type,
      title: title,
      description: description,
      time: "Just now",
      read: false,
      actionRequired: actionRequired,
    );
    _alerts = <FarmAlert>[newAlert, ..._alerts];
    _recomputeUserStats();
    unawaited(_repo.upsertAlert(newAlert));
    unawaited(_repo.upsertProfile(_user));
    notifyListeners();
  }

  void updateCattle(Cattle updated) {
    _cattle = _cattle.map((c) => c.id == updated.id ? updated : c).toList();
    _recomputeUserStats();
    unawaited(_repo.upsertCattle(updated));
    unawaited(_repo.upsertProfile(_user));
    notifyListeners();
  }

  void updateUserProfile({
    String? name,
    String? role,
    String? phone,
    String? location,
    String? email,
    String? membership,
  }) {
    _user = _user.copyWith(
      name: name ?? _user.name,
      role: role ?? _user.role,
      phone: phone ?? _user.phone,
      location: location ?? _user.location,
      email: email ?? _user.email,
      membership: membership ?? _user.membership,
    );
    unawaited(_repo.upsertProfile(_user));
    notifyListeners();
  }
}
