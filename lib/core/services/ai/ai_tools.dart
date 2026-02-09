/// Defines all available AI tools (function declarations) for OpenAI.
///
/// These tools let the AI execute real actions in the POS system:
/// CRUD products, categories, stock management, etc.
class AiTools {
  static const List<Map<String, dynamic>> toolDeclarations = [
    // ── Product Management ──────────────────────────────────
    {
      'type': 'function',
      'function': {
        'name': 'create_product',
        'description': 'Tambah produk/menu baru ke sistem POS. Gunakan ini saat user minta menambahkan menu baru.',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Nama produk/menu'},
            'selling_price': {'type': 'number', 'description': 'Harga jual dalam Rupiah'},
            'cost_price': {'type': 'number', 'description': 'Harga modal/HPP dalam Rupiah (opsional, default 0)'},
            'category_name': {'type': 'string', 'description': 'Nama kategori (opsional)'},
            'description': {'type': 'string', 'description': 'Deskripsi produk (opsional)'},
          },
          'required': ['name', 'selling_price'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_product',
        'description': 'Update produk yang sudah ada. Bisa ubah nama, harga, kategori, atau deskripsi.',
        'parameters': {
          'type': 'object',
          'properties': {
            'product_name': {'type': 'string', 'description': 'Nama produk yang ingin diupdate (pencarian fuzzy)'},
            'new_name': {'type': 'string', 'description': 'Nama baru (opsional)'},
            'selling_price': {'type': 'number', 'description': 'Harga jual baru (opsional)'},
            'cost_price': {'type': 'number', 'description': 'Harga modal baru (opsional)'},
            'description': {'type': 'string', 'description': 'Deskripsi baru (opsional)'},
          },
          'required': ['product_name'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_product',
        'description': 'Hapus produk dari sistem. Gunakan saat user minta menghapus menu.',
        'parameters': {
          'type': 'object',
          'properties': {
            'product_name': {'type': 'string', 'description': 'Nama produk yang ingin dihapus'},
          },
          'required': ['product_name'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'toggle_product',
        'description': 'Aktifkan atau nonaktifkan produk tanpa menghapus. Berguna untuk menu yang habis sementara.',
        'parameters': {
          'type': 'object',
          'properties': {
            'product_name': {'type': 'string', 'description': 'Nama produk'},
            'is_active': {'type': 'boolean', 'description': 'true untuk aktifkan, false untuk nonaktifkan'},
          },
          'required': ['product_name', 'is_active'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'list_products',
        'description': 'Lihat daftar semua produk/menu. Bisa filter berdasarkan kategori.',
        'parameters': {
          'type': 'object',
          'properties': {
            'category_name': {'type': 'string', 'description': 'Filter berdasarkan kategori (opsional)'},
            'active_only': {'type': 'boolean', 'description': 'Hanya produk aktif (default true)'},
          },
        },
      },
    },

    // ── Category Management ─────────────────────────────────
    {
      'type': 'function',
      'function': {
        'name': 'create_category',
        'description': 'Buat kategori baru untuk produk/menu.',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Nama kategori'},
            'color': {'type': 'string', 'description': 'Warna hex (contoh: #EF4444) (opsional)'},
          },
          'required': ['name'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_category',
        'description': 'Hapus kategori. Produk di kategori ini akan jadi Tanpa Kategori.',
        'parameters': {
          'type': 'object',
          'properties': {
            'category_name': {'type': 'string', 'description': 'Nama kategori yang ingin dihapus'},
          },
          'required': ['category_name'],
        },
      },
    },

    // ── Inventory/Stock Management ──────────────────────────
    {
      'type': 'function',
      'function': {
        'name': 'update_stock',
        'description': 'Update stok bahan baku/ingredient. Bisa set ke nilai tertentu atau tambah/kurang.',
        'parameters': {
          'type': 'object',
          'properties': {
            'ingredient_name': {'type': 'string', 'description': 'Nama bahan baku'},
            'new_quantity': {'type': 'number', 'description': 'Stok baru (set langsung ke angka ini)'},
            'adjustment': {'type': 'number', 'description': 'Penyesuaian stok (+/- dari stok sekarang)'},
            'notes': {'type': 'string', 'description': 'Catatan perubahan stok'},
          },
          'required': ['ingredient_name'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'list_ingredients',
        'description': 'Lihat daftar semua bahan baku dan stoknya.',
        'parameters': {
          'type': 'object',
          'properties': {
            'low_stock_only': {'type': 'boolean', 'description': 'Hanya tampilkan stok menipis (default false)'},
          },
        },
      },
    },

    // ── Sales & Analytics ───────────────────────────────────
    {
      'type': 'function',
      'function': {
        'name': 'get_sales_summary',
        'description': 'Dapatkan ringkasan penjualan. Bisa hari ini, kemarin, minggu ini, atau rentang tanggal tertentu.',
        'parameters': {
          'type': 'object',
          'properties': {
            'period': {'type': 'string', 'description': 'Periode: "today", "yesterday", "this_week", "this_month", "custom"'},
            'start_date': {'type': 'string', 'description': 'Tanggal mulai (YYYY-MM-DD) untuk period custom'},
            'end_date': {'type': 'string', 'description': 'Tanggal akhir (YYYY-MM-DD) untuk period custom'},
          },
        },
      },
    },

    // ── Discount Management ─────────────────────────────────
    {
      'type': 'function',
      'function': {
        'name': 'create_discount',
        'description': 'Buat diskon/promo baru.',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Nama diskon (contoh: "Promo Weekend")'},
            'type': {'type': 'string', 'description': '"percentage" atau "fixed"'},
            'value': {'type': 'number', 'description': 'Nilai diskon (% atau Rp)'},
            'min_purchase': {'type': 'number', 'description': 'Minimum pembelian (opsional)'},
          },
          'required': ['name', 'type', 'value'],
        },
      },
    },

    // ── Operational Costs ─────────────────────────────────────
    {
      'type': 'function',
      'function': {
        'name': 'get_operational_costs',
        'description': 'Lihat daftar biaya operasional bulanan (sewa, listrik, gas, air, internet, gaji) dan bonus karyawan. '
            'Gunakan saat user tanya tentang biaya operasional, overhead, atau HPP.',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_operational_cost',
        'description': 'Update nominal biaya operasional bulanan. Bisa update sewa, listrik, gas, air, internet, gaji, atau bonus karyawan.',
        'parameters': {
          'type': 'object',
          'properties': {
            'cost_name': {'type': 'string', 'description': 'Nama biaya (contoh: "Sewa Tempat", "Listrik", "Gaji Karyawan 1", "Bonus Karyawan")'},
            'amount': {'type': 'number', 'description': 'Nominal baru (Rp untuk biaya, % untuk bonus)'},
          },
          'required': ['cost_name', 'amount'],
        },
      },
    },

    // ── AI Memory (OTAK) ─────────────────────────────────────
    {
      'type': 'function',
      'function': {
        'name': 'save_memory',
        'description': 'Simpan insight/fakta penting tentang bisnis ke memori AI. '
            'Gunakan saat menemukan pola penjualan, preferensi pelanggan, atau fakta operasional penting. '
            'Contoh: "Kopi Latte paling laris di jam 12-14", "Weekend revenue 30% lebih tinggi".',
        'parameters': {
          'type': 'object',
          'properties': {
            'insight': {'type': 'string', 'description': 'Fakta/insight yang ingin disimpan'},
            'category': {
              'type': 'string',
              'description': 'Kategori: "sales", "product", "stock", "customer", "operational"',
            },
          },
          'required': ['insight', 'category'],
        },
      },
    },

    // ── Business Health Check (PERASAAN) ─────────────────────
    {
      'type': 'function',
      'function': {
        'name': 'check_business_health',
        'description': 'Cek kesehatan bisnis hari ini: mood, proyeksi revenue, stok menipis, prediksi jam sibuk. '
            'Gunakan saat user tanya tentang kondisi bisnis atau butuh gambaran umum.',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
  ];
}
