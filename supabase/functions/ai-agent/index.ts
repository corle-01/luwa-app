// =================================================================
// UTTER APP - AI Agent Edge Function
// Main chat handler with DeepSeek AI + function calling
// =================================================================

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// --------------- CORS ---------------
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// --------------- Types ---------------
interface ChatRequest {
  message: string;
  conversation_id: string | null;
  outlet_id: string;
  user_id: string;
  context?: Record<string, unknown>;
}

interface FunctionCall {
  name: string;
  arguments: string;
}

interface DeepSeekMessage {
  role: "system" | "user" | "assistant" | "function";
  content: string | null;
  function_call?: FunctionCall;
  name?: string;
}

// --------------- System Prompt ---------------
function buildSystemPrompt(
  outletName: string,
  userName: string,
  context?: Record<string, unknown>
): string {
  return `Kamu adalah Utter AI, asisten bisnis cerdas untuk outlet "${outletName}".

KEPRIBADIAN:
- Kasual-profesional, seperti teman bisnis yang paham data
- Proaktif menawarkan insight dan saran
- Selalu bicara dalam Bahasa Indonesia
- Gunakan "kamu" untuk menyapa user, bukan "Anda"
- Sering gunakan emoji yang relevan tapi jangan berlebihan
- Kalau ada data, selalu tampilkan dengan format yang rapi
- Kalau nggak yakin, tanya balik daripada asumsi salah

KEMAMPUAN:
- Lihat dan analisis data penjualan, stok, produk
- Buat purchase order, adjust stok, kelola produk
- Buat diskon dan promo
- Forecast demand dan detect anomali
- Sarankan harga optimal
- Generate laporan

ATURAN PENTING:
- Kamu HANYA bisa melakukan aksi pada outlet ini (outlet_id akan di-filter)
- Sebelum melakukan aksi yang mengubah data (write), kamu HARUS memastikan trust level cukup
- Kalau trust level kurang, informasikan ke user dan minta mereka mengubah setting
- Selalu konfirmasi sebelum melakukan aksi besar (buat PO, ubah harga, dll) kecuali trust level sudah cukup tinggi
- Format angka uang pakai Rupiah (Rp) dengan pemisah ribuan titik
- Format tanggal pakai format Indonesia (DD/MM/YYYY)

User saat ini: ${userName}
${context ? `Konteks tambahan: ${JSON.stringify(context)}` : ""}`;
}

// --------------- DeepSeek Tool Definitions ---------------
const tools = [
  {
    name: "get_sales_summary",
    description:
      "Mendapatkan ringkasan penjualan outlet untuk periode tertentu. Bisa per hari, minggu, atau bulan.",
    parameters: {
      type: "object",
      properties: {
        period: {
          type: "string",
          enum: ["today", "yesterday", "this_week", "last_week", "this_month", "last_month", "custom"],
          description: "Periode ringkasan penjualan",
        },
        start_date: {
          type: "string",
          description: "Tanggal mulai (YYYY-MM-DD) untuk period=custom",
        },
        end_date: {
          type: "string",
          description: "Tanggal akhir (YYYY-MM-DD) untuk period=custom",
        },
      },
      required: ["period"],
    },
  },
  {
    name: "get_stock_levels",
    description:
      "Melihat level stok bahan baku saat ini. Bisa filter status: all, low_stock, out_of_stock, overstock.",
    parameters: {
      type: "object",
      properties: {
        status_filter: {
          type: "string",
          enum: ["all", "low_stock", "out_of_stock", "overstock", "healthy"],
          description: "Filter berdasarkan status stok",
        },
        search: {
          type: "string",
          description: "Cari ingredient berdasarkan nama",
        },
      },
      required: [],
    },
  },
  {
    name: "get_top_products",
    description:
      "Mendapatkan produk terlaris berdasarkan jumlah terjual atau revenue.",
    parameters: {
      type: "object",
      properties: {
        period: {
          type: "string",
          enum: ["today", "this_week", "this_month", "last_month"],
          description: "Periode analisis",
        },
        sort_by: {
          type: "string",
          enum: ["quantity", "revenue"],
          description: "Urutkan berdasarkan jumlah atau revenue",
        },
        limit: {
          type: "number",
          description: "Jumlah produk yang ditampilkan (default 10)",
        },
      },
      required: ["period"],
    },
  },
  {
    name: "get_product_hpp",
    description:
      "Lihat HPP (Harga Pokok Produksi) dan margin profit setiap produk.",
    parameters: {
      type: "object",
      properties: {
        product_name: {
          type: "string",
          description: "Filter nama produk tertentu (opsional)",
        },
        sort_by: {
          type: "string",
          enum: ["profit_percent", "hpp", "selling_price"],
          description: "Urutkan berdasarkan",
        },
      },
      required: [],
    },
  },
  {
    name: "create_purchase_order",
    description:
      "Buat Purchase Order (PO) baru untuk restock bahan baku. AKSI WRITE - butuh trust level.",
    parameters: {
      type: "object",
      properties: {
        supplier_id: {
          type: "string",
          description: "ID supplier",
        },
        items: {
          type: "array",
          items: {
            type: "object",
            properties: {
              ingredient_id: { type: "string" },
              quantity: { type: "number" },
              unit_cost: { type: "number" },
            },
            required: ["ingredient_id", "quantity"],
          },
          description: "Daftar item yang dipesan",
        },
        notes: {
          type: "string",
          description: "Catatan untuk PO",
        },
      },
      required: ["items"],
    },
  },
  {
    name: "adjust_stock",
    description:
      "Sesuaikan stok bahan baku (stock opname, koreksi, waste). AKSI WRITE - butuh trust level.",
    parameters: {
      type: "object",
      properties: {
        ingredient_id: { type: "string", description: "ID bahan baku" },
        adjustment_type: {
          type: "string",
          enum: ["adjustment", "waste", "stock_in", "stock_out"],
          description: "Jenis penyesuaian",
        },
        quantity: {
          type: "number",
          description: "Jumlah penyesuaian (positif = tambah, negatif = kurang)",
        },
        notes: { type: "string", description: "Alasan penyesuaian" },
      },
      required: ["ingredient_id", "adjustment_type", "quantity"],
    },
  },
  {
    name: "toggle_product_availability",
    description:
      "Aktifkan atau nonaktifkan ketersediaan produk. AKSI WRITE - butuh trust level.",
    parameters: {
      type: "object",
      properties: {
        product_id: { type: "string", description: "ID produk" },
        is_available: {
          type: "boolean",
          description: "true = tersedia, false = tidak tersedia",
        },
        reason: { type: "string", description: "Alasan perubahan" },
      },
      required: ["product_id", "is_available"],
    },
  },
  {
    name: "update_product_price",
    description:
      "Ubah harga jual produk. AKSI WRITE - butuh trust level.",
    parameters: {
      type: "object",
      properties: {
        product_id: { type: "string", description: "ID produk" },
        new_price: { type: "number", description: "Harga baru dalam Rupiah" },
        reason: { type: "string", description: "Alasan perubahan harga" },
      },
      required: ["product_id", "new_price"],
    },
  },
  {
    name: "create_discount",
    description:
      "Buat diskon atau promo baru. AKSI WRITE - butuh trust level.",
    parameters: {
      type: "object",
      properties: {
        name: { type: "string", description: "Nama diskon" },
        type: {
          type: "string",
          enum: ["percentage", "fixed_amount"],
          description: "Jenis diskon",
        },
        value: { type: "number", description: "Nilai diskon (persen atau nominal)" },
        min_purchase: {
          type: "number",
          description: "Minimum pembelian (opsional)",
        },
        max_discount: {
          type: "number",
          description: "Maksimum potongan (opsional, untuk persentase)",
        },
        start_date: { type: "string", description: "Tanggal mulai (ISO)" },
        end_date: { type: "string", description: "Tanggal berakhir (ISO)" },
        applicable_to: {
          type: "string",
          enum: ["all", "category", "product"],
          description: "Berlaku untuk",
        },
        applicable_ids: {
          type: "array",
          items: { type: "string" },
          description: "ID kategori/produk yang berlaku",
        },
      },
      required: ["name", "type", "value"],
    },
  },
  {
    name: "get_shift_summary",
    description:
      "Lihat ringkasan shift kasir - total penjualan, jumlah order, refund.",
    parameters: {
      type: "object",
      properties: {
        shift_id: { type: "string", description: "ID shift tertentu (opsional)" },
        status: {
          type: "string",
          enum: ["open", "closed", "all"],
          description: "Filter status shift",
        },
        date: { type: "string", description: "Filter tanggal (YYYY-MM-DD)" },
      },
      required: [],
    },
  },
  {
    name: "get_customer_info",
    description:
      "Lihat informasi pelanggan - riwayat belanja, loyalty points.",
    parameters: {
      type: "object",
      properties: {
        customer_id: { type: "string", description: "ID pelanggan" },
        search: { type: "string", description: "Cari pelanggan berdasarkan nama/phone" },
        sort_by: {
          type: "string",
          enum: ["total_spent", "total_orders", "recent"],
          description: "Urutkan berdasarkan",
        },
        limit: { type: "number", description: "Jumlah data" },
      },
      required: [],
    },
  },
  {
    name: "forecast_demand",
    description:
      "Prediksi permintaan/penggunaan bahan baku berdasarkan data historis.",
    parameters: {
      type: "object",
      properties: {
        ingredient_id: {
          type: "string",
          description: "ID bahan baku tertentu (opsional, kosong = semua)",
        },
        forecast_days: {
          type: "number",
          description: "Prediksi untuk berapa hari ke depan (default 7)",
        },
      },
      required: [],
    },
  },
  {
    name: "detect_anomalies",
    description:
      "Deteksi anomali di penjualan, void, refund, atau stok.",
    parameters: {
      type: "object",
      properties: {
        check_type: {
          type: "string",
          enum: ["voids", "refunds", "sales_drop", "stock_discrepancy"],
          description: "Jenis anomali yang dicek",
        },
        period_days: {
          type: "number",
          description: "Periode analisis (default 7 hari)",
        },
      },
      required: ["check_type"],
    },
  },
  {
    name: "suggest_pricing",
    description:
      "Saran harga optimal berdasarkan HPP, margin, dan volume penjualan.",
    parameters: {
      type: "object",
      properties: {
        product_id: {
          type: "string",
          description: "ID produk tertentu (opsional)",
        },
        target_margin: {
          type: "number",
          description: "Target margin persen (default 30)",
        },
      },
      required: [],
    },
  },
  {
    name: "generate_report",
    description:
      "Generate laporan lengkap (penjualan, stok, profit, performa produk).",
    parameters: {
      type: "object",
      properties: {
        report_type: {
          type: "string",
          enum: ["daily_sales", "weekly_summary", "monthly_summary", "stock_report", "product_performance", "profit_analysis"],
          description: "Jenis laporan",
        },
        date: {
          type: "string",
          description: "Tanggal referensi (YYYY-MM-DD, default hari ini)",
        },
      },
      required: ["report_type"],
    },
  },
  {
    name: "get_order_details",
    description:
      "Lihat detail order/transaksi tertentu atau riwayat order terbaru.",
    parameters: {
      type: "object",
      properties: {
        order_id: { type: "string", description: "ID order tertentu" },
        order_number: { type: "string", description: "Nomor order" },
        status: {
          type: "string",
          enum: ["pending", "preparing", "ready", "completed", "cancelled", "refunded"],
          description: "Filter status",
        },
        limit: { type: "number", description: "Jumlah order (default 10)" },
      },
      required: [],
    },
  },
];

