-- ################################################################
-- ################################################################
--
--   UTTER APP - ALL DATABASE MIGRATIONS (Combined)
--
--   Generated: 2026-02-06
--   Contains all 4 migration files in order:
--     1. 001_core_tables.sql       (Tables 1-21 + triggers)
--     2. 002_ai_tables.sql         (Tables 22-26 + AI functions)
--     3. 003_views_functions_rls.sql (Views, Functions, RLS, Realtime)
--     4. 004_seed_data.sql         (Sample/seed data)
--
--   Run this entire file in Supabase SQL Editor
--
-- ################################################################
-- ################################################################


-- ================================================================
-- ================================================================
-- SECTION 1 OF 4: 001_core_tables.sql
-- Core Tables (1-21) + updated_at trigger
-- ================================================================
-- ================================================================

-- ============================================================
-- UTTER APP - Database Migration 001: Core Tables (1-21)
-- ============================================================
-- Run this in Supabase SQL Editor
-- Total: 21 core tables + views + functions
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. OUTLETS - Daftar outlet/cabang
-- ============================================================
CREATE TABLE outlets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  email TEXT,
  logo_url TEXT,
  timezone TEXT DEFAULT 'Asia/Jakarta',
  currency TEXT DEFAULT 'IDR',
  tax_rate DECIMAL(5,2) DEFAULT 0,
  service_charge_rate DECIMAL(5,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 2. PROFILES - Data user/karyawan (extends Supabase auth.users)
-- ============================================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  outlet_id UUID REFERENCES outlets(id),
  full_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'cashier' CHECK (role IN ('owner', 'admin', 'manager', 'cashier', 'kitchen', 'waiter')),
  pin TEXT,
  is_active BOOLEAN DEFAULT true,
  last_login_at TIMESTAMPTZ,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 3. CATEGORIES - Kategori produk
-- ============================================================
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  name TEXT NOT NULL,
  description TEXT,
  color TEXT DEFAULT '#6366F1',
  icon TEXT,
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 4. PRODUCTS - Daftar produk/menu
-- ============================================================
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  category_id UUID REFERENCES categories(id),
  name TEXT NOT NULL,
  description TEXT,
  sku TEXT,
  barcode TEXT,
  image_url TEXT,
  selling_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  cost_price DECIMAL(12,2) DEFAULT 0,
  is_available BOOLEAN DEFAULT true,
  is_active BOOLEAN DEFAULT true,
  track_stock BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  tags TEXT[],
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_products_outlet ON products(outlet_id);
CREATE INDEX idx_products_category ON products(category_id);

-- ============================================================
-- 5. MODIFIER_GROUPS - Grup modifier (Size, Topping, dll)
-- ============================================================
CREATE TABLE modifier_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  name TEXT NOT NULL,
  description TEXT,
  is_required BOOLEAN DEFAULT false,
  min_selections INT DEFAULT 0,
  max_selections INT DEFAULT 1,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 6. MODIFIER_OPTIONS - Opsi modifier
-- ============================================================
CREATE TABLE modifier_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  modifier_group_id UUID NOT NULL REFERENCES modifier_groups(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price_adjustment DECIMAL(12,2) DEFAULT 0,
  is_default BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 7. PRODUCT_MODIFIER_GROUPS - Link produk ke modifier groups
-- ============================================================
CREATE TABLE product_modifier_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  modifier_group_id UUID NOT NULL REFERENCES modifier_groups(id) ON DELETE CASCADE,
  sort_order INT DEFAULT 0,
  UNIQUE(product_id, modifier_group_id)
);

-- ============================================================
-- 8. SUPPLIERS - Daftar supplier
-- ============================================================
CREATE TABLE suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 9. INGREDIENTS - Bahan baku
-- ============================================================
CREATE TABLE ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  supplier_id UUID REFERENCES suppliers(id),
  name TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT 'gram',
  current_stock DECIMAL(12,3) DEFAULT 0,
  min_stock DECIMAL(12,3) DEFAULT 0,
  max_stock DECIMAL(12,3) DEFAULT 0,
  cost_per_unit DECIMAL(12,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ingredients_outlet ON ingredients(outlet_id);

-- ============================================================
-- 10. RECIPES - Resep produk (link produk ke bahan baku)
-- ============================================================
CREATE TABLE recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  quantity DECIMAL(12,3) NOT NULL,
  unit TEXT NOT NULL DEFAULT 'gram',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(product_id, ingredient_id)
);

-- ============================================================
-- 11. STOCK_MOVEMENTS - Riwayat pergerakan stok
-- ============================================================
CREATE TABLE stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  movement_type TEXT NOT NULL CHECK (movement_type IN (
    'stock_in', 'stock_out', 'adjustment', 'auto_deduct',
    'transfer', 'waste', 'return', 'purchase_order'
  )),
  quantity DECIMAL(12,3) NOT NULL,
  cost_per_unit DECIMAL(12,2) DEFAULT 0,
  total_cost DECIMAL(12,2) DEFAULT 0,
  reference_type TEXT,
  reference_id UUID,
  notes TEXT,
  performed_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_stock_movements_ingredient ON stock_movements(ingredient_id);
CREATE INDEX idx_stock_movements_outlet ON stock_movements(outlet_id);
CREATE INDEX idx_stock_movements_created ON stock_movements(created_at);

-- ============================================================
-- 12. PURCHASE_ORDERS - Purchase Order header
-- ============================================================
CREATE TABLE purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  supplier_id UUID REFERENCES suppliers(id),
  po_number TEXT NOT NULL,
  status TEXT DEFAULT 'draft' CHECK (status IN (
    'draft', 'sent', 'partially_received', 'received', 'cancelled'
  )),
  total_amount DECIMAL(12,2) DEFAULT 0,
  notes TEXT,
  expected_date DATE,
  received_date DATE,
  created_by UUID REFERENCES profiles(id),
  approved_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 13. PURCHASE_ORDER_ITEMS - Item-item dalam PO
-- ============================================================
CREATE TABLE purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  quantity_ordered DECIMAL(12,3) NOT NULL,
  quantity_received DECIMAL(12,3) DEFAULT 0,
  unit_cost DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_cost DECIMAL(12,2) DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 14. CUSTOMERS - Data pelanggan
-- ============================================================
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  loyalty_points INT DEFAULT 0,
  total_spent DECIMAL(12,2) DEFAULT 0,
  total_orders INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_customers_outlet ON customers(outlet_id);
CREATE INDEX idx_customers_phone ON customers(phone);

-- ============================================================
-- 15. DISCOUNTS - Diskon & promo
-- ============================================================
CREATE TABLE discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  name TEXT NOT NULL,
  description TEXT,
  type TEXT NOT NULL CHECK (type IN ('percentage', 'fixed_amount')),
  value DECIMAL(12,2) NOT NULL,
  min_purchase DECIMAL(12,2) DEFAULT 0,
  max_discount DECIMAL(12,2),
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  usage_limit INT,
  usage_count INT DEFAULT 0,
  applicable_to TEXT DEFAULT 'all' CHECK (applicable_to IN ('all', 'category', 'product')),
  applicable_ids UUID[],
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 16. TAXES - Pajak & service charge
-- ============================================================
CREATE TABLE taxes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('tax', 'service_charge')),
  rate DECIMAL(5,2) NOT NULL,
  is_inclusive BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 17. TABLES - Meja (untuk dine-in)
