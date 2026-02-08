import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/online_food_provider.dart';
import 'widgets/platform_selector.dart';
import 'widgets/online_food_menu_grid.dart';
import 'widgets/online_food_cart.dart';

/// Dark-theme color constants for the Online Food feature.
class _C {
  static const background = Color(0xFF13131D);
  static const card = Color(0xFF1A1A28);
  static const border = Color(0xFF1E1E2E);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF9CA3AF);
  static const textTertiary = Color(0xFF6B7280);
}

/// Main screen for the Online Food Order feature.
///
/// Split layout:
/// - Left panel (flex 6, ~60%): Platform selector + order ID input + menu grid
/// - Right panel (flex 4, ~40%): Cart + final amount + submit button
class OnlineFoodScreen extends ConsumerStatefulWidget {
  const OnlineFoodScreen({super.key});

  @override
  ConsumerState<OnlineFoodScreen> createState() => _OnlineFoodScreenState();
}

class _OnlineFoodScreenState extends ConsumerState<OnlineFoodScreen> {
  final _orderIdController = TextEditingController();
  final _orderIdFocusNode = FocusNode();
  bool _orderIdFocused = false;

  @override
  void initState() {
    super.initState();
    _orderIdFocusNode.addListener(() {
      setState(() => _orderIdFocused = _orderIdFocusNode.hasFocus);
    });

    // Sync order ID controller with provider state
    final currentId = ref.read(onlineFoodProvider).platformOrderId;
    if (currentId.isNotEmpty) {
      _orderIdController.text = currentId;
    }
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    _orderIdFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for success to auto-clear the text field
    ref.listen<OnlineFoodState>(onlineFoodProvider, (prev, next) {
      if (next.isSuccess) {
        _orderIdController.clear();
      }
    });

    return Scaffold(
      backgroundColor: _C.background,
      appBar: AppBar(
        backgroundColor: _C.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _C.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Online Food Order',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _C.textPrimary,
          ),
        ),
        actions: [
          // Reset / clear button
          IconButton(
            icon: const Icon(Icons.refresh, color: _C.textSecondary),
            tooltip: 'Reset Form',
            onPressed: () {
              ref.read(onlineFoodProvider.notifier).reset();
              _orderIdController.clear();
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: _C.border,
          ),
        ),
      ),
      body: Row(
        children: [
          // ── Left Panel (Platform + Order ID + Menu Grid) ───────────
          Expanded(
            flex: 6,
            child: Column(
              children: [
                // Platform selector
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: const PlatformSelector(),
                ),

                // Order ID input
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _buildOrderIdInput(),
                ),

                // Divider
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: _C.border,
                ),

                // Menu grid
                const Expanded(child: OnlineFoodMenuGrid()),
              ],
            ),
          ),

          // ── Right Panel (Cart) ────────────────────────────────────
          const Expanded(
            flex: 4,
            child: OnlineFoodCart(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderIdInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _orderIdFocused ? const Color(0xFF6366F1) : _C.border,
          width: _orderIdFocused ? 1.5 : 1,
        ),
        boxShadow: _orderIdFocused
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _orderIdController,
        focusNode: _orderIdFocusNode,
        onChanged: (value) {
          ref.read(onlineFoodProvider.notifier).setPlatformOrderId(value.trim());
        },
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _C.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Masukkan Order ID platform...',
          hintStyle: GoogleFonts.inter(
            color: _C.textTertiary,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.tag,
            color: _orderIdFocused
                ? const Color(0xFF6366F1)
                : _C.textTertiary,
            size: 20,
          ),
          suffixIcon: _orderIdController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  color: _C.textTertiary,
                  onPressed: () {
                    _orderIdController.clear();
                    ref
                        .read(onlineFoodProvider.notifier)
                        .setPlatformOrderId('');
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
    );
  }
}
