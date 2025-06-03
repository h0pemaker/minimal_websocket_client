import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _userIdKey = 'userId';
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> saveUserId(String userId) async {
    await _prefs?.setString(_userIdKey, userId);
  }

  static String? getUserId() {
    return _prefs?.getString(_userIdKey);
  }

  static Future<void> logout() async {
    await _prefs?.remove(_userIdKey);
  }
} 