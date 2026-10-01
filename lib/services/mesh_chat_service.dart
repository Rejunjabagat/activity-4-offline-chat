import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import 'mesh_chat_state.dart';
import 'mesh_message.dart';
import 'mesh_transport.dart';



/// Activity 4 background logic.
///
/// Broadcasts this device's presence (advertising) and simultaneously scans for
/// neighbours (discovery) over Bluetooth / local Wi-Fi. When two devices see
/// each other they run a pairing handshake, and once accepted they can exchange
/// text payloads directly. No internet connection and no central server are
/// involved at any point.
///
/// Injected into the widget tree with Provider so any screen can read the live
/// mesh state.
class MeshChatService extends ChangeNotifier {
  /// Must match on every device in the mesh for peers to find each other.
  static const String serviceId = 'com.student.portfolio.meshchat';

  /// Protocol marker prefixed to the name a device presents over the radio.
  static const String protocolTag = 'mesh:v1';

  /// Shared pairing secret. Only devices that present it are allowed to join the
  /// mesh, so an unrelated app advertising on the same Wi-Fi is rejected.
  ///
  /// This travels in the endpoint name rather than
  /// [ConnectionInfo.authenticationToken], because the two-argument
  /// `NearbyConnections.requestConnection` overload used by the plugin builds
  /// its `ConnectionInfo` with no token, so that field always arrives empty.
  static const String pairingSecret = '7Qm2Vt9Kc4Xp';

  static const int _maxTranscript = 200;

  final MeshTransport _transport;
  final String _localName;

  bool _advertising = false;
  bool _discovering = false;
  bool _permission = true;
  String? _permissionHint;
  bool _transportLive = false;

  final Map<String, MeshPeer> _peers = {};
  final List<MeshLogEntry> _transcript = [];

  MeshChatService({
    MeshTransport? transport,
    String? localName,
  })  : _transport = transport ?? NearbyTransport(),
        _localName = localName ?? 'MeshPeer';

  /// The name this device presents to peers. Carries the protocol marker and
  /// pairing secret so the remote side can authorise the handshake, and ends
  /// with the human-readable device name.
  String get _presentedName => '$protocolTag:$pairingSecret:$_localName';

  /// Strips the credential off a presented name, leaving the friendly name.
  static String _friendlyName(String presented) {
    if (presented.startsWith('$protocolTag:$pairingSecret:')) {
      return presented.substring(protocolTag.length + pairingSecret.length + 2);
    }
    return presented;
  }

  // ---------------------------------------------------------------------
  // Radial state
  // ---------------------------------------------------------------------

  MeshChatState get state => MeshChatState(
        advertising: _advertising,
        discovering: _discovering,
        localName: _localName,
        peers: _peers.values.toList(growable: false),
        transcript: List.unmodifiable(_transcript),
        hasPermission: _permission,
        permissionHint: _permissionHint,
        transportLive: _transportLive,
      );

  List<MeshPeer> get peers => _peers.values.toList(growable: false);

  List<MeshLogEntry> get transcript => List.unmodifiable(_transcript);

  // ---------------------------------------------------------------------
  // Local discovery: broadcast presence + scan for neighbours
  // ---------------------------------------------------------------------

  /// Starts both halves of discovery. Advertising broadcasts our presence,
  /// discovery scans for theirs; Nearby Connections resolves the two when they
  /// meet, so either device can win the race to connect.
  Future<bool> startMesh() async {
    if (_advertising && _discovering) return true;

    _permission = true;
    _permissionHint = null;

    if (!_advertising) {
      final ok = await _guard(() => _transport.startAdvertising(
            nickName: _presentedName,
            strategy: Strategy.P2P_CLUSTER,
            serviceId: serviceId,
            onConnectionInitiated: _onConnectionInitiated,
            onConnectionResult: _onConnectionResult,
            onDisconnected: _onDisconnected,
          ));
      _advertising = ok;
      if (!ok) {
        _permissionHint =
            'Advertising blocked. Nearby devices permission is required.';
        _permission = false;
      }
    }

    if (!_discovering) {
      final ok = await _guard(() => _transport.startDiscovery(
            nickName: _presentedName,
            strategy: Strategy.P2P_CLUSTER,
            serviceId: serviceId,
            onEndpointFound: _onEndpointFound,
            onEndpointLost: _onEndpointLost,
          ));
      _discovering = ok;
      if (!ok && _permission) {
        _permissionHint =
            'Scanning blocked. Location and nearby devices permissions are required.';
        _permission = false;
      }
    }

    _transportLive = _advertising || _discovering;
    _systemNote(_transportLive
        ? 'Mesh active. Broadcasting as "$_localName" and scanning for peers.'
        : 'Mesh could not start. Grant nearby devices permission and retry.');
    notifyListeners();
    return _transportLive;
  }

