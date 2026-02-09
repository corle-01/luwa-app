// =================================================================
// UTTER APP - Telegram Bot Edge Function
// Webhook handler for Telegram Bot + DeepSeek AI
// =================================================================

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// --------------- Config (from environment variables) ---------------
const TELEGRAM_BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") || "";
const TELEGRAM_API = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}`;
const DEEPSEEK_API_KEY = Deno.env.get("DEEPSEEK_API_KEY") || "";
const DEEPSEEK_API_URL = "https://api.deepseek.com/v1/chat/completions";
const OUTLET_ID = Deno.env.get("OUTLET_ID") || "a0000000-0000-0000-0000-000000000001";
const MAX_HISTORY = 10;

// --------------- Conversation Memory (in-memory per chat_id) ---------------
const conversationHistory: Map<
  number,
  Array<{ role: string; content: string }>
> = new Map();

// --------------- Types ---------------
interface TelegramUpdate {
  update_id: number;
  message?: {
    message_id: number;
    from: {
      id: number;
      first_name: string;
      last_name?: string;
      username?: string;
    };
    chat: {
      id: number;
      type: string;
    };
    date: number;
    text?: string;
  };
}

// --------------- Telegram API Helpers ---------------
async function sendMessage(
  chatId: number,
  text: string,
  parseMode: string = "Markdown"
): Promise<void> {
  try {
    const response = await fetch(`${TELEGRAM_API}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: chatId,
        text: text,
        parse_mode: parseMode,
      }),
    });

    // If Markdown fails (malformed), retry with plain text
    if (!response.ok) {
      const errData = await response.json();
      if (
        errData?.description?.includes("can't parse entities") ||
        errData?.description?.includes("Bad Request")
      ) {
        await fetch(`${TELEGRAM_API}/sendMessage`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            chat_id: chatId,
            text: text,
          }),
        });
      }
    }
  } catch (err) {
    console.error("Failed to send Telegram message:", err);
  }
}

async function sendChatAction(
  chatId: number,
  action: string = "typing"
): Promise<void> {
  try {
    await fetch(`${TELEGRAM_API}/sendChatAction`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: chatId,
        action: action,
      }),
    });
  } catch (_) {
    // Ignore errors for typing indicator
  }
}

// --------------- Date Helpers ---------------
function getTodayDateRange(): { start: string; end: string } {
  const now = new Date();
  const jakartaOffset = 7 * 60 * 60 * 1000;
  const jakartaNow = new Date(now.getTime() + jakartaOffset);
  const todayStr = jakartaNow.toISOString().split("T")[0];
  return { start: todayStr, end: todayStr };
}

function formatRupiah(amount: number): string {
  return "Rp " + amount.toLocaleString("id-ID");
}

