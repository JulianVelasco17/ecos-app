import 'package:shared_preferences/shared_preferences.dart';

class DebugConfig {
  DebugConfig._();
  static final DebugConfig instance = DebugConfig._();

  static const _key = 'debug_mode';
  bool _activo = false;

  bool get activo => _activo;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _activo = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    _activo = !_activo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _activo);
  }
}
