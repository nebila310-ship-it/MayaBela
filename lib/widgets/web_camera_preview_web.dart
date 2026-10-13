import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:web/web.dart' as web;

const _zxingScriptId = 'mobile-scanner-barcode-reader';
const _zxingScriptUrl = 'zxing.min.js';

Future<void>? _zxingLoad;

/// Load the barcode library from this site before the camera starts.
///
/// The hosted site blocks unpkg.com, so the scanner cannot fetch ZXing from
/// there. Starting the camera before `ZXing` exists throws
/// "Null check operator used on a null value".
Future<void> prepareWebQrScanner() {
  return _zxingLoad ??= _loadZxing().catchError((
    Object error,
    StackTrace stack,
  ) {
    _zxingLoad = null;
    Error.throwWithStackTrace(error, stack);
  });
}

Future<void> _loadZxing() async {
  MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(_zxingScriptUrl);
  _ensureScriptTag();
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (!_zxingLibraryReady()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Barcode library did not load');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void _ensureScriptTag() {
  if (web.document.querySelector('script#$_zxingScriptId') != null) return;
  final script = web.HTMLScriptElement()
    ..id = _zxingScriptId
    ..async = true
    ..src = _zxingScriptUrl;
  web.document.head?.appendChild(script);
}

bool _zxingLibraryReady() {
  final zxing = globalContext.getProperty<JSAny?>('ZXing'.toJS);
  if (zxing == null || zxing.isUndefinedOrNull) return false;
  final reader = (zxing as JSObject).getProperty<JSAny?>(
    'BrowserMultiFormatReader'.toJS,
  );
  return reader != null && !reader.isUndefinedOrNull;
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
