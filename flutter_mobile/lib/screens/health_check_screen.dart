import "dart:io";
import "dart:math";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:path_provider/path_provider.dart";
import "package:record/record.dart";

import "../services/inference/offline_inference_service.dart";
import "../services/storage/local_health_db.dart";
import "../state/app_state.dart";
import "../theme/app_colors.dart";
import "health_records_screen.dart";

enum ScanMode { muzzle, spatial, acoustic }

enum ScanState { idle, capturing, review, processing, acoustic, result }

enum _WorkflowStep { muzzle, skin, acoustic }

class HealthCheckScreen extends StatefulWidget {
  const HealthCheckScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<HealthCheckScreen> createState() => _HealthCheckScreenState();
}

class _HealthCheckScreenState extends State<HealthCheckScreen>
    with SingleTickerProviderStateMixin {
  static const double _acceptThreshold = 0.82;

  final OfflineInferenceService _inference = OfflineInferenceService.instance;
  final LocalHealthDb _db = LocalHealthDb.instance;
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();

  final TextEditingController _nameController = TextEditingController();
  late final AnimationController _pulseController;

  ScanState _scanState = ScanState.idle;
  ScanMode _mode = ScanMode.muzzle;
  _WorkflowStep _step = _WorkflowStep.muzzle;

  bool _ready = false;
  bool _busy = false;
  bool _recording = false;

  XFile? _muzzleImage;
  XFile? _skinImage;
  String? _audioPath;

  CowRecord? _identifiedCow;
  double? _matchConfidence;
  SkinModelResult? _skinResult;

  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _bootstrap();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await Future.wait<void>(<Future<void>>[
        _db.initialize(),
        _inference.initialize(),
      ]);
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result = _errorResult("Initialization failed. Please restart app.");
        _scanState = ScanState.result;
      });
    }
  }

  void _setStep(_WorkflowStep step) {
    _step = step;
    _mode = switch (step) {
      _WorkflowStep.muzzle => ScanMode.muzzle,
      _WorkflowStep.skin => ScanMode.spatial,
      _WorkflowStep.acoustic => ScanMode.acoustic,
    };
  }

  XFile? get _activeImage => _step == _WorkflowStep.muzzle ? _muzzleImage : _skinImage;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _newCowId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return "MZL-${now % 1000}-$now";
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_busy) return;
    final image = await _picker.pickImage(source: source, imageQuality: 92);
    if (image == null || !mounted) return;

    setState(() {
      if (_step == _WorkflowStep.muzzle) {
        _muzzleImage = image;
      } else {
        _skinImage = image;
      }
      _scanState = ScanState.review;
      _result = null;
    });
  }

  Future<void> _submitReview() async {
    if (_busy) return;
    if (_step == _WorkflowStep.muzzle) {
      await _runMuzzleStep();
      return;
    }
    if (_step == _WorkflowStep.skin) {
      await _runSkinStep();
      return;
    }
  }

  Future<void> _runMuzzleStep() async {
    if (!_ready) {
      await _bootstrap();
    }
    if (_muzzleImage == null) {
      setState(() {
        _result = _noMuzzleResult();
        _scanState = ScanState.result;
      });
      return;
    }

    setState(() {
      _busy = true;
      _scanState = ScanState.processing;
    });

    try {
      final bytes = await _muzzleImage!.readAsBytes();
      final embeddingResult = await _inference.runMuzzleEmbedding(
        bytes,
        useClahe: true,
      );

      if (embeddingResult == null) {
        if (!mounted) return;
        setState(() {
          _result = _noMuzzleResult();
          _scanState = ScanState.result;
        });
        return;
      }

      final match = await _db.findBestMatch(
        embeddingResult.embedding,
        acceptThreshold: _inference.usingRuntimeFallback ? 0.985 : _acceptThreshold,
      );

      if (match != null) {
        if (widget.appState.findCattleByMuzzleId(match.cow.cowId) == null) {
          widget.appState.addCattle(
            name: match.cow.name,
            breed: match.cow.breed,
            age: match.cow.age,
            location: match.cow.location,
            healthScore: 80,
            status: "healthy",
            digitalTwinActive: true,
            muzzleId: match.cow.cowId,
          );
        }

        widget.appState.incrementScanCount();

        if (!mounted) return;
        setState(() {
          _identifiedCow = match.cow;
          _matchConfidence = match.similarity;
          _result = null;
          _scanState = ScanState.idle;
          _setStep(_WorkflowStep.skin);
        });
        _showSnack("Existing cattle found. Continue with skin scan.");
        return;
      }

      final form = await _openRegistrationForm(
        initialName: _nameController.text.trim(),
      );
      if (form == null || !mounted) {
        setState(() => _scanState = ScanState.idle);
        return;
      }

      final cowId = _newCowId();
      final record = CowRecord(
        cowId: cowId,
        name: form.name,
        breed: form.breed,
        age: form.age,
        location: form.location,
        embeddingVector: embeddingResult.embedding,
      );

      await _db.upsertCow(record);
      widget.appState.addCattle(
        name: form.name,
        breed: form.breed,
        age: form.age,
        location: form.location,
        healthScore: 80,
        status: "healthy",
        digitalTwinActive: true,
        muzzleId: cowId,
      );
      widget.appState.incrementScanCount();

      if (!mounted) return;
      _showSnack("New cattle registered.");
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint("Muzzle scan error: $e");
      debugPrint("$st");
      if (!mounted) return;
      final details = e.toString();
      setState(() {
        _result = _errorResult(
          "Muzzle scan failed. Please retry with clear image and good lighting.\n$details",
        );
        _scanState = ScanState.result;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _runSkinStep() async {
    if (_identifiedCow == null) {
      setState(() {
        _result = _errorResult("Identify cow first.");
        _scanState = ScanState.result;
      });
      return;
    }
    if (_skinImage == null) {
      setState(() {
        _result = _errorResult("Please capture/select skin image.");
        _scanState = ScanState.result;
      });
      return;
    }

    setState(() {
      _busy = true;
      _scanState = ScanState.processing;
    });

    try {
      final bytes = await _skinImage!.readAsBytes();
      final skin = await _inference.runSkinModel(bytes);
      if (!mounted) return;
      setState(() {
        _skinResult = skin;
        _scanState = ScanState.acoustic;
        _setStep(_WorkflowStep.acoustic);
      });
      _showSnack("Skin scan completed. Run acoustic AI now.");
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result = _errorResult("Skin scan failed. Please retry.");
        _scanState = ScanState.result;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_busy) return;
    try {
      if (_recording) {
        final path = await _recorder.stop();
        if (!mounted) return;
        setState(() {
          _recording = false;
          _audioPath = path;
        });
        return;
      }

      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _showSnack("Microphone permission denied.");
        return;
      }

      final dir = await getTemporaryDirectory();
      final path =
          "${dir.path}${Platform.pathSeparator}acoustic_${DateTime.now().millisecondsSinceEpoch}.wav";

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      if (!mounted) return;
      setState(() {
        _recording = true;
        _audioPath = null;
      });
    } catch (_) {
      _showSnack("Audio recording failed.");
    }
  }

  Future<void> _pickWavFile() async {
    if (_busy || _recording) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>["wav"],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _audioPath = path);
  }

  Future<void> _runAcoustic({required bool skipped}) async {
    if (_busy) return;
    if (_identifiedCow == null || _skinResult == null) {
      _showSnack("Skin scan required before acoustic.");
      return;
    }
    if (!skipped && (_audioPath == null || _audioPath!.isEmpty)) {
      _showSnack("Record/select WAV first, or press skip.");
      return;
    }

    if (_recording) {
      await _recorder.stop();
      if (mounted) {
        setState(() => _recording = false);
      }
    }

    setState(() {
      _busy = true;
      _scanState = ScanState.processing;
    });

    try {
      final acoustic = skipped ? null : await _inference.runAcousticModel(_audioPath!);
      await _finalizeHealthRecord(acoustic: acoustic, skipped: skipped);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result = _errorResult("Acoustic analysis failed.");
        _scanState = ScanState.result;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _finalizeHealthRecord({
    required AcousticModelResult? acoustic,
    required bool skipped,
  }) async {
    final cow = _identifiedCow;
    final skin = _skinResult;
    if (cow == null || skin == null) {
      if (!mounted) return;
      setState(() {
        _result = _errorResult("Unable to create health report.");
        _scanState = ScanState.result;
      });
      return;
    }

    final fused = acoustic == null ? _skinOnlyFusion(skin) : _inference.fuseHealth(acoustic: acoustic, skin: skin);

    await _db.insertHealthLog(
      cowId: cow.cowId,
      acousticResult: <String, dynamic>{
        "label": skipped ? "not_run" : acoustic!.label,
        "probabilities": skipped
            ? const <String, double>{
                "normal": 0,
                "food": 0,
                "cough": 0,
                "estrus": 0,
              }
            : acoustic!.probabilities,
        "risk_score": skipped ? 0.0 : (acoustic?.riskScore ?? 0.0),
        "skipped": skipped,
      },
      skinResult: <String, dynamic>{
        "label": skin.label,
        "probabilities": skin.probabilities,
        "risk_score": skin.riskScore,
        "lumpy_detected": skin.lumpyDetected,
      },
      riskScore: fused.riskScore,
      riskLevel: fused.riskLevel,
      healthStatus: fused.healthStatus,
      recommendations: fused.recommendations,
      timestamp: fused.timestamp,
    );

    final existing = widget.appState.findCattleByMuzzleId(cow.cowId);
    if (existing != null) {
      final score = (100 - (fused.riskScore * 100)).round().clamp(0, 100);
      final status = fused.riskLevel == "RED"
          ? "critical"
          : (fused.riskLevel == "YELLOW" ? "attention" : "healthy");
      widget.appState.updateCattle(
        existing.copyWith(
          healthScore: score,
          status: status,
          alerts: status == "critical" ? 2 : (status == "attention" ? 1 : 0),
          lastScan: "Just now",
        ),
      );
    }

    widget.appState.incrementScanCount();

    if (fused.riskLevel != "GREEN") {
      widget.appState.createAlert(
        cattleName: cow.name,
        cattleBreed: cow.breed,
        type: fused.riskLevel == "RED" ? "critical" : "warning",
        title: "Health Risk ${fused.riskLevel} - ${cow.name}",
        description: fused.recommendations,
        actionRequired: true,
      );
    }

    if (!mounted) return;

    setState(() {
      _result = <String, dynamic>{
        "status": "HEALTH_REPORT",
        "title": "Health Report Ready",
        "message": "Record saved for this muzzle ID.",
        "cowId": cow.cowId,
        "name": cow.name,
        "confidence": _matchConfidence,
        "healthStatus": fused.healthStatus,
        "riskLevel": fused.riskLevel,
        "riskScore": fused.riskScore,
        "recommendations": fused.recommendations,
        "timestamp": _formatDateTime(fused.timestamp),
        "skinLabel": skin.label,
        "acousticLabel": skipped ? "Skipped" : (acoustic?.label ?? "-"),
      };
      _scanState = ScanState.result;
    });
  }

  FusedHealthResult _skinOnlyFusion(SkinModelResult skin) {
    final now = DateTime.now();
    if (skin.lumpyDetected) {
      return FusedHealthResult(
        riskScore: 1.0,
        riskLevel: "RED",
        healthStatus: "Critical Risk",
        recommendations:
            "Lumpy skin indicators found. Acoustic skipped. Immediate veterinary consult advised.",
        overrideApplied: true,
        timestamp: now,
      );
    }

    final score = skin.riskScore.clamp(0.0, 1.0);
    if (score >= 0.75) {
      return FusedHealthResult(
        riskScore: score,
        riskLevel: "RED",
        healthStatus: "High Risk",
        recommendations: "High skin risk detected. Acoustic skipped. Vet review recommended.",
        overrideApplied: false,
        timestamp: now,
      );
    }
    if (score >= 0.4) {
      return FusedHealthResult(
        riskScore: score,
        riskLevel: "YELLOW",
        healthStatus: "Moderate Risk",
        recommendations: "Moderate skin risk. Acoustic skipped. Re-scan within 12 hours.",
        overrideApplied: false,
        timestamp: now,
      );
    }

    return FusedHealthResult(
      riskScore: score,
      riskLevel: "GREEN",
      healthStatus: "Stable",
      recommendations: "Skin appears stable. Continue regular monitoring.",
      overrideApplied: false,
      timestamp: now,
    );
  }

  String _formatDateTime(DateTime dateTime) {
    String two(int v) => v.toString().padLeft(2, "0");
    return "${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)} "
        "${two(dateTime.hour)}:${two(dateTime.minute)}:${two(dateTime.second)}";
  }

  Future<void> _openRecords() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const HealthRecordsScreen(),
      ),
    );
  }

  void _resetAll() {
    setState(() {
      _setStep(_WorkflowStep.muzzle);
      _scanState = ScanState.idle;
      _busy = false;
      _recording = false;
      _muzzleImage = null;
      _skinImage = null;
      _audioPath = null;
      _identifiedCow = null;
      _matchConfidence = null;
      _skinResult = null;
      _result = null;
      _nameController.clear();
    });
  }

  Future<_RegistrationFormData?> _openRegistrationForm({
    required String initialName,
  }) {
    final name = TextEditingController(text: initialName);
    final breed = TextEditingController();
    final age = TextEditingController(text: "3");
    final location = TextEditingController();

    return showModalBottomSheet<_RegistrationFormData>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "New Cattle Registration",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                _RegField(label: "Name", controller: name),
                const SizedBox(height: 10),
                _RegField(label: "Breed", controller: breed),
                const SizedBox(height: 10),
                _RegField(
                  label: "Age",
                  controller: age,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _RegField(label: "Location", controller: location),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final ageValue = int.tryParse(age.text.trim()) ?? 0;
                      if (name.text.trim().isEmpty ||
                          breed.text.trim().isEmpty ||
                          location.text.trim().isEmpty ||
                          ageValue <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("All fields are required.")),
                        );
                        return;
                      }

                      Navigator.of(context).pop(
                        _RegistrationFormData(
                          name: name.text.trim(),
                          breed: breed.text.trim(),
                          age: ageValue,
                          location: location.text.trim(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text("Save"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _noMuzzleResult() {
    return <String, dynamic>{
      "status": "NO_MUZZLE",
      "title": "No Muzzle Detected",
      "message": "The frame does not clearly contain a muzzle. Please retry.",
    };
  }

  Map<String, dynamic> _errorResult(String message) {
    return <String, dynamic>{
      "status": "ERROR",
      "title": "Scan Error",
      "message": message,
    };
  }

  Color _resultColor() {
    if (_result == null) return AppColors.textLight;

    final status = (_result!["status"] ?? "").toString();
    if (status == "HEALTH_REPORT") {
      final level = (_result!["riskLevel"] ?? "").toString();
      if (level == "RED") return AppColors.danger;
      if (level == "YELLOW") return AppColors.warning;
      return AppColors.success;
    }
    if (status == "NO_MUZZLE") return AppColors.warning;
    return AppColors.danger;
  }

  IconData _resultIcon() {
    if (_result == null) return Icons.help_outline;

    final status = (_result!["status"] ?? "").toString();
    if (status == "HEALTH_REPORT") {
      final level = (_result!["riskLevel"] ?? "").toString();
      if (level == "RED") return Icons.warning_rounded;
      if (level == "YELLOW") return Icons.error_outline;
      return Icons.check_circle;
    }
    if (status == "NO_MUZZLE") return Icons.warning_amber_rounded;
    return Icons.error;
  }

  @override
  Widget build(BuildContext context) {
    if (_scanState == ScanState.capturing) return _buildCameraState();
    if (_scanState == ScanState.review) return _buildReviewState();
    if (_scanState == ScanState.acoustic) return _buildAcousticState();
    if (_scanState == ScanState.processing) return _buildProcessingState();
    if (_scanState == ScanState.result && _result != null) {
      return _buildResultState();
    }
    return _buildIdleState();
  }

  Widget _buildIdleState() {
    final frameSize = min<double>(MediaQuery.of(context).size.width - 80, 320.0);
    final title = _step == _WorkflowStep.muzzle ? "Quick Health Check" : "Step 2 - Skin Scan";
    final subtitle = _step == _WorkflowStep.muzzle
        ? "Start with muzzle identification"
        : "Capture cattle skin image";

    final frameTitle = _step == _WorkflowStep.muzzle ? "Muzzle-ID Scanner" : "Skin Scanner";
    final frameSubtitle = _step == _WorkflowStep.muzzle
        ? "Capture cow muzzle for biometric ID"
        : "Capture clear skin patch image";

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, size: 28, color: AppColors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0x99FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.45, end: 1).animate(
                    CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                  ),
                  child: _ScanFrame(
                    size: frameSize,
                    showContent: true,
                    title: frameTitle,
                    subtitle: frameSubtitle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 10,
                children: [
                  _ModeChip(label: "Muzzle-ID", active: _mode == ScanMode.muzzle),
                  _ModeChip(label: "Skin Scan", active: _mode == ScanMode.spatial),
                  _ModeChip(label: "Acoustic", active: _mode == ScanMode.acoustic),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _scanState = ScanState.capturing),
                      icon: const Icon(Icons.camera_alt, size: 24),
                      label: Text(_step == _WorkflowStep.muzzle ? "Open Camera" : "Capture Skin"),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.collections, size: 20, color: AppColors.accent),
                      label: Text(
                        _step == _WorkflowStep.muzzle
                            ? "Upload from Gallery"
                            : "Select Skin from Gallery",
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0x4DFFFFFF)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraState() {
    final title = _step == _WorkflowStep.muzzle ? "Muzzle Scanner" : "Skin Scanner";
    final subtitle = _step == _WorkflowStep.muzzle
        ? "Point camera at cow muzzle"
        : "Point camera at cattle skin patch";

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _scanState = ScanState.idle),
                    child: const Icon(Icons.arrow_back, color: AppColors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 12, color: Color(0x99FFFFFF)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF101A30),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.camera_alt, color: Color(0x44FFFFFF), size: 96),
                    _ScanFrame(size: min<double>(MediaQuery.of(context).size.width - 80, 320.0)),
                    const Positioned(
                      bottom: 36,
                      child: Text(
                        "Align target within frame",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.white,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Center(
                child: InkWell(
                  onTap: () => _pickImage(ImageSource.camera),
                  borderRadius: BorderRadius.circular(36),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 4),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewState() {
    final image = _activeImage;
    final isMuzzle = _step == _WorkflowStep.muzzle;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _scanState = ScanState.idle),
                    child: const Icon(Icons.arrow_back, color: AppColors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMuzzle ? "Confirm Scan" : "Confirm Skin Scan",
                          style: const TextStyle(
                            fontSize: 17,
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          isMuzzle ? "Review and submit" : "Review skin image",
                          style: const TextStyle(fontSize: 12, color: Color(0x99FFFFFF)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: min<double>(MediaQuery.of(context).size.width - 80, 320.0),
                      height: min<double>(MediaQuery.of(context).size.width - 80, 320.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2A2A3E), Color(0xFF111A30)],
                        ),
                      ),
                      child: image == null
                          ? const Icon(Icons.image, size: 68, color: Color(0x66FFFFFF))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(File(image.path), fit: BoxFit.cover),
                            ),
                    ),
                    const SizedBox(height: 20),
                    if (isMuzzle) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Cow Name (optional)",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: AppColors.white),
                        decoration: InputDecoration(
                          hintText: "e.g. Ganga, Laxmi...",
                          hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
                          filled: true,
                          fillColor: const Color(0x1AFFFFFF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0x33FFFFFF)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0x33FFFFFF)),
                          ),
                        ),
                      ),
                    ] else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x14FFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                        child: const Text(
                          "After skin scan, Acoustic AI step will start.",
                          style: TextStyle(fontSize: 12, color: Color(0xB3FFFFFF)),
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitReview,
                        icon: const Icon(Icons.analytics, size: 22),
                        label: Text(isMuzzle ? "Analyze Muzzle" : "Analyze Skin"),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcousticState() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _setStep(_WorkflowStep.skin);
                        _scanState = ScanState.idle;
                      });
                    },
                    child: const Icon(Icons.arrow_back, color: AppColors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Acoustic AI",
                      style: TextStyle(
                        fontSize: 17,
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RowText(label: "Cow ID", value: _identifiedCow?.cowId ?? "-"),
                    _RowText(label: "Skin Result", value: _skinResult?.label ?? "-"),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x33FFFFFF)),
                      ),
                      child: Text(
                        _audioPath == null
                            ? "No audio selected"
                            : _audioPath!.split(Platform.pathSeparator).last,
                        style: const TextStyle(color: AppColors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _toggleRecording,
                            icon: Icon(_recording ? Icons.stop : Icons.mic),
                            label: Text(_recording ? "Stop" : "Record"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _recording ? AppColors.danger : AppColors.primary,
                              foregroundColor: AppColors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickWavFile,
                            icon: const Icon(Icons.upload_file),
                            label: const Text("Select WAV"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _runAcoustic(skipped: false),
                        icon: const Icon(Icons.graphic_eq),
                        label: const Text("Run Acoustic AI"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _runAcoustic(skipped: true),
                        icon: const Icon(Icons.skip_next, color: AppColors.accent),
                        label: const Text(
                          "Skip Acoustic",
                          style: TextStyle(color: AppColors.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingState() {
    final title = _step == _WorkflowStep.muzzle
        ? "Analyzing Muzzle..."
        : (_step == _WorkflowStep.skin ? "Analyzing Skin..." : "Analyzing Acoustic...");

    final subtitle = _step == _WorkflowStep.muzzle
        ? "Running AI detection & embedding"
        : (_step == _WorkflowStep.skin
            ? "Running skin model inference"
            : "Extracting MFCC and running acoustic model");

    final rows = _step == _WorkflowStep.muzzle
        ? const <String>["Muzzle Detection", "Feature Extraction", "Database Matching"]
        : (_step == _WorkflowStep.skin
            ? const <String>["Preprocessing", "Skin Inference", "Risk Scoring"]
            : const <String>["Audio Listening", "MFCC Extraction", "Acoustic Inference"]);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.accent),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Color(0x99FFFFFF)),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < rows.length; i += 1) ...[
                  _StepRow(label: rows[i], active: i == 0),
                  if (i < rows.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultState() {
    final result = _result!;
    final color = _resultColor();
    final isHealth = (result["status"] ?? "") == "HEALTH_REPORT";

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: _resetAll,
                    child: const Icon(Icons.arrow_back, color: AppColors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Scan Result",
                      style: TextStyle(
                        fontSize: 17,
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color),
                      ),
                      child: Column(
                        children: [
                          Icon(_resultIcon(), size: 48, color: color),
                          const SizedBox(height: 12),
                          Text(
                            result["title"].toString(),
                            style: TextStyle(
                              fontSize: 22,
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            result["message"].toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xB3FFFFFF),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          if (result["cowId"] != null)
                            _RowText(label: "Muzzle ID", value: result["cowId"].toString()),
                          if (result["name"] != null)
                            _RowText(label: "Name", value: result["name"].toString()),
                          if (result["confidence"] != null)
                            _RowText(
                              label: "Match Confidence",
                              value:
                                  "${(((result["confidence"] as num).toDouble()) * 100).toStringAsFixed(1)}%",
                            ),
                          if (result["healthStatus"] != null)
                            _RowText(label: "Health Status", value: result["healthStatus"].toString()),
                          if (result["riskLevel"] != null)
                            _RowText(
                              label: "Risk Level",
                              value:
                                  "${result["riskLevel"]} (${(((result["riskScore"] as num?)?.toDouble() ?? 0) * 100).toStringAsFixed(1)}%)",
                            ),
                          if (result["skinLabel"] != null)
                            _RowText(label: "Skin", value: result["skinLabel"].toString()),
                          if (result["acousticLabel"] != null)
                            _RowText(label: "Acoustic", value: result["acousticLabel"].toString()),
                          if (result["recommendations"] != null)
                            _RowText(
                              label: "Recommendations",
                              value: result["recommendations"].toString(),
                            ),
                          if (result["timestamp"] != null)
                            _RowText(label: "Timestamp", value: result["timestamp"].toString()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isHealth ? _openRecords : _resetAll,
                            icon: Icon(isHealth ? Icons.history : Icons.camera_alt, size: 20),
                            label: Text(isHealth ? "View Records" : "Scan Again"),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.home, size: 20),
                            label: const Text("Go Home"),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppColors.accent : const Color(0x4DFFFFFF)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: active ? AppColors.white : const Color(0xB3FFFFFF),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame({
    required this.size,
    this.showContent = false,
    this.title = "Muzzle-ID Scanner",
    this.subtitle = "Capture cow muzzle for biometric ID",
  });

  final double size;
  final bool showContent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent, width: 2),
            ),
          ),
          if (showContent)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fingerprint, size: 56, color: AppColors.accent),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0x80FFFFFF)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (active)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.accent),
          )
        else
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x33FFFFFF), width: 2),
            ),
          ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: active ? AppColors.accent : const Color(0x80FFFFFF)),
        ),
      ],
    );
  }
}

class _RowText extends StatelessWidget {
  const _RowText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegField extends StatelessWidget {
  const _RegField({required this.label, required this.controller, this.keyboardType});

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _RegistrationFormData {
  const _RegistrationFormData({
    required this.name,
    required this.breed,
    required this.age,
    required this.location,
  });

  final String name;
  final String breed;
  final int age;
  final String location;
}
