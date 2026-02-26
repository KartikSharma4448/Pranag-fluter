import "dart:convert";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:path/path.dart" as path;
import "package:sqflite_common_ffi/sqflite_ffi.dart";

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
  static const int _dbVersion = 1;
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
      },
    );
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
