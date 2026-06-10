import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('vi', 'VN');

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;

  String get currentLanguageLabel {
    return _locale.languageCode == 'vi' ? 'Tiếng Việt' : 'English';
  }

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('languageCode') ?? 'vi';
    if (lang == 'en') {
      _locale = const Locale('en', 'US');
    } else {
      _locale = const Locale('vi', 'VN');
    }
    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    if (langCode == 'en') {
      _locale = const Locale('en', 'US');
    } else {
      _locale = const Locale('vi', 'VN');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', langCode);
    notifyListeners();
  }
}
