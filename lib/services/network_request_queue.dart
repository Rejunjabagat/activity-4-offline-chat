import 'dart:async';

import 'package:flutter/foundation.dart';

enum RequestStatus { queued, active, done }

class NetworkRequest {
  final String id;
  final double totalMb;
  double _doneMb = 0;
  RequestStatus status = RequestStatus.queued;

  NetworkRequest({required this.id, required this.totalMb});

  double get doneMb => _doneMb;
  double get remainingMb => totalMb - _doneMb;

  double get progress => (_doneMb / totalMb).clamp(0.0, 1.0);

  bool get isComplete => _doneMb >= totalMb;

  void addProgress(double mb) {
    _doneMb = (_doneMb + mb).clamp(0.0, totalMb);
  }
}

class RequestQueue extends ChangeNotifier {
  RequestQueue({bool online = false}) : _online = online;

  static const double _chunkMb = 2.5;
  static const Duration _tick = Duration(milliseconds: 500);

  final List<NetworkRequest> _requests = [];
  final List<String> _events = [];
  bool _online;
  bool _baseline = true;
  String _lastInterface = 'Unknown';
  Timer? _timer;
  int _counter = 0;

  bool get isOnline => _online;
  String get lastInterface => _lastInterface;
  List<NetworkRequest> get requests => List.unmodifiable(_requests);
  List<String> get events => List.unmodifiable(_events);

  int get queuedCount =>
      _requests.where((r) => r.status == RequestStatus.queued).length;
  int get activeCount =>
      _requests.where((r) => r.status == RequestStatus.active).length;
  int get doneCount =>
      _requests.where((r) => r.status == RequestStatus.done).length;

  void start() {
    _timer ??= Timer.periodic(_tick, (_) => _tickProcessor());
  }

  void addRequest() {
    _counter++;
    final request = NetworkRequest(
      id: 'R$_counter',
      totalMb: 50,
    );
    _requests.add(request);
    _log('Added ${request.id} (50 MB) to the queue.');
    _startTransmission(request);
    notifyListeners();
  }

  void setOnline(bool value, {String? interface}) {
    final prevOnline = _online;
    final prevInterface = _lastInterface;

    if (interface != null && interface.isNotEmpty) {
      _lastInterface = interface;
    }

    if (_baseline) {
      _baseline = false;
      _online = value;
      if (value) _startTransmission();
      notifyListeners();
      return;
    }

    _online = value;

    if (prevOnline && !value) {
      _interruptActiveRequest();
      _log('Connection lost (now $_lastInterface). Active request paused and queued.');
    } else if (!prevOnline && value) {
      _log('Connection restored ($_lastInterface). Resuming queued requests...');
    } else if (prevOnline &&
        value &&
        interface != null &&
        _lastInterface != prevInterface) {
      _log('Handover: switched to $_lastInterface without dropping the connection.');
    }

    if (value) _startTransmission();

    notifyListeners();
  }

  void clearLog() {
    _events.clear();
    notifyListeners();
  }

  void _startTransmission([NetworkRequest? preferred]) {
    if (!_online) return;

    final anyActive =
        _requests.any((r) => r.status == RequestStatus.active);
    if (anyActive) return;

    final candidates =
        preferred == null ? _requests : [preferred, ..._requests];
    for (final request in candidates) {
      if (request.status == RequestStatus.queued) {
        request.status = RequestStatus.active;
        _log('${request.id} is transmitting over $_lastInterface...');
        notifyListeners();
        return;
      }
    }
  }

  void _interruptActiveRequest() {
    for (final request in _requests) {
      if (request.status == RequestStatus.active) {
        request.status = RequestStatus.queued;
      }
    }
  }

  void _tickProcessor() {
    if (!_online) return;

    NetworkRequest? active;
    for (final request in _requests) {
      if (request.status == RequestStatus.active) {
        active = request;
        break;
      }
    }

    if (active == null) {
      final next =
          _requests.where((r) => r.status == RequestStatus.queued).firstOrNull;
      if (next != null) {
        next.status = RequestStatus.active;
        _log('${next.id} is transmitting over $_lastInterface...');
        next.addProgress(_chunkMb);
        if (next.isComplete) _complete(next);
        notifyListeners();
      }
      return;
    }

    active.addProgress(_chunkMb);
    if (active.isComplete) {
      _complete(active);
    }
    notifyListeners();
  }

  void _complete(NetworkRequest request) {
    request.status = RequestStatus.done;
    _log('${request.id} completed (${request.totalMb.toStringAsFixed(0)} MB).');
    _startTransmission();
  }

  void _log(String message) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    _events.insert(0, '[$stamp] $message');
    if (_events.length > 60) {
      _events.removeRange(60, _events.length);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}