import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/network_diagnostic_tool.dart';

class NetworkDiagnosticScreen extends StatelessWidget {
  const NetworkDiagnosticScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tool = context.watch<NetworkDiagnosticTool>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity 3: Network Diagnostic')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHealthBanner(theme, tool),
            const SizedBox(height: 12),
            _buildPhaseCard(theme, tool),
            const SizedBox(height: 16),
            _buildResultsSection(theme, tool),
            const SizedBox(height: 16),
            _buildControls(theme, tool),
            const SizedBox(height: 24),
            _buildLogSection(theme, tool),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthBanner(ThemeData theme, NetworkDiagnosticTool tool) {
    final health = tool.health;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: health.containerColor(theme.brightness),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(health.icon, size: 44, color: health.color(theme.brightness)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection Health',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  health.label,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: health.color(theme.brightness),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  health.description,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                tool.isOnline ? Icons.wifi : Icons.cloud_off,
                size: 18,
                color: tool.isOnline
                    ? Colors.green
                    : theme.colorScheme.error,
              ),
              const SizedBox(height: 4),
              Text(
                tool.isOnline ? tool.interfaceLabel : 'OFFLINE',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (tool.isRunning)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${tool.phaseLabel} ${(tool.phaseProgress * 100).round()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseCard(ThemeData theme, NetworkDiagnosticTool tool) {
    final active = tool.isRunning && tool.currentPhase != null;
    final phaseIcon = switch (tool.currentPhase) {
      DiagnosticPhase.idle => Icons.timer_outlined,
      DiagnosticPhase.download => Icons.cloud_download_outlined,
      DiagnosticPhase.upload => Icons.cloud_upload_outlined,
      null => Icons.hourglass_empty,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(phaseIcon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool.isRunning && tool.currentPhase != null
                      ? tool.phaseLabel
                      : 'Diagnostic tool is idle',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: active
                      ? tool.phaseProgress
                      : tool.completedRuns > 0
                          ? 1
                          : 0,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          if (active)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                '${tool.currentMbps.toStringAsFixed(1)} Mbps',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(ThemeData theme, NetworkDiagnosticTool tool) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Diagnostic Results',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _ResultCard(
          icon: Icons.timer_outlined,
          title: 'Idle Ping',
          value: _fmtPing(tool.idlePingMs),
          subtitle: 'Baseline latency (ms)',
          progress: tool.currentPhase == DiagnosticPhase.idle
              ? tool.phaseProgress
              : null,
        ),
        const SizedBox(height: 8),
        _ResultCard(
          icon: Icons.cloud_download_outlined,
          title: 'Download Bandwidth',
          value: tool.downloadMbps.toStringAsFixed(1),
          unit: 'Mbps',
          subtitle: 'Concurrent ping '
              '${_fmtPing(tool.downloadPingMs)}',
          progress: tool.currentPhase == DiagnosticPhase.download
              ? tool.phaseProgress
              : null,
        ),
        const SizedBox(height: 8),
        _ResultCard(
          icon: Icons.cloud_upload_outlined,
          title: 'Upload Bandwidth',
          value: tool.uploadMbps.toStringAsFixed(1),
          unit: 'Mbps',
          subtitle: 'Upload ping ${_fmtPing(tool.uploadPingMs)}',
          progress: tool.currentPhase == DiagnosticPhase.upload
              ? tool.phaseProgress
              : null,
        ),
        const SizedBox(height: 8),
        _ResultCard(
          icon: Icons.signal_cellular_alt,
          title: 'Packet Loss',
          value: '${tool.packetLossPercent.toStringAsFixed(1)}%',
          subtitle: 'idle samples lost',
          progress: null,
        ),
      ],
    );
  }

  Widget _buildControls(ThemeData theme, NetworkDiagnosticTool tool) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: tool.isRunning ? null : tool.runTest,
            icon: const Icon(Icons.play_arrow),
            label: Text(tool.isRunning
                ? 'Testing...'
                : 'Run Diagnostic Test'),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          tooltip: tool.autoEnabled
              ? 'Stop automatic re-testing'
              : 'Re-test automatically every 30s',
          onPressed: tool.autoEnabled
              ? tool.stopAuto
              : (tool.isRunning ? null : tool.startAuto),
          icon: Icon(
            tool.autoEnabled ? Icons.radar : Icons.radar_outlined,
            color: tool.autoEnabled ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  Widget _buildLogSection(ThemeData theme, NetworkDiagnosticTool tool) {
    final events = tool.log;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Diagnostic Log',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          Text(
            'No tests yet. Tap "Run Diagnostic Test" to start the '
            'idle, download, and upload sequence.',
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

  String _fmtPing(double ms) =>
      ms >= 9999 ? '—' : '${ms.toStringAsFixed(1)} ms';
}

class _ResultCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? unit;
  final String subtitle;
  final double? progress;

  const _ResultCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.unit,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 28, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (unit != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          unit!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (progress != null)
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    )
                  else
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}