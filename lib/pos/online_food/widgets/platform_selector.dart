import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/online_food_provider.dart';

/// Dark-theme color constants for the Online Food feature.
class _C {
  static const background = Color(0xFF13131D);
  static const card = Color(0xFF1A1A28);
  static const border = Color(0xFF1E1E2E);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF9CA3AF);
}

/// Platform accent colors.
const _platformColors = <OnlinePlatform, Color>{
  OnlinePlatform.gofood: Color(0xFF00880C),
  OnlinePlatform.grabfood: Color(0xFF00B14F),
  OnlinePlatform.shopeefood: Color(0xFFEE4D2D),
};

/// Platform icons.
const _platformIcons = <OnlinePlatform, IconData>{
  OnlinePlatform.gofood: Icons.delivery_dining,
  OnlinePlatform.grabfood: Icons.motorcycle,
  OnlinePlatform.shopeefood: Icons.shopping_bag,
};

/// Three large horizontal toggle buttons for GoFood / GrabFood / ShopeeFood.
///
/// Single-select: the chosen platform has a colored border + filled background
/// with opacity. Unselected platforms show a dark card background with a
/// subtle border.
class PlatformSelector extends ConsumerWidget {
  const PlatformSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onlineFoodProvider);
    final selected = state.selectedPlatform;

    return Row(
      children: OnlinePlatform.values.map((platform) {
        final isSelected = selected == platform;
        final color = _platformColors[platform]!;
        final icon = _platformIcons[platform]!;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: platform != OnlinePlatform.shopeefood ? 10 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                ref.read(onlineFoodProvider.notifier).selectPlatform(platform);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : _C.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : _C.border,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.20),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Platform icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.25)
                            : _C.border,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? color : _C.textSecondary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Platform name
                    Text(
                      platform.label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : _C.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
