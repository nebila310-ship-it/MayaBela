/// Daily attendance hours for one school. Every teacher uses the same window.
class AttendanceWindowSettings {
  const AttendanceWindowSettings({
    this.openHour = 8,
    this.openMinute = 30,
    this.closeHour = 9,
    this.closeMinute = 0,
  });

  final int openHour;
  final int openMinute;
  final int closeHour;
  final int closeMinute;

  int get openMinutes => openHour * 60 + openMinute;
  int get closeMinutes => closeHour * 60 + closeMinute;

  /// Close must be later the same day so the register has a real window.
  bool get isValid =>
      _hourOk(openHour) &&
      _hourOk(closeHour) &&
      _minuteOk(openMinute) &&
      _minuteOk(closeMinute) &&
      closeMinutes > openMinutes;

  String get openLabel => format(openHour, openMinute);
  String get closeLabel => format(closeHour, closeMinute);

  static String format(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  AttendanceWindowSettings copyWith({
    int? openHour,
    int? openMinute,
    int? closeHour,
    int? closeMinute,
  }) {
    return AttendanceWindowSettings(
      openHour: openHour ?? this.openHour,
      openMinute: openMinute ?? this.openMinute,
      closeHour: closeHour ?? this.closeHour,
      closeMinute: closeMinute ?? this.closeMinute,
    );
  }

  Map<String, dynamic> toMap() => {
        'openHour': openHour,
        'openMinute': openMinute,
        'closeHour': closeHour,
        'closeMinute': closeMinute,
      };

  factory AttendanceWindowSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const AttendanceWindowSettings();
    int read(String key, int fallback) {
      final raw = map[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse('${raw ?? ''}') ?? fallback;
    }

    final next = AttendanceWindowSettings(
      openHour: _clamp(read('openHour', 8), 0, 23),
      openMinute: _clamp(read('openMinute', 30), 0, 59),
      closeHour: _clamp(read('closeHour', 9), 0, 23),
      closeMinute: _clamp(read('closeMinute', 0), 0, 59),
    );
    if (!next.isValid) return const AttendanceWindowSettings();
    return next;
  }

  static bool _hourOk(int hour) => hour >= 0 && hour <= 23;
  static bool _minuteOk(int minute) => minute >= 0 && minute <= 59;

  static int _clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

enum AttendanceWindowPhase { open, beforeOpen, closed }