// --------------- Business Context Builder ---------------
async function buildBusinessContext(
  supabase: ReturnType<typeof createClient>
): Promise<string> {
  const { start, end } = getTodayDateRange();
  const sections: string[] = [];

  // 1. Today's sales summary
  try {
    const { data: orders } = await supabase
      .from("orders")
      .select("id, total, status, payment_method, created_at")
      .eq("outlet_id", OUTLET_ID)
      .gte("created_at", `${start}T00:00:00+07:00`)
      .lte("created_at", `${end}T23:59:59+07:00`);

    const allOrders = orders || [];
    const completed = allOrders.filter(
      (o: any) => o.status === "completed"
    );
    const totalRevenue = completed.reduce(
      (s: number, o: any) => s + Number(o.total),
      0
    );

    // Payment breakdown
    const payments: Record<string, number> = {};
    for (const o of completed) {
      const method = (o as any).payment_method || "cash";
      payments[method] = (payments[method] || 0) + 1;
    }
    const paymentStr = Object.entries(payments)
      .map(([k, v]) => `${k}: ${v}`)
      .join(", ");

    sections.push(
      `PENJUALAN HARI INI (${start}):
- Total order: ${allOrders.length}
- Order selesai: ${completed.length}
- Total revenue: ${formatRupiah(totalRevenue)}
- Rata-rata per order: ${formatRupiah(completed.length > 0 ? Math.round(totalRevenue / completed.length) : 0)}
- Metode bayar: ${paymentStr || "belum ada"}`
    );
  } catch (err) {
    sections.push(`PENJUALAN: Gagal memuat data - ${(err as Error).message}`);
  }

  // 2. Current shift info
  try {
    const { data: shift } = await supabase
      .from("shifts")
      .select(
        "id, opened_at, status, opening_cash, total_sales, total_orders"
      )
      .eq("outlet_id", OUTLET_ID)
      .eq("status", "open")
      .order("opened_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (shift) {
      sections.push(
        `SHIFT AKTIF:
- Dibuka: ${new Date(shift.opened_at).toLocaleString("id-ID", { timeZone: "Asia/Jakarta" })}
- Kas awal: ${formatRupiah(Number(shift.opening_cash))}
- Total penjualan shift: ${formatRupiah(Number(shift.total_sales))}
- Jumlah order shift: ${shift.total_orders}`
      );
    } else {
      sections.push("SHIFT: Tidak ada shift aktif saat ini.");
    }
  } catch (_) {
    sections.push("SHIFT: Gagal memuat data shift.");
  }

  // 3. Low stock alerts
  try {
    const { data: ingredients } = await supabase
      .from("ingredients")
      .select("name, current_stock, min_stock, unit")
      .eq("outlet_id", OUTLET_ID)
      .eq("is_active", true);

    const lowStock = (ingredients || []).filter(
      (i: any) => Number(i.current_stock) <= Number(i.min_stock)
    );

    if (lowStock.length > 0) {
      const items = lowStock
        .slice(0, 10)
        .map(
          (i: any) =>
            `  - ${i.name}: ${i.current_stock} ${i.unit} (min: ${i.min_stock})`
        )
        .join("\n");
      sections.push(
        `STOK MENIPIS (${lowStock.length} item):\n${items}`
      );
    } else {
      sections.push("STOK: Semua bahan baku aman.");
    }

    // Also check products with track_stock
    const { data: products } = await supabase
      .from("products")
      .select("name, stock_quantity")
      .eq("outlet_id", OUTLET_ID)
      .eq("track_stock", true)
      .eq("is_available", true)
      .lte("stock_quantity", 5);

    if (products && products.length > 0) {
      const prodItems = products
        .slice(0, 5)
        .map((p: any) => `  - ${p.name}: ${p.stock_quantity} pcs`)
        .join("\n");
      sections.push(
        `PRODUK STOK RENDAH (${products.length} produk):\n${prodItems}`
      );
    }
  } catch (_) {
    sections.push("STOK: Gagal memuat data stok.");
  }

  // 4. Top 5 selling products today
  try {
    const { data: orderItems } = await supabase
      .from("order_items")
      .select(
        `
        product_name,
        quantity,
        total,
        order:orders!inner(outlet_id, status, created_at)
      `
      )
      .eq("order.outlet_id", OUTLET_ID)
      .eq("order.status", "completed")
      .gte("order.created_at", `${start}T00:00:00+07:00`)
      .lte("order.created_at", `${end}T23:59:59+07:00`);

    const productMap: Record<string, { qty: number; revenue: number }> = {};
    for (const item of orderItems || []) {
      const name = (item as any).product_name;
      if (!productMap[name]) productMap[name] = { qty: 0, revenue: 0 };
      productMap[name].qty += (item as any).quantity;
      productMap[name].revenue += Number((item as any).total);
    }

    const ranked = Object.entries(productMap)
      .sort((a, b) => b[1].qty - a[1].qty)
      .slice(0, 5);

    if (ranked.length > 0) {
      const items = ranked
        .map(
          ([name, v], i) =>
            `  ${i + 1}. ${name} - ${v.qty}x (${formatRupiah(v.revenue)})`
        )
        .join("\n");
      sections.push(`TOP 5 PRODUK HARI INI:\n${items}`);
    } else {
      sections.push("TOP PRODUK: Belum ada penjualan hari ini.");
    }
  } catch (_) {
    sections.push("TOP PRODUK: Gagal memuat data.");
  }

  return sections.join("\n\n");
}

