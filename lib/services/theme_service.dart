// lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService with ChangeNotifier {
  static const String _themeModeKey = 'themeMode';
  static const String _accentColorKey = 'accentColor';

  late ThemeMode _themeMode;
  late Color _accentColor;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;

  // Define a list of available accent colors
  static final List<Color> availableColors = [
    Colors.green,
    Colors.blue,
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
  ];

  ThemeService() {
    _themeMode = ThemeMode.system; // Default value
    _accentColor = availableColors[0]; // Default color
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey) ?? 2; // Default to system
    _themeMode = ThemeMode.values[themeModeIndex];

    final colorValue = prefs.getInt(_accentColorKey) ?? availableColors[0].value;
    _accentColor = Color(colorValue);

    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, _themeMode.index);
    await prefs.setInt(_accentColorKey, _accentColor.value);
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    _saveToPrefs();
  }

  void setAccentColor(Color color) {
    if (_accentColor.value == color.value) return;
    _accentColor = color;
    notifyListeners();
    _saveToPrefs();
  }
} 