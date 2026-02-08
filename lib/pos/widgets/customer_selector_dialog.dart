import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/themes/app_theme.dart';
import '../../core/models/cart.dart';
import '../../core/models/customer.dart';
import '../repositories/pos_customer_repository.dart';
import '../providers/pos_cart_provider.dart';

class CustomerSelectorDialog extends ConsumerStatefulWidget {
  const CustomerSelectorDialog({super.key});

  @override
  ConsumerState<CustomerSelectorDialog> createState() => _CustomerSelectorDialogState();
}

class _CustomerSelectorDialogState extends ConsumerState<CustomerSelectorDialog> {
  final _searchController = TextEditingController();
  final _repo = PosCustomerRepository();
  List<Customer> _results = [];
  bool _loading = false;
  bool _showAddForm = false;

  // Form fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  Future<void> _search(String query) async {
    if (query.length < 2) { setState(() => _results = []); return; }
    setState(() => _loading = true);
    try {
      _results = await _repo.searchCustomers('a0000000-0000-0000-0000-000000000001', query);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final customer = await _repo.createCustomer(
        'a0000000-0000-0000-0000-000000000001',
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      );
      if (mounted) {
        ref.read(posCartProvider.notifier).setCustomer(
          CartCustomer(id: customer.id, name: customer.name, phone: customer.phone),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(posCartProvider);

    return Dialog(
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _showAddForm ? 'Tambah Customer Baru' : 'Pilih Customer',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),

            if (!_showAddForm) ...[
              // Search mode
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Cari nama atau telepon...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: _search,
              ),
              const SizedBox(height: 8),
              // Add new button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showAddForm = true),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Tambah Customer Baru'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )),
              if (!_loading && _results.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final c = _results[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(c.name),
                        subtitle: Text(c.phone ?? '-'),
                        trailing: Text('${c.loyaltyPoints} pts', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        onTap: () {
                          ref.read(posCartProvider.notifier).setCustomer(CartCustomer(id: c.id, name: c.name, phone: c.phone));
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              if (!_loading && _results.isEmpty && _searchController.text.length >= 2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        const Text('Customer tidak ditemukan', style: TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            _nameController.text = _searchController.text;
                            setState(() => _showAddForm = true);
                          },
                          child: const Text('Tambah sebagai customer baru'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (cart.customer != null)
                Center(
                  child: TextButton(
                    onPressed: () { ref.read(posCartProvider.notifier).setCustomer(null); Navigator.pop(context); },
                    child: const Text('Hapus Customer', style: TextStyle(color: AppTheme.errorColor)),
                  ),
                ),
            ] else ...[
              // Add form mode
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama *',
                        hintText: 'Nama customer',
                        prefixIcon: Icon(Icons.person),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'No. Telepon',
                        hintText: '08xxxxxxxxxx',
                        prefixIcon: Icon(Icons.phone),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'email@contoh.com',
                        prefixIcon: Icon(Icons.email),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : () => setState(() => _showAddForm = false),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _createCustomer,
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                            child: _saving
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Simpan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
