import 'package:share_plus/share_plus.dart';

import 'package:mayabela/services/student_account_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

class StudentCredentialsService {
  StudentCredentialsService._();
  static final instance = StudentCredentialsService._();

  Future<void> share(AdminStudentRecord student) async {
    await Share.share(
      StudentAccountService.instance.buildCredentialsMessage(student),
      subject: 'Student portal login — ${student.fullName}',
    );
  }
}
