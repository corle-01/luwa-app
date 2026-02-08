import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/product.dart';
import '../providers/online_food_provider.dart';

/// Dark-theme color constants for the Online Food feature.
class _C {
  static const background = Color(0xFF13131D);
  static const card = Color(0xFF1A1A28);
  static const border = Color(0xFF1E1E2E);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF9CA3AF);
  static const textTertiary = Color(0xFF6B7280);
}

const _outletId = 'a0000000-0000-0000-0000-000000000001';

// ---------------------------------------------------------------------------
// Providers (local to this file – categories, products, filter state)
// ---------------------------------------------------------------------------

final _categoriesProvider = FutureProvider<List<ProductCategory>>((ref) async {
  final response = await Supabase.instance.client
      .from('categories')
      .select()
      .eq('outlet_id', _outletId)
      .order('sort_order', ascending: true);

  return (response as List)
      .map((json) => ProductCategory.fromJson(json))
      .toList();
});

final _productsProvider = FutureProvider<List<Product>>((ref) async {
  final response = await Supabase.instance.client
      .from('products')
      .select('*, categories(name)')
      .eq('outlet_id', _outletId)
      .eq('is_active', true)
      .order('sort_order', ascending: true);

  return (response as List).map((json) => Product.fromJson(json)).toList();
});

final _selectedCategoryProvider = StateProvider<String?>((ref) => null);
final _searchQueryProvider = StateProvider<String>((ref) => '');

final _filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(_productsProvider);
  final selectedCategory = ref.watch(_selectedCategoryProvider);
  final searchQuery = ref.watch(_searchQueryProvider).toLowerCase();

  return productsAsync.whenData((products) {
    var filtered = products;
    if (selectedCategory != null) {
      filtered =
          filtered.where((p) => p.categoryId == selectedCategory).toList();
    }
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((p) => p.name.toLowerCase().contains(searchQuery))
          .toList();
    }
    return filtered;
  });
});

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Product grid for the Online Food feature.
///
/// Shows category tabs at the top, a search bar, and a grid of products
/// displaying only the icon + name (no price). Tapping a product calls
/// [OnlineFoodNotifier.addItem] and a quantity badge is shown for products
/// already in the cart.
class OnlineFoodMenuGrid extends ConsumerStatefulWidget {
  const OnlineFoodMenuGrid({super.key});

  @override
  ConsumerState<OnlineFoodMenuGrid> createState() => _OnlineFoodMenuGridState();
}

class _OnlineFoodMenuGridState extends ConsumerState<OnlineFoodMenuGrid> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      setState(() => _isFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFocused
                    ? const Color(0xFF6366F1)
                    : _C.border,
                width: _isFocused ? 1.5 : 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (value) {
                ref.read(_searchQueryProvider.notifier).state = value;
              },
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _C.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                hintStyle: GoogleFonts.inter(
                  color: _C.textTertiary,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: _isFocused
                      ? const Color(0xFF6366F1)
                      : _C.textTertiary,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        color: _C.textTertiary,
                        onPressed: () {
                          _searchController.clear();
                          ref.read(_searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                filled: true,
                fillColor: _C.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                isDense: true,
              ),
            ),
          ),
        ),

        // ── Category tabs ───────────────────────────────────────────────
        _CategoryTabs(),

        const SizedBox(height: 4),

        // ── Product grid ────────────────────────────────────────────────
        Expanded(child: _ProductGrid()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category tabs
// ---------------------------------------------------------------------------

class _CategoryTabs extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(_categoriesProvider);
    final selectedCategory = ref.watch(_selectedCategoryProvider);

    return SizedBox(
      height: 44,
      child: categoriesAsync.when(
        data: (categories) {
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _CategoryChip(
                label: 'Semua',
                isSelected: selectedCategory == null,
                onTap: () =>
                    ref.read(_selectedCategoryProvider.notifier).state = null,
              ),
              ...categories.map((cat) => _CategoryChip(
                    label: cat.name,
                    isSelected: selectedCategory == cat.id,
                    onTap: () => ref
                        .read(_selectedCategoryProvider.notifier)
                        .state = cat.id,
                  )),
            ],
          );
        },
        loading: () => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
          ),
        ),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1) : _C.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : _C.border,
              width: isSelected ? 0 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : _C.textSecondary,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Product grid
// ---------------------------------------------------------------------------

class _ProductGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_filteredProductsProvider);

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
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 56,
                    color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada produk',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Produk akan muncul di sini',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _C.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final int crossAxisCount;
            if (constraints.maxWidth > 900) {
              crossAxisCount = 5;
            } else if (constraints.maxWidth > 700) {
              crossAxisCount = 4;
            } else if (constraints.maxWidth > 450) {
              crossAxisCount = 3;
            } else {
              crossAxisCount = 2;
            }

            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1.0,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return _OnlineFoodProductCard(product: products[index]);
              },
            );
          },
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF6366F1),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat produk...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _C.textSecondary,
              ),
            ),
          ],
        ),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 44,
                color: const Color(0xFFEF4444).withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Terjadi Kesalahan',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _C.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error.toString(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFFEF4444),
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

// ---------------------------------------------------------------------------
// Single product card – icon + name, NO price.  Shows qty badge if in cart.
// ---------------------------------------------------------------------------

class _OnlineFoodProductCard extends ConsumerStatefulWidget {
  final Product product;
  const _OnlineFoodProductCard({required this.product});

  @override
  ConsumerState<_OnlineFoodProductCard> createState() =>
      _OnlineFoodProductCardState();
}

class _OnlineFoodProductCardState
    extends ConsumerState<_OnlineFoodProductCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onlineFoodProvider);
    // Find qty of this product in the online food cart
    final qtyInCart = state.items
        .where((i) => i.productId == widget.product.id)
        .fold<int>(0, (sum, i) => sum + i.quantity);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          ref.read(onlineFoodProvider.notifier).addItem(
                widget.product.id,
                widget.product.name,
              );
        },
        child: AnimatedScale(
          scale: _isHovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered
                    ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                    : _C.border,
                width: _isHovered ? 1.5 : 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                // Content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Product icon / initial
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF6366F1).withValues(alpha: 0.5),
                              const Color(0xFF6366F1).withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            widget.product.name.isNotEmpty
                                ? widget.product.name[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Product name
                      Text(
                        widget.product.name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _C.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Qty badge
                if (qtyInCart > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$qtyInCart',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
