import 'package:mayabela/models/school_logo_style.dart';

/// Last school shown on login/launch, persisted so the first Flutter frame
/// can show that school's name and logo before the registry finishes loading.
class RememberedSchoolBrand {
  const RememberedSchoolBrand({
    required this.schoolId,
    required this.name,
    this.logoUrl,
    this.logoPath,
    this.logoStyle = SchoolLogoStyle.rectangular,
  });

  final String schoolId;
  final String name;
  final String? logoUrl;
  final String? logoPath;
  final SchoolLogoStyle logoStyle;

  bool get hasLogo =>
      (logoUrl != null && logoUrl!.trim().isNotEmpty) ||
      (logoPath != null && logoPath!.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {
        'schoolId': schoolId,
        'name': name,
        'logoUrl': logoUrl,
        'logoPath': logoPath,
        'logoStyle': logoStyle.name,
      };

  factory RememberedSchoolBrand.fromJson(Map<String, dynamic> json) {
    return RememberedSchoolBrand(
      schoolId: (json['schoolId'] as String? ?? '').trim().toUpperCase(),
      name: (json['name'] as String? ?? '').trim(),
      logoUrl: json['logoUrl'] as String?,
      logoPath: json['logoPath'] as String?,
      logoStyle: SchoolLogoStyle.parse(json['logoStyle'] as String?),
    );
  }
}
