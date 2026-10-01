import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/mesh_chat_service.dart';
import '../services/network_diagnostic_tool.dart';
import '../widgets/module_card.dart';
import 'activity1_screen.dart';
import 'local_mesh_chat_screen.dart';
import 'network_diagnostic_screen.dart';
import 'network_monitor_screen.dart';
import 'settings_screen.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  /// Live mesh summary, injected from the global MeshChatService so the
  /// dashboard reflects peer connectivity without opening the chat screen.
  Widget _buildMeshStatus(
    BuildContext context,
    ThemeData theme,
    MeshChatService mesh,
  ) {
    final live = mesh.isActive;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: live
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            live ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            size: 20,
            color: live
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              live
                  ? 'Mesh active · ${mesh.peers.length} peer(s) found · '
                      '${mesh.state.connectedCount} connected'
                  : 'Mesh chat is idle. Open Activity 4 to start discovery.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: live
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final diagnostic = context.watch<NetworkDiagnosticTool>();
    final mesh = context.watch<MeshChatService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Flutter Portfolio'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => _goTo(context, const SettingsScreen()),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${appState.userName}!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Everything I build for my lab goes in here, '
                      'one activity at a time.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          appState.isDarkMode
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          size: 18,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          appState.isDarkMode
                              ? 'Dark mode is ON'
                              : 'Light mode is ON',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Live Diagnostic',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: diagnostic.health.containerColor(theme.brightness),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: Icon(
                    diagnostic.health.icon,
                    color: diagnostic.health.color(theme.brightness),
                    size: 32,
                  ),
                  title: Text(
                    '${diagnostic.health.label} connection',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: diagnostic.health.color(theme.brightness),
                    ),
                  ),
                  subtitle: Text(
                    '${diagnostic.downloadMbps.toStringAsFixed(1)} Mbps down '
                    '· ${diagnostic.idlePingMs >= 9999 ? '—' : diagnostic.idlePingMs.toStringAsFixed(0)} ms ping'
                    '${diagnostic.interfaceLabel == 'Offline' ? ' · OFFLINE' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: diagnostic.isRunning
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: diagnostic
                                .health
                                .color(theme.brightness),
                          ),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () => _goTo(context, const NetworkDiagnosticScreen()),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Laboratory Activities',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ModuleCard(
                title: 'Activity 1: Tap Counter',
                subtitle: 'A simple stateful counter screen.',
                icon: Icons.touch_app_outlined,
                onTap: () => _goTo(context, const Activity1Screen()),
              ),
              const SizedBox(height: 12),
              ModuleCard(
                title: 'Activity 2: Network Monitor',
                subtitle: 'Watch the network switch live and get '
                    'downloads back on track automatically.',
                icon: Icons.network_check_outlined,
                onTap: () => _goTo(context, const NetworkMonitorScreen()),
              ),
              const SizedBox(height: 12),
              ModuleCard(
                title: 'Activity 3: Network Diagnostic Dashboard',
                subtitle: 'Idle ping, download, and upload bandwidth tests '
                    'that rate connection health live.',
                icon: Icons.speed_outlined,
                onTap: () => _goTo(context, const NetworkDiagnosticScreen()),
              ),
              const SizedBox(height: 12),
              ModuleCard(
                title: 'Activity 4: Local Mesh Chat',
                subtitle: 'Chat with nearby phones over Bluetooth and local '
                    'Wi-Fi. No internet, no server.',
                icon: Icons.forum_outlined,
                onTap: () => _goTo(context, const LocalMeshChatScreen()),
              ),
              const SizedBox(height: 16),
              _buildMeshStatus(context, theme, mesh),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Made with Flutter',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}