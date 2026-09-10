import 'package:flutter/material.dart';

import 'vpn_home.dart';

void main() => runApp(const KidSafeVpnApp());

class KidSafeVpnApp extends StatelessWidget {
  const KidSafeVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KidSafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const VpnHome(),
    );
  }
}
