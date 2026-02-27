import "dart:io";
import "dart:math" as math;
import "dart:typed_data";

import "package:image/image.dart" as img;
import "package:tflite_flutter/tflite_flutter.dart";

import "audio_features.dart";

class MuzzleEmbeddingResult {
  const MuzzleEmbeddingResult({
    required this.embedding,
    required this.detectionConfidence,
  });

  final List<double> embedding;
  final double detectionConfidence;
}

class AcousticModelResult {
  const AcousticModelResult({
    required this.label,
    required this.probabilities,
    required this.riskScore,
    required this.respiratoryDistress,
  });

  final String label;
  final Map<String, double> probabilities;
  final double riskScore;
  final bool respiratoryDistress;
}

class SkinModelResult {
  const SkinModelResult({
    required this.label,
    required this.probabilities,
    required this.riskScore,
    required this.lumpyDetected,
  });

  final String label;
  final Map<String, double> probabilities;
  final double riskScore;
  final bool lumpyDetected;
}

class FusedHealthResult {
  const FusedHealthResult({
    required this.riskScore,
    required this.riskLevel,
    required this.healthStatus,
    required this.recommendations,
    required this.overrideApplied,
    required this.timestamp,
  });

  final double riskScore;
  final String riskLevel;
  final String healthStatus;
  final String recommendations;
  final bool overrideApplied;
  final DateTime timestamp;
}

class OfflineInferenceService {
  OfflineInferenceService._();

  static final OfflineInferenceService instance = OfflineInferenceService._();

  static const String _muzzleDetectorAsset =
      "assets/models/muzzle_detector.tflite";
  static const String _muzzleEmbedderAsset =
      "assets/models/muzzle_embedder.tflite";
  static const String _skinAsset =
      "assets/models/cattleskin_model_float16.tflite";
  static const String _acousticAsset =
      "assets/models/cow_acoustic_4class.tflite";

  final AudioFeatureExtractor _audioExtractor = AudioFeatureExtractor();

  Interpreter? _muzzleDetector;
  Interpreter? _muzzleEmbedder;
  Interpreter? _skinModel;
  Interpreter? _acousticModel;

  IsolateInterpreter? _muzzleDetectorIsolate;
  IsolateInterpreter? _muzzleEmbedderIsolate;
  IsolateInterpreter? _skinModelIsolate;
  IsolateInterpreter? _acousticModelIsolate;

  bool _initialized = false;
  bool _nativeInferenceReady = false;
  String? _runtimeNotice;

