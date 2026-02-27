import "dart:io";
import "dart:math" as math;
import "dart:typed_data";

class AudioFeatureExtractor {
  static const int targetSampleRate = 16000;
  static const int minDurationSeconds = 3;
  static const int maxDurationSeconds = 5;
  static const int minSamples = targetSampleRate * minDurationSeconds;
  static const int maxSamples = targetSampleRate * maxDurationSeconds;

  static const int fftSize = 512;
  static const int hopLength = 160;
  static const int melBins = 40;
  static const int mfccCount = 40;
  static const double epsilon = 1e-10;

  Future<List<List<double>>> mfccForModel(
    String wavPath, {
    int expectedCoefficients = 40,
    int expectedFrames = 100,
  }) async {
    final wav = await _loadWav(wavPath);
    var samples = wav.samples;

    if (wav.sampleRate != targetSampleRate) {
      samples = _resampleLinear(
        samples,
        sourceRate: wav.sampleRate,
        targetRate: targetSampleRate,
      );
    }

    samples = _fitLength(samples);
    final melSpectrogram = _logMelSpectrogram(samples);
    final mfcc = _dct2(melSpectrogram, coeffCount: mfccCount);

    final coeffTarget =
        expectedCoefficients > 0 ? expectedCoefficients : mfccCount;
    final frameTarget = expectedFrames > 0 ? expectedFrames : 100;
    return _fitShape(mfcc, coeffTarget: coeffTarget, frameTarget: frameTarget);
  }

  Future<_WavData> _loadWav(String path) async {
    final bytes = await File(path).readAsBytes();
    final data = ByteData.sublistView(bytes);
    if (!_matchesTag(bytes, 0, "RIFF") || !_matchesTag(bytes, 8, "WAVE")) {
      throw FormatException("Unsupported WAV container.");
    }

    var fmtChunkOffset = -1;
    var fmtChunkSize = 0;
    var dataChunkOffset = -1;
    var dataChunkSize = 0;

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      final chunkDataOffset = offset + 8;
      final chunkEnd = chunkDataOffset + chunkSize;
      if (chunkEnd > bytes.length) {
        break;
      }

      if (_matchesTag(bytes, offset, "fmt ")) {
        fmtChunkOffset = chunkDataOffset;
        fmtChunkSize = chunkSize;
      } else if (_matchesTag(bytes, offset, "data")) {
        dataChunkOffset = chunkDataOffset;
        dataChunkSize = chunkSize;
      }

      offset = chunkEnd + (chunkSize.isOdd ? 1 : 0);
    }

    if (fmtChunkOffset < 0 || dataChunkOffset < 0 || fmtChunkSize < 16) {
      throw FormatException("Missing WAV fmt/data chunks.");
    }

    final audioFormat = data.getUint16(fmtChunkOffset, Endian.little);
    final channels = data.getUint16(fmtChunkOffset + 2, Endian.little);
    final sampleRate = data.getUint32(fmtChunkOffset + 4, Endian.little);
    final bitsPerSample = data.getUint16(fmtChunkOffset + 14, Endian.little);
    final bytesPerSample = bitsPerSample ~/ 8;
    final frameBytes = channels * bytesPerSample;

    if (channels <= 0 || bytesPerSample <= 0 || frameBytes <= 0) {
      throw FormatException("Invalid WAV format.");
    }
    if (audioFormat != 1 && audioFormat != 3) {
      throw FormatException("Only PCM or IEEE float WAV is supported.");
    }

    final frameCount = dataChunkSize ~/ frameBytes;
    final samples = List<double>.filled(frameCount, 0.0);

    for (var frame = 0; frame < frameCount; frame += 1) {
      var mono = 0.0;
      final frameOffset = dataChunkOffset + frame * frameBytes;
      for (var ch = 0; ch < channels; ch += 1) {
        final sampleOffset = frameOffset + ch * bytesPerSample;
        mono += _readSample(
          data,
          sampleOffset,
          bitsPerSample: bitsPerSample,
          audioFormat: audioFormat,
        );
      }
      samples[frame] = mono / channels;
    }

