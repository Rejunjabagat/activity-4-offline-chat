import 'dart:math';

import 'mesh_message.dart';
import 'nearby_permissions.dart';

/// Connection state of a single peer in the mesh.
enum PeerStatus { discovered, handshaking, connected, failed }

/// A neighbouring device we can see over Bluetooth / local Wi-Fi.
class MeshPeer {
  final String endpointId;

  /// Mutable: replaced once the remote sends its hello handshake, so the
  /// transcript can show the real device name instead of the endpoint id.
  String name;
  PeerStatus status;

  MeshPeer({
    required this.endpointId,
    required this.name,
    this.status = PeerStatus.discovered,
  });

  String get shortId =>
      endpointId.length <= 8 ? endpointId : endpointId.substring(0, 8);

  String get displayName => name.isEmpty ? 'Peer $shortId' : name;
}

/// A text payload shown in the transcript.
class MeshLogEntry {
  final MeshMessage message;
  final bool outgoing;
  final String peerName;
  final String? endpointId;
  final bool delivered;

  const MeshLogEntry({
    required this.message,
    required this.outgoing,
    required this.peerName,
    this.endpointId,
    this.delivered = true,
  });
}

/// Radial state for the mesh chat. The UI is a pure function of this: every
/// mutation calls [notifyListeners] and rebuilds from these fields.
class MeshChatState {
  final bool advertising;
  final bool discovering;
  final String localName;
  final List<MeshPeer> peers;
  final List<MeshLogEntry> transcript;
  final bool hasPermission;
  final String? permissionHint;
  final bool transportLive;

  /// Fine-grained OS state, so the UI can say whether to prompt again or send
  /// the user to system settings.
  final NearbyPermissionStatus permissionStatus;

  const MeshChatState({
    this.advertising = false,
    this.discovering = false,
    this.localName = 'Android',
    this.peers = const [],
    this.transcript = const [],
    this.hasPermission = true,
    this.permissionHint,
    this.transportLive = false,
    this.permissionStatus = NearbyPermissionStatus.unknown,
  });

  MeshChatState copyWith({
    bool? advertising,
    bool? discovering,
    String? localName,
    List<MeshPeer>? peers,
    List<MeshLogEntry>? transcript,
    bool? hasPermission,
    String? permissionHint,
    bool? transportLive,
    NearbyPermissionStatus? permissionStatus,
  }) =>
      MeshChatState(
        advertising: advertising ?? this.advertising,
        discovering: discovering ?? this.discovering,
        localName: localName ?? this.localName,
        peers: peers ?? this.peers,
        transcript: transcript ?? this.transcript,
        hasPermission: hasPermission ?? this.hasPermission,
        permissionHint: permissionHint ?? this.permissionHint,
        transportLive: transportLive ?? this.transportLive,
        permissionStatus: permissionStatus ?? this.permissionStatus,
      );

  int get connectedCount =>
      peers.where((p) => p.status == PeerStatus.connected).length;

  bool get isActive => advertising || discovering;
}

/// Generates short, collision-resistant message ids.
String newMessageId() {
  final rand = Random();
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final salt = rand.nextInt(1 << 32).toRadixString(36);
  return '$stamp-$salt';
}