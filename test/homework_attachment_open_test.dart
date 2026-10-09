import 'package:flutter_test/flutter_test.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/profile_photo_codec.dart';
import 'package:mayabela/utils/web_file_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const homeworkUrl =
      'https://example.supabase.co/storage/v1/object/public/school-files/'
      'schools/TB-001/homework_attachments/hw1_worksheet.pdf';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'parent.hw',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
    WebAttachmentCache.instance.remove(homeworkUrl);
  });

  test('homework cloud attachments are private school-files objects', () {
    expect(ProfilePhotoCodec.isPrivateSchoolFilesUrl(homeworkUrl), isTrue);
    expect(ProfilePhotoCodec.isDeviceLocalPath(homeworkUrl), isFalse);
  });

  test('opening a private homework URL without bytes does not pretend success',
      () async {
    final opened = await WebFileUtils.openOrDownload(
      filePath: homeworkUrl,
      fileName: 'worksheet.pdf',
    );
    expect(opened, isFalse);
  });

  test('opening a homework attachment uses hydrated bytes, not the 404 URL',
      () async {
    WebAttachmentCache.instance.remember(
      homeworkUrl,
      List<int>.filled(32, 7),
    );
    final opened = await WebFileUtils.openOrDownload(
      filePath: homeworkUrl,
      fileName: 'worksheet.pdf',
    );
    expect(opened, isTrue);
  });

  test('openAttachment does not treat a private 404 URL as success', () async {
    final result = await AnnouncementAttachmentService.instance.openAttachment(
      AnnouncementAttachment(
        id: 'hw-att-1',
        fileName: 'worksheet.pdf',
        filePath: homeworkUrl,
      ),
    );
    expect(result.type, isNot(ResultType.done));
  });

  test('homework cloud map drops laptop-only attachment paths', () {
    final item = HomeworkItem(
      id: 'HW-404',
      className: 'Grade 4A',
      subject: 'Math',
      description: 'Worksheet',
      teacherName: 'Miss Belen',
      teacherId: 'TCH-1',
      postedAt: DateTime.utc(2026, 10, 9),
      attachmentPaths: const [
        'web://1/local.pdf',
        homeworkUrl,
      ],
    );
    final map = CloudAppStore.instance.homeworkCloudMapForTest(item);
    expect(map['attachmentPaths'], [homeworkUrl]);
  });
}
