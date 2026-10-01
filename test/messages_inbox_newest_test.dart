import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = AuthService.allUsers['teacher'];
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('conversation lastActivityAt is the newest message time', () {
    final older = DateTime(2026, 1, 1);
    final newer = DateTime(2026, 10, 1);
    final chat = Conversation(
      id: 'order',
      name: 'Peer',
      role: 'Teacher',
      messages: [
        ChatMessage(
          text: 'old',
          senderRole: AuthService.roleTeacher,
          time: newer,
        ),
        ChatMessage(
          text: 'older',
          senderRole: AuthService.roleAdmin,
          time: older,
        ),
      ],
    );
    expect(chat.lastActivityAt, newer);
  });

  test('inbox lists threads with a new message first', () {
    final before = SchoolDataService.instance.getConversationsForRole(
      AuthService.roleTeacher,
    );
    expect(before.length, greaterThan(1));
    final olderThread = before.firstWhere((c) => c.id == '2');
    expect(before.first.id, isNot(olderThread.id));

    SchoolDataService.instance.sendMessage(
      olderThread.id,
      'Just now — please see this',
    );

    final after = SchoolDataService.instance.getConversationsForRole(
      AuthService.roleTeacher,
    );
    expect(after.first.id, olderThread.id);
    expect(after.first.messages.last.text, 'Just now — please see this');
    expect(
      after.first.lastActivityAt.isAfter(before.first.lastActivityAt),
      isTrue,
    );
  });
}
