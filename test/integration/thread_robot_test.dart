import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:tmail_ui_user/features/base/model/ui_keys.dart';

import '../../integration_test/robots/thread_robot.dart';

class _UnusedPlatformAutomator extends Fake implements PlatformAutomator {}

void main() {
  for (final key in const <Key>[
    Key(UiKeys.composeEmailPrimaryAction),
    Key('compose_email_button_collapsed'),
    Key(UiKeys.composeEmailButton),
  ]) {
    testWidgets('openComposer waits for delayed compose action $key', (
      tester,
    ) async {
      var composeCalls = 0;
      final ready = Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FutureBuilder<void>(
              future: ready,
              builder: (context, snapshot) =>
                  snapshot.connectionState == ConnectionState.done
                  ? FilledButton(
                      key: key,
                      onPressed: () => composeCalls++,
                      child: const Text('Compose'),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      expect(find.byKey(key), findsNothing);

      final patrolTester = PatrolIntegrationTester(
        tester: tester,
        config: const PatrolTesterConfig(
          visibleTimeout: Duration(seconds: 2),
          settlePolicy: SettlePolicy.noSettle,
        ),
        platformAutomator: _UnusedPlatformAutomator(),
      );
      await ThreadRobot(patrolTester).openComposer();

      expect(composeCalls, 1);
    });
  }
}
