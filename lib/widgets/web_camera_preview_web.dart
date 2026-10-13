import 'package:web/web.dart' as web;

const _zxingScriptId = 'mobile-scanner-barcode-reader';
const _zxingScriptUrl = 'https://unpkg.com/@zxing/library@0.21.3';

/// Load the barcode library before the user taps Start, so the tap itself
/// can call getUserMedia while the browser still treats it as a gesture.
void prepareWebQrScanner() {
  if (web.document.querySelector('script#$_zxingScriptId') != null) return;
  final script = web.HTMLScriptElement()
    ..id = _zxingScriptId
    ..async = true
    ..src = _zxingScriptUrl;
  web.document.head?.appendChild(script);
}

/// iOS Safari will not show a camera preview unless the video is inline.
void markWebCameraPreviewInline() {
  final videos = web.document.querySelectorAll('video');
  for (var i = 0; i < videos.length; i++) {
    final node = videos.item(i);
    if (node == null) continue;
    final video = node as web.HTMLVideoElement;
    video
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true')
      ..muted = true
      ..autoplay = true;
    video.play();
  }
}
