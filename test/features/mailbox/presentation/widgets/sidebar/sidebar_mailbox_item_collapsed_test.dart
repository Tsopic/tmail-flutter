import 'package:core/presentation/resources/image_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/unsigned_int.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:model/mailbox/presentation_mailbox.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/model/mailbox_node.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/widgets/sidebar/sidebar_mailbox_item.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations_delegate.dart';
import 'package:tmail_ui_user/main/localizations/localization_service.dart';

void main() {
  testWidgets(
    'collapsed rows display unread count and retain mailbox selection',
    (tester) async {
      final node = _node(unread: 7);
      MailboxNode? opened;
      await _pump(tester, node, onOpen: (mailbox) => opened = mailbox);

      expect(find.text('7'), findsOneWidget);
      expect(find.text('Custom folder'), findsNothing);
      expect(find.byType(Tooltip), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      expect(opened, same(node));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'collapsed unread count is capped and respects mailbox role exclusions',
    (tester) async {
      await _pump(tester, _node(unread: 1000));
      expect(find.text('999+'), findsOneWidget);

      await _pump(tester, _node(unread: 0));
      expect(find.text('0'), findsNothing);
      expect(find.text('999+'), findsNothing);

      for (final role in [
        PresentationMailbox.roleTrash,
        PresentationMailbox.roleSpam,
        PresentationMailbox.roleDrafts,
      ]) {
        await _pump(tester, _node(unread: 7, role: role));
        expect(find.text('7'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
}

MailboxNode _node({required int unread, Role? role}) => MailboxNode(
  PresentationMailbox(
    MailboxId(Id('folder')),
    name: MailboxName('Custom folder'),
    role: role,
    unreadEmails: UnreadEmails(UnsignedInt(unread)),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  MailboxNode node, {
  void Function(MailboxNode?)? onOpen,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 48,
          child: SidebarMailboxItem(
            mailboxNode: node,
            imagePaths: ImagePaths(),
            isWebDesktop: true,
            isCollapsed: true,
            onOpenMailboxFolderClick: onOpen,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
