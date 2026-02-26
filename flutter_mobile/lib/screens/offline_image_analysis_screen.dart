import "dart:io";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../services/inference/offline_inference_service.dart";
import "../services/storage/local_health_db.dart";
import "../state/app_state.dart";
import "../theme/app_colors.dart";
import "health_records_screen.dart";

enum _AnalysisModel { skin, muzzle }

class OfflineImageAnalysisScreen extends StatefulWidget {
  const OfflineImageAnalysisScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<OfflineImageAnalysisScreen> createState() =>
      _OfflineImageAnalysisScreenState();
}

class _OfflineImageAnalysisScreenState extends State<OfflineImageAnalysisScreen> {
  final LocalHealthDb _db = LocalHealthDb.instance;
  final OfflineInferenceService _inference = OfflineInferenceService.instance;
  final ImagePicker _picker = ImagePicker();

  _AnalysisModel _model = _AnalysisModel.skin;
  XFile? _image;
  String? _pickedFileName;
  String? _selectedCowId;
  List<CowRecord> _cows = const <CowRecord>[];
  bool _loading = true;
  bool _running = false;
  String? _error;
  String? _summary;

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
      await _inference.initialize();
      final cows = await _db.getAllCows();
      if (!mounted) {
        return;
      }
      setState(() {
        _cows = cows;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = "Failed to load resources: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) {
      return;
    }
    setState(() {
      _image = image;
      _pickedFileName = image.name;
      _summary = null;
      _error = null;
    });
  }

  Future<void> _pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>["jpg", "jpeg", "png", "webp"],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) {
      return;
    }
    setState(() {
      _image = XFile(path);
      _pickedFileName = result!.files.single.name;
      _summary = null;
      _error = null;
    });
  }

  Future<void> _runAnalysis() async {
    if (_loading || _running) {
      return;
    }
    if (_image == null) {
      setState(() {
        _error = "Please select stored image first.";
      });
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _summary = null;
    });

    try {
      final bytes = await _image!.readAsBytes();

      if (_model == _AnalysisModel.skin) {
        final skin = await _inference.runSkinModel(bytes);
        final acousticPlaceholder = AcousticModelResult(
          label: "normal",
          probabilities: const <String, double>{
            "normal": 1.0,
            "food": 0.0,
            "cough": 0.0,
            "estrus": 0.0,
          },
          riskScore: 0.1,
          respiratoryDistress: false,
        );
        final fused = _inference.fuseHealth(
          acoustic: acousticPlaceholder,
          skin: skin,
        );

        final cowId = _selectedCowId ?? (_cows.isNotEmpty ? _cows.first.cowId : null);
        if (cowId == null) {
          setState(() {
            _error = "No cow found. Register a cow from workflow first.";
          });
          return;
        }

        await _db.insertHealthLog(
          cowId: cowId,
          acousticResult: <String, dynamic>{
            "label": "normal",
            "note": "offline_image_analysis_skin_only",
          },
          skinResult: <String, dynamic>{
            "label": skin.label,
            "probabilities": skin.probabilities,
            "risk_score": skin.riskScore,
          },
          riskScore: fused.riskScore,
          riskLevel: fused.riskLevel,
          healthStatus: fused.healthStatus,
          recommendations: fused.recommendations,
          timestamp: fused.timestamp,
        );

        widget.appState.incrementScanCount();
        if (fused.riskLevel != "GREEN") {
          final cow = _cows.where((c) => c.cowId == cowId).firstOrNull;
          widget.appState.createAlert(
            cattleName: cow?.name ?? cowId,
            cattleBreed: cow?.breed ?? "Unknown",
            type: fused.riskLevel == "RED" ? "critical" : "warning",
            title: "Offline Skin Analysis ${fused.riskLevel}",
            description: fused.recommendations,
            actionRequired: true,
          );
        }

        if (!mounted) {
          return;
        }
        setState(() {
          _summary =
              "Skin analysis complete. ${fused.healthStatus} (${fused.riskLevel}) log saved.";
        });
        return;
      }

      final embeddingResult = await _inference.runMuzzleEmbedding(bytes);
      if (embeddingResult == null) {
        setState(() {
          _error = "Muzzle not detected in selected image.";
        });
        return;
      }

      final match = await _db.findBestMatch(
        embeddingResult.embedding,
        acceptThreshold: 0.82,
      );
      final cowId = match?.cow.cowId ?? _selectedCowId;
      if (cowId == null) {
        setState(() {
          _error = "No matching cow found. Select cow for log append.";
        });
        return;
      }

      final similarity = match?.similarity ?? 0.0;
      final matched = match != null;
      final level = matched ? "GREEN" : "YELLOW";

      await _db.insertHealthLog(
        cowId: cowId,
        acousticResult: <String, dynamic>{
          "label": "muzzle_only",
          "matched": matched,
          "similarity": similarity,
        },
        skinResult: const <String, dynamic>{
          "label": "not_run",
        },
        riskScore: matched ? 0.1 : 0.5,
        riskLevel: level,
        healthStatus: matched ? "Muzzle Verified" : "Muzzle Uncertain",
        recommendations: matched
            ? "Cow identity verified from stored image."
            : "Identity uncertain. Capture fresh muzzle image.",
      );

      widget.appState.incrementScanCount();
      if (!matched) {
        final cow = _cows.where((c) => c.cowId == cowId).firstOrNull;
        widget.appState.createAlert(
          cattleName: cow?.name ?? cowId,
          cattleBreed: cow?.breed ?? "Unknown",
          type: "warning",
          title: "Muzzle verification uncertain",
          description: "Stored image verification below threshold.",
          actionRequired: true,
        );
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _summary =
            "Muzzle analysis complete. ${matched ? "Matched" : "Unmatched"} log appended.";
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = "Offline image analysis failed: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  Future<void> _openRecords() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const HealthRecordsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Offline Image Analysis"),
        backgroundColor: AppColors.white,
        actions: [
          IconButton(
            onPressed: _openRecords,
            icon: const Icon(Icons.history),
            tooltip: "Open Records",
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModelSelector(),
                  const SizedBox(height: 12),
                  _buildCowSelector(),
                  const SizedBox(height: 12),
                  _buildImagePicker(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _running ? null : _runAnalysis,
                      icon: const Icon(Icons.analytics),
                      label: const Text("Run Analysis"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                      ),
                    ),
                  ),
                  if (_running) ...[
                    const SizedBox(height: 12),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  if (_summary != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _summary!,
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildModelSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Model",
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<_AnalysisModel>(
            segments: const [
              ButtonSegment<_AnalysisModel>(
                value: _AnalysisModel.skin,
                label: Text("Skin"),
                icon: Icon(Icons.health_and_safety),
              ),
              ButtonSegment<_AnalysisModel>(
                value: _AnalysisModel.muzzle,
                label: Text("Muzzle"),
                icon: Icon(Icons.fingerprint),
              ),
            ],
            selected: {_model},
            onSelectionChanged: (set) {
              setState(() {
                _model = set.first;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCowSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedCowId,
        decoration: const InputDecoration(
          labelText: "Target Cow (optional for muzzle match)",
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: _cows
            .map(
              (cow) => DropdownMenuItem<String>(
                value: cow.cowId,
                child: Text("${cow.name} (${cow.cowId})"),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedCowId = value;
          });
        },
      ),
    );
  }

  Widget _buildImagePicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _pickedFileName ?? "No image selected",
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _running ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo),
                  label: const Text("Gallery"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _running ? null : _pickFromFiles,
                  icon: const Icon(Icons.folder_open),
                  label: const Text("Files"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
          if (_image != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(_image!.path),
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
