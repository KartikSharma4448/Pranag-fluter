import "dart:convert";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:path/path.dart" as path;
import "package:sqflite_common_ffi/sqflite_ffi.dart";

import "../../models/app_models.dart";

class CowRecord {
  const CowRecord({
    required this.cowId,
    required this.name,
    required this.breed,
    required this.age,
    required this.location,
    required this.embeddingVector,
  });

  final String cowId;
  final String name;
  final String breed;
  final int age;
  final String location;
  final List<double> embeddingVector;

  Map<String, Object?> toMap() {
    final safeEmbedding = embeddingVector
        .map((v) => v.isFinite ? v : 0.0)
        .toList(growable: false);
    return <String, Object?>{
      "cow_id": cowId,
      "name": name,
      "breed": breed,
      "age": age,
      "location": location,
      "embedding_vector": jsonEncode(safeEmbedding),
    };
  }

  factory CowRecord.fromMap(Map<String, Object?> row) {
    final rawEmbedding = (row["embedding_vector"] as String? ?? "[]");
    List<double> embedding;
    try {
      final decoded = jsonDecode(rawEmbedding) as List<dynamic>;
      embedding = decoded.map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      embedding = const <double>[];
    }

    return CowRecord(
      cowId: (row["cow_id"] ?? "").toString(),
      name: (row["name"] ?? "").toString(),
      breed: (row["breed"] ?? "").toString(),
      age: (row["age"] as num?)?.toInt() ?? 0,
      location: (row["location"] ?? "").toString(),
      embeddingVector: embedding,
    );
  }
}

class HealthLogRecord {
  const HealthLogRecord({
    required this.id,
    required this.cowId,
    required this.acousticResult,
    required this.skinResult,
    required this.riskScore,
    required this.riskLevel,
    required this.healthStatus,
    required this.recommendations,
    required this.timestamp,
  });

  final int id;
  final String cowId;
  final Map<String, dynamic> acousticResult;
  final Map<String, dynamic> skinResult;
  final double riskScore;
  final String riskLevel;
  final String healthStatus;
  final String recommendations;
  final DateTime timestamp;

