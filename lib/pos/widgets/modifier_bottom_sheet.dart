import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../../shared/utils/format_utils.dart';
import '../../core/models/cart.dart';
import '../../core/models/product.dart';
import '../providers/pos_modifier_provider.dart';
import '../repositories/pos_modifier_repository.dart';

class ModifierBottomSheet extends ConsumerStatefulWidget {
  final Product product;
  final void Function(int quantity, List<SelectedModifier> modifiers, String? notes) onAdd;

  const ModifierBottomSheet({super.key, required this.product, required this.onAdd});

  @override
  ConsumerState<ModifierBottomSheet> createState() => _ModifierBottomSheetState();
}

class _ModifierBottomSheetState extends ConsumerState<ModifierBottomSheet> {
  int _quantity = 1;
  final _notesController = TextEditingController();
  // groupId → selected option ids
  final Map<String, Set<String>> _selections = {};
  // Cache group data for price calculation
  List<ModifierGroup> _groups = [];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _modifierTotal {
    double total = 0;
    for (final group in _groups) {
      final selectedIds = _selections[group.id] ?? {};
      for (final option in group.options) {
        if (selectedIds.contains(option.id)) {
          total += option.priceAdjustment;
        }
      }
    }
    return total;
  }

  double get _unitPrice => widget.product.sellingPrice + _modifierTotal;
  double get _totalPrice => _unitPrice * _quantity;

  List<SelectedModifier> get _selectedModifiers {
    final modifiers = <SelectedModifier>[];
    for (final group in _groups) {
      final selectedIds = _selections[group.id] ?? {};
      for (final option in group.options) {
        if (selectedIds.contains(option.id)) {
          modifiers.add(SelectedModifier(
            groupName: group.name,
            optionName: option.name,
            priceAdjustment: option.priceAdjustment,
          ));
        }
      }
    }
    return modifiers;
  }

  bool get _isValid {
    for (final group in _groups) {
      if (group.isRequired) {
        final selectedIds = _selections[group.id] ?? {};
        if (selectedIds.isEmpty) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final modifierGroupsAsync = ref.watch(posModifierGroupsProvider(widget.product.id));

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(widget.product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(FormatUtils.currency(widget.product.sellingPrice), style: const TextStyle(fontSize: 15, color: AppTheme.primaryColor)),
          const SizedBox(height: 16),

          // Modifier groups
          Flexible(
            child: modifierGroupsAsync.when(
              data: (groups) {
                _groups = groups;
                if (groups.isEmpty) return const SizedBox.shrink();
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  itemBuilder: (_, i) => _buildModifierGroup(groups[i]),
                );
              },
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),

          const SizedBox(height: 12),

          // Quantity
          Row(
            children: [
              const Text('Jumlah:', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null),
              Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _quantity++)),
            ],
          ),

          const SizedBox(height: 12),

          // Notes
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(hintText: 'Catatan (opsional)', isDense: true),
          ),

          const SizedBox(height: 20),

          // Add button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isValid
                  ? () {
                      widget.onAdd(
                        _quantity,
                        _selectedModifiers,
                        _notesController.text.isEmpty ? null : _notesController.text,
                      );
                      Navigator.pop(context);
                    }
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text('Tambah - ${FormatUtils.currency(_totalPrice)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModifierGroup(ModifierGroup group) {
    final selectedIds = _selections[group.id] ?? {};
    final isSingle = group.selectionType == 'single';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              if (group.isRequired) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Wajib', style: TextStyle(fontSize: 10, color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ...group.options.where((o) => o.isAvailable).map((option) {
            final isSelected = selectedIds.contains(option.id);
            return InkWell(
              onTap: () {
                setState(() {
                  if (isSingle) {
                    // Radio behavior
                    if (isSelected && !group.isRequired) {
                      _selections[group.id] = {};
                    } else {
                      _selections[group.id] = {option.id};
                    }
                  } else {
                    // Checkbox behavior
                    final current = Set<String>.from(selectedIds);
                    if (isSelected) {
                      current.remove(option.id);
                    } else {
                      if (group.maxSelections != null && current.length >= group.maxSelections!) {
                        return;
                      }
                      current.add(option.id);
                    }
                    _selections[group.id] = current;
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      isSingle
                          ? (isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked)
                          : (isSelected ? Icons.check_box : Icons.check_box_outline_blank),
                      size: 20,
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(option.name, style: const TextStyle(fontSize: 14))),
                    if (option.priceAdjustment != 0)
                      Text(
                        '+ ${FormatUtils.currency(option.priceAdjustment)}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
