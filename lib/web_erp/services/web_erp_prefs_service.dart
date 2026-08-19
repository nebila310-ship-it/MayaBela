import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web ERP navigation preferences: favorites, recents, sidebar state.
class WebErpPrefsService extends ChangeNotifier {
  WebErpPrefsService._();
  static final instance = WebErpPrefsService._();

  static const _favoritesKey = 'web_erp_favorites_v1';
  static const _recentsKey = 'web_erp_recents_v1';
  static const _sidebarCollapsedKey = 'web_erp_sidebar_collapsed';

  List<String> favorites = [];
  List<String> recents = [];
  bool sidebarCollapsed = false;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    sidebarCollapsed = prefs.getBool(_sidebarCollapsedKey) ?? false;
    favorites = _decodeList(prefs.getString(_favoritesKey));
    recents = _decodeList(prefs.getString(_recentsKey));
    notifyListeners();
  }

  List<String> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sidebarCollapsedKey, sidebarCollapsed);
    await prefs.setString(_favoritesKey, jsonEncode(favorites));
    await prefs.setString(_recentsKey, jsonEncode(recents));
  }

  Future<void> setSidebarCollapsed(bool value) async {
    sidebarCollapsed = value;
    notifyListeners();
    await _persist();
  }

  Future<void> toggleFavorite(String routeId) async {
    if (favorites.contains(routeId)) {
      favorites.remove(routeId);
    } else {
      favorites.insert(0, routeId);
      if (favorites.length > 12) favorites = favorites.take(12).toList();
    }
    notifyListeners();
    await _persist();
  }

  bool isFavorite(String routeId) => favorites.contains(routeId);

  Future<void> recordVisit(String routeId) async {
    if (routeId == 'dashboard') return;
    recents.remove(routeId);
    recents.insert(0, routeId);
    if (recents.length > 10) recents = recents.take(10).toList();
    notifyListeners();
    await _persist();
  }
}
