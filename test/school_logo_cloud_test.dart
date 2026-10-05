import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/models/school_logo_style.dart';
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

  test('public branding URLs are stable per school and style', () {
    expect(
      SchoolLogoService.publicUrl('fen101'),
      '$kSupabaseUrl/storage/v1/object/public/school-files/'
      'schools/FEN101/branding/logo.jpg',
    );
    expect(
      SchoolLogoService.publicUrl(
        'fen101',
        style: SchoolLogoStyle.circular,
      ),
      '$kSupabaseUrl/storage/v1/object/public/school-files/'
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
}