-- ============================================================
CREATE TABLE tables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  table_number TEXT NOT NULL,
  name TEXT,
  capacity INT DEFAULT 4,
  section TEXT,
  status TEXT DEFAULT 'available' CHECK (status IN ('available', 'occupied', 'reserved', 'maintenance')),
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 18. SHIFTS - Shift kasir
-- ============================================================
CREATE TABLE shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  cashier_id UUID NOT NULL REFERENCES profiles(id),
  opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ,
  opening_cash DECIMAL(12,2) DEFAULT 0,
  closing_cash DECIMAL(12,2),
  expected_cash DECIMAL(12,2),
  cash_difference DECIMAL(12,2),
  total_sales DECIMAL(12,2) DEFAULT 0,
  total_orders INT DEFAULT 0,
  total_refunds DECIMAL(12,2) DEFAULT 0,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_shifts_outlet ON shifts(outlet_id);
CREATE INDEX idx_shifts_cashier ON shifts(cashier_id);

-- ============================================================
-- 19. ORDERS - Header order/transaksi
-- ============================================================
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  shift_id UUID REFERENCES shifts(id),
  customer_id UUID REFERENCES customers(id),
  table_id UUID REFERENCES tables(id),
  cashier_id UUID REFERENCES profiles(id),
  order_number TEXT NOT NULL,
  order_type TEXT DEFAULT 'dine_in' CHECK (order_type IN (
    'dine_in', 'takeaway', 'delivery', 'online'
  )),
  status TEXT DEFAULT 'pending' CHECK (status IN (
    'draft', 'pending', 'preparing', 'ready', 'completed', 'cancelled', 'refunded'
  )),
  subtotal DECIMAL(12,2) DEFAULT 0,
  discount_amount DECIMAL(12,2) DEFAULT 0,
  discount_id UUID REFERENCES discounts(id),
  tax_amount DECIMAL(12,2) DEFAULT 0,
  service_charge_amount DECIMAL(12,2) DEFAULT 0,
  total DECIMAL(12,2) DEFAULT 0,
  payment_method TEXT CHECK (payment_method IN (
    'cash', 'card', 'qris', 'ewallet', 'bank_transfer', 'split'
  )),
  payment_status TEXT DEFAULT 'unpaid' CHECK (payment_status IN (
    'unpaid', 'paid', 'partial', 'refunded'
  )),
  amount_paid DECIMAL(12,2) DEFAULT 0,
  change_amount DECIMAL(12,2) DEFAULT 0,
  notes TEXT,
  customer_name TEXT,
  refund_reason TEXT,
  refunded_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_orders_outlet ON orders(outlet_id);
CREATE INDEX idx_orders_shift ON orders(shift_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created ON orders(created_at);
CREATE INDEX idx_orders_customer ON orders(customer_id);

-- ============================================================
-- 20. ORDER_ITEMS - Item-item dalam order
-- ============================================================
CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  product_name TEXT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  unit_price DECIMAL(12,2) NOT NULL,
  subtotal DECIMAL(12,2) NOT NULL,
  discount_amount DECIMAL(12,2) DEFAULT 0,
  total DECIMAL(12,2) NOT NULL,
  notes TEXT,
  modifiers JSONB DEFAULT '[]',
  status TEXT DEFAULT 'pending' CHECK (status IN (
    'pending', 'preparing', 'ready', 'served', 'cancelled'
  )),
  prepared_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);

