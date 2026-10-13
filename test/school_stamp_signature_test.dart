import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mayabela/services/school_mark_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/supabase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SchoolRegistryService.instance.applyPersistedSchools([]);
  });

  test('stamp and signature URLs are public branding files', () {
    expect(
      SchoolMarkService.publicUrl('fen101', SchoolMarkKind.stamp),
      '$kSupabaseUrl/storage/v1/object/public/school-branding/'
      'schools/FEN101/branding/stamp.png',
    );
    expect(
      SchoolMarkService.publicUrl('fen101', SchoolMarkKind.principalSignature),
      endsWith('/branding/principal-signature.png'),
    );
  });

  test('paper-white background becomes transparent ink', () async {
    final source = img.Image(width: 24, height: 24, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(255, 255, 255, 255));
    img.fillRect(
      source,
      x1: 8,
      y1: 8,
      x2: 16,
      y2: 16,
      color: img.ColorRgba8(180, 20, 20, 255),
    );
    final png = await SchoolMarkService.instance.normalizeToPng(
      Uint8List.fromList(img.encodePng(source)),
      SchoolMarkKind.stamp,
    );
    expect(png, isNotNull);
    expect(png!.take(8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final decoded = img.decodePng(png)!;
    var clear = 0;
    var ink = 0;
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y);
        if (pixel.a.toInt() < 16) {
          clear++;
        } else if (pixel.r.toInt() > 50 && pixel.g.toInt() < 40) {
          ink++;
        }
      }
    }
    expect(clear, greaterThan(0));
    expect(ink, greaterThan(0));
  });

  test('stamp ink drops a black scan backdrop and keeps the blue seal', () {
    final source = img.Image(width: 32, height: 32, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(0, 0, 0, 255));
    img.fillRect(
      source,
      x1: 8,
      y1: 6,
      x2: 24,
      y2: 26,
      color: img.ColorRgba8(37, 78, 196, 255),
    );
    final png = SchoolMarkService.instance.forReport(
      Uint8List.fromList(img.encodePng(source)),
      SchoolMarkKind.stamp,
    );
    final decoded = img.decodePng(png)!;
    var black = 0;
    var blue = 0;
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y);
        if (pixel.a.toInt() < 16 &&
            pixel.r.toInt() < 20 &&
            pixel.g.toInt() < 20 &&
            pixel.b.toInt() < 20) {
          // transparent, not a painted black square
        }
        if (pixel.a.toInt() > 40 && pixel.b.toInt() > pixel.r.toInt()) {
          blue++;
        }
        if (pixel.a.toInt() > 200 &&
            pixel.r.toInt() < 15 &&
            pixel.g.toInt() < 15 &&
            pixel.b.toInt() < 15) {
          black++;
        }
      }
    }
    expect(blue, greaterThan(20));
    expect(black, 0);
  });

  test('pale seal letters stay a solid stroke and the disc stays clear', () {
    final source = img.Image(width: 48, height: 48, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(0, 0, 0, 255));
    img.fillRect(
      source,
      x1: 4,
      y1: 4,
      x2: 43,
      y2: 43,
      color: img.ColorRgba8(158, 160, 166, 255),
    );
    img.fillRect(
      source,
      x1: 12,
      y1: 16,
      x2: 36,
      y2: 30,
      color: img.ColorRgba8(115, 119, 140, 255),
    );
    final png = SchoolMarkService.instance.forReport(
      Uint8List.fromList(img.encodePng(source)),
      SchoolMarkKind.stamp,
    );
    final decoded = img.decodePng(png)!;
    var stroke = 0;
    var disc = 0;
    var black = 0;
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y);
        final alpha = pixel.a.toInt();
        if (alpha < 40) continue;
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final chroma = [r, g, b].reduce((a, c) => a > c ? a : c) -
            [r, g, b].reduce((a, c) => a < c ? a : c);
        if (b > r && alpha > 180) {
          stroke++;
        } else if (chroma < 12) {
          disc++;
        }
        if (alpha > 200 && r < 15 && g < 15 && b < 15) black++;
      }
    }
    expect(stroke, greaterThan(200));
    expect(disc, 0);
    expect(black, 0);
  });

  test('signature ink sits as pen strokes, not lined paper', () {
    final source = img.Image(width: 40, height: 24, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(248, 246, 242, 255));
    for (final y in [6, 12, 18]) {
      img.drawLine(
        source,
        x1: 0,
        y1: y,
        x2: 39,
        y2: y,
        color: img.ColorRgba8(186, 170, 214, 255),
      );
    }
    img.drawLine(
      source,
      x1: 8,
      y1: 16,
      x2: 30,
      y2: 8,
      color: img.ColorRgba8(20, 24, 40, 255),
    );
    final png = SchoolMarkService.instance.forReport(
      Uint8List.fromList(img.encodePng(source)),
      SchoolMarkKind.principalSignature,
    );
    final decoded = img.decodePng(png)!;
    var paper = 0;
    var pen = 0;
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y);
        if (pixel.a.toInt() < 16) continue;
        paper++;
        if (pixel.b.toInt() > pixel.r.toInt() && pixel.r.toInt() < 80) pen++;
      }
    }
    expect(pen, greaterThan(0));
    expect(paper, pen);
    expect(decoded.height, greaterThan(4));
    expect(decoded.width, lessThan(38));
  });

  test('school record keeps stamp and signature across json and stale sync', () {
    final registry = SchoolRegistryService.instance;
    final dataUrl = SchoolMarkService.dataUrlFor(
      Uint8List.fromList(const [1, 2, 3, 4]),
    );
    registry.upsertSchool(
      SchoolRecord(
        id: 'MAYU',
        name: 'Mayu International Academy',
        stampUrl: dataUrl,
        principalSignatureUrl: 'https://cdn.example/principal-signature.png',
      ),
    );

    final roundTrip = SchoolRecord.fromJson(registry.lookup('MAYU')!.toJson());
    expect(roundTrip.stampUrl, dataUrl);
    expect(
      roundTrip.principalSignatureUrl,
      'https://cdn.example/principal-signature.png',
    );
    expect(SchoolMarkService.bytesFromStored(roundTrip.stampUrl), [1, 2, 3, 4]);

    registry.upsertSchool(
      SchoolRecord(id: 'MAYU', name: 'Mayu International Academy'),
      keepLogosIfIncomingEmpty: true,
    );
    final kept = registry.lookup('MAYU');
    expect(kept?.stampUrl, dataUrl);
    expect(kept?.principalSignatureUrl, contains('principal-signature.png'));

    final cleared = kept!.copyWith(clearStamp: true);
    expect(cleared.stampUrl, isNull);
    expect(cleared.principalSignatureUrl, contains('principal-signature.png'));
  });
}
