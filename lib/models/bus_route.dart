enum TripStatus { notStarted, inProgress, completed }

enum StopStatus { pending, current, completed }

class BusStop {
  BusStop({
    required this.name,
    required this.scheduledTime,
    required this.students,
    required this.latitude,
    required this.longitude,
    this.status = StopStatus.pending,
    this.etaMinutes,
  });

  final String name;
  final String scheduledTime;
  final List<String> students;
  final double latitude;
  final double longitude;
  StopStatus status;
  int? etaMinutes;
}

class BusRoute {
  BusRoute({
    required this.id,
    required this.busNumber,
    required this.driverName,
    required this.plateNumber,
    required this.routeName,
    required this.stops,
    this.currentStopIndex = -1,
    this.tripStatus = TripStatus.notStarted,
    this.progressToNextStop = 0,
  });

  final String id;
  final String busNumber;
  final String driverName;
  final String plateNumber;
  final String routeName;
  final List<BusStop> stops;
  int currentStopIndex;
  TripStatus tripStatus;
  double progressToNextStop;

  BusStop? get currentStop {
    if (currentStopIndex < 0 || currentStopIndex >= stops.length) return null;
    return stops[currentStopIndex];
  }

  BusStop? get nextStop {
    final nextIndex = currentStopIndex + 1;
    if (nextIndex >= stops.length) return null;
    return stops[nextIndex];
  }

  int? get etaMinutes {
    if (tripStatus == TripStatus.completed) return 0;
    if (tripStatus == TripStatus.notStarted) return null;
    final current = currentStop;
    if (current?.etaMinutes != null) return current!.etaMinutes;
    return ((1 - progressToNextStop) * 8).round().clamp(1, 15);
  }

  String get statusLabel {
    switch (tripStatus) {
      case TripStatus.notStarted:
        return 'Waiting to depart';
      case TripStatus.inProgress:
        if (currentStop != null) {
          return 'Heading to ${currentStop!.name}';
        }
        return 'On the way';
      case TripStatus.completed:
        return 'Arrived at school';
    }
  }

  ({double lat, double lng})? get busPosition {
    if (stops.isEmpty) return null;

    if (tripStatus == TripStatus.notStarted) {
      return (lat: stops.first.latitude, lng: stops.first.longitude);
    }
    if (tripStatus == TripStatus.completed) {
      final last = stops.last;
      return (lat: last.latitude, lng: last.longitude);
    }

    final fromIndex = currentStopIndex.clamp(0, stops.length - 1);
    final toIndex = (currentStopIndex + 1).clamp(0, stops.length - 1);
    final from = stops[fromIndex];
    final to = stops[toIndex];
    final t = progressToNextStop;

    return (
      lat: from.latitude + (to.latitude - from.latitude) * t,
      lng: from.longitude + (to.longitude - from.longitude) * t,
    );
  }
}

class ChildBusAssignment {
  ChildBusAssignment({
    required this.childName,
    required this.routeId,
    required this.stopName,
    this.studentId,
  });

  final String childName;
  final String routeId;
  final String stopName;
  final String? studentId;
}
