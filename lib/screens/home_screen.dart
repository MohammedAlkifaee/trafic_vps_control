import 'package:flutter/material.dart';

import '../models/blockable_app.dart';
import '../services/blocker_store.dart';
import '../services/native_blocker.dart';
import 'manage_apps_screen.dart';

/// Parent dashboard: permission setup, the master blocking switch, and a
/// summary of what is currently blocked.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final BlockerStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _accessibilityOn = false;
  bool _overlayOn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when the parent returns from a system settings screen.
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final a = await NativeBlocker.isAccessibilityEnabled();
    final o = await NativeBlocker.canDrawOverlays();
    if (!mounted) return;
    setState(() {
      _accessibilityOn = a;
      _overlayOn = o;
      _loading = false;
    });
  }

  bool get _ready => _accessibilityOn && _overlayOn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KidSafe'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Re-check permissions',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPermissions,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPermissions,
        child: AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _StatusBanner(
                  ready: _ready,
                  enabled: widget.store.blockingEnabled,
                  loading: _loading,
                ),
                const SizedBox(height: 16),
                _SetupSection(
                  accessibilityOn: _accessibilityOn,
                  overlayOn: _overlayOn,
                  onEnableAccessibility:
                      NativeBlocker.openAccessibilitySettings,
                  onEnableOverlay: NativeBlocker.requestOverlayPermission,
                ),
                const SizedBox(height: 16),
                _MasterSwitch(store: widget.store, ready: _ready),
                const SizedBox(height: 16),
                _BlockedSummary(store: widget.store),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner(
      {required this.ready, required this.enabled, required this.loading});
  final bool ready;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final active = ready && enabled;
    final Color bg;
    final IconData icon;
    final String title;
    final String subtitle;

    if (loading) {
      bg = Colors.grey.shade200;
      icon = Icons.hourglass_empty;
      title = 'Checking status…';
      subtitle = '';
    } else if (active) {
      bg = const Color(0xFF16A34A);
      icon = Icons.verified_user;
      title = 'Protection is active';
      subtitle = 'Blocked apps will be stopped when opened.';
    } else if (!ready) {
      bg = const Color(0xFFF59E0B);
      icon = Icons.warning_amber_rounded;
      title = 'Setup needed';
      subtitle = 'Grant the two permissions below to start blocking.';
    } else {
      bg = const Color(0xFF64748B);
      icon = Icons.pause_circle_filled;
      title = 'Blocking is paused';
      subtitle = 'Turn the switch back on to resume.';
    }

    final onColor = loading ? Colors.black87 : Colors.white;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: onColor, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: onColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: onColor)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupSection extends StatelessWidget {
  const _SetupSection({
    required this.accessibilityOn,
    required this.overlayOn,
    required this.onEnableAccessibility,
    required this.onEnableOverlay,
  });

  final bool accessibilityOn;
  final bool overlayOn;
  final VoidCallback onEnableAccessibility;
  final VoidCallback onEnableOverlay;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Permissions',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Android requires these to be enabled by hand — they cannot be turned on automatically.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _PermissionTile(
              title: 'Accessibility service',
              description: 'Lets KidSafe notice which app is open.',
              granted: accessibilityOn,
              onEnable: onEnableAccessibility,
            ),
            const Divider(height: 24),
            _PermissionTile(
              title: 'Display over other apps',
              description: 'Lets KidSafe show the block screen on top.',
              granted: overlayOn,
              onEnable: onEnableOverlay,
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.description,
    required this.granted,
    required this.onEnable,
  });

  final String title;
  final String description;
  final bool granted;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: granted ? const Color(0xFF16A34A) : Colors.grey,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(description,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 8),
        granted
            ? const Text('On', style: TextStyle(color: Color(0xFF16A34A)))
            : FilledButton.tonal(onPressed: onEnable, child: const Text('Enable')),
      ],
    );
  }
}

class _MasterSwitch extends StatelessWidget {
  const _MasterSwitch({required this.store, required this.ready});
  final BlockerStore store;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text('Blocking',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(store.blockingEnabled
            ? 'Blocked apps are stopped when opened.'
            : 'All apps are currently allowed.'),
        value: store.blockingEnabled,
        onChanged: ready ? (v) => store.setBlockingEnabled(v) : null,
      ),
    );
  }
}

class _BlockedSummary extends StatelessWidget {
  const _BlockedSummary({required this.store});
  final BlockerStore store;

  @override
  Widget build(BuildContext context) {
    final blocked = kBlockableApps
        .where((a) => store.isBlocked(a.packageName))
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Blocked apps (${store.blockedCount})',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ManageAppsScreen(store: store),
                    ));
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (blocked.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No apps blocked yet. Tap Manage to choose some.'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: blocked
                    .map((a) => Chip(
                          avatar: Icon(a.icon, size: 18, color: a.color),
                          label: Text(a.name),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
