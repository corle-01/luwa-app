# UTTER APP — CHECKPOINT vs MASTER BLUEPRINT v2.1
> Last updated: 2026-02-09

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
- [x] Order-level notes

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
- [x] Split payment (multi-method)
- [x] Online Food platform (GoFood/GrabFood/ShopeeFood) — integrated into regular PaymentDialog

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
- [x] Ingredient CRUD (nama, unit, cost, kategori)
- [x] Kategori bahan: Makanan, Minuman, Snack (tab filter + badge warna)
- [x] Stock levels (current, min, max)
- [x] Low stock alerts
- [x] Harga/unit column in table + edit in adjustment dialog
- [x] Tambah bahan dialog (nama, kategori, satuan, harga/unit, min stok)
- [x] Mobile-optimized cards + responsive dialogs

### 2D. Inventory & Stock ✅
- [x] Stock movements (stock in, adjustment, waste, etc.)
- [x] Movement history
- [x] Low stock tab
- [x] Purchase Order UI (create, detail, receive, cancel)
- [x] Supplier Management UI (CRUD + search)
- [x] Stok Produk Jadi (finished goods tracking, movements, tab in Inventory)
- [x] 7 tabs: Semua, Makanan, Minuman, Snack, Stok Rendah, Riwayat, Produk Jadi

### 2E. Recipe & HPP ✅
- [x] Link ingredient ke product
- [x] Qty per ingredient
- [x] Cost tracking (HPP per product)
- [x] Margin display
- [x] **Auto HPP**: recipe change → auto-recalculate product.cost_price (DB trigger)
- [x] **Ingredient price cascade**: harga bahan naik → semua produk terkait auto-update HPP
- [x] **Stock auto-deduct**: order completed → stok bahan berkurang sesuai resep (DB trigger)
- [x] **Recipe in Product Edit**: resep langsung di dialog edit produk (add/edit/delete bahan, HPP summary + margin)
- [x] **Ingredient category edit**: bisa ubah kategori bahan (Makanan/Minuman/Snack) dari dialog stok

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
- [x] QR code per meja

### 2I. Settings Hub ✅
- [x] Card-based navigation (16 sub-pages)

---

## PHASE 3 — REPORTS & ANALYTICS ✅ ~95%

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
- [x] **Operational cost integration**: HPP Bahan + Biaya Operasional/bln + Overhead/porsi + Laba Bersih
- [x] **Bonus allocation**: tampil kartu bonus jika % > 0

### 3C. Export ✅
- [x] Export to CSV (browser download via dart:js_interop)
- [x] Sales report CSV, HPP CSV, Order history CSV
- [ ] Email report

### 3D. Monthly Analytics ✅
- [x] Monthly comparison (6-month trend)
- [x] Trend analysis (line chart + bar chart)
- [x] Growth metrics (current vs previous month, % badges)
- [x] Monthly comparison table

### 3E. Report Hub ✅
- [x] Tabbed navigation (Penjualan, HPP, Analitik, Advanced)
- [x] P&L Report (profit/loss with purchase expenses)

---

## PHASE 4 — KITCHEN DISPLAY SYSTEM ✅ ~90%

### 4A. Kitchen Display ✅
- [x] Kitchen queue display (dark-themed grid layout)
- [x] Order item status (pending → cooking → ready)
- [x] Kitchen staff interface (full-screen, realtime via Supabase)
- [x] Order card with elapsed timer
- [x] Item-level status cycling (tap to advance)
- [x] Bulk actions (Start All, Complete All, Serve)
- [x] Recall served orders
- [x] Status filter tabs (All, Waiting, In Progress, Ready, Served)
- [x] DB trigger auto-updates order kitchen_status from item statuses
- [x] Entry point from Role Selection page (3rd card)
- [x] Sound notification (Web Audio API beep)

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
- [x] Push notification when order ready (browser Notification API + in-app animated banner)

---

## PHASE 6 — ONLINE FOOD INTEGRATION ✅ ~90%

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
- [ ] Real GoFood API webhook (requires partner account)

### 6C. GrabFood Integration ✅
- [x] GrabFood config + enable/disable toggle
- [x] GrabFood order acceptance/rejection
- [x] GrabFood order status tracking
- [ ] Real GrabFood API webhook (requires partner account)

### 6D. ShopeeFood Integration ✅
- [x] ShopeeFood config + enable/disable toggle
- [x] ShopeeFood order acceptance/rejection
- [x] ShopeeFood order status tracking
- [ ] Real ShopeeFood API webhook (requires partner account)

