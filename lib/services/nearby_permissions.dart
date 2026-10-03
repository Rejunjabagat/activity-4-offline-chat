import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the OS reports about the permissions and toggles Nearby Connections
/// needs before it will discover anything.
@immutable
class NearbyPermissionStatus {
  /// Every required runtime permission is granted.
  final bool granted;

  /// Permissions still outstanding.
  final List<String> missing;

  /// The device location toggle is on. Nearby Connections refuses to scan
  /// without it even when the permissions themselves are held.
  final bool locationEnabled;

  /// The user denied a permission permanently, so only system settings can fix
  /// it and another in-app prompt would be ignored.
  final bool permanentlyDenied;

  const NearbyPermissionStatus({
    required this.granted,
    required this.missing,
    required this.locationEnabled,
    required this.permanentlyDenied,
  });

  /// Nothing blocks starting the mesh.
  bool get ready => granted && locationEnabled;

  /// Held, but the OS location switch is off.
  bool get needsLocationToggle => granted && !locationEnabled;

  /// A prompt was declined for good; send the user to settings.
  bool get needsSettings => permanentlyDenied;

  /// Straightforward case: ask again.
  bool get canPromptAgain => !granted && !permanentlyDenied;

  /// The actionable instruction for the UI, or null when there is nothing to do.
  String? get remedy {
    if (ready) return null;
    if (needsSettings) {
      return 'Nearby devices permission was permanently denied. '
          'Open Settings > Apps > Portfolio > Permissions and allow '
          'Nearby devices and Location, then press Start again.';
    }
    if (needsLocationToggle) {
      return 'Permissions are granted, but Location is switched off on this '
          'device. Turn on the location toggle, then press Start again.';
    }
    return 'Nearby devices and Location permissions are required. '
        'Tap Start and choose Allow.';
  }

  static const NearbyPermissionStatus unknown = NearbyPermissionStatus(
    granted: false,
    missing: <String>[],
    locationEnabled: false,
    permanentlyDenied: false,
  );

  /// Folds the platform reply into a status.
  factory NearbyPermissionStatus.fromMap(Map<Object?, Object?> map) {
    final missing = (map['missing'] as List<Object?>? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
    return NearbyPermissionStatus(
      granted: missing.isEmpty && (map['granted'] as bool? ?? false),
      missing: missing,
      locationEnabled: map['locationEnabled'] as bool? ?? false,
      permanentlyDenied: map['permanentlyDenied'] as bool? ?? false,
    );
  }
}

/// Requests the dangerous permissions Nearby Connections needs.
///
/// Handled by `MainActivity` over a method channel rather than a permission
/// plugin, because the nearby_connections package requests nothing itself and a
/// failed request there surfaces only as an opaque SecurityException.
///
/// Every method degrades to "not ready" off-device, so the widget tests and any
/// non-Android build stay usable.
class NearbyPermissions {
  NearbyPermissions({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel('portfolio_app/nearby');

  final MethodChannel _channel;

  /// Reads the current status without prompting the user.
  Future<NearbyPermissionStatus> check() => _invoke('check');

  /// Prompts for anything outstanding and reports the result.
  Future<NearbyPermissionStatus> request() => _invoke('request');

  Future<NearbyPermissionStatus> _invoke(String method) async {
    if (kIsWeb) return NearbyPermissionStatus.unknown;
    try {
      final reply = await _channel.invokeMethod<Object?>(method);
      if (reply is Map) return NearbyPermissionStatus.fromMap(reply);
      return NearbyPermissionStatus.unknown;
    } on PlatformException {
      return NearbyPermissionStatus.unknown;
    } on MissingPluginException {
      // Non-Android target: nothing to grant.
      return NearbyPermissionStatus.unknown;
    }
  }
}

/// Deep links into the system screens where the remaining blockers are fixed.
///
/// Both are no-ops off-device, so the UI stays usable in tests.
class NearbySystem {
  NearbySystem({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel('portfolio_app/nearby');

  final MethodChannel _channel;

  /// Opens the location toggle, for when permissions are held but the OS
  /// location switch is off.
  Future<void> openLocationSettings() => _invoke('openLocationSettings');

  /// Opens this app's permission page, for a permanently denied permission.
  Future<void> openAppSettings() => _invoke('openAppSettings');

  Future<void> _invoke(String method) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException {
      // Nothing actionable; the screen still shows the manual instruction.
    } on MissingPluginException {
      // Non-Android target.
    }
  }
}