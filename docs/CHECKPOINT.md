# UTTER APP — CHECKPOINT vs MASTER BLUEPRINT v2.1
> Last updated: 2026-02-08

## LEGEND
- [x] Selesai
- [~] Partial (ada tapi belum lengkap)
- [ ] Belum dibuat
- [!] EXTRA (tidak ada di blueprint)

---

## PHASE 0 — FOUNDATION ✅ 100%
- [x] Supabase project + schema
- [x] Flutter project setup
- [x] AppTheme (light theme)
- [x] Core models (Product, Order, Customer, Shift, Discount, Tax, etc.)
- [x] Repository pattern
- [x] Riverpod state management
- [x] Routing (Splash → Role Selection → POS / Back Office)

---

## PHASE 1 — POS KASIR ✅ ~95%

### 1A. Shift Management ✅
- [x] Open shift (pilih kasir, input opening cash)
- [x] PIN login per kasir
- [x] Close shift (discrepancy calculation)
- [x] Shift summary (total sales, orders, cash/non-cash)

### 1B. Order Entry ✅
- [x] Product grid by category
- [x] Product search
- [x] Add to cart, modify qty, remove item
- [x] Item-level notes
- [x] Order type selector (Dine In / Takeaway)
- [x] Table selector (Dine In)
- [x] Customer selector
- [x] Open Tab / Hold Order / Park Order
- [ ] Order-level notes

### 1C. Modifier System ✅
- [x] Modifier groups dari DB
- [x] Single & multi selection
- [x] Required modifier validation
- [x] Price adjustment per modifier
- [x] Bottom sheet UI

### 1D. Discount & Tax ✅
- [x] Apply discount (percentage / fixed)
- [x] Tax calculation (PPN, service charge)
- [x] Inclusive/exclusive tax
- [x] Cart summary display

### 1E. Payment ✅
- [x] Cash (amount paid + change)
- [x] QRIS
- [x] Debit Card
- [x] E-Wallet
- [x] Bank Transfer
- [ ] Split payment (multi-method)

### 1F. Refund ✅
- [x] Refund dialog UI (full/partial refund)
- [x] Refund logic + stock restore (DB trigger)
- [x] Refund status tracking
- [x] Refund reason chips

### 1G. Void ✅
- [x] Void dialog UI
- [x] Void reason input (predefined + custom)
- [x] Void logic + stock restore (DB trigger)
- [x] Table release on void

### 1H. Order History ✅
- [x] Order list (today + custom date range)
- [x] Order detail dialog
- [x] Status badges (completed, cancelled, voided, refunded)
- [x] Print receipt from history
- [x] Filter by date range (Hari Ini, Minggu, Bulan, Custom)
- [x] Filter by status / payment method
- [x] Search by order number

### 1I. Receipt ✅
- [x] Receipt HTML generation (thermal 80mm)
- [x] Browser print (web)
- [x] Receipt dari payment success + order history

---

## PHASE 2 — BACK OFFICE ✅ ~95%

### 2A. Dashboard ✅
- [x] Summary cards (sales, orders, products)
- [x] Recent orders widget
- [x] Quick access cards

### 2B. Library ✅
- [x] Product CRUD (nama, SKU, harga, kategori, active toggle)
- [x] Category management
- [x] Modifier management (via recipe page)
- [x] Discount CRUD (percentage/fixed, validity, min purchase, max cap)
- [x] Tax CRUD (PPN/service charge, inclusive toggle)

### 2C. Ingredient Management ✅
- [x] Ingredient CRUD (nama, unit, cost)
- [x] Stock levels (current, min, max)
- [x] Low stock alerts

### 2D. Inventory & Stock ✅
- [x] Stock movements (stock in, adjustment, waste, etc.)
- [x] Movement history
- [x] Low stock tab
- [x] Purchase Order UI (create, detail, receive, cancel)
- [x] Supplier Management UI (CRUD + search)

### 2E. Recipe & HPP ✅
- [x] Link ingredient ke product
- [x] Qty per ingredient
- [x] Cost tracking (HPP per product)
- [x] Margin display

### 2F. Customer ✅
- [x] Customer CRUD
- [x] Search
- [x] Stats (total spent, visit count)
- [x] Loyalty points (field exists)
- [x] Loyalty program management UI (create/edit programs, transaction history)

