import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesProvider extends ChangeNotifier {
  bool _isVegMode = false;
  bool get isVegMode => _isVegMode;

  String _appLanguage = 'English';
  String get appLanguage => _appLanguage;

  PreferencesProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isVegMode = prefs.getBool('isVegMode') ?? false;
    _appLanguage = prefs.getString('appLanguage') ?? 'English';
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    if (_appLanguage == lang) return;
    _appLanguage = lang;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appLanguage', lang);
  }

  Future<void> toggleVegMode() async {
    _isVegMode = !_isVegMode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isVegMode', _isVegMode);
  }

  Future<void> setVegMode(bool value) async {
    if (_isVegMode == value) return;
    _isVegMode = value;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isVegMode', value);
  }
}
