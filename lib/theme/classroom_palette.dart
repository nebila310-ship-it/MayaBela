import 'package:flutter/material.dart';

/// Google Classroom-style class colors used across dashboards and ERP chrome.
abstract final class ClassroomPalette {
  static const teal = Color(0xFF00897B);
  static const green = Color(0xFF1E8E3E);
  static const blue = Color(0xFF1A73E8);
  static const navy = Color(0xFF174EA6);
  static const purple = Color(0xFF8E24AA);
  static const grape = Color(0xFFA142F4);
  static const pink = Color(0xFFC2185B);
  static const orange = Color(0xFFE37400);
  static const amber = Color(0xFFF9AB00);
  static const cyan = Color(0xFF12B5CB);
  static const red = Color(0xFFD93025);

  static const stream = Color(0xFFF8F9FA);
  static const streamTint = Color(0xFFE8F0FE);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF202124);
  static const muted = Color(0xFF5F6368);
  static const line = Color(0xFFDADCE0);

  static const List<Color> classes = [
    teal,
    blue,
    purple,
    orange,
    green,
    pink,
    cyan,
    navy,
    grape,
    amber,
    red,
  ];

  static Color at(int index) => classes[index.abs() % classes.length];

  static Color forKey(String key) => at(key.hashCode);
}
