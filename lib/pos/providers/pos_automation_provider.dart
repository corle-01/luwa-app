import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Always returns true — stock deduction is always automatic.
/// Toggle has been removed; this provider is kept for backward compatibility.
final posAutomationProvider = Provider<bool>((ref) => true);
