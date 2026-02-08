import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theme mode provider (light / dark / system)
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Derived provider: is dark mode currently active?
final isDarkModeProvider = Provider<bool>((ref) {
  final mode = ref.watch(themeModeProvider);
  if (mode == ThemeMode.system) {
    // Default to light when we can't read platform brightness.
    // MaterialApp handles system mode automatically via themeMode.
    return false;
  }
  return mode == ThemeMode.dark;
});
