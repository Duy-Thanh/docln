import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _serverKey = 'current_server';
  static final SettingsService _instance = SettingsService._internal();
  
  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  Future<void> saveCurrentServer(String server) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, server);
  }

  Future<String?> getCurrentServer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverKey);
  }
}