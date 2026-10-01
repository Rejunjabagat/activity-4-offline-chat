import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:provider/provider.dart';

import 'package:portfolio_app/main.dart';
import 'package:portfolio_app/providers/app_state.dart';
import 'package:portfolio_app/services/mesh_chat_service.dart';
import 'package:portfolio_app/services/mesh_transport.dart';
import 'package:portfolio_app/services/network_diagnostic_tool.dart';

/// Keeps the widget test off real radios: every platform call resolves false.
class _NoopTransport implements MeshTransport {
  @override
  Future<bool> startAdvertising({
    required String nickName,
    required Strategy strategy,
    required String serviceId,
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
  }) async =>
      false;

  @override
  Future<void> stopAdvertising() async {}

  @override
  Future<bool> startDiscovery({
    required String nickName,
    required Strategy strategy,
    required String serviceId,
    required OnEndpointFound onEndpointFound,
    required OnEndpointLost onEndpointLost,
  }) async =>
      false;

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<bool> requestConnection({
    required String nickName,
    required String endpointId,
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
  }) async =>
      false;

  @override
  Future<bool> acceptConnection(
    String endpointId, {
    required OnPayloadReceived onPayloadReceived,
  }) async =>
      false;

  @override
  Future<bool> rejectConnection(String endpointId) async => false;

  @override
  Future<void> sendBytesPayload(String endpointId, Uint8List bytes) async {}

  @override
  Future<void> disconnectFromEndpoint(String endpointId) async {}

  @override
  Future<void> stopAllEndpoints() async {}
}

void main() {
  testWidgets('Home dashboard renders with default profile',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => AppState()),
          ChangeNotifierProvider(create: (context) => NetworkDiagnosticTool()),
          ChangeNotifierProvider(
            create: (context) => MeshChatService(transport: _NoopTransport()),
          ),
        ],
        child: const PortfolioApp(),
      ),
    );

    expect(find.text('My Flutter Portfolio'), findsOneWidget);
    expect(find.textContaining('Welcome back, Student'), findsOneWidget);
    expect(find.textContaining('Activity 1'), findsOneWidget);
    expect(find.textContaining('Activity 2'), findsWidgets);
    expect(find.textContaining('Activity 3'), findsOneWidget);
    expect(find.textContaining('Activity 4: Local Mesh Chat'), findsOneWidget);
  });
}