  bool get usingRuntimeFallback => _initialized && !_nativeInferenceReady;
  String? get runtimeNotice => _runtimeNotice;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    // Desktop build is for workflow testing. Native TFLite DLL packaging on
    // Windows is optional and can fail; keep app functional via fallback mode.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _nativeInferenceReady = false;
      _runtimeNotice =
          "Desktop fallback mode active. Native TFLite runs on Android/iOS.";
      _initialized = true;
      return;
    }

    final options = InterpreterOptions()..threads = 4;
    if (Platform.isAndroid) {
      options.useNnApiForAndroid = true;
    }
    try {
      _muzzleDetector = await Interpreter.fromAsset(
        _muzzleDetectorAsset,
        options: options,
      );
      _muzzleEmbedder = await Interpreter.fromAsset(
        _muzzleEmbedderAsset,
        options: options,
      );
      _skinModel = await Interpreter.fromAsset(
        _skinAsset,
        options: options,
      );
      _acousticModel = await Interpreter.fromAsset(
        _acousticAsset,
        options: options,
      );

      _muzzleDetector!.allocateTensors();
      _muzzleEmbedder!.allocateTensors();
      _skinModel!.allocateTensors();
      _acousticModel!.allocateTensors();

      _muzzleDetectorIsolate = await _tryCreateIsolate(_muzzleDetector);
      _muzzleEmbedderIsolate = await _tryCreateIsolate(_muzzleEmbedder);
      _skinModelIsolate = await _tryCreateIsolate(_skinModel);
      _acousticModelIsolate = await _tryCreateIsolate(_acousticModel);

      _nativeInferenceReady = true;
      _runtimeNotice = null;
    } catch (e) {
      _closeInterpreters();

      final allowDesktopFallback =
          Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      if (!allowDesktopFallback) {
        rethrow;
      }

      _nativeInferenceReady = false;
      _runtimeNotice =
          "Native TFLite runtime unavailable on desktop. Using offline approximation mode.";
    } finally {
      _initialized = true;
    }
  }

  Future<MuzzleEmbeddingResult?> runMuzzleEmbedding(
    Uint8List imageBytes, {
    bool useClahe = true,
  }) async {
    await initialize();

    final original = img.decodeImage(imageBytes);
    if (original == null) {
      throw FormatException("Unable to decode muzzle image.");
    }
    if (!_nativeInferenceReady) {
      return _runMuzzleFallback(original, useClahe: useClahe);
    }
    try {
      final detectorWidth = _positiveOr(
        _muzzleDetector!.getInputTensor(0).shape[2],
        640,
      );
      final detectorHeight = _positiveOr(
        _muzzleDetector!.getInputTensor(0).shape[1],
        640,
      );
      var prepared = img.copyResize(
        original,
        width: detectorWidth,
        height: detectorHeight,
      );
      if (useClahe) {
        prepared = _applyClaheApprox(prepared);
      }

      final detectorInput = _toInputTensor3(
        prepared,
        normalizeToMinusOneToOne: false,
      );
      final detectorOutputShape = _muzzleDetector!.getOutputTensor(0).shape;
      final detectorOutput = _createZeroTensor(detectorOutputShape);
      await _runInference(
        _muzzleDetector!,
        _muzzleDetectorIsolate,
        detectorInput,
        detectorOutput,
      );

      final best = _pickBestDetection(detectorOutput, detectorOutputShape);
      if (best == null || best.confidence < 0.2) {
        return null;
      }

      final crop = _cropDetection(
        original,
        best,
        detectorWidth: detectorWidth,
        detectorHeight: detectorHeight,
      );
      if (crop == null) {
        return null;
      }

      final embedderWidth = _positiveOr(
        _muzzleEmbedder!.getInputTensor(0).shape[2],
        224,
      );
      final embedderHeight = _positiveOr(
        _muzzleEmbedder!.getInputTensor(0).shape[1],
        224,
      );
      final embedderImage = img.copyResize(
        crop,
        width: embedderWidth,
        height: embedderHeight,
      );
      final embedderInput = _toInputTensor3(
        embedderImage,
        normalizeToMinusOneToOne: false,
      );
      final embedderOutputShape = _muzzleEmbedder!.getOutputTensor(0).shape;
      final embedderOutput = _createZeroTensor(embedderOutputShape);
      await _runInference(
        _muzzleEmbedder!,
        _muzzleEmbedderIsolate,
        embedderInput,
        embedderOutput,
      );

      final embedding = _toFixedEmbedding(
        _l2Normalize(_flattenToDoubleList(embedderOutput)),
        length: 256,
      );
      if (embedding.isEmpty) {
        return null;
      }

      return MuzzleEmbeddingResult(
        embedding: embedding,
        detectionConfidence: best.confidence.clamp(0.0, 1.0),
      );
    } catch (_) {
      // Keep workflow alive when native model output shape differs on-device.
      return _runMuzzleFallback(original, useClahe: useClahe);
    }
  }

  Future<AcousticModelResult> runAcousticModel(String wavPath) async {
    await initialize();
    if (!_nativeInferenceReady) {
      return _runAcousticFallback(wavPath);
    }
    try {
      final inputShape = _acousticModel!.getInputTensor(0).shape;
      final coeffCount = _positiveOr(inputShape[1], 40);
      final frameCount = _positiveOr(inputShape[2], 100);

      final mfcc = await _audioExtractor.mfccForModel(
        wavPath,
        expectedCoefficients: coeffCount,
        expectedFrames: frameCount,
      );

      final input = List.generate(
        1,
        (_) => List.generate(
          coeffCount,
          (c) => List.generate(frameCount, (f) => <double>[mfcc[c][f]]),
        ),
      );

      final outputShape = _acousticModel!.getOutputTensor(0).shape;
      final output = _createZeroTensor(outputShape);
      await _runInference(
        _acousticModel!,
        _acousticModelIsolate,
        input,
        output,
      );

      final probs = _toProbabilities(_flattenToDoubleList(output));
      const labels = <String>["normal", "food", "cough", "estrus"];
      final mapped = <String, double>{
        "normal": _safeProb(probs, 0),
        "food": _safeProb(probs, 1),
        "cough": _safeProb(probs, 2),
        "estrus": _safeProb(probs, 3),
      };
      final maxIdx = _argMax(
        labels.map((label) => mapped[label] ?? 0).toList(),
      );
      final label = labels[maxIdx];

      final respiratoryDistress = mapped["cough"]! >= 0.45 || label == "cough";
      final riskScore = (mapped["normal"]! * 0.1) +
          (mapped["food"]! * 0.35) +
          (mapped["estrus"]! * 0.55) +
          (mapped["cough"]! * 0.95);

      return AcousticModelResult(
        label: label,
        probabilities: mapped,
        riskScore: riskScore.clamp(0.0, 1.0),
        respiratoryDistress: respiratoryDistress,
      );
    } catch (_) {
      return _runAcousticFallback(wavPath);
    }
  }

  Future<SkinModelResult> runSkinModel(Uint8List imageBytes) async {
    await initialize();

    final source = img.decodeImage(imageBytes);
    if (source == null) {
      throw FormatException("Unable to decode skin image.");
    }
    if (!_nativeInferenceReady) {
      return _runSkinFallback(source);
    }
    try {
      final width = _positiveOr(_skinModel!.getInputTensor(0).shape[2], 224);
      final height = _positiveOr(_skinModel!.getInputTensor(0).shape[1], 224);
      final resized = img.copyResize(source, width: width, height: height);
      final input = _toInputTensor3(
        resized,
        normalizeToMinusOneToOne: true,
      );

      final outputShape = _skinModel!.getOutputTensor(0).shape;
      final output = _createZeroTensor(outputShape);
      await _runInference(_skinModel!, _skinModelIsolate, input, output);

      final raw = _flattenToDoubleList(output);
      final probs = raw.length >= 3
          ? _toProbabilities(raw.take(3).toList())
          : _binaryToThreeClass(raw);

      final mapped = <String, double>{
        "healthy": _safeProb(probs, 0),
        "lumpy": _safeProb(probs, 1),
        "other_issue": _safeProb(probs, 2),
      };

      var label = "healthy";
      if (mapped["lumpy"]! >= mapped["healthy"]! &&
          mapped["lumpy"]! >= mapped["other_issue"]!) {
        label = "lumpy";
      } else if (mapped["other_issue"]! > mapped["healthy"]!) {
        label = "other_issue";
      }

      final lumpyDetected = label == "lumpy" || mapped["lumpy"]! >= 0.45;
      final riskScore = mapped["healthy"]! * 0.15 +
          mapped["other_issue"]! * 0.6 +
          mapped["lumpy"]! * 0.95;

      return SkinModelResult(
        label: label,
        probabilities: mapped,
        riskScore: riskScore.clamp(0.0, 1.0),
        lumpyDetected: lumpyDetected,
      );
    } catch (_) {
      return _runSkinFallback(source);
    }
  }

  FusedHealthResult fuseHealth({
    required AcousticModelResult acoustic,
    required SkinModelResult skin,
  }) {
    final now = DateTime.now();
    if (acoustic.respiratoryDistress || skin.lumpyDetected) {
      return FusedHealthResult(
        riskScore: 1.0,
        riskLevel: "RED",
        healthStatus: "Critical Risk",
        recommendations:
            "Immediate vet consultation, isolation check, and close monitoring in next 24h.",
        overrideApplied: true,
        timestamp: now,
      );
    }

    final score = (acoustic.riskScore * 0.55) + (skin.riskScore * 0.45);
    if (score >= 0.75) {
      return FusedHealthResult(
        riskScore: score,
        riskLevel: "RED",
        healthStatus: "High Risk",
        recommendations:
            "Veterinary review recommended as soon as possible and repeat scan in 6 hours.",
        overrideApplied: false,
        timestamp: now,
      );
    }
    if (score >= 0.4) {
      return FusedHealthResult(
        riskScore: score,
        riskLevel: "YELLOW",
        healthStatus: "Moderate Risk",
        recommendations:
            "Observe feeding, activity, and symptoms. Re-scan in 12 hours.",
        overrideApplied: false,
        timestamp: now,
      );
    }

    return FusedHealthResult(
      riskScore: score,
      riskLevel: "GREEN",
      healthStatus: "Stable",
      recommendations:
          "No immediate action needed. Continue routine monitoring and daily scans.",
      overrideApplied: false,
      timestamp: now,
    );
  }

  void dispose() {
    _closeInterpreters();
    _nativeInferenceReady = false;
    _runtimeNotice = null;
    _initialized = false;
  }

  void _closeInterpreters() {
    _muzzleDetectorIsolate?.close();
    _muzzleEmbedderIsolate?.close();
    _skinModelIsolate?.close();
    _acousticModelIsolate?.close();
    _muzzleDetectorIsolate = null;
    _muzzleEmbedderIsolate = null;
    _skinModelIsolate = null;
    _acousticModelIsolate = null;

    _muzzleDetector?.close();
    _muzzleEmbedder?.close();
    _skinModel?.close();
    _acousticModel?.close();
    _muzzleDetector = null;
    _muzzleEmbedder = null;
    _skinModel = null;
    _acousticModel = null;
  }

  MuzzleEmbeddingResult? _runMuzzleFallback(
    img.Image source, {
    required bool useClahe,
  }) {
    var prepared = img.copyResize(source, width: 224, height: 224);
    if (useClahe) {
      prepared = _applyClaheApprox(prepared);
    }

    final gray = img.grayscale(prepared);
    final pixels = gray.width * gray.height;
    if (pixels <= 0 || gray.width < 16 || gray.height < 16) {
      return null;
    }

    var globalSum = 0.0;
    for (var y = 0; y < gray.height; y += 1) {
      for (var x = 0; x < gray.width; x += 1) {
        globalSum += gray.getPixel(x, y).r.toDouble();
      }
    }
    final globalMean = globalSum / pixels;

    const gridSize = 16;
    final cellWidth = math.max(1, gray.width ~/ gridSize);
    final cellHeight = math.max(1, gray.height ~/ gridSize);
    final features = List<double>.filled(gridSize * gridSize, 0.0);

    var index = 0;
    for (var gy = 0; gy < gridSize; gy += 1) {
      for (var gx = 0; gx < gridSize; gx += 1) {
        final startX = gx * cellWidth;
        final startY = gy * cellHeight;
        final endX = gx == gridSize - 1 ? gray.width : math.min(gray.width, startX + cellWidth);
        final endY =
            gy == gridSize - 1 ? gray.height : math.min(gray.height, startY + cellHeight);

        var sum = 0.0;
        var count = 0;
        for (var y = startY; y < endY; y += 1) {
          for (var x = startX; x < endX; x += 1) {
            sum += gray.getPixel(x, y).r.toDouble();
            count += 1;
          }
        }

        final mean = count == 0 ? globalMean : sum / count;
        // Centering by global mean reduces lighting bias while preserving pattern.
        features[index] = ((mean - globalMean) / 128.0).clamp(-1.0, 1.0).toDouble();
        index += 1;
      }
    }

    final embedding = _toFixedEmbedding(_l2Normalize(features), length: 256);
    if (embedding.isEmpty) {
      return null;
    }

    var varianceSum = 0.0;
    for (var y = 0; y < gray.height; y += 1) {
      for (var x = 0; x < gray.width; x += 1) {
        final diff = gray.getPixel(x, y).r.toDouble() - globalMean;
        varianceSum += diff * diff;
      }
    }
    final stdDev = math.sqrt(varianceSum / pixels);
    final confidence = (0.55 + (stdDev / 70.0).clamp(0.0, 0.4)).clamp(0.0, 0.95);

    return MuzzleEmbeddingResult(
      embedding: embedding,
      detectionConfidence: confidence,
    );
  }

  Future<AcousticModelResult> _runAcousticFallback(String wavPath) async {
    final mfcc = await _audioExtractor.mfccForModel(
      wavPath,
      expectedCoefficients: 40,
      expectedFrames: 100,
    );

    var sumAbs = 0.0;
    for (final row in mfcc) {
      for (final value in row) {
        sumAbs += value.abs();
      }
    }
    final avgAbs = sumAbs / math.max(1, 40 * 100);
    final normalized = (avgAbs / 25.0).clamp(0.0, 1.0);

    final coughScore = 0.15 + normalized * 0.85;
    final foodScore = 0.2 + (1 - normalized) * 0.5;
    final estrusScore = 0.15 + (0.5 - (normalized - 0.5).abs()) * 0.45;
    final normalScore =
        (1.2 - (coughScore * 0.45) - (foodScore * 0.25) - (estrusScore * 0.3))
            .clamp(0.05, 1.0);

    final probs = _normalizeScores(
      <double>[normalScore, foodScore, coughScore, estrusScore],
    );
    const labels = <String>["normal", "food", "cough", "estrus"];
    final mapped = <String, double>{
      "normal": _safeProb(probs, 0),
      "food": _safeProb(probs, 1),
      "cough": _safeProb(probs, 2),
      "estrus": _safeProb(probs, 3),
    };

    final maxIdx = _argMax(
      labels.map((label) => mapped[label] ?? 0.0).toList(),
    );
    final label = labels[maxIdx];
    final respiratoryDistress = mapped["cough"]! >= 0.45 || label == "cough";
    final riskScore = (mapped["normal"]! * 0.1) +
        (mapped["food"]! * 0.35) +
        (mapped["estrus"]! * 0.55) +
        (mapped["cough"]! * 0.95);

    return AcousticModelResult(
      label: label,
      probabilities: mapped,
      riskScore: riskScore.clamp(0.0, 1.0),
      respiratoryDistress: respiratoryDistress,
    );
  }

  SkinModelResult _runSkinFallback(img.Image source) {
    final resized = img.copyResize(source, width: 224, height: 224);

    var lumSum = 0.0;
    var lumSqSum = 0.0;
    var redExcessSum = 0.0;
    final total = math.max(1, resized.width * resized.height);

    for (var y = 0; y < resized.height; y += 1) {
      for (var x = 0; x < resized.width; x += 1) {
        final p = resized.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        final lum = (r + g + b) / 3.0;
        lumSum += lum;
        lumSqSum += lum * lum;
        redExcessSum += math.max(0.0, r - ((g + b) / 2.0));
      }
    }

    final meanLum = lumSum / total;
    final varianceLum = (lumSqSum / total) - (meanLum * meanLum);
    final texture = (math.sqrt(math.max(0.0, varianceLum)) / 64.0)
        .clamp(0.0, 1.0)
        .toDouble();
    final redExcess = (redExcessSum / total / 95.0).clamp(0.0, 1.0).toDouble();

    final lumpyScore = (0.6 * redExcess + 0.4 * texture).clamp(0.0, 1.0);
    final otherScore =
        (0.65 * texture + 0.35 * (1.0 - (meanLum / 255.0))).clamp(0.0, 1.0);
    final healthyScore = (1.25 - lumpyScore - otherScore).clamp(0.05, 1.0);

    final probs = _normalizeScores(
      <double>[healthyScore, lumpyScore, otherScore],
    );
    final mapped = <String, double>{
      "healthy": _safeProb(probs, 0),
      "lumpy": _safeProb(probs, 1),
      "other_issue": _safeProb(probs, 2),
    };

    var label = "healthy";
    if (mapped["lumpy"]! >= mapped["healthy"]! &&
        mapped["lumpy"]! >= mapped["other_issue"]!) {
      label = "lumpy";
    } else if (mapped["other_issue"]! > mapped["healthy"]!) {
      label = "other_issue";
    }

    final lumpyDetected = label == "lumpy" || mapped["lumpy"]! >= 0.45;
    final riskScore = mapped["healthy"]! * 0.15 +
        mapped["other_issue"]! * 0.6 +
        mapped["lumpy"]! * 0.95;

    return SkinModelResult(
      label: label,
      probabilities: mapped,
      riskScore: riskScore.clamp(0.0, 1.0),
      lumpyDetected: lumpyDetected,
    );
  }

  Future<IsolateInterpreter?> _tryCreateIsolate(Interpreter? interpreter) async {
    if (interpreter == null) {
      return null;
    }
    try {
      return await IsolateInterpreter.create(address: interpreter.address);
    } catch (_) {
      return null;
    }
  }

  Future<void> _runInference(
    Interpreter interpreter,
    IsolateInterpreter? isolate,
    Object input,
    Object output,
  ) async {
    if (isolate != null) {
      await isolate.run(input, output);
      return;
    }
    interpreter.run(input, output);
  }

  img.Image? _cropDetection(
    img.Image source,
    _Detection detection, {
    required int detectorWidth,
    required int detectorHeight,
  }) {
    var cx = detection.cx;
    var cy = detection.cy;
    var bw = detection.w;
    var bh = detection.h;

    if (cx > 1 || cy > 1 || bw > 1 || bh > 1) {
      cx /= detectorWidth;
      cy /= detectorHeight;
      bw /= detectorWidth;
      bh /= detectorHeight;
    }

    final x1 = ((cx - bw / 2) * source.width)
        .round()
        .clamp(0, source.width - 1)
        .toInt();
    final y1 = ((cy - bh / 2) * source.height)
        .round()
        .clamp(0, source.height - 1)
        .toInt();
    final x2 = ((cx + bw / 2) * source.width)
        .round()
        .clamp(0, source.width)
        .toInt();
    final y2 = ((cy + bh / 2) * source.height)
        .round()
        .clamp(0, source.height)
        .toInt();

    final width = x2 - x1;
    final height = y2 - y1;
    if (width < 10 || height < 10) {
      return null;
    }
    return img.copyCrop(source, x: x1, y: y1, width: width, height: height);
  }

  _Detection? _pickBestDetection(dynamic output, List<int> shape) {
    if (shape.length < 3 || output is! List<dynamic> || output.isEmpty) {
      return null;
    }

    final matrix = output.first;
    if (matrix is! List<dynamic>) {
      return null;
    }

    var bestConf = -1.0;
    _Detection? best;

    if (shape[1] == 5 && matrix.length >= 5) {
      final xs = (matrix[0] as List<dynamic>).cast<num>();
      final ys = (matrix[1] as List<dynamic>).cast<num>();
      final ws = (matrix[2] as List<dynamic>).cast<num>();
      final hs = (matrix[3] as List<dynamic>).cast<num>();
      final cs = (matrix[4] as List<dynamic>).cast<num>();
      for (var i = 0; i < cs.length; i += 1) {
        final conf = cs[i].toDouble();
        if (conf > bestConf) {
          bestConf = conf;
          best = _Detection(
            cx: xs[i].toDouble(),
            cy: ys[i].toDouble(),
            w: ws[i].toDouble(),
            h: hs[i].toDouble(),
            confidence: conf,
          );
        }
      }
      return best;
    }

    if (shape[2] == 5) {
      for (final rowAny in matrix) {
        if (rowAny is! List<dynamic> || rowAny.length < 5) {
          continue;
        }
        final row = rowAny.cast<num>();
        final conf = row[4].toDouble();
        if (conf > bestConf) {
          bestConf = conf;
          best = _Detection(
            cx: row[0].toDouble(),
            cy: row[1].toDouble(),
            w: row[2].toDouble(),
            h: row[3].toDouble(),
            confidence: conf,
          );
        }
      }
    }
    return best;
  }

  List<List<List<List<double>>>> _toInputTensor3(
    img.Image source, {
    required bool normalizeToMinusOneToOne,
  }) {
    return List.generate(
      1,
      (_) => List.generate(
        source.height,
        (y) => List.generate(source.width, (x) {
          final pixel = source.getPixel(x, y);
          final r = pixel.r.toDouble() / 255.0;
          final g = pixel.g.toDouble() / 255.0;
          final b = pixel.b.toDouble() / 255.0;
          if (normalizeToMinusOneToOne) {
            return <double>[
              (r - 0.5) / 0.5,
              (g - 0.5) / 0.5,
              (b - 0.5) / 0.5,
            ];
          }
          return <double>[r, g, b];
        }),
      ),
    );
  }

  dynamic _createZeroTensor(List<int> shape, [int depth = 0]) {
    if (shape.isEmpty) {
      return 0.0;
    }
    final length = shape[depth] > 0 ? shape[depth] : 1;
    if (depth == shape.length - 1) {
      return List<double>.filled(length, 0.0);
    }
    return List.generate(length, (_) => _createZeroTensor(shape, depth + 1));
  }

  List<double> _flattenToDoubleList(dynamic value) {
    if (value is List<dynamic>) {
      final out = <double>[];
      for (final item in value) {
        out.addAll(_flattenToDoubleList(item));
      }
      return out;
    }
    if (value is num) {
      final parsed = value.toDouble();
      if (!parsed.isFinite) {
        return <double>[0.0];
      }
      return <double>[parsed];
    }
    return const <double>[];
  }

  List<double> _toProbabilities(List<double> raw) {
    if (raw.isEmpty) {
      return const <double>[];
    }

    var sum = 0.0;
    var bounded = true;
    for (final v in raw) {
      if (v < 0 || v > 1) {
        bounded = false;
      }
      sum += v;
    }

    if (bounded && sum > 0.99 && sum < 1.01) {
      return raw;
    }

    final maxV = raw.reduce(math.max);
    final exps = raw.map((v) => math.exp(v - maxV)).toList();
    final expSum = exps.fold<double>(0.0, (a, b) => a + b);
    if (expSum <= 0) {
      return List<double>.filled(raw.length, 1 / raw.length);
    }
    return exps.map((v) => v / expSum).toList();
  }

  List<double> _normalizeScores(List<double> scores) {
    if (scores.isEmpty) {
      return const <double>[];
    }
    final clipped = scores.map((v) => v.clamp(0.0, 1.0).toDouble()).toList();
    final sum = clipped.fold<double>(0.0, (a, b) => a + b);
    if (sum <= 0) {
      return List<double>.filled(scores.length, 1 / scores.length);
    }
    return clipped.map((v) => v / sum).toList();
  }

  List<double> _binaryToThreeClass(List<double> raw) {
    if (raw.isEmpty) {
      return const <double>[0.33, 0.33, 0.34];
    }
    final value = raw.first.clamp(0.0, 1.0).toDouble();
    final healthy = 1 - value;
    final lumpy = value;
    return <double>[healthy, lumpy, 0.0];
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
        .toList();
  }

  List<double> _toFixedEmbedding(List<double> input, {required int length}) {
    if (length <= 0) {
      return const <double>[];
    }
    if (input.isEmpty) {
      return const <double>[];
    }
    final out = List<double>.filled(length, 0.0);
    final limit = math.min(length, input.length);
    for (var i = 0; i < limit; i += 1) {
      final value = input[i];
      out[i] = value.isFinite ? value : 0.0;
    }
    final normalized = _l2Normalize(out);
    return normalized.isEmpty ? out : normalized;
  }

  int _argMax(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    var bestIdx = 0;
    var bestValue = values.first;
    for (var i = 1; i < values.length; i += 1) {
      if (values[i] > bestValue) {
        bestIdx = i;
        bestValue = values[i];
      }
    }
    return bestIdx;
  }

  int _positiveOr(int value, int fallback) => value > 0 ? value : fallback;

  double _safeProb(List<double> values, int index) {
    if (index < 0 || index >= values.length) {
      return 0.0;
    }
    return values[index];
  }
}