### 6E. Unified Order Management ✅
- [x] Online order management page in Back Office nav
- [x] Stats cards (total orders, revenue, per-platform breakdown)
- [x] Filter by platform + status
- [x] Order cards with platform branding, customer/driver info, items
- [x] Accept/reject incoming orders (creates internal order)
- [x] Status flow: incoming→accepted→preparing→ready→picked_up→delivered
- [x] Order detail dialog with status timeline
- [x] Simulate incoming order (for testing/demo)
- [x] Auto-refresh every 15 seconds (→ now realtime via Supabase)
- [x] Incoming order count badge in nav
- [x] POS integration: GoFood/GrabFood/ShopeeFood as payment methods in PaymentDialog
- [x] Online food orders: harga jual real (bukan 0), selisih total vs diterima = komisi platform
- [x] Receipt/report/order detail updated for platform payment + komisi display

---

## PHASE 7 — ENHANCEMENTS ✅ ~90%

### 7A. Multi-Outlet Support ✅
- [x] Outlet provider (currentOutletProvider, currentOutletIdProvider)
- [x] Outlet selector page (auto-select if single, manual grid if multiple)
- [x] Outlet management page (CRUD: name, address, phone, email, timezone, currency)
- [x] Settings hub integration ("Kelola Outlet" card)
- [x] Backward compatible (fallback to hardcoded outlet ID)
- [x] Migrate all existing providers to use currentOutletIdProvider

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

### AI Overhaul - DeepSeek Direct + Function Calling (2026-02-08, updated 2026-02-09)
- [x] Switched from Supabase RPC proxy to direct Flutter→DeepSeek API calls (fixes 5001ms timeout)
- [x] 15 AI tools with function calling: products, categories, stock, sales, discounts, memory, health, operational costs
- [x] AiActionExecutor bridges AI intent to real database operations
- [x] Multi-turn function calling (up to 5 rounds per message)
- [x] Retry with backoff for rate limiting
- [x] AI is now the system itself - can execute real CRUD operations via natural language
- [x] Context builder sends full order details, top products, low stock items, operational costs, bonus %

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
| 2 | Stok Produk Jadi | SUDAH ADA (product stock tracking + movements + UI tab) |
| 3 | Laporan Keuangan Lengkap | PARTIAL (HPP+margin ada, full P&L belum) |
| 4 | Manajemen Pelanggan | SUDAH ADA (Phase 2F + Loyalty) |
| 5 | Manajemen Karyawan | SUDAH ADA (Phase 2G, role/PIN) |
| 6 | Integrasi Pembayaran | SUDAH ADA (Cash, QRIS, E-Wallet, Bank, Debit) |
| 7 | Pesanan Real-time (KDS) | SUDAH ADA (Phase 4) |
| 8 | Analisis Prediktif | BELUM (forecasting, demand prediction) |
| 9 | Multi-outlet | SUDAH ADA (Phase 7A) |
| 10 | Backup & Recovery | BELUM |

**AI Persona System: DONE (2026-02-08)**
- [x] OTAK (Memory): AI remembers business patterns, auto-extracts insights from conversations, localStorage persistence
- [x] BADAN (Action): Enhanced with proactive suggestions, save_memory + check_business_health tools (13 tools total)
- [x] PERASAAN (Prediction): Business mood indicator, revenue projections, predicted busy hours, stock warnings
- [x] Dashboard: Perasaan Bisnis card, Memori AI section, persona status dots in status bar
- [x] System prompt rewritten with 3 persona instructions (warm, proactive, empathetic)

**AI Avatar + Chat Overlay Refactor: DONE (2026-02-08)**
- [x] Removed AI from POS kasir (security: prevents company info exposure)
- [x] AI chat only accessible in Back Office via floating avatar overlay
- [x] Programmatic CustomPainter mascot (owl/bird) - no PNG dependency
- [x] Expressive animations: mood-reactive eyes, blinking, breathing, floating, thinking mode
- [x] Voice Command: Web Speech API STT (mic button) + TTS (Dengar button on AI messages)
- [x] Chat BG pattern on overlay message area
- [x] Dashboard: full-width layout with insights, memory, predictions, recent actions
- [x] UtterMiniAvatar for inline use in message bubbles and headers

