import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/mesh_chat_service.dart';
import '../services/mesh_chat_state.dart';
import '../services/nearby_permissions.dart';

/// Activity 4: Local Mesh Chat.
///
/// The whole screen is a pure function of [MeshChatService] state — it renders
/// whatever the service exposes and never mutates state itself. Every user
/// gesture is a method call on the service, which then broadcasts through
/// Provider.
class LocalMeshChatScreen extends StatefulWidget {
  const LocalMeshChatScreen({super.key});

  @override
  State<LocalMeshChatScreen> createState() => _LocalMeshChatScreenState();
}

class _LocalMeshChatScreenState extends State<LocalMeshChatScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _submit(MeshChatService service) {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    service.send(text);
    _composer.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.watch<MeshChatService>();
    final state = service.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Activity 4: Local Mesh Chat')),
      body: SafeArea(
        child: Column(
          children: [
            _buildMeshCard(theme, service, state),
            const SizedBox(height: 8),
            Expanded(
              child: _buildBody(theme, service, state),
            ),
            _buildComposer(theme, service),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    MeshChatService service,
    MeshChatState state,
  ) {
    if (state.peers.isEmpty && state.transcript.isEmpty) {
      return _EmptyState(active: state.isActive);
    }
    return _buildTranscript(theme, state);
  }

  // ---------------------------------------------------------------------
  // Mesh status
  // ---------------------------------------------------------------------

  Widget _buildMeshCard(
    ThemeData theme,
    MeshChatService service,
    MeshChatState state,
  ) {
    final live = state.isActive && state.transportLive;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: live
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Laid out as a Wrap so the Start/Stop button drops onto its own line on
            // narrow screens instead of overflowing the status text.
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  live ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: live
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                SizedBox(
                  // Intrinsic width of the text block, capped so it still wraps
                  // on a small screen rather than forcing a horizontal overflow.
                  width: (MediaQuery.sizeOf(context).width - 140)
                      .clamp(160.0, 340.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        live ? 'Mesh is live' : 'Mesh is offline',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Identity: ${state.localName}  ·  '
                        'advertising: ${state.advertising ? 'on' : 'off'}  ·  '
                        'scanning: ${state.discovering ? 'on' : 'off'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: live
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: service.toggleMesh,
                  icon: Icon(
                    live ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                    size: 18,
                  ),
                  label: Text(live ? 'Stop' : 'Start'),
                ),
              ],
            ),
            if (state.peers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Nearby peers (${state.peers.length} found · '
                '${state.connectedCount} connected)',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              for (final peer in state.peers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _PeerTile(
                    peer: peer,
                    onPair: () => service.pairWith(peer),
                    onDisconnect: () => service.disconnect(peer),
                  ),
                ),
            ],
            if (state.permissionHint != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.permissionHint!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          if (state.permissionStatus.needsLocationToggle ||
                              state.permissionStatus.needsSettings) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (state.permissionStatus
                                    .needsLocationToggle)
                                  OutlinedButton.icon(
                                    onPressed: () => NearbySystem()
                                        .openLocationSettings(),
                                    icon:
                                        const Icon(Icons.my_location, size: 16),
                                    label: const Text('Turn on Location'),
                                  ),
                                if (state.permissionStatus.needsSettings)
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        NearbySystem().openAppSettings(),
                                    icon: const Icon(Icons.settings, size: 16),
                                    label: const Text('Open Settings'),
                                  ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await service.refreshPermissionStatus();
                                  },
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Re-check'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Transcript
  // ---------------------------------------------------------------------

  Widget _buildTranscript(ThemeData theme, MeshChatState state) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: state.transcript.length,
      itemBuilder: (context, index) {
        final entry = state.transcript[index];
        if (entry.message.kind == 'system') {
          return _SystemLine(text: entry.message.body);
        }
        return _Bubble(theme: theme, entry: entry);
      },
    );
  }

  // ---------------------------------------------------------------------
  // Composer
  // ---------------------------------------------------------------------

  Widget _buildComposer(ThemeData theme, MeshChatService service) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _composer,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(service),
                decoration: InputDecoration(
                  hintText: 'Message nearby peers...',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send to mesh',
              onPressed: () => _submit(service),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeerTile extends StatelessWidget {
  final MeshPeer peer;
  final VoidCallback onPair;
  final VoidCallback onDisconnect;

  const _PeerTile({
    required this.peer,
    required this.onPair,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, color, label) = switch (peer.status) {
      PeerStatus.connected => (
          Icons.link,
          Colors.green,
          'Connected - socket open'
        ),
      PeerStatus.handshaking => (
          Icons.sync,
          Colors.orange,
          'Pairing...'
        ),
      PeerStatus.failed => (
          Icons.link_off,
          theme.colorScheme.error,
          'Last attempt failed'
        ),
      PeerStatus.discovered => (
          Icons.bluetooth_searching,
          theme.colorScheme.primary,
          'Discovered - ready to pair'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$label · id ${peer.shortId}',
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
          if (peer.status == PeerStatus.connected)
            IconButton(
              tooltip: 'Disconnect',
              onPressed: onDisconnect,
              icon: const Icon(Icons.link_off, size: 18),
            )
          else
            TextButton(
              onPressed: onPair,
              child: const Text('Pair'),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ThemeData theme;
  final MeshLogEntry entry;

  const _Bubble({required this.theme, required this.entry});

  String get _stamp {
    final t = entry.message.sentAt;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final mine = entry.outgoing;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!mine)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      entry.peerName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: mine
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(mine ? 16 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    entry.message.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mine
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    _stamp,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemLine extends StatelessWidget {
  final String text;

  const _SystemLine({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: [
          // Fixed-width rules: an Expanded divider cannot shrink below nothing
          // usefully here, and letting the label grow is what overflowed the row.
          const SizedBox(width: 12, child: Divider()),
          const SizedBox(width: 10),
          // Flexible, so a long notification wraps onto more lines instead of
          // spilling past both edges of a narrow screen.
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox(width: 12, child: Divider()),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool active;

  const _EmptyState({required this.active});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? Icons.radar : Icons.bluetooth_searching,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              active ? 'Scanning for nearby devices...' : 'Mesh is not running',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              active
                  ? 'Keep this screen open on two Android phones with the '
                      'app installed. They should appear in the peer list '
                      'automatically - no server, no internet needed.'
                  : 'Tap Start to broadcast this device and start scanning for '
                      'neighbours over Bluetooth and local Wi-Fi.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}