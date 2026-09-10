import 'package:flutter/material.dart';

import '../models/blockable_app.dart';
import '../services/blocker_store.dart';

/// Lets the parent choose which apps from the curated catalog are blocked.
class ManageAppsScreen extends StatelessWidget {
  const ManageAppsScreen({super.key, required this.store});
  final BlockerStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose apps to block')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return ListView.separated(
            itemCount: kBlockableApps.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final app = kBlockableApps[i];
              final blocked = store.isBlocked(app.packageName);
              return SwitchListTile(
                secondary: CircleAvatar(
                  backgroundColor: app.color.withValues(alpha: 0.15),
                  child: Icon(app.icon, color: app.color),
                ),
                title: Text(app.name),
                subtitle: Text(app.packageName,
                    style: Theme.of(context).textTheme.bodySmall),
                value: blocked,
                onChanged: (v) => store.setAppBlocked(app.packageName, v),
              );
            },
          );
        },
      ),
    );
  }
}
