import 'dart:convert';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:portfolio_app/services/mesh_chat_service.dart';
import 'package:portfolio_app/services/mesh_chat_state.dart';
import 'package:portfolio_app/services/mesh_message.dart';
import 'package:portfolio_app/services/mesh_transport.dart';

/// Records everything the service sends so tests can assert on wire traffic
/// and replay incoming payloads, without needing a real radio.
class FakeTransport implements MeshTransport {
  bool advertising = false;
  bool discovering = false;

  /// Endpoints advertised by simulated neighbours.
  final Map<String, String> remoteEndpoints = {};

  /// Tokens that incoming connections will offer.
  final Map<String, String> offeredTokens = {};

  final List<(String endpointId, Uint8List bytes)> sent = [];
  final List<String> rejected = [];
  final List<String> disconnected = [];

  /// Set to make the next platform call fail, exercising the error path.
  bool failNext = false;

  /// When true every platform call fails, as it does when the user denies the
  /// nearby-devices permission.
  bool denyAll = false;

  OnEndpointFound? onEndpointFound;
  OnEndpointLost? onEndpointLost;
  OnConnectionInitiated? onConnectionInitiated;
  OnPayloadReceived? onPayloadReceived;
  OnConnectionResult? onConnectionResult;
  OnDisconnected? onDisconnected;

  Future<bool> _maybeFail() async {
    if (denyAll) {
      throw Exception('nearby devices permission denied');
    }
    if (failNext) {
      failNext = false;
      throw Exception('simulated platform failure');
    }
    return true;
  }

  @override
  Future<bool> startAdvertising({
    required String nickName,
    required Strategy strategy,
    required String serviceId,
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
  }) async {
    advertising = true;
    this.onConnectionInitiated = onConnectionInitiated;
    this.onConnectionResult = onConnectionResult;
    this.onDisconnected = onDisconnected;
    return _maybeFail();
  }

  @override
  Future<void> stopAdvertising() async => advertising = false;

  @override
  Future<bool> startDiscovery({
    required String nickName,
    required Strategy strategy,
    required String serviceId,
    required OnEndpointFound onEndpointFound,
    required OnEndpointLost onEndpointLost,
  }) async {
    discovering = true;
    this.onEndpointFound = onEndpointFound;
    this.onEndpointLost = onEndpointLost;
    return _maybeFail();
  }

  @override
  Future<void> stopDiscovery() async => discovering = false;

  @override
  Future<bool> requestConnection({
    required String nickName,
    required String endpointId,
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
  }) async {
    this.onConnectionInitiated = onConnectionInitiated;
    this.onConnectionResult = onConnectionResult;
    this.onDisconnected = onDisconnected;
    return _maybeFail();
  }

  @override
  Future<bool> acceptConnection(
    String endpointId, {
    required OnPayloadReceived onPayloadReceived,
  }) async {
    this.onPayloadReceived = onPayloadReceived;
    return _maybeFail();
  }

  @override
  Future<bool> rejectConnection(String endpointId) async {
    rejected.add(endpointId);
    return true;
  }

  @override
  Future<void> sendBytesPayload(String endpointId, Uint8List bytes) async {
    if (denyAll) {
      throw Exception('nearby devices permission denied');
    }
    if (failNext) {
      failNext = false;
      throw Exception('simulated send failure');
    }
    sent.add((endpointId, bytes));
  }

  @override
  Future<void> disconnectFromEndpoint(String endpointId) async {
    disconnected.add(endpointId);
  }

  @override
  Future<void> stopAllEndpoints() async {}

  // ---- test helpers -------------------------------------------------

  /// Pretends a neighbour advertising our service appeared in range.
  void emitEndpointFound(String endpointId, String name,
      {String? serviceId}) {
    onEndpointFound?.call(endpointId, name, serviceId ?? MeshChatService.serviceId);
  }

