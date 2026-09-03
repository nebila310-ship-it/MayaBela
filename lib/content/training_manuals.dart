class TrainingArticle {
  const TrainingArticle({
    required this.id,
    required this.audience,
    required this.title,
    required this.summary,
    required this.body,
  });

  final String id;
  final String audience;
  final String title;
  final String summary;
  final String body;
}

/// Short in-app training for LIA go-live. Not a substitute for a live workshop.
abstract final class TrainingManuals {
  static const audiences = ['admin', 'teacher', 'parent'];

  static List<TrainingArticle> all() => [
        const TrainingArticle(
          id: 'admin-login',
          audience: 'admin',
          title: 'Sign in and stay signed in',
          summary: 'School ID, role tile, and optional authenticator.',
          body:
              'Open MayaBela and choose Administration Staff. Enter the School ID '
              'your office issued, then your username and password.\n\n'
              'Authenticator (MFA) is optional. Enroll it from Settings after '
              'the first successful sign-in. Admin is never forced to enroll on '
              'first boot.\n\n'
              'If the live site looks old, hard-refresh with Ctrl+Shift+R.',
        ),
        const TrainingArticle(
          id: 'admin-students',
          audience: 'admin',
          title: 'Students and Excel import',
          summary: 'Add one student or import a class list.',
          body:
              'Use Students → Add student for a single child. Required fields: '
              'full name, grade, class, and date of birth. MayaBela assigns a '
              'short STU-#### id.\n\n'
              'For a class list, open Go-live → Import and pick a CSV or Excel '
              'file with columns for name, grade, class, and date of birth. '
              'Preview the rows, then import. Duplicates (same name + class, or '
              'an existing id) are skipped. This does not write grades or exams.',
        ),
        const TrainingArticle(
          id: 'admin-privacy',
          audience: 'admin',
          title: 'Privacy, access, and erasure',
          summary: 'Consent register and data-rights queue.',
          body:
              'Parents and students can record consent and file access or '
              'erasure requests from Settings or their dashboard.\n\n'
              'Access exports the student profile and consents only. Counseling '
              'staff notes and safeguarding files are never included.\n\n'
              'Erasure redacts phones, parent names, and photos. The student id '
              'and markbook rows stay so grades are not orphaned. Do not delete '
              'the registry row.',
        ),
        const TrainingArticle(
          id: 'admin-backup',
          audience: 'admin',
          title: 'School backups',
          summary: 'Snapshot the school desk before a term cutover.',
          body:
              'Go-live → Backups writes a school snapshot (counts and a student '
              'directory without passwords or authenticator secrets).\n\n'
              'Platform-owner registry restore is a separate drill '
              '(tools/restore_drill_staging.mjs). This button does not replace '
              'that owner tool.',
        ),
        const TrainingArticle(
          id: 'teacher-class',
          audience: 'teacher',
          title: 'Classroom daily path',
          summary: 'Attendance, homework, markbook, messages.',
          body:
              'Sign in as Teacher. Open My classes for the roster, then '
              'Attendance, Homework, and Grade reports.\n\n'
              'Markbook weights stay as the school configured them. Do not ask '
              'IT to invent a second grade store.\n\n'
              'Optional authenticator lives under Settings. Lesson plans and '
              'exams are on the Teaching tools row.',
        ),
        const TrainingArticle(
          id: 'teacher-parents',
          audience: 'teacher',
          title: 'Parents and approvals',
          summary: 'Linked parents and the approval queue.',
          body:
              'Parent Approvals is where new parent-link requests land. Approve '
              'only after you recognise the child.\n\n'
              'Messages stay on the shared parent-teacher thread. Do not send '
              'safeguarding detail in chat — use the Student support desk.',
        ),
        const TrainingArticle(
          id: 'parent-start',
          audience: 'parent',
          title: 'See your children',
          summary: 'School ID, phone login, and the children tile.',
          body:
              'Choose Parent, enter the School ID, and sign in with the phone '
              'number the school has on file.\n\n'
              'My children opens grades, attendance, homework, and bus tracking '
              'for linked students only. You will not see another family’s data.',
        ),
        const TrainingArticle(
          id: 'parent-privacy',
          audience: 'parent',
          title: 'Consent and data requests',
          summary: 'Grant consent or ask for a copy / redaction.',
          body:
              'Open Privacy from Settings or the dashboard. Record consent for '
              'data processing, photos, messaging, or transport.\n\n'
              'File an access request to receive a profile + consent export. '
              'File an erasure request if you want personal fields redacted. '
              'The school reviews the queue; grades and the student id stay.',
        ),
      ];

  static List<TrainingArticle> forAudience(String audience) {
    final key = audience.trim().toLowerCase();
    return all().where((item) => item.audience == key).toList();
  }
}