**Logo/Branding Integration: DONE (2026-02-08)**
- [x] Utter x IXON logos integrated (splash, role selection, POS header, self-order, back office sidebar)
- [x] Favicon 16/32, PWA icons 192/512, maskable icons, apple-touch-icon
- [x] web/index.html loading screen, manifest.json branding

**Multi-App Split: DONE (2026-02-09)**
- [x] Split into 3 separate web apps: POS, Office, Kitchen
- [x] Dedicated entry points: main_pos.dart, main_office.dart, main_kitchen.dart
- [x] Static HTML landing page at root with card navigation to all 3 apps
- [x] Self-order redirect via landing page JS (table param → office self-order route)
- [x] Shared initialization extracted to core/config/app_init.dart
- [x] BackOfficeShell extracted to own file with configurable logo tap callback
- [x] CI builds 3 Flutter web apps sequentially, assembles into /pos/, /office/, /kitchen/
- [x] KDS standalone always uses dark theme
- URLs: /utterapp/pos/, /utterapp/office/, /utterapp/kitchen/

**Mobile Web Responsive: DONE (2026-02-09)**
- [x] POS: mobile layout — full-screen product grid + floating cart FAB → bottom sheet
- [x] POS header: hide logo/text on mobile, icon-only buttons
- [x] POS product grid: responsive aspect ratios per breakpoint
- [x] Shift gate page: responsive card width for small screens
- [x] Back Office: 5-item bottom nav + "Lainnya" overflow menu (was 7, exceeded mobile limit)
- [x] Dashboard: responsive stat/menu cards, compact mobile order rows
- [x] Product management: icon-only AppBar actions on mobile
- [x] Settings hub: adjusted grid for mobile single-column layout
- [x] KDS: two-row mobile top bar with compact status badges
- [x] Landing page: wider mobile cards, adjusted spacing

**Telegram Bot: DONE (2026-02-08, updated 2026-02-09)**
- [x] @UtterAIBot Supabase Edge Function
- [x] Commands: /start, /help, /sales, /stock, /top, /shift, /reset, /opcost
- [x] Natural language AI chat with business context via DeepSeek
- [x] Updated context builder with operational costs, 12 KEMAMPUAN in system prompt

### Fix: Online Food Revenue & Platform Fee ✅ FIXED (2026-02-09)
- Online food orders now record real selling prices (bukan 0)
- `totalAmount` = harga jual real, `amountPaid` = jumlah diterima dari platform
- Selisih (total - amountPaid) = komisi/potongan platform, ditampilkan di:
  - Order detail dialog (box kuning "Komisi Platform")
  - Receipt HTML (row "Komisi Platform")
  - ESC/POS thermal receipt
  - Online food cart (realtime breakdown)
- Payment dialog info text updated (tidak lagi bilang "harga di-0-kan")
- Online food screen: `OnlineFoodItem` now carries `unitPrice` from product DB
- GoFood/GrabFood/ShopeeFood as payment methods in PaymentDialog

### Feature: Purchasing/Expense System ✅ DONE (2026-02-09)
1. DB Migration `021_purchasing_system.sql` — `purchases` + `purchase_items` tables with RLS + auto stock-in trigger
2. Model `lib/core/models/purchase.dart` — Purchase, PurchaseItem, PurchaseStats classes
3. Repository `lib/backoffice/repositories/purchase_repository.dart` — full CRUD + stats + receipt upload
4. Provider `lib/backoffice/providers/purchase_provider.dart` — purchaseListProvider, purchaseStatsProvider
5. UI `lib/backoffice/pages/purchase_page.dart` — full purchase management (create, detail, delete, receipt upload)
6. Navigation: "Pembelian" added to backoffice shell (8 nav items now)
7. P&L Integration: purchases shown as expenses in profit/loss report (by kas kasir vs uang luar)
8. Storage: `purchase-receipts` bucket for receipt/nota images

### Feature: Kitchen Auto-Print ✅ DONE (2026-02-09)
1. `lib/core/services/escpos_generator.dart` — EscPosKitchenTicket class (ESC/POS + HTML kitchen tickets)
2. `lib/core/services/kitchen_print_service.dart` — KitchenPrintService with auto-print toggle, printer selection
3. POS checkout: auto-prints kitchen ticket after successful order (fire-and-forget)
4. KDS: reprint button on each order card
5. Printer Settings: kitchen printer config card with auto-print toggle + printer dropdown
6. Kitchen tickets: no prices, large font, prominent order#/table, modifier/notes emphasis