// --------------- System Prompt ---------------
function buildSystemPrompt(businessContext: string, userName: string): string {
  return `Kamu adalah *Utter AI*, asisten bisnis cerdas untuk cafe/restaurant POS.

PERAN:
- Membantu pemilik cafe/restoran memantau dan mengelola bisnis mereka
- Melaporkan penjualan, status stok, dan performa bisnis
- Memberikan saran bisnis berdasarkan data
- Menjawab pertanyaan seputar operasional outlet

ATURAN FORMAT (PENTING - ini Telegram):
- Jawab SINGKAT dan padat (max 3-4 paragraf)
- Gunakan *bold* untuk angka penting dan judul
- Gunakan format list dengan - atau angka
- Jangan gunakan header markdown (# atau ##), gunakan *bold* saja
- Format uang: Rp dengan titik pemisah ribuan (contoh: Rp 150.000)
- Format tanggal: DD/MM/YYYY
- Gunakan emoji secukupnya untuk keterbacaan (1-3 per pesan)
- JANGAN gunakan code block atau tabel - tidak bagus di Telegram

KONTEKS BISNIS REAL-TIME:
${businessContext}

KEMAMPUAN:
- Laporan penjualan (harian, mingguan, bulanan)
- Status stok dan peringatan stok menipis
- Produk terlaris dan performa produk
- Info shift kasir
- Saran bisnis (harga, promo, restock)
- Analisis tren penjualan

User saat ini: ${userName}

Selalu jawab dalam Bahasa Indonesia yang natural dan hangat.
Jika ada stok menipis atau masalah, sampaikan secara proaktif.`;
}

// --------------- Handle Commands ---------------
function handleStartCommand(firstName: string): string {
  return `Halo ${firstName}! Selamat datang di *Utter AI* - Asisten Bisnis Cerdasmu.

Saya bisa membantu kamu memantau dan mengelola bisnis cafe/restoran kamu langsung dari Telegram.

*Yang bisa saya bantu:*
- Cek penjualan hari ini
- Laporan penjualan mingguan/bulanan
- Status stok bahan baku
- Produk terlaris
- Info shift kasir
- Saran bisnis & analisis

*Contoh pertanyaan:*
- "Berapa penjualan hari ini?"
- "Produk apa yang paling laris?"
- "Ada stok yang menipis?"
- "Gimana performa minggu ini?"
- "Kasih saran untuk naikkan penjualan"

Langsung ketik pertanyaan kamu ya!`;
}

function handleHelpCommand(): string {
  return `*Panduan Utter AI Bot*

*Perintah:*
/start - Mulai percakapan baru
/help - Tampilkan panduan ini
/sales - Ringkasan penjualan hari ini
/stock - Status stok bahan baku
/top - Produk terlaris hari ini
/shift - Info shift aktif
/reset - Reset percakapan

*Tips:*
- Tanya pakai bahasa natural, misal "berapa omzet hari ini?"
- Bot mengingat konteks percakapan (max ${MAX_HISTORY} pesan)
- Gunakan /reset untuk mulai percakapan baru`;
}

// --------------- Handle Quick Commands ---------------
async function handleSalesCommand(
  supabase: ReturnType<typeof createClient>
): Promise<string> {
  const { start, end } = getTodayDateRange();

  const { data: orders } = await supabase
    .from("orders")
    .select("id, total, status, payment_method")
    .eq("outlet_id", OUTLET_ID)
    .gte("created_at", `${start}T00:00:00+07:00`)
    .lte("created_at", `${end}T23:59:59+07:00`);

  const allOrders = orders || [];
  const completed = allOrders.filter((o: any) => o.status === "completed");
  const totalRevenue = completed.reduce(
    (s: number, o: any) => s + Number(o.total),
    0
  );
  const avgOrder =
    completed.length > 0 ? Math.round(totalRevenue / completed.length) : 0;

  return `*Penjualan Hari Ini* (${start})

- Total order: *${allOrders.length}*
- Order selesai: *${completed.length}*
- Total revenue: *${formatRupiah(totalRevenue)}*
- Rata-rata/order: *${formatRupiah(avgOrder)}*`;
}