// --------------- Date helpers ---------------
function getDateRange(period: string, startDate?: string, endDate?: string): { start: string; end: string } {
  const now = new Date();
  const jakartaOffset = 7 * 60 * 60 * 1000;
  const jakartaNow = new Date(now.getTime() + jakartaOffset);
  const todayStr = jakartaNow.toISOString().split("T")[0];

  switch (period) {
    case "today":
      return { start: todayStr, end: todayStr };
    case "yesterday": {
      const y = new Date(jakartaNow);
      y.setDate(y.getDate() - 1);
      const yStr = y.toISOString().split("T")[0];
      return { start: yStr, end: yStr };
    }
    case "this_week": {
      const d = new Date(jakartaNow);
      const day = d.getDay();
      const diff = d.getDate() - day + (day === 0 ? -6 : 1);
      d.setDate(diff);
      return { start: d.toISOString().split("T")[0], end: todayStr };
    }
    case "last_week": {
      const d = new Date(jakartaNow);
      const day = d.getDay();
      const diff = d.getDate() - day + (day === 0 ? -6 : 1);
      d.setDate(diff - 7);
      const s = d.toISOString().split("T")[0];
      d.setDate(d.getDate() + 6);
      return { start: s, end: d.toISOString().split("T")[0] };
    }
    case "this_month":
      return {
        start: `${todayStr.slice(0, 7)}-01`,
        end: todayStr,
      };
    case "last_month": {
      const d = new Date(jakartaNow);
      d.setMonth(d.getMonth() - 1);
      const s = `${d.toISOString().split("T")[0].slice(0, 7)}-01`;
      const lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0);
      return { start: s, end: lastDay.toISOString().split("T")[0] };
    }
    case "custom":
      return {
        start: startDate || todayStr,
        end: endDate || todayStr,
      };
    default:
      return { start: todayStr, end: todayStr };
  }
}

// --------------- Function Handlers ---------------
async function executeFunctionCall(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  userId: string,
  fnName: string,
  args: Record<string, unknown>
): Promise<string> {
  try {
    switch (fnName) {
      case "get_sales_summary":
        return await handleGetSalesSummary(supabase, outletId, args);
      case "get_stock_levels":
        return await handleGetStockLevels(supabase, outletId, args);
      case "get_top_products":
        return await handleGetTopProducts(supabase, outletId, args);
      case "get_product_hpp":
        return await handleGetProductHpp(supabase, outletId, args);
      case "create_purchase_order":
        return await handleCreatePurchaseOrder(supabase, outletId, userId, args);
      case "adjust_stock":
        return await handleAdjustStock(supabase, outletId, userId, args);
      case "toggle_product_availability":
        return await handleToggleProductAvailability(supabase, outletId, args);
      case "update_product_price":
        return await handleUpdateProductPrice(supabase, outletId, args);
      case "create_discount":
        return await handleCreateDiscount(supabase, outletId, userId, args);
      case "get_shift_summary":
        return await handleGetShiftSummary(supabase, outletId, args);
      case "get_customer_info":
        return await handleGetCustomerInfo(supabase, outletId, args);
      case "forecast_demand":
        return await handleForecastDemand(supabase, outletId, args);
      case "detect_anomalies":
        return await handleDetectAnomalies(supabase, outletId, args);
      case "suggest_pricing":
        return await handleSuggestPricing(supabase, outletId, args);
      case "generate_report":
        return await handleGenerateReport(supabase, outletId, args);
      case "get_order_details":
        return await handleGetOrderDetails(supabase, outletId, args);
      default:
        return JSON.stringify({ error: `Unknown function: ${fnName}` });
    }
  } catch (err) {
    console.error(`Error executing ${fnName}:`, err);
    return JSON.stringify({ error: `Gagal menjalankan ${fnName}: ${(err as Error).message}` });
  }
}

