/// Unit Converter Utility
/// Handles conversion between weight (mg, g, kg) and volume (ml, l) units
/// All conversions use base units: grams (g) for weight, milliliters (ml) for volume

class UnitConverter {
  // ══════════════════════════════════════════════════════════════
  // Unit Categories
  // ══════════════════════════════════════════════════════════════

  static const weightUnits = ['mg', 'g', 'kg'];
  static const volumeUnits = ['ml', 'l'];
  static const countUnits = ['pcs', 'buah', 'botol', 'kaleng', 'pack', 'lembar', 'porsi'];

  /// All supported units
  static const allUnits = [
    ...weightUnits,
    ...volumeUnits,
    ...countUnits,
  ];

  /// Default units for each category
  static const defaultWeightUnit = 'g';
  static const defaultVolumeUnit = 'ml';
  static const defaultCountUnit = 'pcs';

  // ══════════════════════════════════════════════════════════════
  // Unit Type Detection
  // ══════════════════════════════════════════════════════════════

  static UnitType getUnitType(String unit) {
    final u = unit.toLowerCase().trim();
    if (weightUnits.contains(u)) return UnitType.weight;
    if (volumeUnits.contains(u)) return UnitType.volume;
    if (countUnits.contains(u)) return UnitType.count;
    return UnitType.unknown;
  }

  static bool isWeightUnit(String unit) => getUnitType(unit) == UnitType.weight;
  static bool isVolumeUnit(String unit) => getUnitType(unit) == UnitType.volume;
  static bool isCountUnit(String unit) => getUnitType(unit) == UnitType.count;

  /// Check if two units are compatible (can be converted)
  static bool areCompatible(String unit1, String unit2) {
    final type1 = getUnitType(unit1);
    final type2 = getUnitType(unit2);
    return type1 == type2 && type1 != UnitType.unknown;
  }

  // ══════════════════════════════════════════════════════════════
  // Base Unit Conversion
  // ══════════════════════════════════════════════════════════════

  /// Get the base unit for a given unit type
  static String getBaseUnit(String unit) {
    switch (getUnitType(unit)) {
      case UnitType.weight:
        return 'g'; // Base: grams
      case UnitType.volume:
        return 'ml'; // Base: milliliters
      case UnitType.count:
        return unit; // Count units don't convert
      case UnitType.unknown:
        return unit;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Conversion Functions
  // ══════════════════════════════════════════════════════════════

  /// Convert from one unit to another
  /// Returns null if units are incompatible
  static double? convert({
    required double value,
    required String from,
    required String to,
  }) {
    if (!areCompatible(from, to)) return null;

    // No conversion needed for same unit
    if (from.toLowerCase() == to.toLowerCase()) return value;

    // Convert to base unit first
    final baseValue = _toBaseUnit(value, from);
    if (baseValue == null) return null;

    // Then convert from base to target unit
    return _fromBaseUnit(baseValue, to);
  }

  /// Convert to base unit (g for weight, ml for volume)
  static double? _toBaseUnit(double value, String unit) {
    final u = unit.toLowerCase().trim();

    // Weight conversions to grams
    if (weightUnits.contains(u)) {
      switch (u) {
        case 'mg':
          return value / 1000; // 1000 mg = 1 g
        case 'g':
          return value;
        case 'kg':
          return value * 1000; // 1 kg = 1000 g
      }
    }

    // Volume conversions to milliliters
    if (volumeUnits.contains(u)) {
      switch (u) {
        case 'ml':
          return value;
        case 'l':
          return value * 1000; // 1 l = 1000 ml
      }
    }

    // Count units don't convert
    if (countUnits.contains(u)) return value;

    return null;
  }

  /// Convert from base unit (g or ml) to target unit
  static double? _fromBaseUnit(double baseValue, String unit) {
    final u = unit.toLowerCase().trim();

    // Weight conversions from grams
    if (weightUnits.contains(u)) {
      switch (u) {
        case 'mg':
          return baseValue * 1000; // 1 g = 1000 mg
        case 'g':
          return baseValue;
        case 'kg':
          return baseValue / 1000; // 1000 g = 1 kg
      }
    }

    // Volume conversions from milliliters
    if (volumeUnits.contains(u)) {
      switch (u) {
        case 'ml':
          return baseValue;
        case 'l':
          return baseValue / 1000; // 1000 ml = 1 l
      }
    }

    // Count units don't convert
    if (countUnits.contains(u)) return baseValue;

    return null;
  }

  // ══════════════════════════════════════════════════════════════
  // Display Helpers
  // ══════════════════════════════════════════════════════════════

  /// Format value with unit for display
  /// Example: formatValue(1500, 'g') -> "1.5 kg" (auto-converts to larger unit)
  static String formatValue(double value, String unit, {bool autoConvert = true}) {
    if (!autoConvert) {
      return '${_formatNumber(value)} $unit';
    }

    final type = getUnitType(unit);

    // Auto-convert weight to larger units
    if (type == UnitType.weight) {
      // Convert to base (grams) first
      final grams = _toBaseUnit(value, unit) ?? value;

      if (grams >= 1000) {
        // Display in kg
        return '${_formatNumber(grams / 1000)} kg';
      } else if (grams < 1) {
        // Display in mg
        return '${_formatNumber(grams * 1000)} mg';
      } else {
        // Display in g
        return '${_formatNumber(grams)} g';
      }
    }

    // Auto-convert volume to larger units
    if (type == UnitType.volume) {
      // Convert to base (ml) first
      final ml = _toBaseUnit(value, unit) ?? value;

      if (ml >= 1000) {
        // Display in liters
        return '${_formatNumber(ml / 1000)} l';
      } else {
        // Display in ml
        return '${_formatNumber(ml)} ml';
      }
    }

    // No auto-conversion for count units
    return '${_formatNumber(value)} $unit';
  }

  static String _formatNumber(double value) {
    // Remove trailing zeros
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  // ══════════════════════════════════════════════════════════════
  // Unit Suggestions
  // ══════════════════════════════════════════════════════════════

  /// Get suggested display unit based on value
  /// Example: suggestUnit(1500, 'g') -> 'kg'
  static String suggestUnit(double value, String currentUnit) {
    final type = getUnitType(currentUnit);

    if (type == UnitType.weight) {
      final grams = _toBaseUnit(value, currentUnit) ?? value;
      if (grams >= 1000) return 'kg';
      if (grams < 1) return 'mg';
      return 'g';
    }

    if (type == UnitType.volume) {
      final ml = _toBaseUnit(value, currentUnit) ?? value;
      if (ml >= 1000) return 'l';
      return 'ml';
    }

    return currentUnit;
  }

  /// Get compatible units for a given unit
  static List<String> getCompatibleUnits(String unit) {
    final type = getUnitType(unit);
    switch (type) {
      case UnitType.weight:
        return [...weightUnits];
      case UnitType.volume:
        return [...volumeUnits];
      case UnitType.count:
        return [...countUnits];
      case UnitType.unknown:
        return [unit];
    }
  }
}

// ══════════════════════════════════════════════════════════════
// Unit Type Enum
// ══════════════════════════════════════════════════════════════

enum UnitType {
  weight,  // mg, g, kg
  volume,  // ml, l
  count,   // pcs, buah, botol, etc
  unknown,
}