-- ============================================================
-- 21. LOYALTY_PROGRAMS - Program loyalty
-- ============================================================
CREATE TABLE loyalty_programs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  name TEXT NOT NULL,
  description TEXT,
  points_per_amount DECIMAL(12,2) DEFAULT 1000,
  reward_threshold INT DEFAULT 100,
  reward_type TEXT DEFAULT 'discount' CHECK (reward_type IN ('discount', 'free_item', 'cashback')),
  reward_value DECIMAL(12,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- UPDATED_AT TRIGGER FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all tables with updated_at column
CREATE TRIGGER update_outlets_updated_at BEFORE UPDATE ON outlets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_modifier_groups_updated_at BEFORE UPDATE ON modifier_groups FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_suppliers_updated_at BEFORE UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_ingredients_updated_at BEFORE UPDATE ON ingredients FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_recipes_updated_at BEFORE UPDATE ON recipes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_purchase_orders_updated_at BEFORE UPDATE ON purchase_orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_discounts_updated_at BEFORE UPDATE ON discounts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_taxes_updated_at BEFORE UPDATE ON taxes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_tables_updated_at BEFORE UPDATE ON tables FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_loyalty_programs_updated_at BEFORE UPDATE ON loyalty_programs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- ================================================================
-- ================================================================
-- SECTION 2 OF 4: 002_ai_tables.sql
-- AI Tables (22-26) + AI functions
-- ================================================================
-- ================================================================

-- ============================================================
-- UTTER APP - Database Migration 002: AI Tables (22-26)
-- ============================================================
-- Run this AFTER 001_core_tables.sql
-- Total: 5 AI tables + functions
-- ============================================================

-- ============================================================
-- 22. AI_TRUST_SETTINGS - Pengaturan trust level per fitur AI
-- ============================================================
CREATE TABLE ai_trust_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  feature_key TEXT NOT NULL,
  trust_level INT NOT NULL DEFAULT 0 CHECK (trust_level BETWEEN 0 AND 3),
  is_enabled BOOLEAN DEFAULT true,
  config JSONB DEFAULT '{}',
  updated_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(outlet_id, feature_key)
);

CREATE TRIGGER update_ai_trust_settings_updated_at BEFORE UPDATE ON ai_trust_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function: Initialize default trust settings for new outlet
CREATE OR REPLACE FUNCTION init_ai_trust_settings(p_outlet_id UUID)
RETURNS VOID AS $$
BEGIN
  INSERT INTO ai_trust_settings (outlet_id, feature_key, trust_level) VALUES
    (p_outlet_id, 'stock_alert', 0),
    (p_outlet_id, 'auto_disable_product', 2),
    (p_outlet_id, 'auto_enable_product', 2),
    (p_outlet_id, 'draft_purchase_order', 1),
    (p_outlet_id, 'send_purchase_order', 1),
    (p_outlet_id, 'demand_forecast', 0),
    (p_outlet_id, 'pricing_recommendation', 1),
    (p_outlet_id, 'auto_promo', 1),
    (p_outlet_id, 'anomaly_alert', 2),
    (p_outlet_id, 'staffing_suggestion', 0),
    (p_outlet_id, 'auto_reorder', 1),
    (p_outlet_id, 'menu_recommendation', 0)
  ON CONFLICT (outlet_id, feature_key) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 23. AI_CONVERSATIONS - Riwayat percakapan AI
-- ============================================================
CREATE TABLE ai_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  user_id UUID NOT NULL REFERENCES profiles(id),
  title TEXT,
  source TEXT DEFAULT 'chat' CHECK (source IN ('chat', 'floating', 'voice')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER update_ai_conversations_updated_at BEFORE UPDATE ON ai_conversations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_ai_conversations_outlet ON ai_conversations(outlet_id);
CREATE INDEX idx_ai_conversations_user ON ai_conversations(user_id);

-- ============================================================
-- 24. AI_MESSAGES - Pesan dalam percakapan AI
-- ============================================================
CREATE TABLE ai_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system', 'function')),
  content TEXT NOT NULL,
  function_calls JSONB,
  tokens_used INT,
  model TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ai_messages_conversation ON ai_messages(conversation_id);
CREATE INDEX idx_ai_messages_created ON ai_messages(created_at);

-- ============================================================
-- 25. AI_ACTION_LOGS - Log semua aksi AI
-- ============================================================
CREATE TABLE ai_action_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  feature_key TEXT NOT NULL,
  trust_level INT NOT NULL,
  action_type TEXT NOT NULL CHECK (action_type IN (
    'informed', 'suggested', 'auto_executed', 'silent_executed',
    'approved', 'rejected', 'edited', 'undone'
  )),
  action_description TEXT NOT NULL,
  action_data JSONB,
  source TEXT DEFAULT 'scheduler' CHECK (source IN ('chat', 'scheduler', 'trigger')),
  conversation_id UUID REFERENCES ai_conversations(id),
  triggered_by UUID REFERENCES profiles(id),
  approved_by UUID REFERENCES profiles(id),
  is_undone BOOLEAN DEFAULT false,
  undo_deadline TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ai_action_logs_outlet ON ai_action_logs(outlet_id);
CREATE INDEX idx_ai_action_logs_feature ON ai_action_logs(feature_key);
CREATE INDEX idx_ai_action_logs_created ON ai_action_logs(created_at);

-- ============================================================
-- 26. AI_INSIGHTS - Insight proaktif dari AI
-- ============================================================
CREATE TABLE ai_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  insight_type TEXT NOT NULL CHECK (insight_type IN (
    'demand_forecast', 'stock_prediction', 'anomaly',
    'pricing_suggestion', 'promo_suggestion', 'staffing',
    'product_performance', 'general'
  )),
  title TEXT NOT NULL,
  description TEXT,
  severity TEXT DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical', 'positive')),
  data JSONB,
  suggested_action JSONB,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'dismissed', 'acted_on', 'expired')),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ai_insights_outlet ON ai_insights(outlet_id);
