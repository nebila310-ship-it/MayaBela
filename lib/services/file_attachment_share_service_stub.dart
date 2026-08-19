import 'file_attachment_share_service.dart';

Future<AttachmentShareResult> sharePath(
  String path, {
  String? subject,
}) async {
  return const AttachmentShareResult(success: false, message: 'not_found');
}

Future<AttachmentShareResult> downloadPath(String path) async {
  return const AttachmentShareResult(success: false, message: 'not_found');
}
