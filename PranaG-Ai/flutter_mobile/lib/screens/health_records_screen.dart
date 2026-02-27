import "package:flutter/material.dart";

import "../services/storage/local_health_db.dart";
import "../theme/app_colors.dart";

class HealthRecordsScreen extends StatefulWidget {
  const HealthRecordsScreen({super.key});

  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  final LocalHealthDb _db = LocalHealthDb.instance;
  bool _loading = true;
  String? _error;
  List<HealthLogRecord> _logs = const <HealthLogRecord>[];
  Map<String, CowRecord> _cowById = const <String, CowRecord>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _db.initialize();
      final cows = await _db.getAllCows();
      final logs = await _db.getHealthLogs();
      if (!mounted) {
        return;
      }
      setState(() {
        _cowById = {for (final cow in cows) cow.cowId: cow};
        _logs = logs;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = "Failed to load records: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Health Records"),
        backgroundColor: AppColors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  )
                : _logs.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text(
                              "No health logs yet.",
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final cow = _cowById[log.cowId];
                          return _LogCard(log: log, cow: cow);
                        },
                      ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.log,
    required this.cow,
  });

  final HealthLogRecord log;
  final CowRecord? cow;

  @override
  Widget build(BuildContext context) {
    final riskColor = switch (log.riskLevel) {
      "RED" => AppColors.danger,
      "YELLOW" => AppColors.warning,
      _ => AppColors.success,
    };

    String two(int v) => v.toString().padLeft(2, "0");
    final ts = log.timestamp;
    final timestamp =
        "${ts.year}-${two(ts.month)}-${two(ts.day)} ${two(ts.hour)}:${two(ts.minute)}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cow == null ? log.cowId : "${cow!.name} (${log.cowId})",
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  log.riskLevel,
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Health: ${log.healthStatus}",
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Text(
            "Risk Score: ${(log.riskScore * 100).toStringAsFixed(1)}%",
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Text(
            "Acoustic: ${(log.acousticResult["label"] ?? "-").toString()}",
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Text(
            "Skin: ${(log.skinResult["label"] ?? "-").toString()}",
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            log.recommendations,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            "Timestamp: $timestamp",
            style: const TextStyle(color: AppColors.textLight, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