CREATE INDEX idx_ai_insights_status ON ai_insights(status);
CREATE INDEX idx_ai_insights_type ON ai_insights(insight_type);
CREATE INDEX idx_ai_insights_created ON ai_insights(created_at);


-- ================================================================
-- ================================================================
-- SECTION 3 OF 4: 003_views_functions_rls.sql
-- Views, Functions, Row Level Security & Realtime
-- ================================================================
-- ================================================================

-- ============================================================
-- UTTER APP - Database Migration 003: Views, Functions & RLS
-- ============================================================
-- Run this AFTER 002_ai_tables.sql
-- ============================================================

-- ============================================================
-- VIEWS
-- ============================================================

-- Low Stock Alerts View
CREATE OR REPLACE VIEW low_stock_alerts AS
SELECT
  i.id,
  i.outlet_id,
  i.name,
  i.unit,
  i.current_stock,
  i.min_stock,
  i.max_stock,
  i.cost_per_unit,
  s.name AS supplier_name,
  s.id AS supplier_id,
  CASE
    WHEN i.current_stock <= 0 THEN 'out_of_stock'
    WHEN i.current_stock <= i.min_stock THEN 'low_stock'
    WHEN i.current_stock >= i.max_stock THEN 'overstock'
    ELSE 'healthy'
  END AS stock_status
FROM ingredients i
LEFT JOIN suppliers s ON i.supplier_id = s.id
WHERE i.is_active = true;

-- Product HPP Summary View
CREATE OR REPLACE VIEW product_hpp_summary AS
SELECT
  p.id AS product_id,
  p.outlet_id,
  p.name AS product_name,
  p.selling_price,
  p.image_url,
  p.is_available,
  c.name AS category_name,
  COALESCE(SUM(r.quantity * i.cost_per_unit), 0) AS hpp,
  p.selling_price - COALESCE(SUM(r.quantity * i.cost_per_unit), 0) AS profit,
  CASE
    WHEN p.selling_price > 0 THEN
      ROUND(((p.selling_price - COALESCE(SUM(r.quantity * i.cost_per_unit), 0)) / p.selling_price * 100)::numeric, 1)
    ELSE 0
  END AS profit_percent
FROM products p
LEFT JOIN recipes r ON p.id = r.product_id
LEFT JOIN ingredients i ON r.ingredient_id = i.id
LEFT JOIN categories c ON p.category_id = c.id
WHERE p.is_active = true
GROUP BY p.id, p.outlet_id, p.name, p.selling_price, p.image_url, p.is_available, c.name;

-- Daily Sales Summary View
CREATE OR REPLACE VIEW daily_sales_summary AS
SELECT
  o.outlet_id,
  DATE(o.created_at AT TIME ZONE 'Asia/Jakarta') AS sale_date,
  COUNT(*) AS total_orders,
  COUNT(*) FILTER (WHERE o.status = 'completed') AS completed_orders,
  COUNT(*) FILTER (WHERE o.status IN ('cancelled', 'refunded')) AS cancelled_orders,
  COALESCE(SUM(o.total) FILTER (WHERE o.status = 'completed'), 0) AS total_revenue,
  COALESCE(SUM(o.discount_amount) FILTER (WHERE o.status = 'completed'), 0) AS total_discount,
  COALESCE(SUM(o.tax_amount) FILTER (WHERE o.status = 'completed'), 0) AS total_tax,
  COALESCE(AVG(o.total) FILTER (WHERE o.status = 'completed'), 0) AS avg_order_value
