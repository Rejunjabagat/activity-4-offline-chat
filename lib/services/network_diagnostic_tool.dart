import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'connection_health.dart';

enum DiagnosticPhase { idle, download, upload }

class _NetworkProfile {
  final double idlePingMs;
  final double idleJitterMs;
  final double packetLossPercent;
  final double downloadMbps;
  final double downloadPingMs;
  final double uploadMbps;
  final double uploadPingMs;

  const _NetworkProfile({
    required this.idlePingMs,
    required this.idleJitterMs,
    required this.packetLossPercent,
    required this.downloadMbps,
    required this.downloadPingMs,
    required this.uploadMbps,
    required this.uploadPingMs,
  });
}

class NetworkDiagnosticTool extends ChangeNotifier {
  NetworkDiagnosticTool({
    Duration autoInterval = const Duration(seconds: 30),
    math.Random? random,
  })  : _autoInterval = autoInterval,
        _random = random ?? math.Random();

  // Profiles are cycled per run so a demo naturally shows multiple health
  // tiers: Excellent, Fair, Poor, Degraded.
  static const List<_NetworkProfile> _profiles = [
    _NetworkProfile(
      idlePingMs: 24,
      idleJitterMs: 3,
      packetLossPercent: 0.4,
      downloadMbps: 58,
      downloadPingMs: 28,
      uploadMbps: 22,
      uploadPingMs: 35,
    ),
    _NetworkProfile(
      idlePingMs: 18,
      idleJitterMs: 4,
      packetLossPercent: 0.3,
      downloadMbps: 82,
      downloadPingMs: 22,
      uploadMbps: 30,
      uploadPingMs: 30,
    ),
    _NetworkProfile(
      idlePingMs: 45,
      idleJitterMs: 8,
      packetLossPercent: 0.6,
      downloadMbps: 12,
      downloadPingMs: 52,
      uploadMbps: 5,
      uploadPingMs: 60,
    ),
    _NetworkProfile(
      idlePingMs: 52,
      idleJitterMs: 12,
      packetLossPercent: 1.5,
      downloadMbps: 7,
      downloadPingMs: 68,
      uploadMbps: 3,
      uploadPingMs: 80,
    ),
    _NetworkProfile(
      idlePingMs: 70,
      idleJitterMs: 15,
      packetLossPercent: 2.2,
      downloadMbps: 3.6,
      downloadPingMs: 95,
      uploadMbps: 1.6,
      uploadPingMs: 110,
    ),
    _NetworkProfile(
      idlePingMs: 120,
      idleJitterMs: 25,
      packetLossPercent: 4.5,
      downloadMbps: 1.6,
      downloadPingMs: 160,
      uploadMbps: 0.7,
      uploadPingMs: 190,
    ),
    _NetworkProfile(
      idlePingMs: 900,
      idleJitterMs: 200,
      packetLossPercent: 42,
      downloadMbps: 0.4,
      downloadPingMs: 1050,
      uploadMbps: 0.2,
      uploadPingMs: 1200,
    ),
  ];

  static const int _idleSamples = 4;
  static const Duration _idleInterval = Duration(milliseconds: 180);
  static const double _downloadTotalMb = 40.0;
  static const int _downloadSteps = 18;
  static const Duration _downloadTick = Duration(milliseconds: 140);
  static const double _uploadTotalMb = 12.0;
  static const int _uploadSteps = 12;
  static const Duration _uploadTick = Duration(milliseconds: 140);

  final Duration _autoInterval;
  final math.Random _random;

  Timer? _autoTimer;
  Timer? _ticker;
  bool _disposed = false;

  bool _isRunning = false;
  bool _isOnline = true;
  String _interfaceLabel = 'Simulated Wi-Fi';
  DiagnosticPhase? _currentPhase;
  double _phaseProgress = 0;
  double _currentMbps = 0;

  double _idlePingMs = 0;
  double _downloadMbps = 0;
  double _downloadPingMs = 0;
  double _uploadMbps = 0;
  double _uploadPingMs = 0;
  double _packetLossPercent = 0;
  ConnectionHealth _health = ConnectionHealth.poor;
  int _completedRuns = 0;
  final List<String> _logEvents = [];

  bool get isRunning => _isRunning;
  bool get isOnline => _isOnline;
  String get interfaceLabel => _interfaceLabel;
  DiagnosticPhase? get currentPhase => _currentPhase;
  String get phaseLabel => switch (_currentPhase) {
        DiagnosticPhase.idle => 'Idle Ping (Baseline)',
        DiagnosticPhase.download => 'Download Bandwidth',
        DiagnosticPhase.upload => 'Upload Bandwidth',
        null => 'Idle',
      };
  double get phaseProgress => _phaseProgress;
  double get currentMbps => _currentMbps;

