/// Defines all available AI tools (function declarations) for Gemini.
///
/// These tools let the AI execute real actions in the POS system:
/// CRUD products, categories, stock management, etc.
class AiTools {
  static const List<Map<String, dynamic>> toolDeclarations = [
    // ── Product Management ──────────────────────────────────
    {
      'name': 'create_product',
      'description': 'Tambah produk/menu baru ke sistem POS. Gunakan ini saat user minta menambahkan menu baru.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'name': {'type': 'STRING', 'description': 'Nama produk/menu'},
          'selling_price': {'type': 'NUMBER', 'description': 'Harga jual dalam Rupiah'},
          'cost_price': {'type': 'NUMBER', 'description': 'Harga modal/HPP dalam Rupiah (opsional, default 0)'},
          'category_name': {'type': 'STRING', 'description': 'Nama kategori (opsional)'},
          'description': {'type': 'STRING', 'description': 'Deskripsi produk (opsional)'},
        },
        'required': ['name', 'selling_price'],
      },
    },
    {
      'name': 'update_product',
      'description': 'Update produk yang sudah ada. Bisa ubah nama, harga, kategori, atau deskripsi.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'product_name': {'type': 'STRING', 'description': 'Nama produk yang ingin diupdate (pencarian fuzzy)'},
          'new_name': {'type': 'STRING', 'description': 'Nama baru (opsional)'},
          'selling_price': {'type': 'NUMBER', 'description': 'Harga jual baru (opsional)'},
          'cost_price': {'type': 'NUMBER', 'description': 'Harga modal baru (opsional)'},
          'description': {'type': 'STRING', 'description': 'Deskripsi baru (opsional)'},
        },
        'required': ['product_name'],
      },
    },
    {
      'name': 'delete_product',
      'description': 'Hapus produk dari sistem. Gunakan saat user minta menghapus menu.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'product_name': {'type': 'STRING', 'description': 'Nama produk yang ingin dihapus'},
        },
        'required': ['product_name'],
      },
    },
    {
      'name': 'toggle_product',
      'description': 'Aktifkan atau nonaktifkan produk tanpa menghapus. Berguna untuk menu yang habis sementara.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'product_name': {'type': 'STRING', 'description': 'Nama produk'},
          'is_active': {'type': 'BOOLEAN', 'description': 'true untuk aktifkan, false untuk nonaktifkan'},
        },
        'required': ['product_name', 'is_active'],
      },
    },
    {
      'name': 'list_products',
      'description': 'Lihat daftar semua produk/menu. Bisa filter berdasarkan kategori.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'category_name': {'type': 'STRING', 'description': 'Filter berdasarkan kategori (opsional)'},
          'active_only': {'type': 'BOOLEAN', 'description': 'Hanya produk aktif (default true)'},
        },
      },
    },

    // ── Category Management ─────────────────────────────────
    {
      'name': 'create_category',
      'description': 'Buat kategori baru untuk produk/menu.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'name': {'type': 'STRING', 'description': 'Nama kategori'},
          'color': {'type': 'STRING', 'description': 'Warna hex (contoh: #EF4444) (opsional)'},
        },
        'required': ['name'],
      },
    },
    {
      'name': 'delete_category',
      'description': 'Hapus kategori. Produk di kategori ini akan jadi Tanpa Kategori.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'category_name': {'type': 'STRING', 'description': 'Nama kategori yang ingin dihapus'},
        },
        'required': ['category_name'],
      },
    },

    // ── Inventory/Stock Management ──────────────────────────
    {
      'name': 'update_stock',
      'description': 'Update stok bahan baku/ingredient. Bisa set ke nilai tertentu atau tambah/kurang.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'ingredient_name': {'type': 'STRING', 'description': 'Nama bahan baku'},
          'new_quantity': {'type': 'NUMBER', 'description': 'Stok baru (set langsung ke angka ini)'},
          'adjustment': {'type': 'NUMBER', 'description': 'Penyesuaian stok (+/- dari stok sekarang)'},
          'notes': {'type': 'STRING', 'description': 'Catatan perubahan stok'},
        },
        'required': ['ingredient_name'],
      },
    },
    {
      'name': 'list_ingredients',
      'description': 'Lihat daftar semua bahan baku dan stoknya.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'low_stock_only': {'type': 'BOOLEAN', 'description': 'Hanya tampilkan stok menipis (default false)'},
        },
      },
    },

    // ── Sales & Analytics ───────────────────────────────────
    {
      'name': 'get_sales_summary',
      'description': 'Dapatkan ringkasan penjualan. Bisa hari ini, kemarin, minggu ini, atau rentang tanggal tertentu.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'period': {'type': 'STRING', 'description': 'Periode: "today", "yesterday", "this_week", "this_month", "custom"'},
          'start_date': {'type': 'STRING', 'description': 'Tanggal mulai (YYYY-MM-DD) untuk period custom'},
          'end_date': {'type': 'STRING', 'description': 'Tanggal akhir (YYYY-MM-DD) untuk period custom'},
        },
      },
    },

    // ── Discount Management ─────────────────────────────────
    {
      'name': 'create_discount',
      'description': 'Buat diskon/promo baru.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'name': {'type': 'STRING', 'description': 'Nama diskon (contoh: "Promo Weekend")'},
          'type': {'type': 'STRING', 'description': '"percentage" atau "fixed"'},
          'value': {'type': 'NUMBER', 'description': 'Nilai diskon (% atau Rp)'},
          'min_purchase': {'type': 'NUMBER', 'description': 'Minimum pembelian (opsional)'},
        },
        'required': ['name', 'type', 'value'],
      },
    },
  ];
}