// --- Write-action feature keys ---
const writeActionFeatureKeys: Record<string, string> = {
  create_purchase_order: "draft_purchase_order",
  adjust_stock: "stock_alert",
  toggle_product_availability: "auto_disable_product",
  update_product_price: "pricing_recommendation",
  create_discount: "auto_promo",
};

async function checkTrustLevel(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  featureKey: string
): Promise<{ allowed: boolean; level: number }> {
  const { data } = await supabase
    .from("ai_trust_settings")
    .select("trust_level, is_enabled")
    .eq("outlet_id", outletId)
    .eq("feature_key", featureKey)
    .single();

  if (!data || !data.is_enabled) {
    return { allowed: false, level: 0 };
  }
  // trust_level >= 2 means auto-execute allowed
  return { allowed: data.trust_level >= 2, level: data.trust_level };
}

// --- Handler implementations ---

async function handleGetSalesSummary(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  args: Record<string, unknown>
): Promise<string> {
  const { start, end } = getDateRange(
    args.period as string,
    args.start_date as string,
    args.end_date as string
  );

  const { data, error } = await supabase
    .from("orders")
    .select("id, total, discount_amount, tax_amount, status, payment_method, created_at")
    .eq("outlet_id", outletId)
    .gte("created_at", `${start}T00:00:00+07:00`)
    .lte("created_at", `${end}T23:59:59+07:00`);

  if (error) return JSON.stringify({ error: error.message });

  const orders = data || [];
  const completed = orders.filter((o) => o.status === "completed");
  const cancelled = orders.filter((o) => o.status === "cancelled" || o.status === "refunded");
  const totalRevenue = completed.reduce((s, o) => s + Number(o.total), 0);
  const totalDiscount = completed.reduce((s, o) => s + Number(o.discount_amount), 0);
  const totalTax = completed.reduce((s, o) => s + Number(o.tax_amount), 0);
  const avgOrderValue = completed.length > 0 ? totalRevenue / completed.length : 0;

  // Payment method breakdown
  const paymentBreakdown: Record<string, { count: number; total: number }> = {};
  for (const o of completed) {
    const method = o.payment_method || "unknown";
    if (!paymentBreakdown[method]) paymentBreakdown[method] = { count: 0, total: 0 };
    paymentBreakdown[method].count++;
    paymentBreakdown[method].total += Number(o.total);
  }

  return JSON.stringify({
    period: { start, end },
    total_orders: orders.length,
    completed_orders: completed.length,
    cancelled_orders: cancelled.length,
    total_revenue: totalRevenue,
    total_discount: totalDiscount,
    total_tax: totalTax,
    avg_order_value: Math.round(avgOrderValue),
    payment_breakdown: paymentBreakdown,
  });
}

async function handleGetStockLevels(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  args: Record<string, unknown>
): Promise<string> {
  let query = supabase
    .from("low_stock_alerts")
    .select("*")
    .eq("outlet_id", outletId);

  const statusFilter = args.status_filter as string;
  if (statusFilter && statusFilter !== "all") {
    query = query.eq("stock_status", statusFilter);
  }

  if (args.search) {
    query = query.ilike("name", `%${args.search}%`);
  }

  const { data, error } = await query.order("stock_status");

  if (error) return JSON.stringify({ error: error.message });

  const summary = {
    total_items: (data || []).length,
    out_of_stock: (data || []).filter((d) => d.stock_status === "out_of_stock").length,
    low_stock: (data || []).filter((d) => d.stock_status === "low_stock").length,
    overstock: (data || []).filter((d) => d.stock_status === "overstock").length,
    healthy: (data || []).filter((d) => d.stock_status === "healthy").length,
    items: (data || []).map((d) => ({
      id: d.id,
      name: d.name,
      unit: d.unit,
      current_stock: d.current_stock,
      min_stock: d.min_stock,
      max_stock: d.max_stock,
      cost_per_unit: d.cost_per_unit,
      supplier_name: d.supplier_name,
      supplier_id: d.supplier_id,
      status: d.stock_status,
    })),
  };
  return JSON.stringify(summary);
}

async function handleGetTopProducts(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  args: Record<string, unknown>
): Promise<string> {
  const { start, end } = getDateRange(args.period as string);
  const limit = (args.limit as number) || 10;
  const sortBy = (args.sort_by as string) || "quantity";

  const { data, error } = await supabase
    .from("order_items")
    .select(`
      product_id,
      product_name,
      quantity,
      total,
      order:orders!inner(outlet_id, status, created_at)
    `)
    .eq("order.outlet_id", outletId)
    .eq("order.status", "completed")
    .gte("order.created_at", `${start}T00:00:00+07:00`)
    .lte("order.created_at", `${end}T23:59:59+07:00`);

  if (error) return JSON.stringify({ error: error.message });

  // Aggregate by product
  const productMap: Record<string, { name: string; qty: number; revenue: number }> = {};
  for (const item of data || []) {
    const pid = item.product_id;
    if (!productMap[pid]) {
      productMap[pid] = { name: item.product_name, qty: 0, revenue: 0 };
    }
    productMap[pid].qty += item.quantity;
    productMap[pid].revenue += Number(item.total);
  }

  let ranked = Object.entries(productMap).map(([id, v]) => ({
    product_id: id,
    product_name: v.name,
    total_quantity: v.qty,
    total_revenue: v.revenue,
  }));

  if (sortBy === "revenue") {
    ranked.sort((a, b) => b.total_revenue - a.total_revenue);
  } else {
    ranked.sort((a, b) => b.total_quantity - a.total_quantity);
  }

  ranked = ranked.slice(0, limit);

  return JSON.stringify({
    period: { start, end },
    sort_by: sortBy,
    products: ranked,
  });
}

async function handleGetProductHpp(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  args: Record<string, unknown>
): Promise<string> {
  let query = supabase
    .from("product_hpp_summary")
    .select("*")
    .eq("outlet_id", outletId);

  if (args.product_name) {
    query = query.ilike("product_name", `%${args.product_name}%`);
  }

  const sortBy = (args.sort_by as string) || "profit_percent";
  query = query.order(sortBy, { ascending: sortBy === "hpp" });

  const { data, error } = await query;
  if (error) return JSON.stringify({ error: error.message });

  return JSON.stringify({
    products: (data || []).map((p) => ({
      product_id: p.product_id,
      product_name: p.product_name,
      category: p.category_name,
      selling_price: Number(p.selling_price),
      hpp: Number(p.hpp),
      profit: Number(p.profit),
      profit_percent: Number(p.profit_percent),
      is_available: p.is_available,
    })),
  });
}

