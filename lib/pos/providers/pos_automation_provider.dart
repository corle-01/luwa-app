import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAutoModeKey = 'pos_auto_mode';

class PosAutomationNotifier extends StateNotifier<bool> {
  PosAutomationNotifier() : super(true) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kAutoModeKey) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoModeKey, state);
  }

  Future<void> setAutoMode(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoModeKey, value);
  }
}

final posAutomationProvider = StateNotifierProvider<PosAutomationNotifier, bool>(
  (ref) => PosAutomationNotifier(),
);