### Feature: Featured Categories ✅ DONE (2026-02-09)
1. `is_featured` flag on categories + 3 seeded (Rekomendasi, Promo, Paket)
2. `product_featured_categories` junction table (many-to-many product ↔ featured category)
3. POS & Self-Order: featured tabs appear first with star icon + accent color
4. Back Office: FilterChip toggles in product edit form to tag products to featured categories
5. Migration: `023_featured_categories.sql`, `024_product_featured_categories.sql`

### Feature: Auto HPP Triggers ✅ DONE (2026-02-09)
1. Trigger `trg_recipe_cost_update`: recipe change → auto-recalculate product.cost_price from SUM(qty × cost_per_unit)
2. Trigger `trg_ingredient_cost_cascade`: ingredient cost_per_unit change → cascade update to ALL products using that ingredient
3. Trigger `deduct_stock_on_order_complete`: order completed → auto-deduct ingredient stock via recipes (already existed)
4. Backfill: all existing products HPP recalculated from recipe data
5. Migration: `025_auto_hpp_triggers.sql`
6. Full automation: Resep → HPP → Margin → Stock deduction, all automatic

### Feature: Theme-Aware Logos ✅ DONE (2026-02-09)
1. All logo references switch between _dark/_light variants based on Theme.brightness
2. CSS prefers-color-scheme support in landing.html
3. Responsive logo sizing with percentage-based widths + clamp

### UX Simplification: Search Autocomplete ✅ DONE (2026-02-09)
1. **Resep → Pilih Bahan**: dropdown 58 item → search autocomplete (ketik → filter instant)
2. **Pembelian → Pilih Supplier**: dropdown + toggle "Ketik Manual" → unified search field (cari existing ATAU ketik nama baru)
3. **Produk Jadi → Edit**: added edit dialog for min_stock + cost_price per product
4. Smart HPP indicator: detects recipe products (auto HPP, locked) vs purchased goods (manual HPP, editable)
5. Supplier search: auto-detects new supplier when name doesn't match existing

### Feature: Supabase Realtime Sync ✅ DONE (2026-02-09)
1. `lib/core/services/realtime_sync_service.dart` — central Supabase Realtime listener
2. Listens to 9 tables: products, categories, ingredients, recipes, orders, stock_movements, product_stock_movements, purchases, operational_costs
3. Auto-invalidates all related Riverpod providers on DB change (debounced 500ms)
4. Enabled in all 3 apps: POS, Office, Kitchen (replaces KDS 10s polling)
5. Navigation state persistence: tab index saved to localStorage, restored on refresh
6. Migration `027_enable_realtime.sql` — adds tables to `supabase_realtime` publication

### Feature: Recipe in Product Edit ✅ DONE (2026-02-09)
1. Resep & HPP section langsung di dialog edit produk (tidak perlu buka halaman resep terpisah)
2. Add/edit/delete bahan baku dengan ingredient search autocomplete
3. HPP summary: total biaya bahan + margin amount + margin % (color-coded)
4. "Belum ada resep" warning badge di section header
5. File: `lib/backoffice/pages/product_management_page.dart` (+ _RecipeItemInlineDialog, _IngredientSearchInline)

### Feature: Operational Costs & Bonus ✅ DONE (2026-02-09)
1. DB Migration `028_operational_costs.sql` — tabel `operational_costs` with RLS
2. Model `lib/core/models/operational_cost.dart` — OperationalCost class
3. Repository `lib/backoffice/repositories/operational_cost_repository.dart` — CRUD + getTotalMonthlyCost + getBonusPercentage
4. Provider `lib/backoffice/providers/operational_cost_provider.dart` — operationalCostsProvider, totalMonthlyCostProvider, bonusPercentageProvider
5. UI `lib/backoffice/pages/operational_cost_page.dart` — summary cards, inline editable amounts, bonus % input
6. Settings Hub: "Biaya Operasional" card added (16th item)
7. HPP Report: 6 summary cards (Pendapatan, HPP Bahan, Biaya Operasional/bln, Overhead/porsi, Laba Bersih, Bonus)
8. Bonus: % dari laba bersih, hanya tampil di HPP jika > 0%
9. Seed data: 7 common items (Sewa, Listrik, Gas, Air, Internet, Gaji Karyawan, BPJS) + 1 bonus config
10. Realtime sync for operational_costs table

