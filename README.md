# Portfolio App — Activity 4: Local Mesh Chat

A Flutter app I've been building up through my lab activities. This one adds the
**Local Mesh Chat**: two phones find each other over Bluetooth / local Wi-Fi,
pair, and exchange text messages directly. There is no internet connection and no
central server involved at any point — if Wi-Fi is off and there's no mobile data,
the two devices still talk to each other.

Still includes the earlier activities (Tap Counter, the Network Monitor, and the
Network Diagnostic Dashboard) plus a settings screen for the profile name and
dark/light theme.

## How it works

Built on the `nearby_connections` package, which wraps the Google Nearby
Connections API.

1. **Local discovery** — the device both *advertises* its presence and *scans* for
   neighbours at the same time. Nearby Connections resolves the meeting, so
   whichever phone spots the other first wins the race to pair.
2. **Connection & handshake** — when two devices see each other, the token
   offered by the remote peer is checked before accepting. Anything not presenting
   a valid mesh token is rejected, so a random app on the same network can't join.
   On acceptance a direct peer-to-peer socket opens.
3. **Payload routing** — messages are newline-free JSON envelopes sent as byte
   payloads. Both sides decode defensively, so a malformed payload is logged and
   skipped instead of taking the session down.

The whole UI follows `UI = f(state)`: the chat screen renders whatever
`MeshChatService` exposes and never mutates state itself. Every gesture is a method
call on the service, which then broadcasts through Provider. That also means the
home dashboard can display live mesh status without the chat screen being open.

## Global state injection

`MeshChatService` is registered in `main.dart` with `ChangeNotifierProvider`, so it
is available to the entire widget tree:

```dart
ChangeNotifierProvider(create: (context) => MeshChatService())
```

The dashboard reads it with `context.watch<MeshChatService>()` to show the peer
count live.

## Running it

Requires **two real Android phones** — a single device cannot discover itself.

```sh
flutter pub get
flutter run
```

Install and launch on both phones, then on each one:

1. Open **Activity 4: Local Mesh Chat**
2. Tap **Start** and grant the nearby-devices permission
3. Tap **Pair** on the peer you want to talk to
4. Type and send

Keep the phones within a few metres of each other. Nearby Connections handles the
radio negotiation, so you do not need to pair over the Android Bluetooth settings
menu first.

### Permissions

The manifest declares the modern permissions (`BLUETOOTH_SCAN`,
`BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`, `NEARBY_WIFI_DEVICES`) alongside the
legacy location permissions, so it behaves correctly on both Android 12+ and older
devices. The app degrades gracefully when a permission is denied: discovery simply
stays inactive and the UI explains why, instead of crashing.

## Tests

```sh
flutter test
```

`test/mesh_chat_service_test.dart` covers the wire format, discovery, handshake
acceptance and rejection, payload routing in both directions, and the failure
paths. A `FakeTransport` stands in for the plugin, so the whole suite runs on the
machine with no radios involved.