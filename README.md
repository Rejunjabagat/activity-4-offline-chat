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
2. **Connection & handshake** — every device advertises itself under a name
   carrying a protocol marker and a shared pairing secret, e.g.
   `mesh:v1:<secret>:PixelB`. When two devices see each other, the remote peer must
   present that credential before the connection is accepted; anything else is
   rejected, so a random app on the same Wi-Fi can't join. On acceptance a direct
   peer-to-peer socket opens.

   The credential rides in the endpoint name rather than the plugin's
   `authenticationToken` field, because the two-argument
   `NearbyConnections.requestConnection` overload the plugin calls builds its
   `ConnectionInfo` with no token, leaving that field permanently empty.
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

The `nearby_connections` plugin requests nothing at runtime on your behalf, so
`MainActivity` handles it over a `portfolio_app/nearby` method channel. On Start
the app asks for the permissions this Android version actually needs, checks the
OS location toggle, and reports exactly what is blocking if it still cannot start:

- nothing held → prompt, then retry
- held but the location switch is off → "Turn on Location" button
- permanently denied → "Open Settings" button, since a second prompt would be ignored

Declaring a permission is not enough on its own. Each of these had to be left
uncapped in the manifest, because a `maxSdkVersion` limit makes Android silently
refuse the runtime grant and Nearby Connections then fails with
`MISSING_PERMISSION_*`:

| Permission | Consequence if capped |
|---|---|
| `ACCESS_FINE_LOCATION` | no peers found on Android 12+ |
| `ACCESS_WIFI_STATE` | `MISSING_PERMISSION_ACCESS_WIFI_STATE`, mesh never starts |

`BLUETOOTH_SCAN` and `NEARBY_WIFI_DEVICES` are also declared without
`neverForLocation`, since that flag suppresses the location grant that
location-backed peer scanning depends on.

NFC is intentionally not requested: the log warns about it during advertising,
but peer-to-peer sockets use Bluetooth and local Wi-Fi, so it changes nothing.

## Tests

```sh
flutter test
```

`test/mesh_chat_service_test.dart` covers the wire format, discovery, handshake
acceptance and rejection, payload routing in both directions, and the failure
paths. A `FakeTransport` stands in for the plugin, so the whole suite runs on the
machine with no radios involved.