### AI Knowledge Update ✅ DONE (2026-02-09)
1. **Context Builder**: added `_getOperationalCosts()` — AI now knows about monthly costs, bonus %, overhead
2. **System Prompt**: updated with 15 KEMAMPUAN SISTEM, operational cost data in PERASAAN section
3. **AI Tools**: added 2 new tools → `get_operational_costs`, `update_operational_cost` (15 tools total)
4. **AI Action Executor**: handlers for operational cost read/update with fuzzy name matching
5. **Telegram Bot**: updated context, system prompt, `/start`, `/help`, added `/opcost` command
6. Telegram bot redeployed to Supabase Edge Functions

### Bugfix: Tax CRUD ✅ FIXED (2026-02-09)
- DB column is `rate` but repository was sending `value` → INSERT/UPDATE silently failed
- Fixed `tax_repository.dart`: fromJson reads `rate` (fallback `value`), insert/update sends `rate`

### Bugfix: Inventory Category Edit ✅ FIXED (2026-02-09)
- Changing ingredient category forced entering stock quantity (validator rejected empty)
- Made quantity field optional: validator accepts empty, `_save()` skips stock adjustment when empty
- Changed hint text to "Kosongkan jika tidak ubah stok"

### Feature: Produk Jadi Delete ✅ DONE (2026-02-09)
- Added `deleteProduct()` to `product_stock_repository.dart` (soft delete: is_active=false)
- Added delete button (desktop DataTable + mobile card) with confirmation dialog
- Users can now remove seed/dummy product data

### Bugfix: TTS Voice Quality ✅ FIXED (2026-02-09)
1. **Markdown cleanup**: added `_cleanForTts()` in avatar_chat_overlay — strips `**bold**`, `_italic_`, headers, bullets, code blocks, emojis, links before TTS
2. **Indonesian voice**: explicit `getVoices()` API + `_findIndonesianVoice()` selects id-ID voice (fallback: id* → ms-MY)
3. **Stop playback**: `_isSpeaking` toggle — tap to speak, tap again to stop; icon changes play→stop
4. **Preload voices**: `preloadVoices()` called on initState for async voice loading
5. Updated `voice_command_service.dart` with full JS interop for SpeechSynthesisVoice, getVoices(), voice setter, onend callback

### Improvement kecil yang relevan
1. **Split bill / partial payment** — DONE
2. **Stok produk jadi** — DONE (migration 018, product stock page, inventory tab)
3. **Digital receipt WhatsApp/email** — sekarang cuma print browser

### Feature: Multi-Image Upload per Produk ✅ DONE (2026-02-08)
1. DB Migration `020_product_images.sql` — tabel `product_images` + RLS + Storage bucket (product-images)
2. Model `lib/core/models/product_image.dart` — ProductImage class with fromJson/toJson/copyWith
3. Service `lib/core/services/image_upload_service.dart` — browser file picker (dart:js_interop) + Supabase Storage upload/delete
4. Updated `lib/core/models/product.dart` — `List<ProductImage> images` field + `primaryImageUrl` getter
5. Updated `lib/backoffice/repositories/product_repository.dart` — join query, getProductImages, addProductImage, deleteProductImage, setPrimaryImage, reorderImages
6. Updated `lib/backoffice/pages/product_management_page.dart` — image section in edit form (thumbnails + upload + delete + set primary + drag reorder), primary image in product card
7. Updated `lib/self_order/pages/self_order_menu_page.dart` — image carousel in product detail sheet, primary image in grid card
8. Updated `lib/self_order/repositories/self_order_repository.dart` — join product_images in menu query

### Bugfix: Migration 028 — Critical Bug Fixes ✅ FIXED (2026-02-09)
Full code audit found 70 bugs (11 CRITICAL, 17 HIGH, 22 MEDIUM, 20 LOW). All 6 critical DB/code bugs fixed:
1. **payment_method CHECK constraint**: added 'e_wallet', 'platform', 'gofood', 'grabfood', 'shopeefood' to allowed values
2. **movement_type CHECK constraint**: added 'purchase' to allowed values (used by purchase trigger)
3. **void trigger column name**: `p.quantity` → `p.stock_quantity` + enhanced to restore ingredient stock via recipes
4. **payment_details column**: added JSONB column for split payment data
5. **orders status CHECK constraint**: added 'voided', 'served', 'pending_sync' to allowed values
6. **Kitchen print broken**: added browser-default printer to orphan PrinterService in kitchenPrintServiceProvider
7. **Self-order completion**: added missing UPDATE to 'completed' step (triggers now fire for self-orders)
- Migration: `028_fix_critical_bugs.sql`
- Code fixes: `kitchen_print_service.dart`, `self_order_repository.dart`

