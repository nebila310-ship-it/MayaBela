import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:mayabela/maps/free_map_links.dart';
import 'package:mayabela/models/bus_route.dart';
import 'package:mayabela/widgets/free_street_map.dart';

void main() {
  test('free map links point at real public providers', () {
    const lat = 9.0054;
    const lng = 38.7636;
    expect(
      FreeMapLinks.openStreetMap(latitude: lat, longitude: lng).host,
      'www.openstreetmap.org',
    );
    expect(
      FreeMapLinks.googleMaps(latitude: lat, longitude: lng).host,
      'www.google.com',
    );
    expect(
      FreeMapLinks.appleMaps(latitude: lat, longitude: lng).host,
      'maps.apple.com',
    );
    expect(FreeMapStyle.streets.urlTemplate, contains('basemaps.cartocdn.com'));
    expect(FreeMapStyle.osm.urlTemplate, contains('tile.openstreetmap.org'));
    expect(FreeMapStyle.satellite.urlTemplate, contains('arcgisonline.com'));
  });

  testWidgets('street map builds without a Google key', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: FreeStreetMap(
              center: const LatLng(9.0054, 38.7636),
              liveBus: const LatLng(9.0054, 38.7636),
              busLabel: 'Bus 1',
              stops: [
                BusStop(
                  name: 'Bole',
                  scheduledTime: '07:00',
                  students: const [],
                  latitude: 9.01,
                  longitude: 38.79,
                ),
                BusStop(
                  name: 'School',
                  scheduledTime: '07:40',
                  students: const [],
                  latitude: 9.00,
                  longitude: 38.76,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Streets'), findsOneWidget);
    expect(find.text('OSM'), findsOneWidget);
    expect(find.text('Satellite'), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsWidgets);
  });
}