FROM orders o
GROUP BY o.outlet_id, DATE(o.created_at AT TIME ZONE 'Asia/Jakarta');

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Auto-generate order number
CREATE OR REPLACE FUNCTION generate_order_number(p_outlet_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_count INT;
  v_date TEXT;
BEGIN
  v_date := TO_CHAR(NOW() AT TIME ZONE 'Asia/Jakarta', 'YYYYMMDD');

  SELECT COUNT(*) + 1 INTO v_count
  FROM orders
  WHERE outlet_id = p_outlet_id
  AND DATE(created_at AT TIME ZONE 'Asia/Jakarta') = DATE(NOW() AT TIME ZONE 'Asia/Jakarta');

  RETURN 'ORD-' || v_date || '-' || LPAD(v_count::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Auto-generate PO number
CREATE OR REPLACE FUNCTION generate_po_number(p_outlet_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_count INT;
  v_date TEXT;
BEGIN
  v_date := TO_CHAR(NOW() AT TIME ZONE 'Asia/Jakarta', 'YYYYMMDD');

  SELECT COUNT(*) + 1 INTO v_count
  FROM purchase_orders
  WHERE outlet_id = p_outlet_id
  AND DATE(created_at AT TIME ZONE 'Asia/Jakarta') = DATE(NOW() AT TIME ZONE 'Asia/Jakarta');

  RETURN 'PO-' || v_date || '-' || LPAD(v_count::TEXT, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- Deduct stock after order completed
CREATE OR REPLACE FUNCTION deduct_stock_on_order_complete()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    INSERT INTO stock_movements (outlet_id, ingredient_id, movement_type, quantity, reference_type, reference_id, notes)
    SELECT
      NEW.outlet_id,
      r.ingredient_id,
      'auto_deduct',
      -(r.quantity * oi.quantity),
      'order',
      NEW.id,
      'Auto-deducted from order ' || NEW.order_number
    FROM order_items oi
    JOIN recipes r ON oi.product_id = r.product_id
    WHERE oi.order_id = NEW.id
    AND oi.status != 'cancelled';

    -- Update ingredient stock
    UPDATE ingredients i
    SET current_stock = i.current_stock - sub.total_deducted
    FROM (
      SELECT r.ingredient_id, SUM(r.quantity * oi.quantity) AS total_deducted
      FROM order_items oi
      JOIN recipes r ON oi.product_id = r.product_id
      WHERE oi.order_id = NEW.id
      AND oi.status != 'cancelled'
      GROUP BY r.ingredient_id
    ) sub
    WHERE i.id = sub.ingredient_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_deduct_stock_on_order
AFTER UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION deduct_stock_on_order_complete();

-- Update shift totals on order completion
CREATE OR REPLACE FUNCTION update_shift_on_order()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' AND NEW.shift_id IS NOT NULL THEN
    UPDATE shifts
    SET total_sales = total_sales + NEW.total,
        total_orders = total_orders + 1
    WHERE id = NEW.shift_id;
  END IF;

  IF NEW.status = 'refunded' AND OLD.status != 'refunded' AND NEW.shift_id IS NOT NULL THEN
    UPDATE shifts
    SET total_refunds = total_refunds + NEW.total
    WHERE id = NEW.shift_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_shift_on_order
AFTER UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION update_shift_on_order();

-- Update customer stats on order completion
CREATE OR REPLACE FUNCTION update_customer_on_order()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' AND NEW.customer_id IS NOT NULL THEN
    UPDATE customers
    SET total_spent = total_spent + NEW.total,
        total_orders = total_orders + 1
    WHERE id = NEW.customer_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_customer_on_order
AFTER UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION update_customer_on_order();

-- Get average daily voids (used by AI scheduler)
CREATE OR REPLACE FUNCTION get_avg_daily_voids(p_outlet_id UUID, p_days INT DEFAULT 30)
RETURNS NUMERIC AS $$
DECLARE
  v_total INT;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM orders
  WHERE outlet_id = p_outlet_id
  AND status IN ('cancelled', 'refunded')
  AND created_at >= NOW() - (p_days || ' days')::INTERVAL;

  RETURN ROUND(v_total::NUMERIC / p_days, 1);
END;
$$ LANGUAGE plpgsql;

-- Auto-initialize AI trust settings when outlet is created
CREATE OR REPLACE FUNCTION auto_init_ai_trust_settings()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM init_ai_trust_settings(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_init_ai_trust
AFTER INSERT ON outlets
FOR EACH ROW
EXECUTE FUNCTION auto_init_ai_trust_settings();

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE outlets ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE modifier_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE modifier_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_modifier_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE taxes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_trust_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_action_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_insights ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only access data from their own outlet
-- Profile policy - user can read own profile
CREATE POLICY "Users can read own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Helper function: get user's outlet_id
CREATE OR REPLACE FUNCTION get_user_outlet_id()
RETURNS UUID AS $$
BEGIN
  RETURN (SELECT outlet_id FROM profiles WHERE id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Outlet policy
CREATE POLICY "Users can read own outlet" ON outlets
  FOR SELECT USING (id = get_user_outlet_id());

-- Generic outlet-based policies for all outlet-scoped tables
DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'categories', 'products', 'modifier_groups', 'suppliers',
    'ingredients', 'stock_movements', 'purchase_orders', 'customers',
    'discounts', 'taxes', 'tables', 'shifts', 'orders',
    'loyalty_programs', 'ai_trust_settings', 'ai_conversations',
    'ai_action_logs', 'ai_insights'
  ])
  LOOP
    EXECUTE format('
      CREATE POLICY "Users can read own outlet data" ON %I
        FOR SELECT USING (outlet_id = get_user_outlet_id());
      CREATE POLICY "Users can insert own outlet data" ON %I
        FOR INSERT WITH CHECK (outlet_id = get_user_outlet_id());
      CREATE POLICY "Users can update own outlet data" ON %I
        FOR UPDATE USING (outlet_id = get_user_outlet_id());
    ', t, t, t);
  END LOOP;
END;
$$;

-- Policies for tables without outlet_id (use parent reference)
CREATE POLICY "Users can read modifier options" ON modifier_options
  FOR SELECT USING (
    modifier_group_id IN (SELECT id FROM modifier_groups WHERE outlet_id = get_user_outlet_id())
  );

CREATE POLICY "Users can manage modifier options" ON modifier_options
  FOR ALL USING (
    modifier_group_id IN (SELECT id FROM modifier_groups WHERE outlet_id = get_user_outlet_id())
  );

CREATE POLICY "Users can read product modifier groups" ON product_modifier_groups
  FOR SELECT USING (
    product_id IN (SELECT id FROM products WHERE outlet_id = get_user_outlet_id())
  );

CREATE POLICY "Users can manage product modifier groups" ON product_modifier_groups
  FOR ALL USING (
    product_id IN (SELECT id FROM products WHERE outlet_id = get_user_outlet_id())
  );

CREATE POLICY "Users can read recipes" ON recipes
  FOR SELECT USING (
    product_id IN (SELECT id FROM products WHERE outlet_id = get_user_outlet_id())
  );

CREATE POLICY "Users can manage recipes" ON recipes
  FOR ALL USING (
    product_id IN (SELECT id FROM products WHERE outlet_id = get_user_outlet_id())
  );

CREATE POLICY "Users can read PO items" ON purchase_order_items
  FOR SELECT USING (
    purchase_order_id IN (SELECT id FROM purchase_orders WHERE outlet_id = get_user_outlet_id())
  );

CREATE POLICY "Users can manage PO items" ON purchase_order_items
  FOR ALL USING (
    purchase_order_id IN (SELECT id FROM purchase_orders WHERE outlet_id = get_user_outlet_id())
  );

CREATE POLICY "Users can read order items" ON order_items
  FOR SELECT USING (
    order_id IN (SELECT id FROM orders WHERE outlet_id = get_user_outlet_id())
  );

CREATE POLICY "Users can manage order items" ON order_items
  FOR ALL USING (
    order_id IN (SELECT id FROM orders WHERE outlet_id = get_user_outlet_id())
  );

CREATE POLICY "Users can read own AI messages" ON ai_messages
  FOR SELECT USING (
    conversation_id IN (SELECT id FROM ai_conversations WHERE outlet_id = get_user_outlet_id())
  );

CREATE POLICY "Users can insert AI messages" ON ai_messages
  FOR INSERT WITH CHECK (
    conversation_id IN (SELECT id FROM ai_conversations WHERE outlet_id = get_user_outlet_id())
  );

-- ============================================================
-- REALTIME
-- ============================================================

-- Enable realtime for key tables
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE order_items;
ALTER PUBLICATION supabase_realtime ADD TABLE shifts;
ALTER PUBLICATION supabase_realtime ADD TABLE ingredients;
ALTER PUBLICATION supabase_realtime ADD TABLE ai_insights;
ALTER PUBLICATION supabase_realtime ADD TABLE ai_action_logs;
ALTER PUBLICATION supabase_realtime ADD TABLE ai_messages;


-- ================================================================
-- ================================================================
-- SECTION 4 OF 4: 004_seed_data.sql
-- Sample/Seed Data for development & testing
-- ================================================================
-- ================================================================

-- ============================================================
-- UTTER APP - Database Migration 004: Seed Data
-- ============================================================
-- Run this AFTER 003_views_functions_rls.sql
-- Sample data for development & testing
-- ============================================================

-- IMPORTANT: Outlet seed data
-- AI trust settings will be auto-created by trigger
INSERT INTO outlets (id, name, address, phone, email, tax_rate, service_charge_rate, settings) VALUES
(
  'a0000000-0000-0000-0000-000000000001',
  'Utter Coffee - Malang',
  'Jl. Veteran No. 1, Malang, Jawa Timur',
  '081234567890',
  'malang@uttercoffee.com',
  11.00,
  5.00,
  '{"opening_hours": "08:00", "closing_hours": "22:00", "wifi_password": "uttercoffee"}'
);

-- Sample categories
INSERT INTO categories (outlet_id, name, color, sort_order) VALUES
('a0000000-0000-0000-0000-000000000001', 'Kopi', '#6F4E37', 1),
('a0000000-0000-0000-0000-000000000001', 'Non-Kopi', '#4CAF50', 2),
('a0000000-0000-0000-0000-000000000001', 'Teh', '#FF9800', 3),
('a0000000-0000-0000-0000-000000000001', 'Makanan', '#E91E63', 4),
('a0000000-0000-0000-0000-000000000001', 'Snack', '#9C27B0', 5);

-- Sample suppliers
INSERT INTO suppliers (id, outlet_id, name, contact_person, phone, email) VALUES
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'PT Kopi Nusantara', 'Budi Santoso', '082111222333', 'budi@kopinusantara.com'),
('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'CV Susu Segar', 'Dewi Lestari', '083222333444', 'dewi@sususegar.com'),
('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'UD Bahan Kue Jaya', 'Ahmad Rizal', '084333444555', 'ahmad@bahankuejaya.com');

-- Sample ingredients
INSERT INTO ingredients (id, outlet_id, supplier_id, name, unit, current_stock, min_stock, max_stock, cost_per_unit) VALUES
('c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'Kopi Arabica', 'gram', 5000, 1000, 10000, 0.80),
('c0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'Kopi Robusta', 'gram', 3000, 800, 8000, 0.50),
('c0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'Susu Full Cream', 'ml', 10000, 3000, 20000, 0.025),
('c0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003', 'Gula Pasir', 'gram', 8000, 2000, 15000, 0.015),
('c0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003', 'Cokelat Bubuk', 'gram', 2000, 500, 5000, 0.12),
('c0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003', 'Matcha Powder', 'gram', 500, 200, 2000, 0.50),
('c0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'Whipped Cream', 'ml', 3000, 1000, 5000, 0.05),
('c0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003', 'Sirup Vanilla', 'ml', 2000, 500, 5000, 0.08),
('c0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003', 'Sirup Caramel', 'ml', 1500, 500, 5000, 0.08),
('c0000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003', 'Es Batu', 'gram', 20000, 5000, 50000, 0.003),
('c0000000-0000-0000-0000-000000000011', 'a0000000-0000-0000-0000-000000000001', NULL, 'Cup Hot 8oz', 'pcs', 500, 100, 1000, 1.50),
('c0000000-0000-0000-0000-000000000012', 'a0000000-0000-0000-0000-000000000001', NULL, 'Cup Iced 16oz', 'pcs', 400, 100, 1000, 2.00),
('c0000000-0000-0000-0000-000000000013', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003', 'Teh Hitam', 'gram', 1500, 500, 3000, 0.10),
('c0000000-0000-0000-0000-000000000014', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003', 'Teh Hijau', 'gram', 1000, 300, 2000, 0.15);

-- Sample products with categories
-- Kopi category
INSERT INTO products (id, outlet_id, category_id, name, selling_price, cost_price) VALUES
('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Kopi' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Americano Hot', 18000, 5000),
('d0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Kopi' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Americano Iced', 20000, 5500),
('d0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Kopi' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Cafe Latte Hot', 25000, 8000),
('d0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Kopi' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Cafe Latte Iced', 27000, 8500),
('d0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Kopi' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Cappuccino', 25000, 8000),
('d0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Kopi' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Mocha Latte', 28000, 10000),
('d0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Kopi' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Caramel Macchiato', 30000, 11000),
('d0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Kopi' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Espresso Single', 15000, 4000),
('d0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Kopi' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Espresso Double', 20000, 6000),
('d0000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Kopi' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'V60 Single Origin', 35000, 12000);

-- Non-Kopi category
INSERT INTO products (id, outlet_id, category_id, name, selling_price, cost_price) VALUES
('d0000000-0000-0000-0000-000000000011', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Non-Kopi' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Matcha Latte', 28000, 12000),
('d0000000-0000-0000-0000-000000000012', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Non-Kopi' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Cokelat Hot', 22000, 8000),
('d0000000-0000-0000-0000-000000000013', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Non-Kopi' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Cokelat Iced', 24000, 8500);

-- Teh category
INSERT INTO products (id, outlet_id, category_id, name, selling_price, cost_price) VALUES
('d0000000-0000-0000-0000-000000000014', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Teh' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Teh Tarik', 18000, 5000),
('d0000000-0000-0000-0000-000000000015', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Teh' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Lemon Tea', 16000, 4500),
('d0000000-0000-0000-0000-000000000016', 'a0000000-0000-0000-0000-000000000001', (SELECT id FROM categories WHERE name = 'Teh' AND outlet_id = 'a0000000-0000-0000-0000-000000000001'), 'Green Tea Latte', 25000, 9000);

-- Sample recipes (link products to ingredients)
INSERT INTO recipes (product_id, ingredient_id, quantity, unit) VALUES
-- Americano Hot
('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 18, 'gram'),
('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000011', 1, 'pcs'),
-- Americano Iced
('d0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 18, 'gram'),
('d0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000010', 150, 'gram'),
('d0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000012', 1, 'pcs'),
-- Cafe Latte Hot
('d0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', 18, 'gram'),
('d0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000003', 200, 'ml'),
('d0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000011', 1, 'pcs'),
-- Cafe Latte Iced
('d0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 18, 'gram'),
('d0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000003', 200, 'ml'),
('d0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000010', 150, 'gram'),
('d0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000012', 1, 'pcs'),
-- Cappuccino
('d0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000001', 18, 'gram'),
('d0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000003', 180, 'ml'),
('d0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000011', 1, 'pcs'),
-- Mocha Latte
('d0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000001', 18, 'gram'),
('d0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000003', 180, 'ml'),
('d0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000005', 20, 'gram'),
('d0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000011', 1, 'pcs'),
-- Caramel Macchiato
('d0000000-0000-0000-0000-000000000007', 'c0000000-0000-0000-0000-000000000001', 18, 'gram'),
('d0000000-0000-0000-0000-000000000007', 'c0000000-0000-0000-0000-000000000003', 200, 'ml'),
('d0000000-0000-0000-0000-000000000007', 'c0000000-0000-0000-0000-000000000009', 30, 'ml'),
('d0000000-0000-0000-0000-000000000007', 'c0000000-0000-0000-0000-000000000012', 1, 'pcs'),
-- Matcha Latte
('d0000000-0000-0000-0000-000000000011', 'c0000000-0000-0000-0000-000000000006', 10, 'gram'),
('d0000000-0000-0000-0000-000000000011', 'c0000000-0000-0000-0000-000000000003', 250, 'ml'),
('d0000000-0000-0000-0000-000000000011', 'c0000000-0000-0000-0000-000000000004', 15, 'gram'),
('d0000000-0000-0000-0000-000000000011', 'c0000000-0000-0000-0000-000000000012', 1, 'pcs'),
-- Cokelat Hot
('d0000000-0000-0000-0000-000000000012', 'c0000000-0000-0000-0000-000000000005', 25, 'gram'),
('d0000000-0000-0000-0000-000000000012', 'c0000000-0000-0000-0000-000000000003', 250, 'ml'),
('d0000000-0000-0000-0000-000000000012', 'c0000000-0000-0000-0000-000000000004', 20, 'gram'),
('d0000000-0000-0000-0000-000000000012', 'c0000000-0000-0000-0000-000000000011', 1, 'pcs'),
-- Teh Tarik
('d0000000-0000-0000-0000-000000000014', 'c0000000-0000-0000-0000-000000000013', 5, 'gram'),
('d0000000-0000-0000-0000-000000000014', 'c0000000-0000-0000-0000-000000000003', 200, 'ml'),
('d0000000-0000-0000-0000-000000000014', 'c0000000-0000-0000-0000-000000000004', 25, 'gram'),
('d0000000-0000-0000-0000-000000000014', 'c0000000-0000-0000-0000-000000000011', 1, 'pcs'),
-- Green Tea Latte
('d0000000-0000-0000-0000-000000000016', 'c0000000-0000-0000-0000-000000000014', 8, 'gram'),
('d0000000-0000-0000-0000-000000000016', 'c0000000-0000-0000-0000-000000000003', 250, 'ml'),
('d0000000-0000-0000-0000-000000000016', 'c0000000-0000-0000-0000-000000000004', 15, 'gram'),
('d0000000-0000-0000-0000-000000000016', 'c0000000-0000-0000-0000-000000000012', 1, 'pcs');

-- Sample modifier groups
INSERT INTO modifier_groups (id, outlet_id, name, is_required, min_selections, max_selections) VALUES
('e0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Ukuran', true, 1, 1),
('e0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'Suhu', true, 1, 1),
('e0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'Extra Topping', false, 0, 3),
('e0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'Tingkat Gula', true, 1, 1);

-- Modifier options
INSERT INTO modifier_options (modifier_group_id, name, price_adjustment, is_default, sort_order) VALUES
-- Ukuran
('e0000000-0000-0000-0000-000000000001', 'Regular', 0, true, 1),
('e0000000-0000-0000-0000-000000000001', 'Large', 5000, false, 2),
-- Suhu
('e0000000-0000-0000-0000-000000000002', 'Hot', 0, true, 1),
('e0000000-0000-0000-0000-000000000002', 'Iced', 0, false, 2),
-- Extra Topping
('e0000000-0000-0000-0000-000000000003', 'Extra Shot', 5000, false, 1),
('e0000000-0000-0000-0000-000000000003', 'Whipped Cream', 3000, false, 2),
('e0000000-0000-0000-0000-000000000003', 'Vanilla Syrup', 3000, false, 3),
('e0000000-0000-0000-0000-000000000003', 'Caramel Drizzle', 3000, false, 4),
-- Tingkat Gula
('e0000000-0000-0000-0000-000000000004', 'Normal', 0, true, 1),
('e0000000-0000-0000-0000-000000000004', 'Less Sugar', 0, false, 2),
('e0000000-0000-0000-0000-000000000004', 'No Sugar', 0, false, 3),
('e0000000-0000-0000-0000-000000000004', 'Extra Sweet', 0, false, 4);

-- Sample taxes
INSERT INTO taxes (outlet_id, name, type, rate, is_inclusive) VALUES
('a0000000-0000-0000-0000-000000000001', 'PPN 11%', 'tax', 11.00, false),
('a0000000-0000-0000-0000-000000000001', 'Service Charge 5%', 'service_charge', 5.00, false);

-- Sample tables
INSERT INTO tables (outlet_id, table_number, name, capacity, section) VALUES
('a0000000-0000-0000-0000-000000000001', 'T01', 'Meja 1', 2, 'Indoor'),
('a0000000-0000-0000-0000-000000000001', 'T02', 'Meja 2', 2, 'Indoor'),
('a0000000-0000-0000-0000-000000000001', 'T03', 'Meja 3', 4, 'Indoor'),
('a0000000-0000-0000-0000-000000000001', 'T04', 'Meja 4', 4, 'Indoor'),
('a0000000-0000-0000-0000-000000000001', 'T05', 'Meja 5', 6, 'Indoor'),
('a0000000-0000-0000-0000-000000000001', 'T06', 'Meja 6', 2, 'Outdoor'),
('a0000000-0000-0000-0000-000000000001', 'T07', 'Meja 7', 4, 'Outdoor'),
('a0000000-0000-0000-0000-000000000001', 'T08', 'Meja 8', 4, 'Outdoor'),
('a0000000-0000-0000-0000-000000000001', 'T09', 'Meja 9', 6, 'VIP'),
('a0000000-0000-0000-0000-000000000001', 'T10', 'Meja 10', 8, 'VIP');

-- Sample discount
INSERT INTO discounts (outlet_id, name, type, value, min_purchase, is_active) VALUES
('a0000000-0000-0000-0000-000000000001', 'Grand Opening 10%', 'percentage', 10, 50000, true),
('a0000000-0000-0000-0000-000000000001', 'Member Discount', 'percentage', 5, 0, true),
('a0000000-0000-0000-0000-000000000001', 'Diskon Rp 10.000', 'fixed_amount', 10000, 100000, true);

-- Sample loyalty program
INSERT INTO loyalty_programs (outlet_id, name, points_per_amount, reward_threshold, reward_type, reward_value) VALUES
('a0000000-0000-0000-0000-000000000001', 'Utter Points', 10000, 100, 'discount', 15000);
