/// MIME type for opening or downloading an attachment in the browser.
///
/// Filename extension is preferred; magic bytes cover the case where the
/// stored name has no useful extension (web then shows binary as garbled text).
String attachmentMimeType({
  required String fileName,
  List<int>? bytes,
}) {
  final fromName = _mimeFromFileName(fileName);
  if (fromName != null) return fromName;
  return _mimeFromBytes(bytes) ?? 'application/octet-stream';
}

/// Types a browser tab can display. Everything else should be downloaded.
bool attachmentOpensInBrowser(String mime) {
  return mime.startsWith('image/') ||
      mime.startsWith('text/') ||
      mime.startsWith('audio/') ||
      mime.startsWith('video/') ||
      mime == 'application/pdf' ||
      mime == 'application/json';
}

String? _mimeFromFileName(String fileName) {
  final q = fileName.split('?').first;
  final dot = q.lastIndexOf('.');
  if (dot < 0 || dot == q.length - 1) return null;
  final ext = q.substring(dot).toLowerCase();
  return switch (ext) {
    '.png' => 'image/png',
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.bmp' => 'image/bmp',
    '.svg' => 'image/svg+xml',
    '.pdf' => 'application/pdf',
    '.txt' || '.log' => 'text/plain',
    '.csv' => 'text/csv',
    '.json' => 'application/json',
    '.mp3' => 'audio/mpeg',
    '.wav' => 'audio/wav',
    '.m4a' => 'audio/mp4',
    '.aac' => 'audio/aac',
    '.ogg' => 'audio/ogg',
    '.mp4' => 'video/mp4',
    '.webm' => 'video/webm',
    '.mov' => 'video/quicktime',
    '.doc' => 'application/msword',
    '.docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.xls' => 'application/vnd.ms-excel',
    '.xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    '.ppt' => 'application/vnd.ms-powerpoint',
    '.pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    '.zip' => 'application/zip',
    _ => null,
  };
}

String? _mimeFromBytes(List<int>? bytes) {
  if (bytes == null || bytes.length < 4) return null;
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
    return 'image/gif';
  }
  if (bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46) {
    return 'application/pdf';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}
