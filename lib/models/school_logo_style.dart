enum SchoolLogoStyle {
  rectangular,
  circular;

  static SchoolLogoStyle parse(String? value) {
    return SchoolLogoStyle.values.firstWhere(
      (s) => s.name == value,
      orElse: () => SchoolLogoStyle.rectangular,
    );
  }

  String get label => switch (this) {
        SchoolLogoStyle.rectangular => 'Rectangular banner',
        SchoolLogoStyle.circular => 'Circular logo',
      };

  /// Display frame proportions — rectangular matches login banner (full width × 140).
  double get frameAspectRatio => switch (this) {
        SchoolLogoStyle.rectangular => 2.78,
        SchoolLogoStyle.circular => 1.0,
      };

  /// High-res export size saved on device (same aspect as [frameAspectRatio]).
  (int width, int height) get exportSize => switch (this) {
        SchoolLogoStyle.rectangular => (1400, 504),
        SchoolLogoStyle.circular => (1024, 1024),
      };

  /// Safe inset baked into the saved file so display can fill edge-to-edge.
  double get exportPaddingFraction => 0.025;
}