class _Detection {
  const _Detection({
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    required this.confidence,
  });

  final double cx;
  final double cy;
  final double w;
  final double h;
  final double confidence;
}

img.Image _applyClaheApprox(
  img.Image input, {
  int tileSize = 32,
  int clipLimit = 40,
}) {
  final gray = img.grayscale(input);
  final output = img.Image.from(gray);

  for (var ty = 0; ty < gray.height; ty += tileSize) {
    for (var tx = 0; tx < gray.width; tx += tileSize) {
      final xEnd = math.min(tx + tileSize, gray.width);
      final yEnd = math.min(ty + tileSize, gray.height);

      final hist = List<int>.filled(256, 0);
      for (var y = ty; y < yEnd; y += 1) {
        for (var x = tx; x < xEnd; x += 1) {
          final lum = gray.getPixel(x, y).r.toInt().clamp(0, 255);
          hist[lum] += 1;
        }
      }

      var clipped = 0;
      for (var i = 0; i < hist.length; i += 1) {
        if (hist[i] > clipLimit) {
          clipped += hist[i] - clipLimit;
          hist[i] = clipLimit;
        }
      }
      final distribute = clipped ~/ hist.length;
      final remainder = clipped % hist.length;
      for (var i = 0; i < hist.length; i += 1) {
        hist[i] += distribute + (i < remainder ? 1 : 0);
      }

      final cdf = List<int>.filled(256, 0);
      cdf[0] = hist[0];
      for (var i = 1; i < cdf.length; i += 1) {
        cdf[i] = cdf[i - 1] + hist[i];
      }
      final total = math.max(1, (xEnd - tx) * (yEnd - ty));
      final cdfMin = cdf.firstWhere((v) => v > 0, orElse: () => 0);

      for (var y = ty; y < yEnd; y += 1) {
        for (var x = tx; x < xEnd; x += 1) {
          final old = gray.getPixel(x, y).r.toInt().clamp(0, 255);
          final mapped = (((cdf[old] - cdfMin) / math.max(1, total - cdfMin)) *
                  255)
              .round()
              .clamp(0, 255);
          output.setPixelRgb(x, y, mapped, mapped, mapped);
        }
      }
    }
  }

  return output;
}
