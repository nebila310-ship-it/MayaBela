/// Free, keyless map links and raster tile sources (OSM data / Esri imagery).
abstract final class FreeMapLinks {
  static const addisLat = 9.0054;
  static const addisLng = 38.7636;

  static Uri openStreetMap({
    required double latitude,
    required double longitude,
    int zoom = 16,
  }) {
    return Uri.parse(
      'https://www.openstreetmap.org/'
      '?mlat=$latitude&mlon=$longitude#map=$zoom/$latitude/$longitude',
    );
  }

  static Uri googleMaps({
    required double latitude,
    required double longitude,
  }) {
    return Uri.parse('https://www.google.com/maps?q=$latitude,$longitude');
  }

  static Uri appleMaps({
    required double latitude,
    required double longitude,
  }) {
    return Uri.parse(
      'https://maps.apple.com/?ll=$latitude,$longitude&q=Bus',
    );
  }
}

/// Raster styles that do not need a Google / Mapbox / MapTiler key.
enum FreeMapStyle {
  streets,
  osm,
  satellite,
}

extension FreeMapStyleTiles on FreeMapStyle {
  String get urlTemplate => switch (this) {
        FreeMapStyle.streets =>
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
        FreeMapStyle.osm =>
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        FreeMapStyle.satellite =>
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      };

  List<String> get subdomains => switch (this) {
        FreeMapStyle.streets => const ['a', 'b', 'c', 'd'],
        FreeMapStyle.osm => const [],
        FreeMapStyle.satellite => const [],
      };

  String get attribution => switch (this) {
        FreeMapStyle.streets => '© OpenStreetMap © CARTO',
        FreeMapStyle.osm => '© OpenStreetMap contributors',
        FreeMapStyle.satellite => 'Tiles © Esri',
      };

  String get label => switch (this) {
        FreeMapStyle.streets => 'Streets',
        FreeMapStyle.osm => 'OSM',
        FreeMapStyle.satellite => 'Satellite',
      };
}
