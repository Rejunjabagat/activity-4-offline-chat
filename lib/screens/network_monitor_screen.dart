import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../services/network_request_queue.dart';

class NetworkMonitorScreen extends StatefulWidget {
  const NetworkMonitorScreen({super.key});

  @override
  State<NetworkMonitorScreen> createState() => _NetworkMonitorScreenState();
}

class _NetworkMonitorScreenState extends State<NetworkMonitorScreen> {
  late final RequestQueue _queue;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = false;
  String _interfaceLabel = 'Detecting...';

  @override
  void initState() {
    super.initState();
    _queue = RequestQueue(online: false);
    _queue.addListener(_onQueueUpdate);
    _queue.start();
    _subscribeConnectivity();
  }

  Future<void> _subscribeConnectivity() async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    _applyConnectivity(results);

    _subscription = connectivity.onConnectivityChanged.listen(_applyConnectivity);
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    if (!mounted) return;

    final online =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    final label = _describe(results);

    setState(() {
      _isOnline = online;
      _interfaceLabel = label;
    });

    _queue.setOnline(online, interface: label);
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

  void _onQueueUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _queue.removeListener(_onQueueUpdate);
    _queue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity 2: Network Monitor')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(theme),
            const SizedBox(height: 16),
            _buildActiveCard(theme),
            const SizedBox(height: 24),
            _buildQueueSection(theme),
            const SizedBox(height: 24),
            _buildLogSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    final color = _isOnline ? Colors.green : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isOnline
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            _isOnline ? Icons.wifi_tethering : Icons.cloud_off,
            size: 44,
            color: _isOnline
                ? theme.colorScheme.primary
                : theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Network',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _isOnline
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _interfaceLabel,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Icon(
                Icons.circle,
                size: 14,
                color: _isOnline
                    ? Colors.green
                    : theme.colorScheme.error,
              ),
              const SizedBox(height: 4),
              Text(
                _isOnline ? 'LIVE' : 'OFFLINE',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _isOnline ? color : theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(ThemeData theme) {
    final active = _queue.requests.firstWhere(
      (r) => r.status == RequestStatus.active,
      orElse: () => NetworkRequest(id: '', totalMb: 1),
    );

    if (active.id.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _queue.queuedCount > 0
                    ? '${_queue.queuedCount} queued request'
                        '${_queue.queuedCount == 1 ? '' : 's'} waiting '
                        'for a connection...'
                    : 'No active transfer. Press "Start download".',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_vert_circle, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'ACTIVE TRANSFER',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${active.remainingMb.toStringAsFixed(1)} MB left',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: active.progress,
            borderRadius: BorderRadius.circular(8),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '${active.id} over ${_queue.lastInterface}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildQueueSection(ThemeData theme) {
    final requests = _queue.requests;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Request Queue',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_queue.queuedCount > 0)
              Chip(
                label: Text('${_queue.queuedCount} queued'),
                visualDensity: VisualDensity.compact,
              ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _queue.addRequest,
              icon: const Icon(Icons.download),
              label: const Text('Start download'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (requests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Tap "Start download" to simulate a long-running request.\n'
              'Toggle Wi-Fi off while it runs to see it queue and auto-resume.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Column(
            children: [
              for (final request in requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildRequestTile(theme, request),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildRequestTile(ThemeData theme, NetworkRequest request) {
    final (icon, iconColor, statusText) = switch (request.status) {
      RequestStatus.active => (
          Icons.cloud_download_outlined,
          Colors.blue,
          'Transmitting over ${_queue.lastInterface}...',
        ),
      RequestStatus.queued => (
          Icons.pause_circle_outline,
          theme.colorScheme.onSurfaceVariant,
          'Queued - waiting for a stable connection...',
        ),
      RequestStatus.done => (
          Icons.check_circle_outline,
          Colors.green,
          'Completed',
        ),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text('${request.id} - ${request.totalMb.toStringAsFixed(0)} MB'),
        subtitle: Text(
          statusText,
          style: TextStyle(
            color: request.status == RequestStatus.queued
                ? theme.colorScheme.onSurfaceVariant
                : null,
          ),
        ),
        trailing: request.status == RequestStatus.done
            ? const Icon(Icons.done)
            : Text(
                '${request.doneMb.toStringAsFixed(1)} / ${request.totalMb.toStringAsFixed(0)} MB',
                style: theme.textTheme.bodySmall,
              ),
      ),
    );
  }

  Widget _buildLogSection(ThemeData theme) {
    final events = _queue.events;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Activity Log',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: events.isEmpty ? null : _queue.clearLog,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          Text(
            'No events yet. Handovers and queue recoveries will appear here.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final event in events.take(30))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      event,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}