async function handleCreatePurchaseOrder(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  userId: string,
  args: Record<string, unknown>
): Promise<string> {
  // Check trust
  const trust = await checkTrustLevel(supabase, outletId, "draft_purchase_order");
  if (!trust.allowed) {
    return JSON.stringify({
      error: "Trust level tidak cukup untuk membuat PO otomatis.",
      trust_level: trust.level,
      required_level: 2,
      message: "Informasikan ke user bahwa mereka perlu menaikkan trust level fitur 'draft_purchase_order' ke level 2 atau lebih di pengaturan AI.",
    });
  }

  // Generate PO number
  const { data: poNumData } = await supabase.rpc("generate_po_number", { p_outlet_id: outletId });
  const poNumber = poNumData || `PO-${Date.now()}`;

  const items = args.items as Array<{ ingredient_id: string; quantity: number; unit_cost?: number }>;

  // If no unit cost provided, get from ingredient
  for (const item of items) {
    if (!item.unit_cost) {
      const { data: ingr } = await supabase
        .from("ingredients")
        .select("cost_per_unit")
        .eq("id", item.ingredient_id)
        .single();
      item.unit_cost = ingr ? Number(ingr.cost_per_unit) : 0;
    }
  }

  const totalAmount = items.reduce((s, i) => s + i.quantity * (i.unit_cost || 0), 0);

  // Create PO header
  const { data: po, error: poErr } = await supabase
    .from("purchase_orders")
    .insert({
      outlet_id: outletId,
      supplier_id: args.supplier_id || null,
      po_number: poNumber,
      status: "draft",
      total_amount: totalAmount,
      notes: args.notes || "Dibuat oleh Utter AI",
      created_by: userId,
    })
    .select()
    .single();

  if (poErr) return JSON.stringify({ error: poErr.message });

  // Create PO items
  const poItems = items.map((item) => ({
    purchase_order_id: po.id,
    ingredient_id: item.ingredient_id,
    quantity_ordered: item.quantity,
    unit_cost: item.unit_cost || 0,
    total_cost: item.quantity * (item.unit_cost || 0),
  }));

  const { error: itemsErr } = await supabase
    .from("purchase_order_items")
    .insert(poItems);

  if (itemsErr) return JSON.stringify({ error: itemsErr.message });

  // Log action
  await supabase.from("ai_action_logs").insert({
    outlet_id: outletId,
    feature_key: "draft_purchase_order",
    trust_level: trust.level,
    action_type: "auto_executed",
    action_description: `Membuat PO ${poNumber} dengan ${items.length} item, total Rp ${totalAmount.toLocaleString("id-ID")}`,
    action_data: { po_id: po.id, po_number: poNumber, items: poItems },
    source: "chat",
    triggered_by: userId,
  });

  return JSON.stringify({
    success: true,
    po_id: po.id,
    po_number: poNumber,
    total_amount: totalAmount,
    items_count: items.length,
    status: "draft",
  });
}

async function handleAdjustStock(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  userId: string,
  args: Record<string, unknown>
): Promise<string> {
  const trust = await checkTrustLevel(supabase, outletId, "stock_alert");
  if (!trust.allowed) {
    return JSON.stringify({
      error: "Trust level tidak cukup untuk adjust stok otomatis.",
      trust_level: trust.level,
      required_level: 2,
    });
  }

  const ingredientId = args.ingredient_id as string;
  const quantity = args.quantity as number;
  const adjustmentType = args.adjustment_type as string;

  // Get current ingredient data
  const { data: ingr, error: ingrErr } = await supabase
    .from("ingredients")
    .select("id, name, current_stock, unit")
    .eq("id", ingredientId)
    .eq("outlet_id", outletId)
    .single();

  if (ingrErr || !ingr) return JSON.stringify({ error: "Bahan baku tidak ditemukan" });

  // Create stock movement
  const { error: moveErr } = await supabase.from("stock_movements").insert({
    outlet_id: outletId,
    ingredient_id: ingredientId,
    movement_type: adjustmentType,
    quantity: quantity,
    notes: (args.notes as string) || `Adjusted by AI - ${adjustmentType}`,
    performed_by: userId,
  });

  if (moveErr) return JSON.stringify({ error: moveErr.message });

  // Update ingredient stock
  const newStock = Number(ingr.current_stock) + quantity;
  const { error: updateErr } = await supabase
    .from("ingredients")
    .update({ current_stock: Math.max(0, newStock) })
    .eq("id", ingredientId);

  if (updateErr) return JSON.stringify({ error: updateErr.message });

  await supabase.from("ai_action_logs").insert({
    outlet_id: outletId,
    feature_key: "stock_alert",
    trust_level: trust.level,
    action_type: "auto_executed",
    action_description: `Adjust stok ${ingr.name}: ${quantity > 0 ? "+" : ""}${quantity} ${ingr.unit} (${adjustmentType})`,
    action_data: { ingredient_id: ingredientId, old_stock: ingr.current_stock, new_stock: Math.max(0, newStock), adjustment: quantity },
    source: "chat",
    triggered_by: userId,
  });

  return JSON.stringify({
    success: true,
    ingredient: ingr.name,
    old_stock: Number(ingr.current_stock),
    adjustment: quantity,
    new_stock: Math.max(0, newStock),
    unit: ingr.unit,
    type: adjustmentType,
  });
}

async function handleToggleProductAvailability(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  args: Record<string, unknown>
): Promise<string> {
  const featureKey = args.is_available ? "auto_enable_product" : "auto_disable_product";
  const trust = await checkTrustLevel(supabase, outletId, featureKey);
  if (!trust.allowed) {
    return JSON.stringify({
      error: `Trust level tidak cukup untuk ${args.is_available ? "mengaktifkan" : "menonaktifkan"} produk otomatis.`,
      trust_level: trust.level,
      required_level: 2,
    });
  }

  const productId = args.product_id as string;
  const isAvailable = args.is_available as boolean;

  const { data: product, error: prodErr } = await supabase
    .from("products")
    .select("id, name, is_available")
    .eq("id", productId)
    .eq("outlet_id", outletId)
    .single();

  if (prodErr || !product) return JSON.stringify({ error: "Produk tidak ditemukan" });

  const { error: updateErr } = await supabase
    .from("products")
    .update({ is_available: isAvailable })
    .eq("id", productId);

  if (updateErr) return JSON.stringify({ error: updateErr.message });

  await supabase.from("ai_action_logs").insert({
    outlet_id: outletId,
    feature_key: featureKey,
    trust_level: trust.level,
    action_type: "auto_executed",
    action_description: `${isAvailable ? "Mengaktifkan" : "Menonaktifkan"} produk "${product.name}". Alasan: ${args.reason || "Tidak ada alasan"}`,
    action_data: { product_id: productId, was_available: product.is_available, is_available: isAvailable, reason: args.reason },
    source: "chat",
  });

  return JSON.stringify({
    success: true,
    product_name: product.name,
    was_available: product.is_available,
    is_available: isAvailable,
    reason: args.reason || null,
  });
}