  /// Pretends a remote device initiated the handshake.
  void emitIncomingConnection(String endpointId, String name, String token) {
    onConnectionInitiated?.call(
      endpointId,
      ConnectionInfo(name, token, true),
    );
  }

  /// Decodes a payload the service wrote onto the wire.
  MeshMessage? decodeLastSent() {
    final (_, bytes) = sent.last;
    return MeshMessage.tryDecode(utf8.decode(bytes));
  }

  /// Pretends a payload arrived from a connected peer.
  void emitPayload(String endpointId, String raw) {
    onPayloadReceived?.call(
      endpointId,
      Payload(
        type: PayloadType.BYTES,
        bytes: Uint8List.fromList(utf8.encode(raw)),
        id: 1,
      ),
    );
  }
}

MeshChatService buildService(FakeTransport transport) =>
    MeshChatService(transport: transport, localName: 'PixelA');

void main() {
  group('MeshMessage wire format', () {
    test('round-trips a chat payload', () {
      final message = MeshMessage.chat(
        sender: 'PixelA',
        body: 'hello mesh',
        id: 'abc-1',
      );

      final decoded = MeshMessage.tryDecode(message.encode());

      expect(decoded, isNotNull);
      expect(decoded!.id, 'abc-1');
      expect(decoded.kind, MeshMessage.kindChat);
      expect(decoded.sender, 'PixelA');
      expect(decoded.body, 'hello mesh');
    });

    test('preserves unicode bodies', () {
      final message = MeshMessage.chat(
        sender: 'PixelA',
        body: 'kumusta! 👋',
        id: 'abc-2',
      );

      final decoded = MeshMessage.tryDecode(message.encode());

      expect(decoded!.body, 'kumusta! 👋');
    });

    test('returns null for malformed payloads instead of throwing', () {
      expect(MeshMessage.tryDecode('not json at all'), isNull);
      expect(MeshMessage.tryDecode('{"id":"x"}'), isNull);
      expect(MeshMessage.tryDecode('[1,2,3]'), isNull);
      expect(MeshMessage.tryDecode(''), isNull);
    });
  });

  group('MeshChatState derivation', () {
    test('counts only connected peers', () {
      final state = MeshChatState(
        peers: [
          MeshPeer(endpointId: 'a', name: 'A', status: PeerStatus.connected),
          MeshPeer(endpointId: 'b', name: 'B', status: PeerStatus.discovered),
          MeshPeer(endpointId: 'c', name: 'C', status: PeerStatus.handshaking),
        ],
      );

      expect(state.connectedCount, 1);
    });

    test('is active when either advertising or discovering', () {
      expect(const MeshChatState(advertising: true).isActive, isTrue);
      expect(const MeshChatState(discovering: true).isActive, isTrue);
      expect(const MeshChatState().isActive, isFalse);
    });

    test('shortId truncates long endpoint ids', () {
      final peer = MeshPeer(
        endpointId: 'ABCDEFGHIJKLMNOP',
        name: '',
      );
      expect(peer.shortId, 'ABCDEFGH');
      expect(peer.displayName, 'Peer ABCDEFGH');
    });
  });

  group('local discovery', () {
    test('startMesh advertises and scans at the same time', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);

      await service.startMesh();

      expect(transport.advertising, isTrue);
      expect(transport.discovering, isTrue);
      expect(service.isActive, isTrue);
      expect(service.state.transportLive, isTrue);
    });

    test('discovers neighbours that advertise our service', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();

      transport.emitEndpointFound('peer-1', 'PixelB');

      expect(service.peers.length, 1);
      expect(service.peers.first.name, 'PixelB');
      expect(service.peers.first.status, PeerStatus.discovered);
    });

    test('ignores devices on a different service id', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();

      transport.emitEndpointFound('other', 'SomeOtherApp',
          serviceId: 'com.not.our.mesh');

      expect(service.peers, isEmpty);
    });

    test('does not duplicate an endpoint already known', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();

      transport.emitEndpointFound('peer-1', 'PixelB');
      transport.emitEndpointFound('peer-1', 'PixelB');

      expect(service.peers.length, 1);
    });

    test('forgets a peer that leaves range', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();
      transport.emitEndpointFound('peer-1', 'PixelB');

      transport.onEndpointLost?.call('peer-1');

      expect(service.peers, isEmpty);
    });

    test('stopMesh clears peers and stops both roles', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();
      transport.emitEndpointFound('peer-1', 'PixelB');

      await service.stopMesh();

      expect(transport.advertising, isFalse);
      expect(transport.discovering, isFalse);
      expect(service.peers, isEmpty);
      expect(service.isActive, isFalse);
    });

    test('reports a permission hint when the user denies nearby devices', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      transport.denyAll = true;

      await service.startMesh();

      expect(service.state.hasPermission, isFalse);
      expect(service.state.permissionHint, isNotNull);
      expect(service.state.transportLive, isFalse);
      expect(service.isActive, isFalse);
    });

    test('stays live on discovery when only advertising is blocked', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      transport.failNext = true;

      await service.startMesh();

      // Advertising threw, scanning still succeeded, so the mesh can still
      // discover neighbours that are already advertising.
      expect(service.state.advertising, isFalse);
      expect(service.state.discovering, isTrue);
      expect(service.state.transportLive, isTrue);
    });

    test('survives a platform exception without throwing', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      transport.failNext = true;

      await expectLater(service.startMesh(), completes);
    });
  });

  group('connection and handshake', () {
    test('pairing marks the peer as handshaking', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();
      transport.emitEndpointFound('peer-1', 'PixelB');

      await service.pairWith(service.peers.first);

      expect(service.peers.first.status, PeerStatus.handshaking);
    });

    test('accepts an incoming peer presenting a mesh token', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();

      transport.emitIncomingConnection('peer-9', 'PixelB', 'mesh:token-123');
      await Future<void>.delayed(Duration.zero);

      expect(transport.rejected, isEmpty);
      expect(
        service.peers.firstWhere((p) => p.endpointId == 'peer-9').status,
        PeerStatus.connected,
      );
    });

    test('rejects an incoming peer with a foreign token', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();

      transport.emitIncomingConnection('peer-9', 'Impostor', 'other:abc');
      await Future<void>.delayed(Duration.zero);

      expect(transport.rejected, contains('peer-9'));
      expect(
        service.peers.where((p) => p.endpointId == 'peer-9'),
        isEmpty,
      );
    });

    test('a connected result marks the peer connected', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();
      transport.emitEndpointFound('peer-1', 'PixelB');

      transport.onConnectionResult?.call('peer-1', Status.CONNECTED);

      expect(service.peers.first.status, PeerStatus.connected);
    });

    test('a rejected result records the failure', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();
      transport.emitEndpointFound('peer-1', 'PixelB');

      transport.onConnectionResult?.call('peer-1', Status.REJECTED);

      expect(service.peers.first.status, PeerStatus.failed);
    });

    test('disconnect resets the peer to discovered', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();
      transport.emitIncomingConnection('peer-1', 'PixelB', 'mesh:t');
      await Future<void>.delayed(Duration.zero);

      await service.disconnect(service.peers.first);

      expect(transport.disconnected, contains('peer-1'));
      expect(service.peers.first.status, PeerStatus.discovered);
    });
  });

  group('payload routing', () {
    test('does not send while no peer is connected', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();
      transport.emitEndpointFound('peer-1', 'PixelB');

      await service.send('anyone there?');

      expect(transport.sent, isEmpty);
      final outgoing = service.transcript
          .where((e) => e.outgoing && e.message.kind == MeshMessage.kindChat)
          .first;
      expect(outgoing.delivered, isFalse);
    });

    test('broadcasts to every connected peer', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();
      transport.emitIncomingConnection('peer-1', 'PixelB', 'mesh:t');
      transport.emitIncomingConnection('peer-2', 'PixelC', 'mesh:t');
      await Future<void>.delayed(Duration.zero);

      await service.send('hello everyone');

      final chatSends = transport.sent
          .map((e) => MeshMessage.tryDecode(utf8.decode(e.$2)))
          .where((m) => m!.kind == MeshMessage.kindChat)
          .toList();

      expect(chatSends.length, 2);
      expect(chatSends.every((m) => m!.body == 'hello everyone'), isTrue);
    });

    test('targets a single peer when one is given', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();
      transport.emitIncomingConnection('peer-1', 'PixelB', 'mesh:t');
      transport.emitIncomingConnection('peer-2', 'PixelC', 'mesh:t');
      await Future<void>.delayed(Duration.zero);

      await service.send('just you', only: service.peers.first);

      final chatSends = transport.sent
          .map((e) => MeshMessage.tryDecode(utf8.decode(e.$2)))
          .where((m) => m!.kind == MeshMessage.kindChat)
          .toList();

      expect(chatSends.length, 1);
    });

    test('ignores blank messages', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();
      transport.emitIncomingConnection('peer-1', 'PixelB', 'mesh:t');
      await Future<void>.delayed(Duration.zero);

      await service.send('   ');

      expect(transport.sent.where((e) {
        final m = MeshMessage.tryDecode(utf8.decode(e.$2));
        return m!.kind == MeshMessage.kindChat;
      }), isEmpty);
    });

    test('records an incoming payload in the transcript', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();
      transport.emitIncomingConnection('peer-1', 'PixelB', 'mesh:t');
      await Future<void>.delayed(Duration.zero);

      final inbound = MeshMessage.chat(
        sender: 'PixelB',
        body: 'got your message',
        id: 'in-1',
      );
      transport.emitPayload('peer-1', inbound.encode());

      final entry = service.transcript
          .firstWhere((e) => !e.outgoing && e.message.id == 'in-1');
      expect(entry.message.body, 'got your message');
      expect(entry.peerName, 'PixelB');
    });

    test('ignores an unreadable payload instead of crashing', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();

      transport.emitPayload('peer-1', '<<<corrupt>>>');

      expect(
        service.transcript.any((e) => e.message.kind == 'system'),
        isTrue,
      );
    });

    test('a hello handshake adopts the remote name', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();
      transport.emitIncomingConnection('peer-1', 'unnamed', 'mesh:t');
      await Future<void>.delayed(Duration.zero);

      transport.emitPayload(
        'peer-1',
        MeshMessage.hello(sender: 'GalaxyS24', id: 'h1').encode(),
      );

      expect(service.peers.first.name, 'GalaxyS24');
    });

    test('does not log the automatic hello as a chat bubble', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();

      transport.emitIncomingConnection('peer-1', 'PixelB', 'mesh:t');
      await Future<void>.delayed(Duration.zero);

      expect(transport.sent, isNotEmpty);
      expect(transport.decodeLastSent()!.kind, MeshMessage.kindHello);
      expect(
        service.transcript
            .any((e) => e.message.kind == MeshMessage.kindChat),
        isFalse,
      );
    });

    test('marks a send as undelivered when the socket write throws', () async {
      final transport = FakeTransport();
      final service = buildService(transport);
      addTearDown(service.dispose);
      await service.startMesh();
      transport.emitIncomingConnection('peer-1', 'PixelB', 'mesh:t');
      await Future<void>.delayed(Duration.zero);
      transport.failNext = true;

      await service.send('will not arrive');

      final entry = service.transcript
          .firstWhere((e) => e.outgoing && e.message.body == 'will not arrive');
      expect(entry.delivered, isFalse);
    });
  });

  test('service notifies listeners on every state change', () async {
    final transport = FakeTransport();
    final service = buildService(transport);
    addTearDown(service.dispose);

    var notifications = 0;
    service.addListener(() => notifications++);

    await service.startMesh();
    transport.emitEndpointFound('peer-1', 'PixelB');

    expect(notifications, greaterThan(1));
  });
}