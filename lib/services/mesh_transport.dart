import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

/// Thin seam over the Nearby Connections plugin so [MeshService] can be
/// unit-tested without a real radio. Production uses [NearbyTransport];
/// tests substitute a fake.
abstract class MeshTransport {
  Future<bool> startAdvertising({
    required String nickName,
    required Strategy strategy,
    required String serviceId,
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
  });

  Future<void> stopAdvertising();

  Future<bool> startDiscovery({
    required String nickName,
    required Strategy strategy,
    required String serviceId,
    required OnEndpointFound onEndpointFound,
    required OnEndpointLost onEndpointLost,
  });

  Future<void> stopDiscovery();

  Future<bool> requestConnection({
    required String nickName,
    required String endpointId,
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
  });

  Future<bool> acceptConnection(
    String endpointId, {
    required OnPayloadReceived onPayloadReceived,
  });

  Future<bool> rejectConnection(String endpointId);

  Future<void> sendBytesPayload(String endpointId, Uint8List bytes);

  Future<void> disconnectFromEndpoint(String endpointId);

  Future<void> stopAllEndpoints();
}

class NearbyTransport implements MeshTransport {
  @override
  Future<bool> startAdvertising({
    required String nickName,
    required Strategy strategy,
    required String serviceId,
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
  }) =>
      Nearby().startAdvertising(
        nickName,
        strategy,
        serviceId: serviceId,
        onConnectionInitiated: onConnectionInitiated,
        onConnectionResult: onConnectionResult,
        onDisconnected: onDisconnected,
      );

  @override
  Future<void> stopAdvertising() => Nearby().stopAdvertising();

  @override
  Future<bool> startDiscovery({
    required String nickName,
    required Strategy strategy,
    required String serviceId,
    required OnEndpointFound onEndpointFound,
    required OnEndpointLost onEndpointLost,
  }) =>
      Nearby().startDiscovery(
        nickName,
        strategy,
        serviceId: serviceId,
        onEndpointFound: onEndpointFound,
        onEndpointLost: onEndpointLost,
      );

  @override
  Future<void> stopDiscovery() => Nearby().stopDiscovery();

  @override
  Future<bool> requestConnection({
    required String nickName,
    required String endpointId,
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
  }) =>
      Nearby().requestConnection(
        nickName,
        endpointId,
        onConnectionInitiated: onConnectionInitiated,
        onConnectionResult: onConnectionResult,
        onDisconnected: onDisconnected,
      );

  @override
  Future<bool> acceptConnection(
    String endpointId, {
    required OnPayloadReceived onPayloadReceived,
  }) =>
      Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: onPayloadReceived,
      );

  @override
  Future<bool> rejectConnection(String endpointId) =>
      Nearby().rejectConnection(endpointId);

  @override
  Future<void> sendBytesPayload(String endpointId, Uint8List bytes) =>
      Nearby().sendBytesPayload(endpointId, bytes);

  @override
  Future<void> disconnectFromEndpoint(String endpointId) =>
      Nearby().disconnectFromEndpoint(endpointId);

  @override
  Future<void> stopAllEndpoints() => Nearby().stopAllEndpoints();
}