### 2G. Employee/Staff ✅
- [x] Staff CRUD (nama, role, PIN, email, phone)
- [x] Role assignment (owner/admin/manager/cashier/kitchen/waiter)
- [x] PIN management

### 2H. Table Management ✅
- [x] Table CRUD (nomor, section, capacity)
- [x] Status tracking (available/occupied/reserved/maintenance)
- [ ] QR code per meja

### 2I. Settings Hub ✅
- [x] Card-based navigation (9 sub-pages)

---

## PHASE 3 — REPORTS & ANALYTICS ✅ 100%

### 3A. Sales Report ✅
- [x] Date range filter (Today/Week/Month/Custom)
- [x] Summary cards
- [x] Top products
- [x] Hourly sales chart (fl_chart)
- [x] Payment method breakdown
- [x] CSV Export (browser download)

### 3B. HPP Report ✅
- [x] Dedicated HPP report page
- [x] Cost vs revenue bar chart (top 10 products)
- [x] Margin per product (color-coded: green/yellow/red)
- [x] Sortable product table (9 columns)
- [x] Date range filter

### 3C. Export ✅
- [x] Export to CSV (browser download via dart:js_interop)
- [x] Sales report CSV, HPP CSV, Order history CSV
- [x] ~~Email report~~ (tidak perlu)

### 3D. Monthly Analytics ✅
- [x] Monthly comparison (6-month trend)
- [x] Trend analysis (line chart + bar chart)
- [x] Growth metrics (current vs previous month, % badges)
- [x] Monthly comparison table

### 3E. Report Hub ✅
- [x] Tabbed navigation (Penjualan, HPP, Analitik)

---

## PHASE 4 — KITCHEN DISPLAY SYSTEM ✅ ~90%

### 4A. Kitchen Display ✅
- [x] Kitchen queue display (dark-themed grid layout)
- [x] Order item status (pending → cooking → ready)
- [x] Kitchen staff interface (full-screen, auto-refresh 10s)
- [x] Order card with elapsed timer
- [x] Item-level status cycling (tap to advance)
- [x] Bulk actions (Start All, Complete All, Serve)
- [x] Recall served orders
- [x] Status filter tabs (All, Waiting, In Progress, Ready, Served)
- [x] DB trigger auto-updates order kitchen_status from item statuses
- [x] Entry point from Role Selection page (3rd card)
- [ ] Sound notification

---

## PHASE 5 — CUSTOMER SELF-ORDER ✅ ~95%

### 5A. QR Code & Entry ✅
- [x] QR code per meja (via external QR API in table management)
- [x] QR dialog with copy link + print button
- [x] Self-order shell with URL routing (/self-order?table=TABLE_ID)
- [x] Manual table selection landing page (fallback when no QR)

### 5B. Customer Menu ✅
- [x] Mobile-first customer-facing menu UI
- [x] Category filter chips (horizontal scroll)
- [x] Product search bar
- [x] 2-column product grid with cards
- [x] Product detail bottom sheet with modifiers
- [x] Modifier selection (single/multi) with price adjustments
- [x] Quantity selector + notes field
- [x] Floating cart button (FAB) with item count & total

### 5C. Cart & Checkout ✅
- [x] Cart page with item list, quantity controls, swipe-to-delete
- [x] Customer notes field for kitchen
- [x] Order summary (subtotal, tax info)
- [x] Submit order (creates pending order for cashier)
- [x] Table auto-set to occupied on order

### 5D. Order Tracking ✅
- [x] Confirmation page with animated checkmark
- [x] Order tracking page with 4-step timeline
- [x] Item-level kitchen status badges
- [x] Auto-refresh every 10 seconds
- [x] Elapsed time display
- [x] "Pesan Lagi" + "Panggil Pelayan" actions
- [ ] Push notification when order ready

---

## PHASE 6 — ONLINE FOOD INTEGRATION ✅ 100%

### 6A. Platform Configuration ✅
- [x] Platform configs table (GoFood, GrabFood, ShopeeFood)
- [x] Platform settings page (enable/disable, store ID, API key, webhook, auto-accept, commission rate)
- [x] Connection test placeholder
- [x] Platform branding (colors, icons per platform)
- [x] Settings hub integration ("Integrasi Platform" card)

