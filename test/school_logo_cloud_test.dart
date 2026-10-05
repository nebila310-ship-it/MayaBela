import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/platform/browser_tab_brand.dart';
import 'package:mayabela/platform/school_splash_brand.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/supabase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SchoolRegistryService.instance.applyPersistedSchools([]);
  });

  test('banner and identity cloud URLs do not overwrite each other', () {
    final school = SchoolRecord(
      id: 'FEN101',
      name: 'Fenote Raey Academy',
      logoUrl: 'https://cdn.example/logo.jpg?v=1',
      identityLogoUrl: 'https://cdn.example/identity.jpg?v=1',
      logoStyle: SchoolLogoStyle.circular,
    );
    expect(school.displayLogoUrl, 'https://cdn.example/identity.jpg?v=1');

    school.logoStyle = SchoolLogoStyle.rectangular;
    expect(school.displayLogoUrl, 'https://cdn.example/logo.jpg?v=1');

    final json = school.toJson();
    expect(json['logoUrl'], 'https://cdn.example/logo.jpg?v=1');
    expect(json['identityLogoUrl'], 'https://cdn.example/identity.jpg?v=1');

    final roundTrip = SchoolRecord.fromJson(json);
    expect(roundTrip.identityLogoUrl, school.identityLogoUrl);
    expect(roundTrip.logoUrl, school.logoUrl);
  });

  test('branding URLs use the public school-branding bucket', () {
    expect(
      SchoolLogoService.publicUrl('fen101'),
      '$kSupabaseUrl/storage/v1/object/public/school-branding/'
      'schools/FEN101/branding/logo.jpg',
    );
    expect(
      SchoolLogoService.publicUrl(
        'fen101',
        style: SchoolLogoStyle.circular,
      ),
      '$kSupabaseUrl/storage/v1/object/public/school-branding/'
      'schools/FEN101/branding/identity.jpg',
    );
    expect(
      SchoolLogoService.brandingFile(SchoolLogoStyle.rectangular),
      'logo.jpg',
    );
    expect(
      SchoolLogoService.brandingFile(SchoolLogoStyle.circular),
      'identity.jpg',
    );
  });

  test('legacy public storage URLs are rewritten for Image.network', () {
    final public =
        '$kSupabaseUrl/storage/v1/object/public/school-files/'
        'schools/FEN101/branding/logo.jpg?v=9';
    final viewable = SchoolLogoService.viewableUrl(public);
    expect(viewable, contains('/object/public/school-branding/'));
    expect(viewable, isNot(contains('/object/public/school-files/')));
    expect(SchoolLogoService.imageHeadersFor(viewable), isNull);
    expect(
      SchoolLogoService.displayUrlFor(
        'FEN101',
        storedUrl: public,
      ),
      contains('/object/public/school-branding/'),
    );
  });

  test('cloud sync does not wipe a just-saved logo URL', () {
    final registry = SchoolRegistryService.instance;
    registry.upsertSchool(
      SchoolRecord(
        id: 'FEN101',
        name: 'Fenote Raey Academy',
        logoUrl:
            'https://example.supabase.co/storage/v1/object/authenticated/'
            'school-files/schools/FEN101/branding/logo.jpg?v=1',
        identityLogoUrl:
            'https://example.supabase.co/storage/v1/object/authenticated/'
            'school-files/schools/FEN101/branding/identity.jpg?v=1',
      ),
    );

    registry.upsertSchool(
      SchoolRecord(id: 'FEN101', name: 'Fenote Raey Academy'),
      keepLogosIfIncomingEmpty: true,
    );

    final kept = registry.lookup('FEN101');
    expect(kept?.logoUrl, contains('logo.jpg'));
    expect(kept?.identityLogoUrl, contains('identity.jpg'));
  });

  test('splash thumbnail is small enough for localStorage', () {
    final canvas = img.Image(width: 1400, height: 504);
    img.fill(canvas, color: img.ColorRgb8(20, 80, 160));
    final raw = Uint8List.fromList(img.encodeJpg(canvas, quality: 95));
    final thumb = SchoolSplashBrand.thumbnailForTest(raw);
    expect(thumb, isNotNull);
    expect(thumb!.length, lessThan(180000));
  });

  test('browser tab title prefers the school name', () {
    expect(
      BrowserTabBrand.resolveTitle(
        sessionSchoolName: 'Fenote Raey Academy',
        splashName: 'Old Name',
        rememberedName: 'Saved Name',
        fallback: 'MaJo e-School Bridge',
      ),
      'Fenote Raey Academy',
    );
    expect(
      BrowserTabBrand.resolveTitle(
        fallback: 'MaJo e-School Bridge',
      ),
      'MaJo e-School Bridge',
    );
  });
}