    return _WavData(sampleRate: sampleRate, samples: samples);
  }

  bool _matchesTag(Uint8List bytes, int offset, String tag) {
    if (offset + 4 > bytes.length) {
      return false;
    }
    return bytes[offset] == tag.codeUnitAt(0) &&
        bytes[offset + 1] == tag.codeUnitAt(1) &&
        bytes[offset + 2] == tag.codeUnitAt(2) &&
        bytes[offset + 3] == tag.codeUnitAt(3);
  }

  double _readSample(
    ByteData data,
    int offset, {
    required int bitsPerSample,
    required int audioFormat,
  }) {
    if (audioFormat == 3 && bitsPerSample == 32) {
      return data
          .getFloat32(offset, Endian.little)
          .clamp(-1.0, 1.0)
          .toDouble();
    }

    switch (bitsPerSample) {
      case 8:
        return ((data.getUint8(offset) - 128) / 128.0)
            .clamp(-1.0, 1.0)
            .toDouble();
      case 16:
        return (data.getInt16(offset, Endian.little) / 32768.0)
            .clamp(-1.0, 1.0)
            .toDouble();
      case 24:
        final b0 = data.getUint8(offset);
        final b1 = data.getUint8(offset + 1);
        final b2 = data.getUint8(offset + 2);
        var value = b0 | (b1 << 8) | (b2 << 16);
        if ((value & 0x00800000) != 0) {
          value |= ~0x00FFFFFF;
        }
        return (value / 8388608.0).clamp(-1.0, 1.0).toDouble();
      case 32:
        return (data.getInt32(offset, Endian.little) / 2147483648.0)
            .clamp(-1.0, 1.0)
            .toDouble();
      default:
        throw FormatException("Unsupported WAV bit depth: $bitsPerSample");
    }
  }

  List<double> _resampleLinear(
    List<double> input, {
    required int sourceRate,
    required int targetRate,
  }) {
    if (input.isEmpty || sourceRate <= 0 || targetRate <= 0) {
      return List<double>.filled(minSamples, 0.0);
    }
    if (sourceRate == targetRate) {
      return List<double>.from(input);
    }

    final targetLength = (input.length * targetRate / sourceRate).round();
    final output = List<double>.filled(targetLength, 0.0);
    final scale = sourceRate / targetRate;

    for (var i = 0; i < targetLength; i += 1) {
      final src = i * scale;
      final left = src.floor().clamp(0, input.length - 1).toInt();
      final right = (left + 1).clamp(0, input.length - 1).toInt();
      final t = src - left;
      output[i] = input[left] * (1 - t) + input[right] * t;
    }
    return output;
  }

  List<double> _fitLength(List<double> samples) {
    if (samples.length < minSamples) {
      return <double>[...samples, ...List<double>.filled(minSamples - samples.length, 0.0)];
    }
    if (samples.length > maxSamples) {
      return samples.sublist(0, maxSamples);
    }
    return samples;
  }

  List<List<double>> _logMelSpectrogram(List<double> samples) {
    final frameCount = ((samples.length - fftSize) ~/ hopLength) + 1;
    final effectiveFrames = frameCount > 0 ? frameCount : 1;
    final hann = _hannWindow(fftSize);
    final melFilter = _melFilterBank(
      melBinCount: melBins,
      fftBinCount: fftSize ~/ 2 + 1,
      sampleRate: targetSampleRate,
      fftSize: fftSize,
    );

    final mel = List<List<double>>.generate(
      melBins,
      (_) => List<double>.filled(effectiveFrames, epsilon),
    );

    for (var frameIndex = 0; frameIndex < effectiveFrames; frameIndex += 1) {
      final start = frameIndex * hopLength;
      final frame = List<double>.filled(fftSize, 0.0);
      for (var i = 0; i < fftSize; i += 1) {
        final src = start + i;
        if (src < samples.length) {
          frame[i] = samples[src] * hann[i];
        }
      }

      final power = _fftPower(frame);
      for (var m = 0; m < melBins; m += 1) {
        var value = 0.0;
        for (var k = 0; k < melFilter[m].length; k += 1) {
          value += melFilter[m][k] * power[k];
        }
        mel[m][frameIndex] = math.log(value + epsilon);
      }
    }
    return mel;
  }

  List<List<double>> _dct2(
    List<List<double>> logMel, {
    required int coeffCount,
  }) {
    final bins = logMel.length;
    final frames = logMel.isEmpty ? 0 : logMel.first.length;
    final targetCoeff = coeffCount > 0 ? coeffCount : bins;
    final mfcc = List<List<double>>.generate(
      targetCoeff,
      (_) => List<double>.filled(frames, 0.0),
    );

    for (var t = 0; t < frames; t += 1) {
      for (var c = 0; c < targetCoeff; c += 1) {
        var sum = 0.0;
        for (var n = 0; n < bins; n += 1) {
          sum += logMel[n][t] *
              math.cos((math.pi / bins) * (n + 0.5) * c);
        }
        mfcc[c][t] = sum;
      }
    }
    return mfcc;
  }

  List<List<double>> _fitShape(
    List<List<double>> mfcc, {
    required int coeffTarget,
    required int frameTarget,
  }) {
    final coeffCurrent = mfcc.length;
    final frameCurrent = mfcc.isEmpty ? 0 : mfcc.first.length;

    final normalized = List<List<double>>.generate(
      coeffTarget,
      (c) => List<double>.generate(frameTarget, (f) {
        final srcC = c < coeffCurrent ? c : coeffCurrent - 1;
        final srcF = f < frameCurrent ? f : frameCurrent - 1;
        if (coeffCurrent == 0 || frameCurrent == 0) {
          return 0.0;
        }
        return mfcc[srcC][srcF];
      }),
    );

    return _zScoreNormalize(normalized);
  }

  List<List<double>> _zScoreNormalize(List<List<double>> mfcc) {
    var sum = 0.0;
    var count = 0;
    for (final row in mfcc) {
      for (final value in row) {
        sum += value;
        count += 1;
      }
    }

    if (count == 0) {
      return mfcc;
    }

    final mean = sum / count;
    var variance = 0.0;
    for (final row in mfcc) {
      for (final value in row) {
        final d = value - mean;
        variance += d * d;
      }
    }
    final std = math.sqrt(variance / count);
    final safeStd = std < epsilon ? 1.0 : std;

    return mfcc
        .map((row) => row.map((v) => (v - mean) / safeStd).toList())
        .toList();
  }

  List<double> _hannWindow(int size) {
    if (size <= 1) {
      return const <double>[1.0];
    }
    return List<double>.generate(
      size,
      (i) => 0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1)),
    );
  }

  List<double> _fftPower(List<double> frame) {
    final n = frame.length;
    final real = List<double>.from(frame);
    final imag = List<double>.filled(n, 0.0);

    var j = 0;
    for (var i = 1; i < n; i += 1) {
      var bit = n >> 1;
      while (j >= bit && bit > 0) {
        j -= bit;
        bit >>= 1;
      }
      j += bit;
      if (i < j) {
        final tr = real[i];
        real[i] = real[j];
        real[j] = tr;
        final ti = imag[i];
        imag[i] = imag[j];
        imag[j] = ti;
      }
    }

    for (var len = 2; len <= n; len <<= 1) {
      final angle = -2 * math.pi / len;
      final half = len >> 1;
      for (var i = 0; i < n; i += len) {
        for (var k = 0; k < half; k += 1) {
          final wr = math.cos(angle * k);
          final wi = math.sin(angle * k);
          final i0 = i + k;
          final i1 = i0 + half;
          final tr = real[i1] * wr - imag[i1] * wi;
          final ti = real[i1] * wi + imag[i1] * wr;
          real[i1] = real[i0] - tr;
          imag[i1] = imag[i0] - ti;
          real[i0] += tr;
          imag[i0] += ti;
        }
      }
    }

    final bins = n ~/ 2 + 1;
    final power = List<double>.filled(bins, 0.0);
    for (var i = 0; i < bins; i += 1) {
      power[i] = real[i] * real[i] + imag[i] * imag[i];
    }
    return power;
  }

  List<List<double>> _melFilterBank({
    required int melBinCount,
    required int fftBinCount,
    required int sampleRate,
    required int fftSize,
  }) {
    final melMin = _hzToMel(0);
    final melMax = _hzToMel(sampleRate / 2);

    final melPoints = List<double>.generate(
      melBinCount + 2,
      (i) => melMin + (melMax - melMin) * i / (melBinCount + 1),
    );
    final hzPoints = melPoints.map(_melToHz).toList();
    final binPoints = hzPoints
        .map((hz) => (((fftSize + 1) * hz) / sampleRate).floor())
        .toList();

    final bank = List<List<double>>.generate(
      melBinCount,
      (_) => List<double>.filled(fftBinCount, 0.0),
    );

    for (var m = 1; m <= melBinCount; m += 1) {
      final left = binPoints[m - 1].clamp(0, fftBinCount - 1).toInt();
      final center = binPoints[m].clamp(0, fftBinCount - 1).toInt();
      final right = binPoints[m + 1].clamp(0, fftBinCount - 1).toInt();

      final riseDen = (center - left).toDouble();
      final fallDen = (right - center).toDouble();
      if (riseDen > 0) {
        for (var k = left; k <= center && k < fftBinCount; k += 1) {
          bank[m - 1][k] = (k - left) / riseDen;
        }
      }
      if (fallDen > 0) {
        for (var k = center; k <= right && k < fftBinCount; k += 1) {
          bank[m - 1][k] = (right - k) / fallDen;
        }
      }
    }
    return bank;
  }

  double _hzToMel(num hz) => 2595.0 * math.log(1 + hz / 700.0) / math.ln10;

  double _melToHz(double mel) =>
      (700.0 * (math.pow(10, mel / 2595.0) - 1)).toDouble();
}

class _WavData {
  const _WavData({
    required this.sampleRate,
    required this.samples,
  });

  final int sampleRate;
  final List<double> samples;
}