async function handleUpdateProductPrice(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  args: Record<string, unknown>
): Promise<string> {
  const trust = await checkTrustLevel(supabase, outletId, "pricing_recommendation");
  if (!trust.allowed) {
    return JSON.stringify({
      error: "Trust level tidak cukup untuk mengubah harga otomatis.",
      trust_level: trust.level,
      required_level: 2,
    });
  }

  const productId = args.product_id as string;
  const newPrice = args.new_price as number;

  const { data: product, error: prodErr } = await supabase
    .from("products")
    .select("id, name, selling_price")
    .eq("id", productId)
    .eq("outlet_id", outletId)
    .single();

  if (prodErr || !product) return JSON.stringify({ error: "Produk tidak ditemukan" });

  const oldPrice = Number(product.selling_price);

  const { error: updateErr } = await supabase
    .from("products")
    .update({ selling_price: newPrice })
    .eq("id", productId);

  if (updateErr) return JSON.stringify({ error: updateErr.message });

  await supabase.from("ai_action_logs").insert({
    outlet_id: outletId,
    feature_key: "pricing_recommendation",
    trust_level: trust.level,
    action_type: "auto_executed",
    action_description: `Mengubah harga "${product.name}" dari Rp ${oldPrice.toLocaleString("id-ID")} ke Rp ${newPrice.toLocaleString("id-ID")}. Alasan: ${args.reason || "-"}`,
    action_data: { product_id: productId, old_price: oldPrice, new_price: newPrice, reason: args.reason },
    source: "chat",
  });

  return JSON.stringify({
    success: true,
    product_name: product.name,
    old_price: oldPrice,
    new_price: newPrice,
    change_percent: Math.round(((newPrice - oldPrice) / oldPrice) * 100 * 10) / 10,
    reason: args.reason || null,
  });
}

async function handleCreateDiscount(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  userId: string,
  args: Record<string, unknown>
): Promise<string> {
  const trust = await checkTrustLevel(supabase, outletId, "auto_promo");
  if (!trust.allowed) {
    return JSON.stringify({
      error: "Trust level tidak cukup untuk membuat diskon otomatis.",
      trust_level: trust.level,
      required_level: 2,
    });
  }

  const { data: discount, error } = await supabase
    .from("discounts")
    .insert({
      outlet_id: outletId,
      name: args.name as string,
      type: args.type as string,
      value: args.value as number,
      min_purchase: (args.min_purchase as number) || 0,
      max_discount: (args.max_discount as number) || null,
      start_date: (args.start_date as string) || new Date().toISOString(),
      end_date: (args.end_date as string) || null,
      is_active: true,
      applicable_to: (args.applicable_to as string) || "all",
      applicable_ids: (args.applicable_ids as string[]) || null,
      created_by: userId,
    })
    .select()
    .single();

  if (error) return JSON.stringify({ error: error.message });

  await supabase.from("ai_action_logs").insert({
    outlet_id: outletId,
    feature_key: "auto_promo",
    trust_level: trust.level,
    action_type: "auto_executed",
    action_description: `Membuat diskon "${args.name}" - ${args.type === "percentage" ? `${args.value}%` : `Rp ${(args.value as number).toLocaleString("id-ID")}`}`,
    action_data: { discount_id: discount.id, ...args },
    source: "chat",
    triggered_by: userId,
  });

  return JSON.stringify({
    success: true,
    discount_id: discount.id,
    name: discount.name,
    type: discount.type,
    value: discount.value,
  });
}

async function handleGetShiftSummary(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  args: Record<string, unknown>
): Promise<string> {
  let query = supabase
    .from("shifts")
    .select(`
      id, opened_at, closed_at, opening_cash, closing_cash,
      expected_cash, cash_difference, total_sales, total_orders,
      total_refunds, status, notes,
      cashier:profiles!shifts_cashier_id_fkey(full_name)
    `)
    .eq("outlet_id", outletId);

  if (args.shift_id) {
    query = query.eq("id", args.shift_id as string);
  }

  if (args.status && args.status !== "all") {
    query = query.eq("status", args.status as string);
  }

  if (args.date) {
    query = query
      .gte("opened_at", `${args.date}T00:00:00+07:00`)
      .lte("opened_at", `${args.date}T23:59:59+07:00`);
  }

  query = query.order("opened_at", { ascending: false }).limit(10);

  const { data, error } = await query;
  if (error) return JSON.stringify({ error: error.message });

  return JSON.stringify({
    shifts: (data || []).map((s) => ({
      id: s.id,
      cashier: (s.cashier as any)?.full_name || "Unknown",
      status: s.status,
      opened_at: s.opened_at,
      closed_at: s.closed_at,
      opening_cash: Number(s.opening_cash),
      closing_cash: s.closing_cash ? Number(s.closing_cash) : null,
      total_sales: Number(s.total_sales),
      total_orders: s.total_orders,
      total_refunds: Number(s.total_refunds),
      cash_difference: s.cash_difference ? Number(s.cash_difference) : null,
    })),
  });
}

async function handleGetCustomerInfo(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  args: Record<string, unknown>
): Promise<string> {
  if (args.customer_id) {
    const { data, error } = await supabase
      .from("customers")
      .select("*")
      .eq("id", args.customer_id as string)
      .eq("outlet_id", outletId)
      .single();

    if (error) return JSON.stringify({ error: error.message });

    // Get recent orders
    const { data: orders } = await supabase
      .from("orders")
      .select("id, order_number, total, status, created_at")
      .eq("customer_id", args.customer_id as string)
      .eq("outlet_id", outletId)
      .order("created_at", { ascending: false })
      .limit(5);

    return JSON.stringify({ customer: data, recent_orders: orders || [] });
  }

  let query = supabase
    .from("customers")
    .select("id, name, phone, loyalty_points, total_spent, total_orders, is_active")
    .eq("outlet_id", outletId);

  if (args.search) {
    query = query.or(`name.ilike.%${args.search}%,phone.ilike.%${args.search}%`);
  }

  const sortBy = (args.sort_by as string) || "total_spent";
  if (sortBy === "recent") {
    query = query.order("created_at", { ascending: false });
  } else {
    query = query.order(sortBy, { ascending: false });
  }

  query = query.limit((args.limit as number) || 20);

  const { data, error } = await query;
  if (error) return JSON.stringify({ error: error.message });

  return JSON.stringify({ customers: data || [] });
}