async function handleStockCommand(
  supabase: ReturnType<typeof createClient>
): Promise<string> {
  const { data: ingredients } = await supabase
    .from("ingredients")
    .select("name, current_stock, min_stock, unit")
    .eq("outlet_id", OUTLET_ID)
    .eq("is_active", true)
    .order("current_stock", { ascending: true });

  const items = ingredients || [];
  const lowStock = items.filter(
    (i: any) => Number(i.current_stock) <= Number(i.min_stock)
  );

  let msg = `*Status Stok Bahan Baku*\n\n`;
  msg += `Total item: *${items.length}*\n`;
  msg += `Stok menipis: *${lowStock.length}* item\n\n`;

  if (lowStock.length > 0) {
    msg += `*Perlu restock:*\n`;
    for (const i of lowStock.slice(0, 10)) {
      const pct = Number((i as any).min_stock) > 0
        ? Math.round((Number((i as any).current_stock) / Number((i as any).min_stock)) * 100)
        : 0;
      msg += `- ${(i as any).name}: *${(i as any).current_stock} ${(i as any).unit}* (${pct}% dari minimum)\n`;
    }
  } else {
    msg += `Semua bahan baku stoknya aman!`;
  }

  return msg;
}

async function handleTopCommand(
  supabase: ReturnType<typeof createClient>
): Promise<string> {
  const { start, end } = getTodayDateRange();

  const { data: orderItems } = await supabase
    .from("order_items")
    .select(
      `
      product_name,
      quantity,
      total,
      order:orders!inner(outlet_id, status, created_at)
    `
    )
    .eq("order.outlet_id", OUTLET_ID)
    .eq("order.status", "completed")
    .gte("order.created_at", `${start}T00:00:00+07:00`)
    .lte("order.created_at", `${end}T23:59:59+07:00`);

  const productMap: Record<string, { qty: number; revenue: number }> = {};
  for (const item of orderItems || []) {
    const name = (item as any).product_name;
    if (!productMap[name]) productMap[name] = { qty: 0, revenue: 0 };
    productMap[name].qty += (item as any).quantity;
    productMap[name].revenue += Number((item as any).total);
  }

  const ranked = Object.entries(productMap)
    .sort((a, b) => b[1].qty - a[1].qty)
    .slice(0, 10);

  if (ranked.length === 0) {
    return `*Produk Terlaris Hari Ini*\n\nBelum ada penjualan hari ini.`;
  }

  let msg = `*Produk Terlaris Hari Ini* (${start})\n\n`;
  for (let i = 0; i < ranked.length; i++) {
    const [name, v] = ranked[i];
    msg += `${i + 1}. *${name}* - ${v.qty}x (${formatRupiah(v.revenue)})\n`;
  }

  return msg;
}

async function handleShiftCommand(
  supabase: ReturnType<typeof createClient>
): Promise<string> {
  const { data: shift } = await supabase
    .from("shifts")
    .select(
      "id, opened_at, status, opening_cash, total_sales, total_orders"
    )
    .eq("outlet_id", OUTLET_ID)
    .eq("status", "open")
    .order("opened_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!shift) {
    return `*Info Shift*\n\nTidak ada shift yang aktif saat ini.`;
  }

  const openedAt = new Date(shift.opened_at).toLocaleString("id-ID", {
    timeZone: "Asia/Jakarta",
  });

  return `*Shift Aktif*

- Dibuka: *${openedAt}*
- Kas awal: *${formatRupiah(Number(shift.opening_cash))}*
- Total penjualan: *${formatRupiah(Number(shift.total_sales))}*
- Jumlah order: *${shift.total_orders}*`;
}

