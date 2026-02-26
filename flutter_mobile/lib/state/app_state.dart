import "dart:convert";

import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../data/mock_data.dart";
import "../models/app_models.dart";

class AppState extends ChangeNotifier {
  AppState() {
    _initialize();
  }

  static const String _kLoggedIn = "pranag_logged_in";
  static const String _kCattle = "pranag_cattle";
  static const String _kAlerts = "pranag_alerts";
  static const String _kUser = "pranag_user";

  SharedPreferences? _prefs;
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
      _prefs = await SharedPreferences.getInstance();
      _loadPersistedState();
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

  void _loadPersistedState() {
    final prefs = _prefs;
    if (prefs == null) return;

    _isLoggedIn = prefs.getBool(_kLoggedIn) ?? false;

    final cattleRaw = prefs.getString(_kCattle);
    if (cattleRaw != null && cattleRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(cattleRaw) as List<dynamic>;
        _cattle = decoded
            .map((e) => Cattle.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _cattle = List<Cattle>.from(MockData.cattle);
      }
    }

    final alertsRaw = prefs.getString(_kAlerts);
    if (alertsRaw != null && alertsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(alertsRaw) as List<dynamic>;
        _alerts = decoded
            .map((e) => FarmAlert.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _alerts = List<FarmAlert>.from(MockData.alerts);
      }
    }

    final userRaw = prefs.getString(_kUser);
    if (userRaw != null && userRaw.isNotEmpty) {
      try {
        _user = UserProfile.fromJson(jsonDecode(userRaw) as Map<String, dynamic>);
      } catch (_) {
        _user = MockData.user;
      }
    }

    _recomputeUserStats();
  }

  void _persist() {
    final prefs = _prefs;
    if (prefs == null) return;

    prefs.setBool(_kLoggedIn, _isLoggedIn);
    prefs.setString(
      _kCattle,
      jsonEncode(_cattle.map((c) => c.toJson()).toList()),
    );
    prefs.setString(
      _kAlerts,
      jsonEncode(_alerts.map((a) => a.toJson()).toList()),
    );
    prefs.setString(_kUser, jsonEncode(_user.toJson()));
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

  void login(String phone) {
    _user = _user.copyWith(phone: "+91$phone");
    _isLoggedIn = true;
    _persist();
    notifyListeners();
  }

  void demoLogin() {
    _isLoggedIn = true;
    _persist();
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _persist();
    notifyListeners();
  }

  void dismissAlert(String id) {
    _alerts = _alerts.where((a) => a.id != id).toList();
    _recomputeUserStats();
    _persist();
    notifyListeners();
  }

  void markAlertRead(String id) {
    _alerts = _alerts
        .map((a) => a.id == id ? a.copyWith(read: true) : a)
        .toList();
    _recomputeUserStats();
    _persist();
    notifyListeners();
  }

  void removeCattle(String id) {
    _cattle = _cattle.where((c) => c.id != id).toList();
    _recomputeUserStats();
    _persist();
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
    _persist();
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
    _persist();
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
    _persist();
    notifyListeners();
  }

  void updateCattle(Cattle updated) {
    _cattle = _cattle.map((c) => c.id == updated.id ? updated : c).toList();
    _recomputeUserStats();
    _persist();
    notifyListeners();
  }

  void updateUserProfile({
    required String name,
    required String role,
    required String phone,
    required String membership,
  }) {
    _user = _user.copyWith(
      name: name,
      role: role,
      phone: phone,
      membership: membership,
    );
    _persist();
    notifyListeners();
  }
}