async function handleForecastDemand(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  args: Record<string, unknown>
): Promise<string> {
  const forecastDays = (args.forecast_days as number) || 7;
  const lookbackDays = 14;
  const since = new Date();
  since.setDate(since.getDate() - lookbackDays);

  let ingredientFilter = {};
  if (args.ingredient_id) {
    ingredientFilter = { ingredient_id: args.ingredient_id as string };
  }

  // Get stock movements for the period
  let query = supabase
    .from("stock_movements")
    .select("ingredient_id, quantity, movement_type, created_at")
    .eq("outlet_id", outletId)
    .in("movement_type", ["auto_deduct", "stock_out", "waste"])
    .gte("created_at", since.toISOString());

  if (args.ingredient_id) {
    query = query.eq("ingredient_id", args.ingredient_id as string);
  }

  const { data: movements, error: moveErr } = await query;
  if (moveErr) return JSON.stringify({ error: moveErr.message });

  // Get current ingredient data
  let ingrQuery = supabase
    .from("ingredients")
    .select("id, name, unit, current_stock, min_stock")
    .eq("outlet_id", outletId)
    .eq("is_active", true);

  if (args.ingredient_id) {
    ingrQuery = ingrQuery.eq("id", args.ingredient_id as string);
  }

  const { data: ingredients, error: ingrErr } = await ingrQuery;
  if (ingrErr) return JSON.stringify({ error: ingrErr.message });

  // Calculate usage per ingredient
  const usageMap: Record<string, number> = {};
  for (const m of movements || []) {
    const id = m.ingredient_id;
    if (!usageMap[id]) usageMap[id] = 0;
    usageMap[id] += Math.abs(Number(m.quantity));
  }

  const forecasts = (ingredients || []).map((ing) => {
    const totalUsage = usageMap[ing.id] || 0;
    const avgDailyUsage = totalUsage / lookbackDays;
    const currentStock = Number(ing.current_stock);
    const daysUntilEmpty = avgDailyUsage > 0 ? Math.round(currentStock / avgDailyUsage) : 999;
    const forecastedNeed = avgDailyUsage * forecastDays;
    const reorderNeeded = forecastedNeed > currentStock;

    return {
      ingredient_id: ing.id,
      name: ing.name,
      unit: ing.unit,
      current_stock: currentStock,
      avg_daily_usage: Math.round(avgDailyUsage * 100) / 100,
      days_until_empty: daysUntilEmpty,
      forecasted_need_next_period: Math.round(forecastedNeed * 100) / 100,
      reorder_needed: reorderNeeded,
      suggested_reorder_qty: reorderNeeded ? Math.round(forecastedNeed - currentStock + Number(ing.min_stock)) : 0,
    };
  });

  forecasts.sort((a, b) => a.days_until_empty - b.days_until_empty);

  return JSON.stringify({
    lookback_days: lookbackDays,
    forecast_days: forecastDays,
    forecasts,
    critical_items: forecasts.filter((f) => f.days_until_empty <= 3),
  });
}

async function handleDetectAnomalies(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  args: Record<string, unknown>
): Promise<string> {
  const checkType = args.check_type as string;
  const periodDays = (args.period_days as number) || 7;

  const now = new Date();
  const periodStart = new Date(now);
  periodStart.setDate(periodStart.getDate() - periodDays);
  const baselineStart = new Date(now);
  baselineStart.setDate(baselineStart.getDate() - 30);

  if (checkType === "voids" || checkType === "refunds") {
    const statusFilter = checkType === "voids" ? "cancelled" : "refunded";

    // Recent period
    const { data: recent } = await supabase
      .from("orders")
      .select("id, created_at")
      .eq("outlet_id", outletId)
      .eq("status", statusFilter)
      .gte("created_at", periodStart.toISOString());

    // Baseline (30 days)
    const { data: baseline } = await supabase
      .from("orders")
      .select("id, created_at")
      .eq("outlet_id", outletId)
      .eq("status", statusFilter)
      .gte("created_at", baselineStart.toISOString());

    const recentCount = (recent || []).length;
    const baselineCount = (baseline || []).length;
    const avgDaily30d = baselineCount / 30;
    const avgDailyRecent = recentCount / periodDays;
    const ratio = avgDaily30d > 0 ? avgDailyRecent / avgDaily30d : 0;

    return JSON.stringify({
      check_type: checkType,
      period_days: periodDays,
      recent_count: recentCount,
      recent_avg_daily: Math.round(avgDailyRecent * 10) / 10,
      baseline_avg_daily: Math.round(avgDaily30d * 10) / 10,
      anomaly_ratio: Math.round(ratio * 100) / 100,
      is_anomaly: ratio > 2.5,
      severity: ratio > 5 ? "critical" : ratio > 2.5 ? "warning" : "normal",
    });
  }

  if (checkType === "sales_drop") {
    const { start: thisWeekStart } = getDateRange("this_week");
    const { start: lastWeekStart, end: lastWeekEnd } = getDateRange("last_week");

    const { data: thisWeek } = await supabase
      .from("orders")
      .select("total")
      .eq("outlet_id", outletId)
      .eq("status", "completed")
      .gte("created_at", `${thisWeekStart}T00:00:00+07:00`);

    const { data: lastWeek } = await supabase
      .from("orders")
      .select("total")
      .eq("outlet_id", outletId)
      .eq("status", "completed")
      .gte("created_at", `${lastWeekStart}T00:00:00+07:00`)
      .lte("created_at", `${lastWeekEnd}T23:59:59+07:00`);

    const thisWeekTotal = (thisWeek || []).reduce((s, o) => s + Number(o.total), 0);
    const lastWeekTotal = (lastWeek || []).reduce((s, o) => s + Number(o.total), 0);
    const changePercent = lastWeekTotal > 0 ? ((thisWeekTotal - lastWeekTotal) / lastWeekTotal) * 100 : 0;

    return JSON.stringify({
      check_type: "sales_drop",
      this_week_revenue: thisWeekTotal,
      last_week_revenue: lastWeekTotal,
      change_percent: Math.round(changePercent * 10) / 10,
      is_anomaly: changePercent < -20,
      severity: changePercent < -50 ? "critical" : changePercent < -20 ? "warning" : "normal",
    });
  }

  if (checkType === "stock_discrepancy") {
    // Compare expected vs actual stock based on movements
    const { data: ingredients } = await supabase
      .from("ingredients")
      .select("id, name, unit, current_stock")
      .eq("outlet_id", outletId)
      .eq("is_active", true);

    const discrepancies: Array<{ name: string; current: number; unit: string }> = [];
    for (const ing of ingredients || []) {
      if (Number(ing.current_stock) < 0) {
        discrepancies.push({
          name: ing.name,
          current: Number(ing.current_stock),
          unit: ing.unit,
        });
      }
    }

    return JSON.stringify({
      check_type: "stock_discrepancy",
      negative_stock_items: discrepancies,
      total_discrepancies: discrepancies.length,
      is_anomaly: discrepancies.length > 0,
    });
  }

  return JSON.stringify({ error: "Unknown check type" });
}