### 6B. GoFood Integration ✅
- [x] GoFood config + enable/disable toggle
- [x] GoFood order acceptance/rejection
- [x] GoFood order status tracking
- [x] ~~Real GoFood API webhook~~ (pakai input manual)

### 6C. GrabFood Integration ✅
- [x] GrabFood config + enable/disable toggle
- [x] GrabFood order acceptance/rejection
- [x] GrabFood order status tracking
- [x] ~~Real GrabFood API webhook~~ (pakai input manual)

### 6D. ShopeeFood Integration ✅
- [x] ShopeeFood config + enable/disable toggle
- [x] ShopeeFood order acceptance/rejection
- [x] ShopeeFood order status tracking
- [x] ~~Real ShopeeFood API webhook~~ (pakai input manual)

### 6E. Unified Order Management ✅
- [x] Online order management page in Back Office nav
- [x] Stats cards (total orders, revenue, per-platform breakdown)
- [x] Filter by platform + status
- [x] Order cards with platform branding, customer/driver info, items
- [x] Accept/reject incoming orders (creates internal order)
- [x] Status flow: incoming→accepted→preparing→ready→picked_up→delivered
- [x] Order detail dialog with status timeline
- [x] Simulate incoming order (for testing/demo)
- [x] Auto-refresh every 15 seconds
- [x] Incoming order count badge in nav

---

## PHASE 7 — ENHANCEMENTS ✅ ~90%

### 7A. Multi-Outlet Support ✅
- [x] Outlet provider (currentOutletProvider, currentOutletIdProvider)
- [x] Outlet selector page (auto-select if single, manual grid if multiple)
- [x] Outlet management page (CRUD: name, address, phone, email, timezone, currency)
- [x] Settings hub integration ("Kelola Outlet" card)
- [x] Backward compatible (fallback to hardcoded outlet ID)
- [ ] Migrate all existing providers to use currentOutletIdProvider

### 7B. Advanced Analytics ✅
- [x] Analytics repository (8 query methods with client-side aggregation)
- [x] Peak hours bar chart (orders per hour, busiest hour highlight)
- [x] Day of week analysis (Mon-Sun revenue comparison)
- [x] Product ABC analysis (A=top 80%, B=next 15%, C=bottom 5%)
- [x] Order source breakdown (POS vs Self-Order vs GoFood/Grab/Shopee)
- [x] Average order value trend (30-day line chart)
- [x] Customer insights (top customers, new vs returning, retention rate)
- [x] Staff performance (orders + revenue per cashier)
- [x] Report Hub 4th tab ("Advanced")

### 7C. Offline Mode ✅
- [x] Connectivity service (30s health check, online/offline/syncing status)
- [x] Offline queue service (in-memory queue, enqueue/dequeue operations)
- [x] Sync service (auto-sync on reconnect, manual sync, snackbar notifications)
- [x] Offline indicator widget (animated banner: red=offline, amber=syncing, blue=pending)
- [ ] Full POS integration (wire into checkout flow)

### 7D. Native Thermal Printer ✅
- [x] ESC/POS command generator (80mm/58mm, formatting, alignment)
- [x] Receipt printer (full receipt generation with items, totals, footer)
- [x] Printer service abstraction (browser/USB/bluetooth/network routing)
- [x] Printer settings page (add/edit/delete, test print, set default)
- [x] Settings hub integration ("Printer" card)
- [ ] WebUSB/WebBluetooth actual implementation (requires hardware testing)

---

## EXTRA (TIDAK ADA DI BLUEPRINT)
- [!] AI Chat System (DeepSeek) — full dashboard, chat, trust levels, insights, action logs
- [!] AI Floating Button di POS
- [!] 5 tabel AI di database
- [!] AI RPC function (ai_chat)

### AI Overhaul - DeepSeek Direct + Function Calling (2026-02-08)
- [x] Switched from Supabase RPC proxy to direct Flutter→DeepSeek API calls (fixes 5001ms timeout)
- [x] 11 AI tools with function calling: create/update/delete products, categories, stock, sales, discounts
- [x] AiActionExecutor bridges AI intent to real database operations
- [x] Multi-turn function calling (up to 5 rounds per message)
- [x] Retry with backoff for rate limiting
- [x] AI is now the system itself - can execute real CRUD operations via natural language
- [x] Context builder sends full order details, top products, low stock items

---

