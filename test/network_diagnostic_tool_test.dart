import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:portfolio_app/services/connection_health.dart';
import 'package:portfolio_app/services/network_diagnostic_tool.dart';

void main() {
  test('runTest completes the idle -> download -> upload sequence', () {
    fakeAsync((async) {
      final tool = NetworkDiagnosticTool();
      tool.runTest();
      async.elapse(Duration.zero);

      expect(tool.isRunning, isTrue);
      expect(tool.currentPhase, DiagnosticPhase.idle);

      async.elapse(const Duration(seconds: 3));
      expect(tool.currentPhase, DiagnosticPhase.download);

      async.elapse(const Duration(milliseconds: 1500));
      expect(tool.currentPhase, DiagnosticPhase.upload);

      async.elapse(const Duration(seconds: 1));
      expect(tool.isRunning, isFalse);
      expect(tool.completedRuns, 1);

      tool.dispose();
    });
  });

  test('results populate and a health tier is classified', () {
    fakeAsync((async) {
      final tool = NetworkDiagnosticTool();
      tool.runTest();

      async.elapse(const Duration(seconds: 11));

      expect(tool.downloadMbps, greaterThan(0));
      expect(tool.uploadMbps, greaterThan(0));
      expect(tool.idlePingMs, greaterThan(0));
      expect(tool.health, isNotNull);
      expect(tool.log, isNotEmpty);

      tool.dispose();
    });
  });

  test('connection is rated degraded under extreme latency', () {
    fakeAsync((async) {
      // Cycling the profile list eventually reaches the Degraded profile.
      final tool = NetworkDiagnosticTool();
      const degradedCycles = 7;
      for (var i = 0; i < degradedCycles; i++) {
        tool.runTest();
        async.elapse(const Duration(seconds: 11));
      }

      expect(tool.completedRuns, degradedCycles);
      expect(tool.idlePingMs, greaterThanOrEqualTo(500));
      expect(tool.health, ConnectionHealth.degraded);

      tool.dispose();
    });
  });

  test('requesting a run while testing is ignored', () {
    fakeAsync((async) {
      final tool = NetworkDiagnosticTool();
      tool.runTest();
      tool.runTest();

      async.elapse(const Duration(seconds: 11));
      expect(tool.completedRuns, 1);

      tool.dispose();
    });
  });
}