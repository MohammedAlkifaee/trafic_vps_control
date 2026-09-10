// Smoke test for the KidSafe VPN client. The native VPN channel doesn't exist
// on the test host, so we mock it.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kidsafe/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.kidsafe/vpn');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'status':
          return 'DOWN';
        case 'connect':
          return 'UP';
        case 'disconnect':
          return 'DOWN';
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('auto-connects, shows no Disconnect button, then self-exits',
      (tester) async {
    await tester.pumpWidget(const KidSafeVpnApp());
    await tester.pump(); // build → connecting
    await tester.pump(const Duration(milliseconds: 100)); // connect resolves

    // Requirement: there must be no disconnect control.
    expect(find.text('Disconnect'), findsNothing);
    expect(find.byType(KidSafeVpnApp), findsOneWidget);

    // Flush the ~900ms self-exit timer so no timer stays pending.
    await tester.pump(const Duration(seconds: 1));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
