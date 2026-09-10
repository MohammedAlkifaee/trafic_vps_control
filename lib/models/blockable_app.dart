import 'package:flutter/material.dart';

/// A single app the parent can choose to block, identified by its Android
/// package name (the value the accessibility service matches against the
/// foreground app).
class BlockableApp {
  const BlockableApp({
    required this.packageName,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String packageName;
  final String name;
  final IconData icon;
  final Color color;
}

/// Curated list of the apps a parent most often wants to block on a child's
/// phone. WhatsApp is first because it is the primary target of this app.
///
/// Using a fixed catalog (instead of enumerating every installed app) avoids
/// the `QUERY_ALL_PACKAGES` permission, which keeps the app off Google Play's
/// sensitive-permission review list.
const List<BlockableApp> kBlockableApps = [
  BlockableApp(
    packageName: 'com.whatsapp',
    name: 'WhatsApp',
    icon: Icons.chat_bubble,
    color: Color(0xFF25D366),
  ),
  BlockableApp(
    packageName: 'com.whatsapp.w4b',
    name: 'WhatsApp Business',
    icon: Icons.business_center,
    color: Color(0xFF075E54),
  ),
  BlockableApp(
    packageName: 'com.instagram.android',
    name: 'Instagram',
    icon: Icons.camera_alt,
    color: Color(0xFFE1306C),
  ),
  BlockableApp(
    packageName: 'com.zhiliaoapp.musically',
    name: 'TikTok',
    icon: Icons.music_note,
    color: Color(0xFF010101),
  ),
  BlockableApp(
    packageName: 'com.snapchat.android',
    name: 'Snapchat',
    icon: Icons.snapchat,
    color: Color(0xFFFFFC00),
  ),
  BlockableApp(
    packageName: 'org.telegram.messenger',
    name: 'Telegram',
    icon: Icons.send,
    color: Color(0xFF0088CC),
  ),
  BlockableApp(
    packageName: 'com.facebook.katana',
    name: 'Facebook',
    icon: Icons.facebook,
    color: Color(0xFF1877F2),
  ),
  BlockableApp(
    packageName: 'com.facebook.orca',
    name: 'Messenger',
    icon: Icons.messenger,
    color: Color(0xFF0084FF),
  ),
  BlockableApp(
    packageName: 'com.google.android.youtube',
    name: 'YouTube',
    icon: Icons.play_circle_fill,
    color: Color(0xFFFF0000),
  ),
  BlockableApp(
    packageName: 'com.twitter.android',
    name: 'X (Twitter)',
    icon: Icons.tag,
    color: Color(0xFF000000),
  ),
];

/// Package that this app blocks out of the box.
const String kDefaultBlockedPackage = 'com.whatsapp';
