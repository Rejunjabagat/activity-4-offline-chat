import 'dart:convert';

/// A single text payload routed across the local peer-to-peer mesh.
///
/// Wire format is newline-delimited JSON so payloads stay human-readable in
/// logs and survive a peer that sends a malformed line without taking the
/// session down.
class MeshMessage {
  static const String kindHello = 'hello';
  static const String kindChat = 'chat';
  static const String kindAck = 'ack';

  final String id;
  final String kind;
  final String sender;
  final String body;
  final DateTime sentAt;

  const MeshMessage({
    required this.id,
    required this.kind,
    required this.sender,
    required this.body,
    required this.sentAt,
  });

  factory MeshMessage.chat({
    required String sender,
    required String body,
    required String id,
  }) =>
      MeshMessage(
        id: id,
        kind: kindChat,
        sender: sender,
        body: body,
        sentAt: DateTime.now(),
      );

  factory MeshMessage.hello({required String sender, required String id}) =>
      MeshMessage(
        id: id,
        kind: kindHello,
        sender: sender,
        body: '',
        sentAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'sender': sender,
        'body': body,
        'ts': sentAt.millisecondsSinceEpoch,
      };

  String encode() => jsonEncode(toJson());

  /// Returns null when the payload is not a valid mesh envelope, so callers can
  /// ignore junk instead of throwing.
  static MeshMessage? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final id = decoded['id'];
      final kind = decoded['kind'];
      final sender = decoded['sender'];
      final body = decoded['body'];
      final ts = decoded['ts'];

      if (id is! String || kind is! String || sender is! String) return null;
      if (body is! String || ts is! num) return null;

      return MeshMessage(
        id: id,
        kind: kind,
        sender: sender,
        body: body,
        sentAt: DateTime.fromMillisecondsSinceEpoch(ts.toInt()),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'MeshMessage($kind, $id, from: $sender)';
}