# 🚀 AI Deep Upgrade - Installation Instructions

## Fitur Yang Akan Diaktifkan:

✅ **Persistent Memory** - Luwa ingat insights di database (gak hilang lagi!)
✅ **Customer Segmentation** - VIP, Loyal, Repeat, New customer tracking
✅ **Profit Margin Analysis** - Analisis profitabilitas per produk
✅ **Week-over-Week Comparison** - Pertumbuhan bisnis WoW/MoM
✅ **Hourly Revenue Patterns** - Tau jam sibuk berdasarkan 90 hari data
✅ **Customer Phone Tracking** - Database nomor HP customer

## 📋 Migrations:

- `034_ai_memories_table.sql` - Persistent memory storage
- `038_add_customer_phone.sql` - Customer phone column
- `035_analytics_views.sql` - 6 analytics views
- `036_ai_helper_functions.sql` - 4 RPC functions

**Total:** 526 lines SQL | Estimated time: 2-5 seconds

---

## 🔧 Cara Install (Via Supabase Dashboard):

### Step 1: Buka Supabase SQL Editor

1. Buka browser di tablet/HP kamu
2. Login ke https://supabase.com/dashboard
3. Pilih project **luwaapp**
4. Klik **SQL Editor** di sidebar kiri

### Step 2: Copy Migration SQL

Kamu punya 2 pilihan:

**Option A: Via File (Recommended)**
```bash
# Di Termux, create GitHub Gist
gh gist create supabase/migrations/AI_DEEP_UPGRADE_COMPLETE.sql --public
```

Copy URL gist yang keluar, buka di browser, copy semua SQL-nya.

**Option B: Via Manual Copy**
```bash
# Di Termux, show file content
cat supabase/migrations/AI_DEEP_UPGRADE_COMPLETE.sql
```

Scroll, select all, copy (mungkin butuh waktu karena 526 lines).

### Step 3: Paste & Run

1. Di Supabase SQL Editor, paste semua SQL
2. Klik **"RUN"** button (besar, warna hijau)
3. Tunggu 2-5 detik
4. ✅ Kalau sukses, akan muncul **"Success. No rows returned"**

### Step 4: Verify Installation

Run query ini untuk verify:

```sql
-- Check ai_memories table exists
SELECT COUNT(*) FROM ai_memories;

-- Check customer_phone column exists
SELECT customer_phone FROM orders LIMIT 1;

-- Check views exist
SELECT * FROM v_product_performance LIMIT 5;

-- Check RPC functions exist
SELECT get_business_metrics('a0000000-0000-0000-0000-000000000001');
```

Kalau semua query jalan tanpa error = **SUKSES!** 🎉

---

## ⚠️ Troubleshooting:

### Error: "column customer_phone does not exist"
→ Migration 038 belum jalan. Re-run dari awal.

### Error: "relation v_product_performance does not exist"
→ Migration 035 belum jalan. Pastikan 038 sudah sukses dulu.

### Error: "function get_business_metrics does not exist"
→ Migration 036 belum jalan. Pastikan 035 sudah sukses.

### Error: "permission denied"
→ Pastikan kamu login sebagai database owner, bukan read-only user.

---

## 🚀 After Installation:

Setelah migrations sukses, Luwa akan otomatis dapat akses ke:

1. **Persistent memory di database** (gak hilang pas reload)
2. **Historical data 30-90 hari** (bukan cuma hari ini)
3. **Customer segments** (VIP/Loyal/Repeat/New)
4. **Profit margins** per produk
5. **Comparative metrics** (WoW growth)
6. **Hourly patterns** (jam sibuk prediction)

Test dengan nanya Luwa:
- "Bagaimana pertumbuhan penjualan minggu ini vs minggu lalu?"
- "Siapa customer VIP kita?"
- "Produk mana yang paling profitable?"
- "Jam berapa biasanya paling ramai?"

---

## 📦 File Migrations:

Location: `supabase/migrations/`

1. `034_ai_memories_table.sql` (68 lines)
2. `038_add_customer_phone.sql` (15 lines)
3. `035_analytics_views.sql` (163 lines)
4. `036_ai_helper_functions.sql` (280 lines)

Combined: `AI_DEEP_UPGRADE_COMPLETE.sql` (526 lines)

---

**Ready? Let's upgrade Luwa! 🚀**
