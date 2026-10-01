import 'package:flutter/material.dart';

enum ConnectionHealth {
  excellent,
  fair,
  poor,
  degraded;

  String get label => switch (this) {
        ConnectionHealth.excellent => 'Excellent',
        ConnectionHealth.fair => 'Fair',
        ConnectionHealth.poor => 'Poor',
        ConnectionHealth.degraded => 'Degraded',
      };

  String get description => switch (this) {
        ConnectionHealth.excellent => 'Fast and stable (>10 Mbps)',
        ConnectionHealth.fair => 'Usable connection (2 - 10 Mbps)',
        ConnectionHealth.poor => 'Slow connection (< 2 Mbps)',
        ConnectionHealth.degraded => 'Heavy packet loss / extreme latency',
      };

  IconData get icon => switch (this) {
        ConnectionHealth.excellent => Icons.speed,
        ConnectionHealth.fair => Icons.network_check,
        ConnectionHealth.poor => Icons.signal_wifi_statusbar_connected_no_internet_4,
        ConnectionHealth.degraded => Icons.error_outline,
      };

  Color color(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      ConnectionHealth.excellent => const Color(0xFF2E7D32),
      ConnectionHealth.fair => _amber,
      ConnectionHealth.poor => _orange,
      ConnectionHealth.degraded => dark ? const Color(0xFFD32F2F) : Colors.deepOrange,
    };
  }

  Color containerColor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      ConnectionHealth.excellent => dark ? const Color(0xFF1B2E1B) : const Color(0xFFD5F5D5),
      ConnectionHealth.fair => dark ? const Color(0xFF2E2A1A) : const Color(0xFFFFF3CD),
      ConnectionHealth.poor => dark ? const Color(0xFF2E211A) : const Color(0xFFFFE0B2),
      ConnectionHealth.degraded => dark ? const Color(0xFF2E1A1A) : const Color(0xFFFFCDD2),
    };
  }
}

const Color _amber = Color(0xFFF9A825);
const Color _orange = Color(0xFFEF6C00);

const double excellentMinMbps = 10.0;
const double fairMinMbps = 2.0;
const double degradedPingThresholdMs = 500.0;
const double degradedPacketLossThreshold = 25.0;

ConnectionHealth classifyConnection({
  required double downloadMbps,
  required double pingMs,
  required double packetLossPercent,
}) {
  final degraded =
      packetLossPercent >= degradedPacketLossThreshold ||
      pingMs >= degradedPingThresholdMs;

  if (degraded) {
    return ConnectionHealth.degraded;
  }
  if (downloadMbps > excellentMinMbps) {
    return ConnectionHealth.excellent;
  }
  if (downloadMbps >= fairMinMbps) {
    return ConnectionHealth.fair;
  }
  return ConnectionHealth.poor;
}