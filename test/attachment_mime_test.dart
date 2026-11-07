import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/utils/attachment_mime.dart';

void main() {
  test('JPEG magic bytes open as an image even without a filename extension',
      () {
    final jpeg = <int>[0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0];
    expect(
      attachmentMimeType(fileName: 'message_attachment', bytes: jpeg),
      'image/jpeg',
    );
    expect(attachmentOpensInBrowser('image/jpeg'), isTrue);
  });

  test('PDF and PNG names keep their types', () {
    expect(
      attachmentMimeType(fileName: 'notes.pdf', bytes: const [1, 2, 3, 4]),
      'application/pdf',
    );
    expect(
      attachmentMimeType(
        fileName: 'photo.png',
        bytes: const [0x89, 0x50, 0x4E, 0x47],
      ),
      'image/png',
    );
  });

  test('Office documents download instead of opening in a tab', () {
    expect(
      attachmentMimeType(fileName: 'letter.docx'),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(
      attachmentOpensInBrowser(
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ),
      isFalse,
    );
  });
}