## TODO NEXT (Belum dikerjakan)

### Fix: AI Settings belum masuk Settings Hub
- File: `lib/backoffice/pages/settings_hub_page.dart`
- `AiSettingsPage` sudah ada di `lib/backoffice/ai/pages/ai_settings_page.dart`
- Tapi BELUM ditambahkan sebagai item di `_items` list dan `_navigateTo` switch
- Error "trust setting not found" perlu diinvestigasi juga (mungkin tabel `ai_trust_settings` belum ada/belum di-seed)

### Saran DeepSeek — Kekurangan Fitur (perlu review)
DeepSeek menyarankan 10 kekurangan. Setelah cross-check, **7 sudah ada**, 3 benar-benar belum:

| # | Saran | Status |
|---|-------|--------|
| 1 | Shift & Kasir | SUDAH ADA (Phase 1A) |
| 2 | Stok Produk Jadi | BELUM (baru stok bahan baku/ingredient) |
| 3 | Laporan Keuangan Lengkap | PARTIAL (HPP+margin ada, full P&L belum) |
| 4 | Manajemen Pelanggan | SUDAH ADA (Phase 2F + Loyalty) |
| 5 | Manajemen Karyawan | SUDAH ADA (Phase 2G, role/PIN) |
| 6 | Integrasi Pembayaran | SUDAH ADA (Cash, QRIS, E-Wallet, Bank, Debit) |
| 7 | Pesanan Real-time (KDS) | SUDAH ADA (Phase 4) |
| 8 | Analisis Prediktif | BELUM (forecasting, demand prediction) |
| 9 | Multi-outlet | SUDAH ADA (Phase 7A) |
| 10 | Backup & Recovery | BELUM |

**DeepSeek juga menyarankan AI Persona:**
- OTAK (Memory): AI ingat semua data bisnis, pola penjualan, bisa analisis
- BADAN (Action): AI bisa langsung eksekusi perintah (tambah menu, update harga, dll)
- PERASAAN (Prediksi): AI prediksi demand besok, saran restock, analisis cuaca/tren

### Fix: Online Food Order ID harus auto-generate
- Saat ini order ID di online food masih input manual
- Seharusnya auto-generate mengikuti sequence order POS (urutan yang sama)
- Saat online order di-accept, otomatis dapat order ID berikutnya seperti order POS biasa

### Improvement kecil yang relevan
1. **Split bill / partial payment** — belum ada, sering dibutuhkan coffee shop
2. **Stok produk jadi** — baru ada stok bahan baku, finished goods belum
3. **Digital receipt WhatsApp/email** — sekarang cuma print browser

### Feature: Multi-Image Upload per Produk
Plan lengkap ada di `/home/awing/.claude/plans/floofy-tickling-hopper.md`

**Steps:**
1. DB Migration `018_product_images.sql` — tabel `product_images` + RLS + Storage bucket
2. Model `lib/core/models/product_image.dart` — ProductImage class
3. Service `lib/core/services/image_upload_service.dart` — upload/delete ke Supabase Storage
4. Edit `lib/core/models/product.dart` — tambah `List<ProductImage> images` field
5. Edit `lib/backoffice/repositories/product_repository.dart` — join query, CRUD images
6. Edit `lib/backoffice/pages/product_management_page.dart` — image picker di form + thumbnail di card
7. Edit `lib/self_order/pages/self_order_menu_page.dart` — carousel di detail sheet

---

## PROGRESS SUMMARY

| Phase | Progress | Status |
|-------|----------|--------|
| Phase 0 - Foundation | 100% | ✅ Done |
| Phase 1 - POS Kasir | ~95% | ✅ Almost complete (split pay remaining) |
| Phase 2 - Back Office | ✅ 100% | ✅ Done (QR added via Phase 5) |
| Phase 3 - Reports | 100% | ✅ Done (email report tidak perlu) |
| Phase 4 - KDS | ~90% | ✅ Almost complete (sound notification remaining) |
| Phase 5 - Self-Order | ~95% | ✅ Almost complete (push notification remaining) |
| Phase 6 - Online Food | 100% | ✅ Done (pakai input manual) |
| Phase 7 - Enhancements | ~90% | ✅ Almost complete (hardware testing remaining) |
| EXTRA - AI System | 100% | [!] Beyond blueprint (overhauled: direct API + function calling) |
