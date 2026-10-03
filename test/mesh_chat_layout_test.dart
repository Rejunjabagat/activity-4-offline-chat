import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:portfolio_app/screens/local_mesh_chat_screen.dart';
import 'package:portfolio_app/services/mesh_chat_service.dart';
import 'package:portfolio_app/services/mesh_chat_state.dart';
import 'package:portfolio_app/services/mesh_transport.dart';
import 'package:portfolio_app/services/nearby_permissions.dart';

class ScriptedMeshChatService extends MeshChatService {
  ScriptedMeshChatService() : super(transport: _T(), permissions: _P());
}

class _T implements MeshTransport {
  @override
  dynamic noSuchMethod(Invocation i) => Future.value(false);
}

class _P extends NearbyPermissions {
  @override
  Future<NearbyPermissionStatus> request() async => const NearbyPermissionStatus(
        granted: true,
        missing: [],
        locationEnabled: true,
        permanentlyDenied: false,
      );
}

Future<void> pumpMesh(WidgetTester tester, ScriptedMeshChatService service,
    {double width = 360}) async {
  tester.view.physicalSize = Size(width * 2, 1612 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<MeshChatService>.value(
      value: service,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const LocalMeshChatScreen(),
      ),
    ),
  );
  await tester.pump();
}

/// Regression cover for a 6.1px overflow that only appeared on a 360dp screen,
/// in the notification line shown right after Start is pressed.
void main() {
  testWidgets('empty mesh renders clean at 360dp', (tester) async {
    final s = ScriptedMeshChatService();
    addTearDown(s.dispose);
    await pumpMesh(tester, s);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long system line does not overflow at 360dp', (tester) async {
    final s = ScriptedMeshChatService();
    addTearDown(s.dispose);
    s.debugSeed(systemLines: const [
      'Mesh active. Broadcasting as "MeshPeer" and scanning for peers.',
    ]);
    await pumpMesh(tester, s);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the longest notifications wrap instead of overflowing',
      (tester) async {
    final s = ScriptedMeshChatService();
    addTearDown(s.dispose);
    s.debugSeed(systemLines: const [
      'Rejected an unknown device claiming to be "SomeOtherApp". Wrong pairing '
          'secret.',
      'Mesh could not start. Nearby devices and Location are required.',
      'Discovered "Pixel 8 Pro Max with a very long device name" nearby.',
      'Permissions are granted, but Location is switched off on this device. '
          'Turn on the location toggle, then press Start again.',
    ]);
    await pumpMesh(tester, s);
    expect(tester.takeException(), isNull);
  });

  testWidgets('peers in every status do not overflow at 360dp', (tester) async {
    final s = ScriptedMeshChatService();
    addTearDown(s.dispose);
    s.debugSeed(peers: [
      MeshPeer(endpointId: 'a', name: 'PixelB', status: PeerStatus.discovered),
      MeshPeer(endpointId: 'b', name: 'GalaxyS', status: PeerStatus.handshaking),
      MeshPeer(endpointId: 'c', name: 'RedmiNote', status: PeerStatus.connected),
      MeshPeer(endpointId: 'd', name: 'AReallyLongDeviceName12345',
          status: PeerStatus.failed),
    ]);
    await pumpMesh(tester, s);
    expect(tester.takeException(), isNull);
  });
}