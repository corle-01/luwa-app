import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/themes/app_theme.dart';
import '../providers/pos_product_provider.dart';
import 'pos_product_card.dart';

class ProductGrid extends ConsumerWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(posFilteredProductsProvider);

    return productsAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tidak ada produk',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Produk akan muncul di sini',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            // Responsive breakpoints - OPTIMIZED for space saving
            final int crossAxisCount;
            final double aspectRatio;
            if (constraints.maxWidth > 1000) {
              crossAxisCount = 5;
              aspectRatio = 0.75; // More items per row, more compact
            } else if (constraints.maxWidth > 800) {
              crossAxisCount = 4;
              aspectRatio = 0.80; // Compact for tablets (from 0.62)
            } else if (constraints.maxWidth > 500) {
              crossAxisCount = 3;
              aspectRatio = 0.85; // More compact (from 0.68)
            } else if (constraints.maxWidth > 350) {
              crossAxisCount = 2;
              aspectRatio = 0.90; // More compact (from 0.75)
            } else {
              crossAxisCount = 2;
              aspectRatio = 0.95; // More compact (from 0.82)
            }

            return GridView.builder(
              padding: const EdgeInsets.all(6), // Further reduced for more space
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: aspectRatio,
                crossAxisSpacing: 6, // Further reduced for more items visible
                mainAxisSpacing: 6, // Further reduced for more items visible
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return PosProductCard(product: products[index]);
              },
            );
          },
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat produk...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.errorColor.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Terjadi Kesalahan',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error.toString(),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.errorColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
