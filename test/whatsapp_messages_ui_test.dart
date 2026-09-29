import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/screens/messages_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/presence_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/widgets/app_floating_chrome.dart';
import 'package:mayabela/widgets/chat_contact_profile.dart';
import 'package:mayabela/widgets/messages_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = AuthService.allUsers['teacher'];
  });

  tearDown(() {
    PresenceService.instance.resetForTests();
    AuthService.allUsers.remove('nabil');
    AuthService.currentUser = null;
  });

  test('teacher profile resolves email and phone from registry', () {
    final profile = ChatContactDirectory.fromStaffId(
      StaffMemberOption.teacherKey('TCH-1001'),
    );
    expect(profile.name, contains('Belen'));
    expect(profile.email, 'belen@mayaschool.et');
    expect(profile.phone, isNotNull);
    expect(profile.phone, isNotEmpty);
  });

  test('parent profile resolves email and phone from the account', () {
    final profile = ChatContactDirectory.fromParentUsername('parent');
    expect(profile.name, 'Mr. Bekele');
    expect(profile.email, 'parent@mayaschool.et');
    expect(profile.phone, '0911000002');
    expect(profile.roleLabel.toLowerCase(), contains('parent'));
  });

  test('inbox rows show the other person, not a stuffed role title', () {
    AuthService.currentUser = AuthService.allUsers['teacher'];
    final conversation = SchoolDataService.instance.getConversation('1')!;
    final title = conversation.inboxTitleForViewer();
    expect(title, contains('Bekele'));
    expect(title, isNot(contains('(')));
    expect(conversation.inboxPeerRoleLabel(), 'Parent');
    final preview = conversation.lastMessagePreviewForViewer();
    expect(preview, conversation.lastMessage);
    expect(preview, isNot(contains('Bekele')));
  });

  test('when Nabil writes Belen, Belen sees Nabil — not School Admin', () {
    AuthService.allUsers['nabil'] = RegisteredUser(
      username: 'nabil',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
      fullName: 'Nabil Ahmed',
      linkedAdminId: 'ADM-1001',
    );
    AuthService.currentUser = AuthService.allUsers['nabil'];

    final ids = SchoolDataService.instance.sendAdminDirectMessage(
      body: 'Belen, can we meet after class?',
      staffId: StaffMemberOption.teacherKey('TCH-1001'),
    );
    expect(ids, isNotEmpty);

    AuthService.currentUser = AuthService.allUsers['teacher'];
    final conversation = SchoolDataService.instance.getConversation(
      ids.single,
    )!;
    expect(conversation.inboxTitleForViewer(), 'Nabil Ahmed');
    expect(conversation.inboxTitleForViewer(), isNot(contains('School Admin')));
    expect(
      conversation.lastMessagePreviewForViewer(),
      'Belen, can we meet after class?',
    );
  });

  test('staff inbox title uses the other person name and role', () {
    AuthService.currentUser = AuthService.allUsers['teacher'];
    final conversation = SchoolDataService.instance.getConversation('2')!;
    expect(conversation.inboxTitleForViewer(), isNotEmpty);
    expect(conversation.inboxPeerRoleLabel(), isNotNull);
  });

  test('incoming parent message opens the parent contact details', () {
    AuthService.currentUser = AuthService.allUsers['teacher'];
    final conversation = SchoolDataService.instance.getConversation('1');
    expect(conversation, isNotNull);
    final incoming = conversation!.messages.firstWhere(
      (m) => m.senderRole == AuthService.roleParent,
    );
    final profile = ChatContactDirectory.fromMessage(
      incoming,
      conversation: conversation,
    );
    expect(profile.email, 'parent@mayaschool.et');
    expect(profile.phone, isNotEmpty);
  });

  test('direct conversation peer profile is the other person', () {
    AuthService.currentUser = AuthService.allUsers['teacher'];
    final conversation = SchoolDataService.instance.getConversation('1');
    expect(conversation, isNotNull);
    final profile = ChatContactDirectory.fromConversationPeer(conversation!);
    expect(profile.email, 'parent@mayaschool.et');
    expect(profile.phone, isNotEmpty);
  });

  testWidgets('contact profile screen shows email and phone', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatContactProfileScreen(
          profile: ChatContactProfile(
            name: 'Miss Belen',
            roleLabel: 'Teacher',
            email: 'belen@mayaschool.et',
            phone: '0911000001',
          ),
        ),
      ),
    );
    expect(find.byKey(ChatContactProfileScreen.screenKey), findsOneWidget);
    expect(find.text('Miss Belen'), findsOneWidget);
    expect(find.text('belen@mayaschool.et'), findsOneWidget);
    expect(find.text('0911000001'), findsOneWidget);
  });

  testWidgets('inbox shows WhatsApp-style chats communities broadcasts tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MessagesScreen()));
    await tester.pump();
    final s = AppLocale.instance.strings;
    expect(find.text(s.messageChatsTab), findsOneWidget);
    expect(find.text(s.messageGroupChats), findsOneWidget);
    expect(find.text(s.messageBroadcasts), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(ConversationCard), findsWidgets);
    expect(find.textContaining('Parent'), findsWidgets);
    expect(find.textContaining('Bekele'), findsWidgets);
    PresenceService.instance.resetForTests();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tapping a sender name opens contact info', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(conversationId: '1', contactName: 'Mr. Bekele'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TappableSenderName), findsWidgets);
    await tester.tap(find.byType(TappableSenderName).first);
    await tester.pumpAndSettle();
    expect(find.byKey(ChatContactProfileScreen.screenKey), findsOneWidget);
    expect(find.text('parent@mayaschool.et'), findsOneWidget);
    expect(find.text('0911000002'), findsOneWidget);
  });

  testWidgets('compose plus does not overlap the Maya AI launcher', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppFloatingChrome(child: MessagesScreen())),
    );
    await tester.pump();
    final compose = tester.getRect(
      find.byKey(const Key('messages-compose-fab')),
    );
    final ai = tester.getRect(find.byIcon(Icons.auto_awesome));
    expect(compose.overlaps(ai), isFalse);
    expect(compose.bottom, lessThanOrEqualTo(ai.top - 8));
    PresenceService.instance.resetForTests();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