### Simulation Testing ✅ DONE (2026-02-09)
Comprehensive SQL-based simulation of all features:
- **14 orders**: 10 completed, 1 voided, 3 pending — 8 payment methods tested (cash, qris, card, e_wallet, split, grabfood, gofood, bank_transfer)
- **5 purchases**: 4 suppliers, 9 items, Rp 1,283,000 total — auto stock-in trigger verified
- **Stock adjustments**: stock_in (+200g Teh), waste (-50g Creamer), adjustment (+500g SKM)
- **Self-order**: SO-SIM001, pending→completed transition, DB triggers fired correctly
- **Void test**: VOID-TEST-001, stock restored (product stock_quantity + ingredient current_stock via recipes)
- **Trigger verification**: deduct_stock (115 auto_deduct), update_shift (352K/10 orders), update_customer (2 orders/95K)
- **Reports verified**: payment breakdown, top products (Milko Creamy 6 units), stock movements (140 total), P&L (378K revenue)

### Bugfix: Migration 029 — Stock System Bugs ✅ FIXED (2026-02-09)
From stock & inventory audit (14 bugs found: 4 CRITICAL, 4 HIGH, 4 MEDIUM, 2 LOW):
1. **AI executor movement types (CRITICAL)**: 'adjustment_in'/'adjustment_out' → 'stock_in'/'adjustment' (valid CHECK values)
2. **Race condition in stock updates (CRITICAL)**: read-then-write → atomic `increment_ingredient_stock()` / `increment_product_stock()` RPCs
3. **Product stock_quantity not deducted (HIGH)**: added `deduct_product_stock_trigger` for track_stock=true products
4. **Void trigger enhanced**: restore product stock_quantity on void/refund (track_stock products)
5. **PO receipt missing outlet_id (MEDIUM)**: added to stock_movements insert in purchase_order_repository
6. **Cost field comma parsing (MEDIUM)**: now strips both dots and commas
- Migration: `029_fix_stock_bugs.sql`
- Code fixes: `ai_action_executor.dart`, `inventory_repository.dart`, `product_stock_repository.dart`, `purchase_order_repository.dart`, `inventory_page.dart`

### Bugfix: AI + Purchasing + Settings Audit Fixes ✅ FIXED (2026-02-09)
From AI+purchasing+settings audit (22 bugs: 5 HIGH, 6 MEDIUM, 10 LOW):
1. **AI LIKE wildcard injection (HIGH)**: sanitize `%` and `_` in all `.ilike()` search patterns
2. **AI hard delete (HIGH)**: changed `_deleteProduct` from hard delete to soft delete (is_active=false)
3. **Tax soft-delete filter (HIGH)**: added `.eq('is_active', true)` to `getTaxes()` query
4. **AI memory persistence (MEDIUM)**: `_WebStorage` was a no-op stub → replaced with SharedPreferences
5. **Purchase unitPrice validation (MEDIUM)**: added `unitPrice > 0` check in purchase form
6. **Staff PIN validation (MEDIUM)**: fixed hint text "4-6 digit", added numeric-only regex validation
- Note: BUG #12 (purchase→stock disconnect) is false positive — DB trigger `trg_auto_stock_in_purchase_item` handles this
- Note: BUG #7 (API key exposure) is architectural — would need server-side proxy to fix

### Bugfix: POS Order+Payment Flow Audit Fixes ✅ FIXED (2026-02-09)
From POS order+payment audit (16 bugs: 3 CRITICAL, 4 HIGH, 5 MEDIUM, 4 LOW):
- 3 CRITICAL already fixed in migration 028 (payment_method CHECK, e_wallet, void trigger)
- 1 HIGH already fixed (self-order completion)
Newly fixed:
1. **Order.toJson() missing fields (HIGH)**: added `amount_paid` and `change_amount`
2. **Dual source columns (HIGH)**: self-order now writes both `source` and `order_source`
3. **Split overpayment (HIGH)**: calculate change instead of silently losing excess
4. **Modifier matching (MEDIUM)**: sort by groupName+optionName for order-independent comparison
5. **tableNumber type crash (LOW)**: safe parsing handles non-numeric table names like "A1"

