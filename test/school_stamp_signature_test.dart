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
        } else if (pixel.r.toInt() > 140 && pixel.g.toInt() < 60) {
          ink++;
        }
      }
    }
    expect(clear, greaterThan(0));
    expect(ink, greaterThan(0));
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