  Future<void> stopMesh() async {
    await _guardVoid(() async {
      await _transport.stopDiscovery();
      await _transport.stopAdvertising();
    });
    _advertising = false;
    _discovering = false;
    _transportLive = false;
    _peers.clear();
    _systemNote('Mesh stopped. All peers cleared.');
    notifyListeners();
  }

  Future<void> toggleMesh() => isActive ? stopMesh() : startMesh();

  bool get isActive => _advertising || _discovering;

  // ---------------------------------------------------------------------
  // Connection and handshake
  // ---------------------------------------------------------------------

  void _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) {
    if (serviceId != MeshChatService.serviceId) return;
    if (_peers.containsKey(endpointId)) return;

    // Discovery is broadcast on the open service id, so a peer may be any
    // instance of the app; only the handshake reveals whether it is one of ours.
    _peers[endpointId] = MeshPeer(
      endpointId: endpointId,
      name: _friendlyName(endpointName),
      status: PeerStatus.discovered,
    );
    _systemNote('Discovered "${_labelFor(_friendlyName(endpointName), endpointId)}" nearby.');
    notifyListeners();
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId == null) return;
    final peer = _peers.remove(endpointId);
    if (peer != null) {
      _systemNote('"${peer.displayName}" left range.');
      notifyListeners();
    }
  }

  /// Outgoing side of the handshake: we ask the discovered peer to connect.
  Future<void> pairWith(MeshPeer peer) async {
    _setStatus(peer.endpointId, PeerStatus.handshaking);
    _systemNote('Pairing with "${peer.displayName}"...');

    final ok = await _guard(() => _transport.requestConnection(
          nickName: _presentedName,
          endpointId: peer.endpointId,
          onConnectionInitiated: _onConnectionInitiated,
          onConnectionResult: _onConnectionResult,
          onDisconnected: _onDisconnected,
        ));

    if (!ok) {
      _setStatus(peer.endpointId, PeerStatus.failed);
      _systemNote('Could not start pairing with "${peer.displayName}".');
    }
    notifyListeners();
  }

  /// Incoming side: accept only after the peer proves it speaks our protocol
  /// and holds the shared pairing secret.
  Future<void> _onConnectionInitiated(
    String endpointId,
    ConnectionInfo connectionInfo,
  ) async {
    // The requester advertises the same credential name, so it passes its own
    // check. Only the receiving side has to decide.
    if (!connectionInfo.isIncomingConnection) return;

    final presented = connectionInfo.endpointName;
    if (!presented.startsWith('$protocolTag:$pairingSecret:')) {
      await _guard(() => _transport.rejectConnection(endpointId));
      _peers.remove(endpointId);
      _systemNote('Rejected an unknown device claiming to be "${_friendlyName(presented)}". '
          'Wrong pairing secret.');
      notifyListeners();
      return;
    }

    final name = _friendlyName(presented);
    _peers[endpointId] = MeshPeer(
      endpointId: endpointId,
      name: name,
      status: PeerStatus.handshaking,
    );

    final accepted = await _guard(() => _transport.acceptConnection(
          endpointId,
          onPayloadReceived: _onPayloadReceived,
        ));

    if (accepted) {
      _setStatus(endpointId, PeerStatus.connected);
      _systemNote('Paired with "${_labelFor(name, endpointId)}". Secure socket open.');
      // Announce ourselves so the other side learns our name over the link.
      unawaited(_send(
        endpointId,
        MeshMessage.hello(sender: _localName, id: newMessageId()),
        silent: true,
      ));
    } else {
      _peers.remove(endpointId);
    }
    notifyListeners();
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _setStatus(endpointId, PeerStatus.connected);
      _systemNote('Link established with "${_nameFor(endpointId)}".');
    } else if (status == Status.REJECTED) {
      _setStatus(endpointId, PeerStatus.failed);
      _systemNote('"${_nameFor(endpointId)}" declined the connection.');
    } else {
      _setStatus(endpointId, PeerStatus.failed);
      _systemNote('Connection error with "${_nameFor(endpointId)}".');
    }
    notifyListeners();
  }

  void _onDisconnected(String endpointId) {
    _setStatus(endpointId, PeerStatus.failed);
    _systemNote('Disconnected from "${_nameFor(endpointId)}".');
    notifyListeners();
  }

  Future<void> disconnect(MeshPeer peer) async {
    await _guardVoid(() => _transport.disconnectFromEndpoint(peer.endpointId));
    _setStatus(peer.endpointId, PeerStatus.discovered);
    _systemNote('Closed the socket to "${peer.displayName}".');
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Payload routing
  // ---------------------------------------------------------------------

  /// Sends [body] to every connected peer, or to [only] when given.
  Future<void> send(String body, {MeshPeer? only}) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final targets = only != null
        ? [only]
        : _peers.values
            .where((p) => p.status == PeerStatus.connected)
            .toList(growable: false);

    if (targets.isEmpty) {
      _append(
        MeshLogEntry(
          message: MeshMessage.chat(
            sender: _localName,
            body: trimmed,
            id: newMessageId(),
          ),
          outgoing: true,
          peerName: 'Nobody connected',
          delivered: false,
        ),
      );
      notifyListeners();
      return;
    }

    for (final peer in targets) {
      await _send(peer.endpointId, MeshMessage.chat(
        sender: _localName,
        body: trimmed,
        id: newMessageId(),
      ));
    }
    notifyListeners();
  }

  Future<void> _send(
    String endpointId,
    MeshMessage message, {
    bool silent = false,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(message.encode()));
    final ok = await _guard(() async {
      await _transport.sendBytesPayload(endpointId, bytes);
      return true;
    });

    if (!silent) {
      _append(
        MeshLogEntry(
          message: message,
          outgoing: true,
          peerName: _nameFor(endpointId),
          endpointId: endpointId,
          delivered: ok,
        ),
      );
    }
    notifyListeners();
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type != PayloadType.BYTES) return;

    final incoming = payload.bytes;
    if (incoming == null || incoming.isEmpty) return;

    final raw = utf8.decode(incoming, allowMalformed: true);
    final message = MeshMessage.tryDecode(raw);

    if (message == null) {
      _systemNote('Ignored an unreadable payload from "${_nameFor(endpointId)}".');
      notifyListeners();
      return;
    }

    // A hello names the peer; adopt it so the transcript shows a real label.
    if (message.kind == MeshMessage.kindHello) {
      final peer = _peers[endpointId];
      if (peer != null) {
        peer.name = message.sender;
        peer.status = PeerStatus.connected;
      }
      notifyListeners();
      return;
    }

    _append(
      MeshLogEntry(
        message: message,
        outgoing: false,
        peerName: _nameFor(endpointId),
        endpointId: endpointId,
      ),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  /// Runs a platform call, converting plugin errors into `false` so a denied
  /// permission degrades gracefully instead of throwing into the UI.
  Future<bool> _guard(Future<bool> Function() action) async {
    try {
      return await action();
    } catch (e) {
      debugPrint('MeshChatService platform call failed: $e');
      return false;
    }
  }

  Future<void> _guardVoid(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('MeshChatService platform call failed: $e');
    }
  }

  void _setStatus(String endpointId, PeerStatus status) {
    final peer = _peers[endpointId];
    if (peer != null) peer.status = status;
  }

  String _nameFor(String endpointId) {
    final peer = _peers[endpointId];
    if (peer != null && peer.name.isNotEmpty) return peer.name;
    return 'Peer ${endpointId.length <= 6 ? endpointId : endpointId.substring(0, 6)}';
  }

  String _labelFor(String name, String endpointId) =>
      name.isNotEmpty ? name : _nameFor(endpointId);

  void _append(MeshLogEntry entry) {
    _transcript.insert(0, entry);
    if (_transcript.length > _maxTranscript) {
      _transcript.removeRange(_maxTranscript, _transcript.length);
    }
  }

  void _systemNote(String text) {
    _append(
      MeshLogEntry(
        message: MeshMessage(
          id: newMessageId(),
          kind: 'system',
          sender: 'System',
          body: text,
          sentAt: DateTime.now(),
        ),
        outgoing: false,
        peerName: 'Mesh',
      ),
    );
  }

  @override
  void dispose() {
    _guardVoid(() async {
      await _transport.stopDiscovery();
      await _transport.stopAdvertising();
      await _transport.stopAllEndpoints();
    });
    super.dispose();
  }
}