### Bugfix: Self-Order + KDS + Online Audit Fixes ✅ FIXED (2026-02-09)
From self-order+KDS+online audit (18 bugs: 3 CRITICAL, 4 HIGH, 6 MEDIUM, 5 LOW):
- 2 CRITICAL already fixed (self-order completion + triggers)
- 1 MEDIUM already fixed (source vs order_source)
- BUG-006/007 verified as false positives (all columns exist in DB)
Newly fixed:
1. **KDS table_number missing (CRITICAL)**: join with tables table to get table_number
2. **KDS N+1 query (MEDIUM→CRITICAL perf)**: single query with `orders + order_items + tables` joins
3. **KDS modifier display (HIGH)**: handle all key formats (option_name/option/name/modifier_name)
4. **Table stuck occupied (HIGH)**: KDS markOrderServed now releases table (checks no other active orders)
5. **Notification icon path (MEDIUM)**: relative path for multi-app split compatibility
6. **KDS table_number type (LOW)**: safe parsing for non-numeric table names

---

### Bugfix: Shift+Dashboard+Reports Audit Fixes ✅ FIXED (2026-02-09)
From shift+dashboard+reports audit (16 bugs: 1 CRITICAL, 4 HIGH, 6 MEDIUM, 5 LOW):
1. **Split payment shift summary (HIGH)**: break down cash/non-cash from payment_details JSONB
2. **salesByPayment non-completed orders (MEDIUM)**: only count completed orders in payment breakdown
3. **ShiftCloseDialog FutureBuilder (HIGH)**: cache future in initState, no refetch on keystroke
4. **Discrepancy visibility (MEDIUM)**: show when text non-empty, not just amount > 0
- Note: Timezone (BUG #1 CRITICAL) → FIXED in dedicated timezone pass below

### Bugfix: DB Triggers+RLS Audit Fixes ✅ FIXED (2026-02-09)
From triggers+RLS audit (8 CRITICAL, 3 HIGH, 4 MEDIUM, 3 LOW):
- 5 CRITICAL trigger bugs already fixed in migrations 028/029
Newly fixed:
1. **recipes table no anon policies (CRITICAL)**: added SELECT/INSERT/UPDATE/DELETE for anon
2. **products/categories missing DELETE (CRITICAL)**: added anon DELETE policies
3. **discounts/customers/ingredients missing DELETE**: added anon DELETE policies
4. **backup_repository wrong table (HIGH)**: 'staff_profiles' → 'profiles'
- Migration: `030_fix_rls_shift_bugs.sql`

### Bugfix: Timezone in Date Queries (CRITICAL) ✅ FIXED (2026-02-09)
All date-filtered Supabase queries used `DateTime.now().toIso8601String()` which omits timezone info —
Supabase treats it as UTC, causing 7-hour offset for Jakarta (UTC+7).

**Solution**: Created `lib/core/utils/date_utils.dart` utility with:
- `toUtcIso(dt)` — converts local DateTime to UTC ISO string
- `startOfTodayUtc()` / `endOfTodayUtc()` — timezone-correct "today" bounds
- `startOfDayUtc(date)` / `endOfDayUtc(date)` — timezone-correct date bounds
- `startOfMonthUtc(year, month)` — for monthly report queries
- `nowUtc()` — for write operations (updated_at, etc.)
- `toDateOnly(dt)` — YYYY-MM-DD for date-only columns

**Files fixed (13 total)**:
1. `dashboard_provider.dart` — today's sales/orders queries
2. `kds_repository.dart` — today's kitchen orders + all write timestamps
3. `report_repository.dart` — sales, hourly, monthly, P&L, HPP queries
4. `analytics_repository.dart` — peak hours, day-of-week, AOV, source, staff queries
5. `pos_order_repository.dart` — today's orders, date range filters, write timestamps
6. `ai_context_builder.dart` — today's orders, weekly top products
7. `ai_prediction_service.dart` — today's mood, historical comparison, 4-week predictions
8. `ai_action_executor.dart` — sales summary date ranges
9. `online_order_repository.dart` — date filters + all write timestamps
10. `purchase_repository.dart` — date-only purchase_date filters
11. `pos_shift_repository.dart` — shift open/close timestamps
12. `prediction_repository.dart` — daily trend, product performance, order source queries
13. New: `lib/core/utils/date_utils.dart` — central timezone utility

### Improvement: Dashboard Low Stock includes Products ✅ FIXED (2026-02-09)
Dashboard `getLowStockCount()` previously only checked ingredients.
Now also checks products with `track_stock=true` and `stock_quantity <= min_stock`.

### Improvement: Monthly Sales Parallel Queries ✅ FIXED (2026-02-09)
`getMonthlySales()` previously ran 6 sequential API calls (one per month).
Now uses `Future.wait()` to fetch all 6 months in parallel — ~6x faster.

### Security: DeepSeek API Proxy ✅ DONE (2026-02-09)
- Created `supabase/functions/ai-proxy/index.ts` — Edge Function proxy for DeepSeek API
- API key stays server-side (DEEPSEEK_API_KEY Supabase secret), client sends Supabase anon key
- `gemini_service.dart` auto-detects proxy availability, falls back to direct API if unavailable
- Deployed via `supabase functions deploy ai-proxy`

### Bugfix: Unit Conversion in Recipe Cost ✅ FIXED (2026-02-09)
Recipe costs were calculated wrong when recipe unit differs from ingredient unit (e.g., recipe uses 200g but ingredient is priced per kg).
1. **DB function**: `unit_conversion_factor()` for g↔kg, ml↔l conversions (Migration 031)
2. **DB triggers updated**: both `update_product_cost_from_recipe()` and `update_products_cost_on_ingredient_price_change()` now use conversion
3. **Dart code**: `RecipeItem.totalCost` uses `unitConversionFactor()` static method
4. **UI**: recipe management + product edit inline recipe both use conversion for cost preview
5. **Backfill**: all existing product cost_prices recalculated with correct unit conversion

### Bugfix: Missing RLS Policies ✅ FIXED (2026-02-09)
Added anon CRUD policies for: `ai_trust_settings`, `ai_conversations`, `ai_messages`, `ai_action_logs`, `ai_insights`.
Added anon UPDATE/DELETE for `loyalty_transactions`. (Migration 031)

### Improvement: KDS Button Performance ✅ FIXED (2026-02-09)
KDS buttons were slow because loading spinner replaced all buttons during network call.
1. **Card actions**: replaced spinner with `IgnorePointer` + `AnimatedOpacity` — buttons stay visible (faded) during loading
2. **Item status tap**: optimistic update — badge changes INSTANTLY, network call runs in background, reverts on failure
3. **markOrderServed**: parallelized 2 independent API calls with `Future.wait()` (was 3 sequential)
- `_ItemRow` converted from `ConsumerWidget` to `ConsumerStatefulWidget` for optimistic state

### Feature: Kitchen/Bar Station Routing ✅ DONE (2026-02-09)
Kitchen tickets now group items by station (Kitchen vs Bar) so server knows which items go where.
1. **Migration 032**: Added `station` column to `categories` (default 'kitchen'), auto-detects drink categories as 'bar'
2. **Models**: `ProductCategory` + `CategoryModel` now include `station` field
3. **Repository**: `createCategory`/`updateCategory` accept `station` parameter
4. **Kitchen ticket**: Both ESC/POS and HTML generators group items with `[ KITCHEN ]` and `[ BAR ]` section headers
5. **Print service**: looks up product→category→station from DB when building ticket
6. **Category UI**: SegmentedButton (Kitchen/Bar) in both create and edit category dialogs
7. **Category list**: shows station badge (icon + label) under category name

---

## PROGRESS SUMMARY

| Phase | Progress | Status |
|-------|----------|--------|
| Phase 0 - Foundation | 100% | ✅ Done |
| Phase 1 - POS Kasir | ✅ 100% | ✅ Done (split pay, kitchen print, order notes) |
| Phase 2 - Back Office | ✅ 100% | ✅ Done (auto HPP, featured categories, purchasing) |
| Phase 3 - Reports | ~95% | ✅ Almost complete (email report remaining) |
| Phase 4 - KDS | ✅ 100% | ✅ Done (sound notification added) |
| Phase 5 - Self-Order | ✅ 100% | ✅ Done |
| Phase 6 - Online Food | ~90% | ✅ Almost complete (real API webhooks need partner accounts) |
| Phase 7 - Enhancements | ~90% | ✅ Almost complete (hardware testing remaining) |
| EXTRA - AI System | 100% | [!] Beyond blueprint (persona, avatar, Telegram bot, 15 tools) |
| EXTRA - Purchasing | 100% | [!] Full purchase/expense tracking with P&L |
| EXTRA - Auto HPP | 100% | [!] Recipe→cost→margin automation with price cascade |
| EXTRA - Operational Cost | 100% | [!] Monthly costs + bonus allocation for HPP |
| EXTRA - Bugfixes | 100% | [!] Tax CRUD, inventory edit, TTS, POS stock, self-order submit, purchase trigger+supplier, migration 028 |
