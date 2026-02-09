import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../providers/pos_product_provider.dart';

class CategoryTabBar extends ConsumerWidget {
  const CategoryTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(posCategoriesProvider);
    final selectedCategory = ref.watch(posSelectedCategoryProvider);

    return SizedBox(
      height: 44,
      child: categoriesAsync.when(
        data: (categories) {
          final featured = categories.where((c) => c.isFeatured).toList();
          final regular = categories.where((c) => !c.isFeatured).toList();

          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Featured categories first
              ...featured.map((cat) => _CategoryChip(
                label: cat.name,
                isSelected: selectedCategory == cat.id,
                onTap: () => ref.read(posSelectedCategoryProvider.notifier).state = cat.id,
                isFeatured: true,
              )),
              // "Semua" after featured
              _CategoryChip(
                label: 'Semua',
                isSelected: selectedCategory == null,
                onTap: () => ref.read(posSelectedCategoryProvider.notifier).state = null,
              ),
              // Regular categories
              ...regular.map((cat) => _CategoryChip(
                label: cat.name,
                isSelected: selectedCategory == cat.id,
                onTap: () => ref.read(posSelectedCategoryProvider.notifier).state = cat.id,
              )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isFeatured;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isFeatured && !isSelected
        ? AppTheme.accentColor
        : AppTheme.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor
                : isFeatured
                    ? AppTheme.accentColor.withValues(alpha: 0.08)
                    : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : isFeatured
                      ? AppTheme.accentColor.withValues(alpha: 0.4)
                      : AppTheme.borderColor.withValues(alpha: 0.5),
              width: isSelected ? 0 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFeatured && !isSelected) ...[
                Icon(Icons.star_rounded, size: 14, color: AppTheme.accentColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isSelected
                      ? Colors.white
                      : isFeatured
                          ? AppTheme.accentColor
                          : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected || isFeatured ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