async function handleSuggestPricing(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  args: Record<string, unknown>
): Promise<string> {
  const targetMargin = (args.target_margin as number) || 30;

  let query = supabase
    .from("product_hpp_summary")
    .select("*")
    .eq("outlet_id", outletId);

  if (args.product_id) {
    query = query.eq("product_id", args.product_id as string);
  }

  const { data: products, error } = await query;
  if (error) return JSON.stringify({ error: error.message });

  // Get sales volume for the last 7 days
  const weekAgo = new Date();
  weekAgo.setDate(weekAgo.getDate() - 7);

  const { data: salesData } = await supabase
    .from("order_items")
    .select(`
      product_id,
      quantity,
      order:orders!inner(outlet_id, status, created_at)
    `)
    .eq("order.outlet_id", outletId)
    .eq("order.status", "completed")
    .gte("order.created_at", weekAgo.toISOString());

  const salesVolume: Record<string, number> = {};
  for (const item of salesData || []) {
    if (!salesVolume[item.product_id]) salesVolume[item.product_id] = 0;
    salesVolume[item.product_id] += item.quantity;
  }

  const suggestions = (products || []).map((p) => {
    const hpp = Number(p.hpp);
    const currentPrice = Number(p.selling_price);
    const currentMargin = Number(p.profit_percent);
    const suggestedPrice = hpp > 0 ? Math.ceil(hpp / (1 - targetMargin / 100) / 500) * 500 : currentPrice;
    const weeklyVolume = salesVolume[p.product_id] || 0;

    return {
      product_id: p.product_id,
      product_name: p.product_name,
      category: p.category_name,
      hpp,
      current_price: currentPrice,
      current_margin: currentMargin,
      suggested_price: suggestedPrice,
      target_margin: targetMargin,
      weekly_volume: weeklyVolume,
      price_change: suggestedPrice - currentPrice,
      needs_adjustment: Math.abs(currentMargin - targetMargin) > 5,
      priority: currentMargin < 15 && weeklyVolume > 10 ? "high" : currentMargin < targetMargin ? "medium" : "low",
    };
  });

  suggestions.sort((a, b) => {
    const priorityOrder = { high: 0, medium: 1, low: 2 };
    return (priorityOrder[a.priority as keyof typeof priorityOrder] || 2) - (priorityOrder[b.priority as keyof typeof priorityOrder] || 2);
  });

  return JSON.stringify({
    target_margin: targetMargin,
    suggestions,
    needs_attention: suggestions.filter((s) => s.priority === "high").length,
  });
}

async function handleGenerateReport(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  args: Record<string, unknown>
): Promise<string> {
  const reportType = args.report_type as string;
  const dateStr = (args.date as string) || new Date().toISOString().split("T")[0];

  switch (reportType) {
    case "daily_sales": {
      const { data } = await supabase
        .from("orders")
        .select(`
          id, order_number, total, discount_amount, tax_amount,
          status, payment_method, order_type, created_at,
          order_items(product_name, quantity, total)
        `)
        .eq("outlet_id", outletId)
        .gte("created_at", `${dateStr}T00:00:00+07:00`)
        .lte("created_at", `${dateStr}T23:59:59+07:00`)
        .order("created_at");

      const orders = data || [];
      const completed = orders.filter((o) => o.status === "completed");
      const revenue = completed.reduce((s, o) => s + Number(o.total), 0);

      // Hourly breakdown
      const hourly: Record<string, { count: number; revenue: number }> = {};
      for (const o of completed) {
        const hour = new Date(o.created_at).getHours().toString().padStart(2, "0") + ":00";
        if (!hourly[hour]) hourly[hour] = { count: 0, revenue: 0 };
        hourly[hour].count++;
        hourly[hour].revenue += Number(o.total);
      }

      return JSON.stringify({
        report_type: "daily_sales",
        date: dateStr,
        total_orders: orders.length,
        completed_orders: completed.length,
        total_revenue: revenue,
        avg_order_value: completed.length > 0 ? Math.round(revenue / completed.length) : 0,
        hourly_breakdown: hourly,
        order_types: {
          dine_in: completed.filter((o) => o.order_type === "dine_in").length,
          takeaway: completed.filter((o) => o.order_type === "takeaway").length,
          delivery: completed.filter((o) => o.order_type === "delivery").length,
          online: completed.filter((o) => o.order_type === "online").length,
        },
      });
    }
    case "stock_report": {
      const { data: stocks } = await supabase
        .from("low_stock_alerts")
        .select("*")
        .eq("outlet_id", outletId);

      const items = stocks || [];
      const totalValue = items.reduce((s, i) => s + Number(i.current_stock) * Number(i.cost_per_unit), 0);

      return JSON.stringify({
        report_type: "stock_report",
        date: dateStr,
        total_ingredients: items.length,
        total_stock_value: totalValue,
        out_of_stock: items.filter((i) => i.stock_status === "out_of_stock").length,
        low_stock: items.filter((i) => i.stock_status === "low_stock").length,
        healthy: items.filter((i) => i.stock_status === "healthy").length,
        overstock: items.filter((i) => i.stock_status === "overstock").length,
        items: items.map((i) => ({
          name: i.name,
          stock: `${i.current_stock} ${i.unit}`,
          status: i.stock_status,
          value: Number(i.current_stock) * Number(i.cost_per_unit),
        })),
      });
    }
    case "profit_analysis": {
      const { data: hpp } = await supabase
        .from("product_hpp_summary")
        .select("*")
        .eq("outlet_id", outletId)
        .order("profit_percent", { ascending: true });

      return JSON.stringify({
        report_type: "profit_analysis",
        products: (hpp || []).map((p) => ({
          name: p.product_name,
          category: p.category_name,
          selling_price: Number(p.selling_price),
          hpp: Number(p.hpp),
          profit: Number(p.profit),
          margin: Number(p.profit_percent),
        })),
        avg_margin: (hpp || []).length > 0
          ? Math.round(
              (hpp || []).reduce((s, p) => s + Number(p.profit_percent), 0) / (hpp || []).length * 10
            ) / 10
          : 0,
        low_margin_count: (hpp || []).filter((p) => Number(p.profit_percent) < 20).length,
      });
    }
    case "product_performance": {
      const { start, end } = getDateRange("this_month");
      const { data: items } = await supabase
        .from("order_items")
        .select(`
          product_id, product_name, quantity, total,
          order:orders!inner(outlet_id, status, created_at)
        `)
        .eq("order.outlet_id", outletId)
        .eq("order.status", "completed")
        .gte("order.created_at", `${start}T00:00:00+07:00`)
        .lte("order.created_at", `${end}T23:59:59+07:00`);

      const productPerf: Record<string, { name: string; qty: number; revenue: number }> = {};
      for (const item of items || []) {
        if (!productPerf[item.product_id]) {
          productPerf[item.product_id] = { name: item.product_name, qty: 0, revenue: 0 };
        }
        productPerf[item.product_id].qty += item.quantity;
        productPerf[item.product_id].revenue += Number(item.total);
      }

      const ranked = Object.entries(productPerf)
        .map(([id, v]) => ({ product_id: id, ...v }))
        .sort((a, b) => b.revenue - a.revenue);

      return JSON.stringify({
        report_type: "product_performance",
        period: { start, end },
        total_products_sold: ranked.length,
        products: ranked,
      });
    }
    default: {
      // weekly_summary, monthly_summary
      const period = reportType === "weekly_summary" ? "this_week" : "this_month";
      const { start, end } = getDateRange(period);

      const { data: orders } = await supabase
        .from("orders")
        .select("total, status, created_at")
        .eq("outlet_id", outletId)
        .gte("created_at", `${start}T00:00:00+07:00`)
        .lte("created_at", `${end}T23:59:59+07:00`);

      const completed = (orders || []).filter((o) => o.status === "completed");
      const revenue = completed.reduce((s, o) => s + Number(o.total), 0);

      return JSON.stringify({
        report_type: reportType,
        period: { start, end },
        total_orders: (orders || []).length,
        completed_orders: completed.length,
        total_revenue: revenue,
        avg_daily_revenue: Math.round(revenue / Math.max(1, Math.ceil((new Date(end).getTime() - new Date(start).getTime()) / 86400000))),
      });
    }
  }
}