  double get idlePingMs => _idlePingMs;
  double get downloadMbps => _downloadMbps;
  double get downloadPingMs => _downloadPingMs;
  double get uploadMbps => _uploadMbps;
  double get uploadPingMs => _uploadPingMs;
  double get packetLossPercent => _packetLossPercent;
  ConnectionHealth get health => _health;
  int get completedRuns => _completedRuns;
  List<String> get log => List.unmodifiable(_logEvents);

  void startAuto() {
    _autoTimer ??= Timer.periodic(_autoInterval, (_) => runTest());
    if (!_isRunning) runTest();
  }

  void stopAuto() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  bool get autoEnabled => _autoTimer != null;

  /// Full multi-step diagnostic cycle:
  /// 1. baseline idle ping
  /// 2. download bandwidth while concurrently measuring ping
  /// 3. upload bandwidth while tracking upload ping
  Future<void> runTest() async {
    if (_isRunning) return;
    _isRunning = true;

    final profile = _profiles[_completedRuns % _profiles.length];

    _log('Starting diagnostic cycle #${_completedRuns + 1} '
        '(idle -> download -> upload)...');
    notifyListeners();

    final online = await _probeConnectivity();
    if (_disposed) return;
    _isOnline = online;

    if (!online) {
      await _runDegradedOfflinePass();
      _finish();
      return;
    }

    await _phaseIdle(profile);
    if (_disposed) return;
    await _phaseDownload(profile);
    if (_disposed) return;
    await _phaseUpload(profile);
    if (_disposed) return;
    _finish();
  }

  void _finish() {
    _health = classifyConnection(
      downloadMbps: _downloadMbps,
      pingMs: _idlePingMs,
      packetLossPercent: _packetLossPercent,
    );
    _completedRuns++;
    _currentPhase = null;
    _phaseProgress = 1;
    _currentMbps = 0;
    _isRunning = false;
    _log('Cycle complete: connection rated ${_health.label} '
        '(${_downloadMbps.toStringAsFixed(1)} Mbps down, '
        '${_idlePingMs.toStringAsFixed(1)} ms ping).');
    notifyListeners();
  }