  factory HealthLogRecord.fromMap(Map<String, Object?> row) {
    Map<String, dynamic> decodeJson(String raw) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    return HealthLogRecord(
      id: (row["id"] as num?)?.toInt() ?? 0,
      cowId: (row["cow_id"] ?? "").toString(),
      acousticResult: decodeJson((row["acoustic_result"] ?? "{}").toString()),
      skinResult: decodeJson((row["skin_result"] ?? "{}").toString()),
      riskScore: (row["risk_score"] as num?)?.toDouble() ?? 0,
      riskLevel: (row["risk_level"] ?? "").toString(),
      healthStatus: (row["health_status"] ?? "").toString(),
      recommendations: (row["recommendations"] ?? "").toString(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (row["timestamp"] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class CachedCattleRow {
  const CachedCattleRow({
    required this.cattle,
    required this.updatedAt,
    required this.deleted,
  });

  final Cattle cattle;
  final int updatedAt;
  final bool deleted;
}

class CachedAlertRow {
  const CachedAlertRow({
    required this.alert,
    required this.updatedAt,
    required this.deleted,
  });

  final FarmAlert alert;
  final int updatedAt;
  final bool deleted;
}

class CachedProfileRow {
  const CachedProfileRow({
    required this.user,
    required this.updatedAt,
  });

  final UserProfile user;
  final int updatedAt;
}

class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.action,
    required this.payload,
    required this.createdAt,
  });

  final int id;
  final String entityType;
  final String action;
  final Map<String, dynamic> payload;
  final int createdAt;
}

class CowMatch {
  const CowMatch({
    required this.cow,
    required this.similarity,
  });

  final CowRecord cow;
  final double similarity;
}

class LocalHealthDb {
  LocalHealthDb._();

  static final LocalHealthDb instance = LocalHealthDb._();
  static const String _dbName = "pranag_offline.db";
  static const int _dbVersion = 2;
  static bool _factoryReady = false;

  Database? _db;

  Future<void> initialize() async {
    if (_db != null) {
      return;
    }
    _ensureFactoryForDesktop();

    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, _dbName);

    _db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute("""
          CREATE TABLE cows(
            cow_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            breed TEXT NOT NULL,
            age INTEGER NOT NULL,
            location TEXT NOT NULL,
            embedding_vector TEXT NOT NULL
          );
        """);

        await db.execute("""
          CREATE TABLE health_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cow_id TEXT NOT NULL,
            acoustic_result TEXT NOT NULL,
            skin_result TEXT NOT NULL,
            risk_score REAL NOT NULL,
            risk_level TEXT NOT NULL,
            health_status TEXT NOT NULL,
            recommendations TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          );
        """);

        await _createCacheTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCacheTables(db);
        }
      },
    );
  }

  Future<void> _createCacheTables(Database db) async {
    await db.execute("""
      CREATE TABLE IF NOT EXISTS cattle_cache(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        breed TEXT NOT NULL,
        age INTEGER NOT NULL,
        muzzle_id TEXT NOT NULL,
        health_score INTEGER NOT NULL,
        status TEXT NOT NULL,
        location TEXT NOT NULL,
        last_scan TEXT NOT NULL,
        digital_twin_active INTEGER NOT NULL,
        alerts INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0
      );
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS alerts_cache(
        id TEXT PRIMARY KEY,
        cattle_id TEXT NOT NULL,
        cattle_name TEXT NOT NULL,
        cattle_breed TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        time TEXT NOT NULL,
        read INTEGER NOT NULL,
        action_required INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0
      );
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS user_profile(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        phone TEXT NOT NULL,
        location TEXT NOT NULL,
        email TEXT NOT NULL,
        membership TEXT NOT NULL,
        total_cattle INTEGER NOT NULL,
        total_scans INTEGER NOT NULL,
        total_alerts INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS sync_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
    """);
  }

  Future<void> upsertCow(CowRecord cow) async {
    final db = await _database;
    await db.insert(
      "cows",
      cow.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CowRecord?> getCowById(String cowId) async {
    final db = await _database;
    final rows = await db.query(
      "cows",
      where: "cow_id = ?",
      whereArgs: <Object?>[cowId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return CowRecord.fromMap(rows.first);
  }

  Future<List<CowRecord>> getAllCows() async {
    final db = await _database;
    final rows = await db.query("cows", orderBy: "name ASC");
    return rows.map(CowRecord.fromMap).toList();
  }

  Future<void> deleteCow(String cowId) async {
    final db = await _database;
    await db.delete(
      "cows",
      where: "cow_id = ?",
      whereArgs: <Object?>[cowId],
    );
  }

  Future<CowMatch?> findBestMatch(
    List<double> embedding, {
    required double acceptThreshold,
  }) async {
    final normalizedQuery = _l2Normalize(embedding);
    if (normalizedQuery.isEmpty) {
      return null;
    }

    final cows = await getAllCows();
    CowRecord? bestCow;
    var bestSimilarity = -1.0;

    for (final cow in cows) {
      final candidate = _l2Normalize(cow.embeddingVector);
      if (candidate.isEmpty || candidate.length != normalizedQuery.length) {
        continue;
      }
      final similarity = _cosineSimilarity(normalizedQuery, candidate);
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestCow = cow;
      }
    }

    if (bestCow == null || bestSimilarity < acceptThreshold) {
      return null;
    }

    return CowMatch(cow: bestCow, similarity: bestSimilarity);
  }

  Future<int> insertHealthLog({
    required String cowId,
    required Map<String, dynamic> acousticResult,
    required Map<String, dynamic> skinResult,
    required double riskScore,
    required String riskLevel,
    required String healthStatus,
    required String recommendations,
    DateTime? timestamp,
  }) async {
    final db = await _database;
    final ts = (timestamp ?? DateTime.now()).millisecondsSinceEpoch;

    return db.insert(
      "health_logs",
      <String, Object?>{
        "cow_id": cowId,
        "acoustic_result": jsonEncode(acousticResult),
        "skin_result": jsonEncode(skinResult),
        "risk_score": riskScore,
        "risk_level": riskLevel,
        "health_status": healthStatus,
        "recommendations": recommendations,
        "timestamp": ts,
      },
    );
  }

  Future<List<HealthLogRecord>> getHealthLogs({String? cowId}) async {
    final db = await _database;
    final rows = await db.query(
      "health_logs",
      where: cowId == null ? null : "cow_id = ?",
      whereArgs: cowId == null ? null : <Object?>[cowId],
      orderBy: "timestamp DESC",
    );
    return rows.map(HealthLogRecord.fromMap).toList();
  }

  Future<void> upsertCachedCattle(
    Cattle cattle, {
    int? updatedAt,
    bool deleted = false,
  }) async {
    final db = await _database;
    final ts = updatedAt ?? DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      "cattle_cache",
      <String, Object?>{
        "id": cattle.id,
        "name": cattle.name,
        "breed": cattle.breed,
        "age": cattle.age,
        "muzzle_id": cattle.muzzleId,
        "health_score": cattle.healthScore,
        "status": cattle.status,
        "location": cattle.location,
        "last_scan": cattle.lastScan,
        "digital_twin_active": _boolToInt(cattle.digitalTwinActive),
        "alerts": cattle.alerts,
        "updated_at": ts,
        "deleted": _boolToInt(deleted),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertCachedAlert(
    FarmAlert alert, {
    int? updatedAt,
    bool deleted = false,
  }) async {
    final db = await _database;
    final ts = updatedAt ?? DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      "alerts_cache",
      <String, Object?>{
        "id": alert.id,
        "cattle_id": alert.cattleId,
        "cattle_name": alert.cattleName,
        "cattle_breed": alert.cattleBreed,
        "type": alert.type,
        "title": alert.title,
        "description": alert.description,
        "time": alert.time,
        "read": _boolToInt(alert.read),
        "action_required": _boolToInt(alert.actionRequired),
        "updated_at": ts,
        "deleted": _boolToInt(deleted),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertCachedUser(
    UserProfile user, {
    int? updatedAt,
  }) async {
    final db = await _database;
    final ts = updatedAt ?? DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      "user_profile",
      <String, Object?>{
        "id": "me",
        "name": user.name,
        "role": user.role,
        "phone": user.phone,
        "location": user.location,
        "email": user.email,
        "membership": user.membership,
        "total_cattle": user.totalCattle,
        "total_scans": user.totalScans,
        "total_alerts": user.totalAlerts,
        "updated_at": ts,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CachedCattleRow>> getCachedCattleRows({
    bool includeDeleted = false,
  }) async {
    final db = await _database;
    final rows = await db.query(
      "cattle_cache",
      where: includeDeleted ? null : "deleted = 0",
      orderBy: "name ASC",
    );
    return rows.map(_mapCachedCattleRow).toList();
  }

  Future<List<CachedAlertRow>> getCachedAlertRows({
    bool includeDeleted = false,
  }) async {
    final db = await _database;
    final rows = await db.query(
      "alerts_cache",
      where: includeDeleted ? null : "deleted = 0",
      orderBy: "updated_at DESC",
    );
    return rows.map(_mapCachedAlertRow).toList();
  }

  Future<CachedProfileRow?> getCachedProfileRow() async {
    final db = await _database;
    final rows = await db.query(
      "user_profile",
      where: "id = ?",
      whereArgs: const <Object?>["me"],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapCachedProfileRow(rows.first);
  }

  Future<void> markCattleDeleted(String id) async {
    final db = await _database;
    await db.update(
      "cattle_cache",
      <String, Object?>{
        "deleted": 1,
        "updated_at": DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ?",
      whereArgs: <Object?>[id],
    );
  }

  Future<void> markAlertDeleted(String id) async {
    final db = await _database;
    await db.update(
      "alerts_cache",
      <String, Object?>{
        "deleted": 1,
        "updated_at": DateTime.now().millisecondsSinceEpoch,
      },
      where: "id = ?",
      whereArgs: <Object?>[id],
    );
  }

  Future<int> enqueueSync({
    required String entityType,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _database;
    return db.insert(
      "sync_queue",
      <String, Object?>{
        "entity_type": entityType,
        "action": action,
        "payload": jsonEncode(payload),
        "created_at": DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<List<SyncQueueItem>> getSyncQueue() async {
    final db = await _database;
    final rows = await db.query("sync_queue", orderBy: "created_at ASC");
    return rows.map(_mapSyncQueueItem).toList();
  }

  Future<void> deleteSyncQueueItem(int id) async {
    final db = await _database;
    await db.delete("sync_queue", where: "id = ?", whereArgs: <Object?>[id]);
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) {
      return;
    }
    await db.close();
    _db = null;
  }

  Future<Database> get _database async {
    await initialize();
    return _db!;
  }

  CachedCattleRow _mapCachedCattleRow(Map<String, Object?> row) {
    final cattle = Cattle(
      id: (row["id"] ?? "").toString(),
      name: (row["name"] ?? "").toString(),
      breed: (row["breed"] ?? "").toString(),
      age: (row["age"] as num?)?.toInt() ?? 0,
      muzzleId: (row["muzzle_id"] ?? "").toString(),
      healthScore: (row["health_score"] as num?)?.toInt() ?? 0,
      status: (row["status"] ?? "healthy").toString(),
      location: (row["location"] ?? "").toString(),
      lastScan: (row["last_scan"] ?? "").toString(),
      digitalTwinActive: _intToBool(row["digital_twin_active"]),
      alerts: (row["alerts"] as num?)?.toInt() ?? 0,
    );
    return CachedCattleRow(
      cattle: cattle,
      updatedAt: (row["updated_at"] as num?)?.toInt() ?? 0,
      deleted: _intToBool(row["deleted"]),
    );
  }

  CachedAlertRow _mapCachedAlertRow(Map<String, Object?> row) {
    final alert = FarmAlert(
      id: (row["id"] ?? "").toString(),
      cattleId: (row["cattle_id"] ?? "").toString(),
      cattleName: (row["cattle_name"] ?? "").toString(),
      cattleBreed: (row["cattle_breed"] ?? "").toString(),
      type: (row["type"] ?? "warning").toString(),
      title: (row["title"] ?? "").toString(),
      description: (row["description"] ?? "").toString(),
      time: (row["time"] ?? "").toString(),
      read: _intToBool(row["read"]),
      actionRequired: _intToBool(row["action_required"]),
    );
    return CachedAlertRow(
      alert: alert,
      updatedAt: (row["updated_at"] as num?)?.toInt() ?? 0,
      deleted: _intToBool(row["deleted"]),
    );
  }

  CachedProfileRow _mapCachedProfileRow(Map<String, Object?> row) {
    final profile = UserProfile(
      name: (row["name"] ?? "").toString(),
      role: (row["role"] ?? "").toString(),
      phone: (row["phone"] ?? "").toString(),
      location: (row["location"] ?? "").toString(),
      email: (row["email"] ?? "").toString(),
      membership: (row["membership"] ?? "").toString(),
      totalCattle: (row["total_cattle"] as num?)?.toInt() ?? 0,
      totalScans: (row["total_scans"] as num?)?.toInt() ?? 0,
      totalAlerts: (row["total_alerts"] as num?)?.toInt() ?? 0,
    );
    return CachedProfileRow(
      user: profile,
      updatedAt: (row["updated_at"] as num?)?.toInt() ?? 0,
    );
  }

  SyncQueueItem _mapSyncQueueItem(Map<String, Object?> row) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode((row["payload"] ?? "{}").toString())
          as Map<String, dynamic>;
    } catch (_) {
      payload = <String, dynamic>{};
    }

    return SyncQueueItem(
      id: (row["id"] as num?)?.toInt() ?? 0,
      entityType: (row["entity_type"] ?? "").toString(),
      action: (row["action"] ?? "").toString(),
      payload: payload,
      createdAt: (row["created_at"] as num?)?.toInt() ?? 0,
    );
  }

  int _boolToInt(bool value) => value ? 1 : 0;

  bool _intToBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return false;
  }

  void _ensureFactoryForDesktop() {
    if (_factoryReady || kIsWeb) {
      return;
    }

    final platform = defaultTargetPlatform;
    final isDesktop = platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;

    if (isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _factoryReady = true;
  }

  List<double> _l2Normalize(List<double> vector) {
    if (vector.isEmpty) {
      return const <double>[];
    }
    final sanitized = vector
        .map((v) => v.isFinite ? v : 0.0)
        .toList(growable: false);
    var sum = 0.0;
    for (final v in sanitized) {
      sum += v * v;
    }
    if (!sum.isFinite || sum <= 0) {
      return const <double>[];
    }
    final norm = math.sqrt(sum);
    if (!norm.isFinite || norm <= 0) {
      return const <double>[];
    }
    return sanitized
        .map((v) => (v / norm).isFinite ? (v / norm) : 0.0)
        .toList(growable: false);
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) {
      return -1.0;
    }
    var dot = 0.0;
    for (var i = 0; i < a.length; i += 1) {
      dot += a[i] * b[i];
    }
    return dot;
  }
}