async function handleGetOrderDetails(
  supabase: ReturnType<typeof createClient>,
  outletId: string,
  args: Record<string, unknown>
): Promise<string> {
  if (args.order_id || args.order_number) {
    let query = supabase
      .from("orders")
      .select(`
        *,
        order_items(id, product_id, product_name, quantity, unit_price, subtotal, discount_amount, total, notes, modifiers, status),
        customer:customers(name, phone),
        cashier:profiles!orders_cashier_id_fkey(full_name),
        table:tables(table_number, name)
      `)
      .eq("outlet_id", outletId);

    if (args.order_id) {
      query = query.eq("id", args.order_id as string);
    } else {
      query = query.eq("order_number", args.order_number as string);
    }

    const { data, error } = await query.single();
    if (error) return JSON.stringify({ error: error.message });
    return JSON.stringify({ order: data });
  }

  // List recent orders
  let query = supabase
    .from("orders")
    .select(`
      id, order_number, order_type, status, total,
      payment_method, payment_status, created_at,
      customer_name
    `)
    .eq("outlet_id", outletId);

  if (args.status) {
    query = query.eq("status", args.status as string);
  }

  query = query.order("created_at", { ascending: false }).limit((args.limit as number) || 10);

  const { data, error } = await query;
  if (error) return JSON.stringify({ error: error.message });

  return JSON.stringify({ orders: data || [] });
}

// --------------- Main Handler ---------------
serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const deepseekApiKey = Deno.env.get("DEEPSEEK_API_KEY")!;

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body: ChatRequest = await req.json();
    const { message, outlet_id, user_id, context } = body;
    let { conversation_id } = body;

    if (!message || !outlet_id || !user_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: message, outlet_id, user_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get outlet info
    const { data: outlet } = await supabase
      .from("outlets")
      .select("name")
      .eq("id", outlet_id)
      .single();

    // Get user info
    const { data: profile } = await supabase
      .from("profiles")
      .select("full_name, role")
      .eq("id", user_id)
      .single();

    const outletName = outlet?.name || "Outlet";
    const userName = profile?.full_name || "User";

    // Create conversation if needed
    if (!conversation_id) {
      const { data: conv, error: convErr } = await supabase
        .from("ai_conversations")
        .insert({
          outlet_id,
          user_id,
          title: message.substring(0, 100),
          source: "chat",
        })
        .select("id")
        .single();

      if (convErr) {
        return new Response(
          JSON.stringify({ error: "Failed to create conversation: " + convErr.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      conversation_id = conv.id;
    }

    // Get conversation history (last 20 messages)
    const { data: historyData } = await supabase
      .from("ai_messages")
      .select("role, content, function_calls")
      .eq("conversation_id", conversation_id)
      .order("created_at", { ascending: true })
      .limit(20);

    // Build messages array for DeepSeek
    const systemPrompt = buildSystemPrompt(outletName, userName, context);
    const messages: DeepSeekMessage[] = [
      { role: "system", content: systemPrompt },
    ];

    // Add history
    for (const msg of historyData || []) {
      if (msg.role === "function") {
        messages.push({
          role: "function",
          name: msg.function_calls?.name || "unknown",
          content: msg.content,
        });
      } else {
        const m: DeepSeekMessage = {
          role: msg.role as "user" | "assistant" | "system",
          content: msg.content,
        };
        if (msg.function_calls && msg.role === "assistant") {
          m.function_call = msg.function_calls as FunctionCall;
          m.content = msg.content || null;
        }
        messages.push(m);
      }
    }

    // Add current user message
    messages.push({ role: "user", content: message });

    // Save user message
    await supabase.from("ai_messages").insert({
      conversation_id,
      role: "user",
      content: message,
    });

    // Function calling loop (max 10 iterations)
    let assistantReply = "";
    const executedActions: Array<{ function: string; result: unknown }> = [];
    let totalTokens = 0;

    for (let iteration = 0; iteration < 10; iteration++) {
      // Call DeepSeek API
      const deepseekResponse = await fetch(
        "https://api.deepseek.com/v1/chat/completions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${deepseekApiKey}`,
          },
          body: JSON.stringify({
            model: "deepseek-chat",
            messages,
            functions: tools,
            function_call: "auto",
            temperature: 0.7,
            max_tokens: 2048,
          }),
        }
      );

      if (!deepseekResponse.ok) {
        const errText = await deepseekResponse.text();
        console.error("DeepSeek API error:", errText);
        throw new Error(`DeepSeek API error: ${deepseekResponse.status} - ${errText}`);
      }

      const deepseekData = await deepseekResponse.json();
      const choice = deepseekData.choices?.[0];
      totalTokens += deepseekData.usage?.total_tokens || 0;

      if (!choice) {
        throw new Error("No response from DeepSeek");
      }

      const assistantMessage = choice.message;

      // If there is a function call, execute it
      if (assistantMessage.function_call) {
        const fnCall = assistantMessage.function_call;
        const fnName = fnCall.name;
        let fnArgs: Record<string, unknown> = {};
        try {
          fnArgs = JSON.parse(fnCall.arguments || "{}");
        } catch {
          fnArgs = {};
        }

        // Add assistant message with function call to conversation
        messages.push({
          role: "assistant",
          content: assistantMessage.content || null,
          function_call: fnCall,
        });

        // Save assistant function call message
        await supabase.from("ai_messages").insert({
          conversation_id,
          role: "assistant",
          content: assistantMessage.content || `Calling ${fnName}...`,
          function_calls: { name: fnName, arguments: fnCall.arguments },
          tokens_used: deepseekData.usage?.total_tokens || 0,
          model: "deepseek-chat",
        });

        // Check if it is a write action and validate trust
        const featureKey = writeActionFeatureKeys[fnName];
        let functionResult: string;

        if (featureKey) {
          // It is a write action - the handler itself checks trust level
          functionResult = await executeFunctionCall(supabase, outlet_id, user_id, fnName, fnArgs);
        } else {
          // Read action - execute directly
          functionResult = await executeFunctionCall(supabase, outlet_id, user_id, fnName, fnArgs);
        }

        executedActions.push({
          function: fnName,
          result: JSON.parse(functionResult),
        });

        // Add function result to messages
        messages.push({
          role: "function",
          name: fnName,
          content: functionResult,
        });

        // Save function result message
        await supabase.from("ai_messages").insert({
          conversation_id,
          role: "function",
          content: functionResult,
          function_calls: { name: fnName },
        });

        // Continue loop - let AI process the result
        continue;
      }

      // No function call - this is the final response
      assistantReply = assistantMessage.content || "";
      break;
    }

    // Save final assistant reply
    if (assistantReply) {
      await supabase.from("ai_messages").insert({
        conversation_id,
        role: "assistant",
        content: assistantReply,
        tokens_used: totalTokens,
        model: "deepseek-chat",
      });
    }

    // Update conversation title if this was the first message
    if (!body.conversation_id) {
      await supabase
        .from("ai_conversations")
        .update({
          title: message.length > 60 ? message.substring(0, 57) + "..." : message,
        })
        .eq("id", conversation_id);
    }

    return new Response(
      JSON.stringify({
        reply: assistantReply,
        actions: executedActions,
        conversation_id,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("AI Agent error:", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