  Future<bool> _probeConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _interfaceLabel = _describe(results);
      return results.isNotEmpty &&
          !results.contains(ConnectivityResult.none);
    } catch (_) {
      _interfaceLabel = 'Simulated Wi-Fi';
      return true;
    }
  }

  String _describe(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return 'Offline';
    }
    final names = results
        .map((r) => switch (r) {
              ConnectivityResult.wifi => 'Wi-Fi',
              ConnectivityResult.mobile => 'Cellular',
              ConnectivityResult.ethernet => 'Ethernet',
              ConnectivityResult.vpn => 'VPN',
              ConnectivityResult.bluetooth => 'Bluetooth',
              ConnectivityResult.satellite => 'Satellite',
              ConnectivityResult.other => 'Other',
              ConnectivityResult.none => 'Offline',
            })
        .toSet()
        .toList();
    return names.join(' + ');
  }

  Future<void> _phaseIdle(_NetworkProfile p) async {
    _currentPhase = DiagnosticPhase.idle;
    _phaseProgress = 0;
    notifyListeners();

    double sum = 0;
    int lost = 0;
    for (var i = 0; i < _idleSamples; i++) {
      await Future<void>.delayed(_idleInterval);
      if (_disposed) return;
      final dropped = _random.nextDouble() * 100 < p.packetLossPercent;
      if (dropped) {
        lost++;
        _log('Idle ping sample ${i + 1}: timed out (packet loss).');
      } else {
        final sample = _clamp(
            p.idlePingMs + _jitter(p.idleJitterMs), 0.5, 9999);
        sum += sample;
        _log('Idle ping sample ${i + 1}: '
            '${sample.toStringAsFixed(1)} ms');
      }
      _phaseProgress = (i + 1) / _idleSamples;
      notifyListeners();
    }

    final delivered = _idleSamples - lost;
    _idlePingMs = delivered > 0 ? sum / delivered : 9999;
    _packetLossPercent = (lost / _idleSamples) * 100;
    _log('Baseline idle ping: ${_idlePingMs.toStringAsFixed(1)} ms avg, '
        '${_packetLossPercent.toStringAsFixed(1)}% packet loss.');
    notifyListeners();
  }

  Future<void> _phaseDownload(_NetworkProfile p) async {
    _currentPhase = DiagnosticPhase.download;
    _phaseProgress = 0;
    notifyListeners();

    double doneMb = 0;
    double pingSum = 0;
    int pingSamples = 0;

    await _tickLoop(_downloadSteps, _downloadTick, (i, total) {
      final wave =
          0.65 + 0.35 * math.sin((i / total) * math.pi);
      final instantaneous =
          p.downloadMbps * wave * (0.85 + _random.nextDouble() * 0.3);
      final mbThisTick =
          instantaneous * _downloadTick.inMilliseconds / 1000 / 8;
      doneMb = (doneMb + mbThisTick).clamp(0.0, _downloadTotalMb);
      _currentMbps = instantaneous;
      _phaseProgress = doneMb / _downloadTotalMb;

      // Concurrent ping sampling while bandwidth is measured.
      if (i % 3 == 0 &&
          _random.nextDouble() * 100 >= p.packetLossPercent) {
        pingSum += _clamp(p.downloadPingMs + _jitter(8), 0.5, 9999);
        pingSamples++;
      }
      notifyListeners();
    });
    if (_disposed) return;

    final durationSeconds =
        _downloadSteps * _downloadTick.inMilliseconds / 1000;
    _downloadMbps = (_downloadTotalMb / durationSeconds) * 8;
    _downloadPingMs = pingSamples > 0 ? pingSum / pingSamples : 9999;
    _log('Download bandwidth: ${_downloadMbps.toStringAsFixed(1)} Mbps, '
        'concurrent ping ${_downloadPingMs.toStringAsFixed(1)} ms.');
    notifyListeners();
  }

  Future<void> _phaseUpload(_NetworkProfile p) async {
    _currentPhase = DiagnosticPhase.upload;
    _phaseProgress = 0;
    notifyListeners();

    double doneMb = 0;
    double pingSum = 0;
    int pingSamples = 0;

    await _tickLoop(_uploadSteps, _uploadTick, (i, total) {
      final wave = 0.7 + 0.3 * math.sin((i / total) * math.pi);
      final instantaneous =
          p.uploadMbps * wave * (0.85 + _random.nextDouble() * 0.3);
      final mbThisTick =
          instantaneous * _uploadTick.inMilliseconds / 1000 / 8;
      doneMb = (doneMb + mbThisTick).clamp(0.0, _uploadTotalMb);
      _currentMbps = instantaneous;
      _phaseProgress = doneMb / _uploadTotalMb;

      // Upload ping tracked while transmitting.
      if (i % 2 == 0 &&
          _random.nextDouble() * 100 >= p.packetLossPercent) {
        pingSum += _clamp(p.uploadPingMs + _jitter(12), 0.5, 9999);
        pingSamples++;
      }
      notifyListeners();
    });
    if (_disposed) return;

    final durationSeconds =
        _uploadSteps * _uploadTick.inMilliseconds / 1000;
    _uploadMbps = (_uploadTotalMb / durationSeconds) * 8;
    _uploadPingMs = pingSamples > 0 ? pingSum / pingSamples : 9999;
    _log('Upload bandwidth: ${_uploadMbps.toStringAsFixed(1)} Mbps, '
        'upload ping ${_uploadPingMs.toStringAsFixed(1)} ms.');
    notifyListeners();
  }

  Future<void> _runDegradedOfflinePass() async {
    _currentPhase = DiagnosticPhase.idle;
    _phaseProgress = 0;
    _log('No active connection ($_interfaceLabel). '
        'Running degraded pass...');
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (_disposed) return;
    _idlePingMs = 9999;
    _downloadPingMs = 9999;
    _uploadPingMs = 9999;
    _downloadMbps = 0;
    _uploadMbps = 0;
    _packetLossPercent = 100;
    _phaseProgress = 1;
    notifyListeners();
  }

  Future<void> _tickLoop(
    int steps,
    Duration interval,
    void Function(int step, int total) onTick,
  ) async {
    final completer = Completer<void>();
    var step = 0;
    _ticker?.cancel();
    _ticker = Timer.periodic(interval, (timer) {
      if (_disposed) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }
      step++;
      onTick(step, steps);
      if (step >= steps) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }

  double _jitter(double range) =>
      (_random.nextDouble() * 2 - 1) * range;

  double _clamp(double value, double min, double max) =>
      value < min ? min : (value > max ? max : value);

  void _log(String message) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    _logEvents.insert(0, '[$stamp] $message');
    if (_logEvents.length > 80) {
      _logEvents.removeRange(80, _logEvents.length);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _autoTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}