// --------------- DeepSeek AI Call ---------------
async function callDeepSeek(
  messages: Array<{ role: string; content: string }>
): Promise<string> {
  const response = await fetch(DEEPSEEK_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages: messages,
      temperature: 0.7,
      max_tokens: 1024,
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    console.error("DeepSeek API error:", response.status, errText);
    throw new Error(`DeepSeek API error: ${response.status}`);
  }

  const data = await response.json();
  const reply = data.choices?.[0]?.message?.content;

  if (!reply) {
    throw new Error("No response from DeepSeek");
  }

  return reply;
}

// --------------- Main Handler ---------------
serve(async (req: Request) => {
  // Only accept POST
  if (req.method !== "POST") {
    return new Response("OK", { status: 200 });
  }

  try {
    const update: TelegramUpdate = await req.json();

    // Only handle text messages
    if (!update.message?.text) {
      return new Response("OK", { status: 200 });
    }

    const chatId = update.message.chat.id;
    const text = update.message.text.trim();
    const firstName = update.message.from.first_name || "User";
    const username = update.message.from.username || firstName;

    // Initialize Supabase client (from environment variables)
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const supabaseKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
      Deno.env.get("SUPABASE_ANON_KEY") || "";

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Handle commands
    if (text === "/start") {
      await sendMessage(chatId, handleStartCommand(firstName));
      return new Response("OK", { status: 200 });
    }

    if (text === "/help") {
      await sendMessage(chatId, handleHelpCommand());
      return new Response("OK", { status: 200 });
    }

    if (text === "/reset") {
      conversationHistory.delete(chatId);
      await sendMessage(
        chatId,
        "Percakapan direset. Mulai pertanyaan baru!"
      );
      return new Response("OK", { status: 200 });
    }

    // Quick commands with direct DB queries (no AI needed)
    if (text === "/sales") {
      await sendChatAction(chatId);
      const msg = await handleSalesCommand(supabase);
      await sendMessage(chatId, msg);
      return new Response("OK", { status: 200 });
    }

    if (text === "/stock") {
      await sendChatAction(chatId);
      const msg = await handleStockCommand(supabase);
      await sendMessage(chatId, msg);
      return new Response("OK", { status: 200 });
    }

    if (text === "/top") {
      await sendChatAction(chatId);
      const msg = await handleTopCommand(supabase);
      await sendMessage(chatId, msg);
      return new Response("OK", { status: 200 });
    }

    if (text === "/shift") {
      await sendChatAction(chatId);
      const msg = await handleShiftCommand(supabase);
      await sendMessage(chatId, msg);
      return new Response("OK", { status: 200 });
    }

    // --- AI Chat flow ---

    // Show typing indicator
    await sendChatAction(chatId);

    // Build business context from DB
    const businessContext = await buildBusinessContext(supabase);

    // Get or create conversation history
    let history = conversationHistory.get(chatId) || [];

    // Reset if too many messages
    if (history.length >= MAX_HISTORY * 2) {
      history = history.slice(-6); // Keep last 3 exchanges
    }

    // Build messages for DeepSeek
    const systemPrompt = buildSystemPrompt(businessContext, username);
    const messages: Array<{ role: string; content: string }> = [
      { role: "system", content: systemPrompt },
      ...history,
      { role: "user", content: text },
    ];

    // Call DeepSeek AI
    const aiReply = await callDeepSeek(messages);

    // Update conversation history
    history.push({ role: "user", content: text });
    history.push({ role: "assistant", content: aiReply });
    conversationHistory.set(chatId, history);

    // Send response
    await sendMessage(chatId, aiReply);

    return new Response("OK", { status: 200 });
  } catch (err) {
    console.error("Telegram bot error:", err);

    // Try to send error message to user
    try {
      const update: TelegramUpdate = await req
        .clone()
        .json()
        .catch(() => null);
      if (update?.message?.chat?.id) {
        await sendMessage(
          update.message.chat.id,
          "Maaf, terjadi kesalahan. Coba lagi dalam beberapa saat ya."
        );
      }
    } catch (_) {
      // Ignore - best effort error message
    }

    return new Response("OK", { status: 200 });
  }
});
