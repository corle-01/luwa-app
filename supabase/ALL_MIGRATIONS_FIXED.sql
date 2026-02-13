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
-- ============================================================
-- UTTER APP - Database Migration 005: Staff RPC Functions
-- ============================================================
-- Run this AFTER 004_seed_data.sql
-- RPC functions to manage staff profiles without auth.users FK
-- + Seed default kasir for testing
-- ============================================================

-- ============================================================
-- 1. RPC: Create Staff Profile (bypass auth.users FK)
-- ============================================================
CREATE OR REPLACE FUNCTION create_staff_profile(
  p_outlet_id UUID,
  p_full_name TEXT,
  p_role TEXT DEFAULT 'cashier',
  p_pin TEXT DEFAULT NULL,
  p_email TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id UUID := gen_random_uuid();
BEGIN
  -- Drop FK constraint to auth.users, insert, then re-add as NOT VALID
  ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

  INSERT INTO profiles (id, outlet_id, full_name, role, pin, email, phone, is_active)
  VALUES (v_id, p_outlet_id, p_full_name, p_role, p_pin, p_email, p_phone, true);

  ALTER TABLE profiles ADD CONSTRAINT profiles_id_fkey
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE NOT VALID;

  RETURN v_id;
END;
$$;

-- ============================================================
-- 2. RPC: Update Staff Profile
-- ============================================================
CREATE OR REPLACE FUNCTION update_staff_profile(
  p_id UUID,
  p_full_name TEXT DEFAULT NULL,
  p_role TEXT DEFAULT NULL,
  p_pin TEXT DEFAULT NULL,
  p_email TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles
  SET
    full_name = COALESCE(p_full_name, full_name),
    role = COALESCE(p_role, role),
    pin = COALESCE(p_pin, pin),
    email = COALESCE(p_email, email),
    phone = COALESCE(p_phone, phone),
    updated_at = now()
  WHERE id = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Staff profile not found: %', p_id;
  END IF;
END;
$$;

-- ============================================================
-- 3. RPC: Delete Staff Profile
-- ============================================================
CREATE OR REPLACE FUNCTION delete_staff_profile(p_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Soft delete — set is_active = false
  UPDATE profiles
  SET is_active = false, updated_at = now()
  WHERE id = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Staff profile not found: %', p_id;
  END IF;
END;
$$;

-- ============================================================
-- 4. Seed Default Kasir
-- ============================================================
-- Use the RPC to insert staff without auth.users dependency
SELECT create_staff_profile(
  'a0000000-0000-0000-0000-000000000001'::UUID,
  'Kasir 1',
  'cashier',
  '1234',
  'kasir1@uttercoffee.com',
  '081000000001'
);

SELECT create_staff_profile(
  'a0000000-0000-0000-0000-000000000001'::UUID,
  'Admin Toko',
  'admin',
  NULL,
  'admin@uttercoffee.com',
  '081000000002'
);

-- ============================================================
-- 5. RLS Policies for Anon Access (dev/web without Supabase Auth)
-- ============================================================
-- The app runs without Supabase Auth login, so auth.uid() is NULL.
-- Existing policies use get_user_outlet_id() which requires auth.uid().
-- Add permissive anon policies for POS-critical tables.

DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'profiles', 'shifts', 'orders', 'order_items', 'products',
    'categories', 'taxes', 'discounts', 'modifier_groups',
    'modifier_options', 'product_modifier_groups', 'customers',
    'tables', 'outlets'
  ] LOOP
    EXECUTE format('CREATE POLICY "Allow anon read %1$s" ON %1$I FOR SELECT TO anon USING (true)', tbl);
    EXECUTE format('CREATE POLICY "Allow anon insert %1$s" ON %1$I FOR INSERT TO anon WITH CHECK (true)', tbl);
    EXECUTE format('CREATE POLICY "Allow anon update %1$s" ON %1$I FOR UPDATE TO anon USING (true)', tbl);
  END LOOP;
END $$;
-- ============================================================
-- UTTER APP - Database Migration 006: Inventory Tables
-- ============================================================
-- Run this AFTER 005_staff_rpc.sql
-- Adds ingredients and stock_movements tables for inventory management
-- ============================================================

-- ============================================================
-- 1. Ingredients Table
-- ============================================================
CREATE TABLE IF NOT EXISTS ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  name TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT 'pcs',
  current_stock NUMERIC NOT NULL DEFAULT 0,
  min_stock NUMERIC NOT NULL DEFAULT 0,
  cost_per_unit NUMERIC NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 2. Stock Movements Table
-- ============================================================
CREATE TABLE IF NOT EXISTS stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  movement_type TEXT NOT NULL DEFAULT 'purchase',
  quantity NUMERIC NOT NULL,
  notes TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 3. RLS
-- ============================================================
ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;

-- Anon policies
CREATE POLICY "Allow anon read ingredients" ON ingredients FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon insert ingredients" ON ingredients FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon update ingredients" ON ingredients FOR UPDATE TO anon USING (true);

CREATE POLICY "Allow anon read stock_movements" ON stock_movements FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon insert stock_movements" ON stock_movements FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon update stock_movements" ON stock_movements FOR UPDATE TO anon USING (true);

-- ============================================================
-- 4. Seed Sample Ingredients
-- ============================================================
INSERT INTO ingredients (outlet_id, name, unit, current_stock, min_stock, cost_per_unit) VALUES
('a0000000-0000-0000-0000-000000000001', 'Biji Kopi Arabica', 'kg', 15.5, 5, 120000),
('a0000000-0000-0000-0000-000000000001', 'Susu Full Cream', 'liter', 20, 10, 18000),
('a0000000-0000-0000-0000-000000000001', 'Gula Pasir', 'kg', 8, 3, 15000),
('a0000000-0000-0000-0000-000000000001', 'Sirup Vanilla', 'botol', 4, 2, 85000),
('a0000000-0000-0000-0000-000000000001', 'Whipped Cream', 'kaleng', 6, 3, 45000),
('a0000000-0000-0000-0000-000000000001', 'Cokelat Bubuk', 'kg', 3, 2, 95000),
('a0000000-0000-0000-0000-000000000001', 'Cup Plastik 16oz', 'pcs', 150, 50, 800),
('a0000000-0000-0000-0000-000000000001', 'Sedotan', 'pcs', 200, 100, 200);
-- ============================================================
-- UTTER APP - Database Migration 007: AI Chat via DeepSeek RPC
-- ============================================================
-- Run this AFTER 006_inventory_tables.sql
-- Enables http extension and creates ai_chat RPC function
-- that proxies requests to DeepSeek API server-side
-- ============================================================

-- ============================================================
-- 1. Enable HTTP Extension
-- ============================================================
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

-- ============================================================
-- 2. AI Chat RPC Function
-- ============================================================
CREATE OR REPLACE FUNCTION ai_chat(
  p_message TEXT,
  p_history JSONB DEFAULT '[]',
  p_context JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET statement_timeout = '60s'
AS $$
DECLARE
  v_system_prompt TEXT;
  v_messages JSONB;
  v_request_body TEXT;
  v_response extensions.http_response;
  v_response_body JSONB;
  v_reply TEXT;
BEGIN
  v_system_prompt := 'Kamu adalah Utter, AI co-pilot untuk bisnis F&B (kafe/restoran). ' ||
    'Kamu membantu pemilik bisnis dengan analisa penjualan, manajemen stok, dan saran bisnis. ' ||
    'Selalu jawab dalam Bahasa Indonesia yang natural dan ramah. ' ||
    'Jika ada data konteks, gunakan untuk menjawab. Konteks: ' || COALESCE(p_context::TEXT, '{}');

  v_messages := jsonb_build_array(
    jsonb_build_object('role', 'system', 'content', v_system_prompt)
  ) || COALESCE(p_history, '[]'::JSONB) || jsonb_build_array(
    jsonb_build_object('role', 'user', 'content', p_message)
  );

  v_request_body := jsonb_build_object(
    'model', 'deepseek-chat',
    'messages', v_messages,
    'max_tokens', 1024,
    'temperature', 0.7
  )::TEXT;

  SELECT * INTO v_response FROM extensions.http(
    (
      'POST',
      'https://api.deepseek.com/chat/completions',
      ARRAY[
        extensions.http_header('Authorization', 'Bearer ' || current_setting('app.deepseek_api_key', true)),
        extensions.http_header('Content-Type', 'application/json')
      ],
      'application/json',
      v_request_body
    )::extensions.http_request
  );

  IF v_response.status != 200 THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, terjadi kesalahan saat menghubungi AI (HTTP ' || v_response.status || '). Silakan coba lagi.',
      'error', TRUE
    );
  END IF;

  v_response_body := v_response.content::JSONB;
  v_reply := v_response_body->'choices'->0->'message'->>'content';

  RETURN jsonb_build_object(
    'reply', COALESCE(v_reply, 'Maaf, saya tidak bisa memproses permintaan ini.'),
    'actions', '[]'::JSONB,
    'tokens_used', (v_response_body->'usage'->>'total_tokens')::INT,
    'model', v_response_body->>'model'
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'reply', 'Maaf, terjadi kesalahan: ' || SQLERRM,
    'error', TRUE
  );
END;
$$;

-- ============================================================
-- 3. Fix AI Tables for Anon Access
-- ============================================================
-- Make user_id nullable (app runs without Supabase Auth)
ALTER TABLE ai_conversations ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE ai_conversations DROP CONSTRAINT IF EXISTS ai_conversations_user_id_fkey;

-- Add RLS policies for AI tables
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'ai_conversations', 'ai_messages', 'ai_action_logs',
    'ai_insights', 'ai_trust_settings'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "Allow anon read %1$s" ON %1$I', tbl);
    EXECUTE format('CREATE POLICY "Allow anon read %1$s" ON %1$I FOR SELECT TO anon USING (true)', tbl);
    EXECUTE format('DROP POLICY IF EXISTS "Allow anon insert %1$s" ON %1$I', tbl);
    EXECUTE format('CREATE POLICY "Allow anon insert %1$s" ON %1$I FOR INSERT TO anon WITH CHECK (true)', tbl);
    EXECUTE format('DROP POLICY IF EXISTS "Allow anon update %1$s" ON %1$I', tbl);
    EXECUTE format('CREATE POLICY "Allow anon update %1$s" ON %1$I FOR UPDATE TO anon USING (true)', tbl);
  END LOOP;
END $$;
-- ============================================================
-- Migration 008: Refund & Void Support
-- Adds columns for refund/void tracking and a trigger to
-- restore stock when an order transitions from 'completed'
-- to 'voided' or 'refunded'.
-- ============================================================

-- 1. Add refund/void metadata columns to orders
ALTER TABLE orders ADD COLUMN IF NOT EXISTS refund_amount DECIMAL(12,2) DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS refund_reason TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS voided_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS voided_by TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS void_reason TEXT;

-- 2. Function: restore stock + release table when order is voided/refunded
CREATE OR REPLACE FUNCTION restore_stock_on_void()
RETURNS trigger AS $$
BEGIN
  IF (NEW.status IN ('voided', 'refunded') AND OLD.status = 'completed') THEN
    -- Restore product quantities from order_items
    UPDATE products p
    SET quantity = p.quantity + oi.quantity
    FROM order_items oi
    WHERE oi.order_id = NEW.id AND oi.product_id = p.id;

    -- Release table if it was dine_in
    IF NEW.table_id IS NOT NULL THEN
      UPDATE tables SET status = 'available' WHERE id = NEW.table_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Trigger: fires AFTER UPDATE only when status transitions to voided/refunded
DROP TRIGGER IF EXISTS restore_stock_on_void_trigger ON orders;
CREATE TRIGGER restore_stock_on_void_trigger
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.status IN ('voided', 'refunded') AND OLD.status = 'completed')
  EXECUTE FUNCTION restore_stock_on_void();
-- ============================================================
-- UTTER APP - Database Migration 009: Suppliers & Purchase Orders
-- ============================================================
-- Run this AFTER 008_refund_void.sql
-- Adds suppliers, purchase_orders, and purchase_order_items tables
-- ============================================================

-- ============================================================
-- 1. Suppliers Table
-- ============================================================
CREATE TABLE IF NOT EXISTS suppliers (
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
-- 2. Purchase Orders Table
-- ============================================================
CREATE TABLE IF NOT EXISTS purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  po_number TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft', -- draft, ordered, partial, received, cancelled
  order_date TIMESTAMPTZ DEFAULT now(),
  expected_date TIMESTAMPTZ,
  received_date TIMESTAMPTZ,
  total_amount DECIMAL(12,2) DEFAULT 0,
  notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 3. Purchase Order Items Table
-- ============================================================
CREATE TABLE IF NOT EXISTS purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  ingredient_name TEXT NOT NULL,
  quantity DECIMAL(12,3) NOT NULL,
  unit TEXT NOT NULL,
  unit_cost DECIMAL(12,2) DEFAULT 0,
  total_cost DECIMAL(12,2) DEFAULT 0,
  received_quantity DECIMAL(12,3) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 4. Generate PO Number Function
-- ============================================================
CREATE OR REPLACE FUNCTION generate_po_number(p_outlet_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_count INT;
BEGIN
  SELECT COUNT(*) + 1 INTO v_count FROM purchase_orders WHERE outlet_id = p_outlet_id;
  RETURN 'PO-' || LPAD(v_count::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 5. RLS Policies
-- ============================================================
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;

-- Suppliers RLS
CREATE POLICY "anon_select_suppliers" ON suppliers FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_suppliers" ON suppliers FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_suppliers" ON suppliers FOR UPDATE TO anon USING (true);
CREATE POLICY "anon_delete_suppliers" ON suppliers FOR DELETE TO anon USING (true);

-- Purchase Orders RLS
CREATE POLICY "anon_select_po" ON purchase_orders FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_po" ON purchase_orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_po" ON purchase_orders FOR UPDATE TO anon USING (true);
CREATE POLICY "anon_delete_po" ON purchase_orders FOR DELETE TO anon USING (true);

-- Purchase Order Items RLS
CREATE POLICY "anon_select_po_items" ON purchase_order_items FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_po_items" ON purchase_order_items FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_po_items" ON purchase_order_items FOR UPDATE TO anon USING (true);
CREATE POLICY "anon_delete_po_items" ON purchase_order_items FOR DELETE TO anon USING (true);

-- ============================================================
-- 6. Seed Sample Supplier
-- ============================================================
INSERT INTO suppliers (outlet_id, name, contact_person, phone, email, address)
VALUES ('a0000000-0000-0000-0000-000000000001', 'PT Bahan Baku Utama', 'Budi Santoso', '081234567890', 'budi@bahanbaku.com', 'Jl. Industri No. 10, Malang');
-- ============================================================
-- Migration 010: Loyalty Program
-- Adds loyalty_programs columns and loyalty_transactions table
-- ============================================================

-- Add missing columns to loyalty_programs (table may already exist from schema)
ALTER TABLE loyalty_programs ADD COLUMN IF NOT EXISTS amount_per_point DECIMAL(12,2) DEFAULT 10000;
ALTER TABLE loyalty_programs ADD COLUMN IF NOT EXISTS min_redeem_points INT DEFAULT 10;
ALTER TABLE loyalty_programs ADD COLUMN IF NOT EXISTS redeem_value DECIMAL(12,2) DEFAULT 10000;

-- Loyalty transactions table (earn/redeem history)
CREATE TABLE IF NOT EXISTS loyalty_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  program_id UUID REFERENCES loyalty_programs(id),
  order_id UUID REFERENCES orders(id),
  type TEXT NOT NULL, -- 'earn' or 'redeem'
  points INT NOT NULL,
  amount DECIMAL(12,2) DEFAULT 0, -- related transaction amount
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE loyalty_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_transactions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_loyalty_programs') THEN
    CREATE POLICY anon_select_loyalty_programs ON loyalty_programs FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_loyalty_programs') THEN
    CREATE POLICY anon_insert_loyalty_programs ON loyalty_programs FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_loyalty_programs') THEN
    CREATE POLICY anon_update_loyalty_programs ON loyalty_programs FOR UPDATE TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_delete_loyalty_programs') THEN
    CREATE POLICY anon_delete_loyalty_programs ON loyalty_programs FOR DELETE TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_loyalty_tx') THEN
    CREATE POLICY anon_select_loyalty_tx ON loyalty_transactions FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_loyalty_tx') THEN
    CREATE POLICY anon_insert_loyalty_tx ON loyalty_transactions FOR INSERT TO anon WITH CHECK (true);
  END IF;
END $$;

-- Seed default loyalty program
INSERT INTO loyalty_programs (outlet_id, name, description, points_per_amount, amount_per_point, min_redeem_points, redeem_value)
SELECT 'a0000000-0000-0000-0000-000000000001', 'Program Loyalitas Utter', 'Setiap pembelian Rp 10.000 mendapat 1 poin', 1, 10000, 10, 10000
WHERE NOT EXISTS (SELECT 1 FROM loyalty_programs WHERE outlet_id = 'a0000000-0000-0000-0000-000000000001' AND name = 'Program Loyalitas Utter');
-- ============================================================
-- Migration 011: Kitchen Display System (KDS)
-- Adds kitchen_status tracking to order_items and orders
-- Trigger auto-updates order kitchen_status based on item statuses
-- ============================================================

-- Add kitchen_status columns to order_items
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS kitchen_status TEXT DEFAULT 'pending';
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS kitchen_started_at TIMESTAMPTZ;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS kitchen_completed_at TIMESTAMPTZ;

-- Add kitchen_status columns to orders
ALTER TABLE orders ADD COLUMN IF NOT EXISTS kitchen_status TEXT DEFAULT 'waiting';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS kitchen_completed_at TIMESTAMPTZ;

-- Function to auto-update order kitchen_status based on its items
-- When all items are 'ready', order becomes 'ready'
-- When some items are 'cooking' or 'ready', order becomes 'in_progress'
-- Otherwise order stays 'waiting'
CREATE OR REPLACE FUNCTION update_order_kitchen_status()
RETURNS trigger AS $$
DECLARE
  v_total INT;
  v_ready INT;
  v_cooking INT;
BEGIN
  SELECT COUNT(*),
         COUNT(*) FILTER (WHERE kitchen_status = 'ready'),
         COUNT(*) FILTER (WHERE kitchen_status = 'cooking')
  INTO v_total, v_ready, v_cooking
  FROM order_items
  WHERE order_id = NEW.order_id;

  IF v_ready = v_total THEN
    UPDATE orders SET kitchen_status = 'ready', kitchen_completed_at = now(), updated_at = now()
    WHERE id = NEW.order_id;
  ELSIF v_cooking > 0 OR v_ready > 0 THEN
    UPDATE orders SET kitchen_status = 'in_progress', updated_at = now()
    WHERE id = NEW.order_id;
  ELSE
    UPDATE orders SET kitchen_status = 'waiting', updated_at = now()
    WHERE id = NEW.order_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger fires when kitchen_status on any order_item is updated
DROP TRIGGER IF EXISTS update_order_kitchen_status_trigger ON order_items;
CREATE TRIGGER update_order_kitchen_status_trigger
  AFTER UPDATE OF kitchen_status ON order_items
  FOR EACH ROW
  EXECUTE FUNCTION update_order_kitchen_status();
-- ============================================================
-- Migration 012: Self-Order Support
-- Adds source column to orders for tracking order origin
-- ============================================================

-- Add source column to orders (pos, self_order, online, etc.)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'pos';

-- Index for filtering by source
CREATE INDEX IF NOT EXISTS idx_orders_source ON orders(source);
-- ============================================================
-- Migration 013: Online Food Integration
-- Platform configs + online orders tracking
-- ============================================================

-- Platform configurations (GoFood, GrabFood, ShopeeFood, etc.)
CREATE TABLE IF NOT EXISTS platform_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  platform TEXT NOT NULL, -- 'gofood', 'grabfood', 'shopeefood'
  is_enabled BOOLEAN DEFAULT false,
  store_id TEXT, -- Platform-specific store/merchant ID
  api_key TEXT, -- Platform API key (encrypted in production)
  webhook_url TEXT, -- Webhook endpoint for receiving orders
  auto_accept BOOLEAN DEFAULT false, -- Auto-accept incoming orders
  settings JSONB DEFAULT '{}', -- Platform-specific settings
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(outlet_id, platform)
);

-- Online orders from food platforms
CREATE TABLE IF NOT EXISTS online_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  order_id UUID REFERENCES orders(id), -- Link to internal order (after accepted)
  platform TEXT NOT NULL, -- 'gofood', 'grabfood', 'shopeefood'
  platform_order_id TEXT NOT NULL, -- Order ID from the platform
  platform_order_number TEXT, -- Display order number from platform
  status TEXT DEFAULT 'incoming' CHECK (status IN (
    'incoming', 'accepted', 'preparing', 'ready', 'picked_up', 'delivered', 'cancelled', 'rejected'
  )),
  customer_name TEXT,
  customer_phone TEXT,
  customer_address TEXT,
  delivery_fee DECIMAL(12,2) DEFAULT 0,
  platform_fee DECIMAL(12,2) DEFAULT 0,
  subtotal DECIMAL(12,2) DEFAULT 0,
  total DECIMAL(12,2) DEFAULT 0,
  items JSONB NOT NULL DEFAULT '[]', -- Raw items from platform
  driver_name TEXT,
  driver_phone TEXT,
  notes TEXT,
  raw_data JSONB DEFAULT '{}', -- Full raw payload from platform
  accepted_at TIMESTAMPTZ,
  prepared_at TIMESTAMPTZ,
  picked_up_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_online_orders_outlet ON online_orders(outlet_id);
CREATE INDEX IF NOT EXISTS idx_online_orders_platform ON online_orders(platform);
CREATE INDEX IF NOT EXISTS idx_online_orders_status ON online_orders(status);
CREATE INDEX IF NOT EXISTS idx_online_orders_created ON online_orders(created_at);
CREATE INDEX IF NOT EXISTS idx_platform_configs_outlet ON platform_configs(outlet_id);

-- RLS
ALTER TABLE platform_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE online_orders ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_platform_configs') THEN
    CREATE POLICY anon_select_platform_configs ON platform_configs FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_platform_configs') THEN
    CREATE POLICY anon_insert_platform_configs ON platform_configs FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_platform_configs') THEN
    CREATE POLICY anon_update_platform_configs ON platform_configs FOR UPDATE TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_delete_platform_configs') THEN
    CREATE POLICY anon_delete_platform_configs ON platform_configs FOR DELETE TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_online_orders') THEN
    CREATE POLICY anon_select_online_orders ON online_orders FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_online_orders') THEN
    CREATE POLICY anon_insert_online_orders ON online_orders FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_online_orders') THEN
    CREATE POLICY anon_update_online_orders ON online_orders FOR UPDATE TO anon USING (true);
  END IF;
END $$;

-- Seed default platform configs
INSERT INTO platform_configs (outlet_id, platform, is_enabled, settings)
SELECT 'a0000000-0000-0000-0000-000000000001', 'gofood', false, '{"commission_rate": 20}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM platform_configs WHERE outlet_id = 'a0000000-0000-0000-0000-000000000001' AND platform = 'gofood');

INSERT INTO platform_configs (outlet_id, platform, is_enabled, settings)
SELECT 'a0000000-0000-0000-0000-000000000001', 'grabfood', false, '{"commission_rate": 25}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM platform_configs WHERE outlet_id = 'a0000000-0000-0000-0000-000000000001' AND platform = 'grabfood');

INSERT INTO platform_configs (outlet_id, platform, is_enabled, settings)
SELECT 'a0000000-0000-0000-0000-000000000001', 'shopeefood', false, '{"commission_rate": 15}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM platform_configs WHERE outlet_id = 'a0000000-0000-0000-0000-000000000001' AND platform = 'shopeefood');
-- ============================================================
-- UTTER APP - Database Migration 014: Fix AI Chat Timeout
-- ============================================================
-- Run this AFTER 013_online_food.sql
-- Fixes: "operation timed out after 5002 milliseconds"
-- The http extension defaults to ~5s timeout which is too short
-- for LLM API calls. This sets it to 30 seconds.
-- Also reduces max_tokens from 1024 to 800 for faster responses.
-- ============================================================

-- ============================================================
-- 1. Recreate ai_chat function with timeout fix
-- ============================================================
CREATE OR REPLACE FUNCTION ai_chat(
  p_message TEXT,
  p_history JSONB DEFAULT '[]',
  p_context JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET statement_timeout = '60s'
AS $$
DECLARE
  v_system_prompt TEXT;
  v_messages JSONB;
  v_request_body TEXT;
  v_response extensions.http_response;
  v_response_body JSONB;
  v_reply TEXT;
  v_api_key TEXT;
BEGIN
  -- --------------------------------------------------------
  -- Set HTTP extension timeout to 30 seconds (default is ~5s)
  -- This is critical for LLM API calls which can take 10-25s
  -- --------------------------------------------------------
  PERFORM set_config('http.timeout_milliseconds', '30000', true);

  -- Also try SET LOCAL as a belt-and-suspenders approach
  BEGIN
    SET LOCAL http.timeout_milliseconds = 30000;
  EXCEPTION WHEN OTHERS THEN
    -- SET LOCAL may not work in all contexts; set_config above is the fallback
    NULL;
  END;

  -- --------------------------------------------------------
  -- Validate API key is configured
  -- --------------------------------------------------------
  v_api_key := current_setting('app.deepseek_api_key', true);
  IF v_api_key IS NULL OR v_api_key = '' THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, API key AI belum dikonfigurasi. Hubungi administrator.',
      'error', TRUE
    );
  END IF;

  -- --------------------------------------------------------
  -- Build system prompt with business context
  -- --------------------------------------------------------
  v_system_prompt := 'Kamu adalah Utter, AI co-pilot untuk bisnis F&B (kafe/restoran). ' ||
    'Kamu membantu pemilik bisnis dengan analisa penjualan, manajemen stok, dan saran bisnis. ' ||
    'Selalu jawab dalam Bahasa Indonesia yang natural dan ramah. ' ||
    'Berikan jawaban yang ringkas dan langsung ke poin. ' ||
    'Jika ada data konteks, gunakan untuk menjawab. Konteks: ' || COALESCE(p_context::TEXT, '{}');

  -- --------------------------------------------------------
  -- Build messages array: system + history + user message
  -- --------------------------------------------------------
  v_messages := jsonb_build_array(
    jsonb_build_object('role', 'system', 'content', v_system_prompt)
  ) || COALESCE(p_history, '[]'::JSONB) || jsonb_build_array(
    jsonb_build_object('role', 'user', 'content', p_message)
  );

  -- --------------------------------------------------------
  -- Build request body (reduced max_tokens for faster response)
  -- --------------------------------------------------------
  v_request_body := jsonb_build_object(
    'model', 'deepseek-chat',
    'messages', v_messages,
    'max_tokens', 800,
    'temperature', 0.7
  )::TEXT;

  -- --------------------------------------------------------
  -- Make the HTTP call to DeepSeek API
  -- --------------------------------------------------------
  SELECT * INTO v_response FROM extensions.http(
    (
      'POST',
      'https://api.deepseek.com/chat/completions',
      ARRAY[
        extensions.http_header('Authorization', 'Bearer ' || v_api_key),
        extensions.http_header('Content-Type', 'application/json')
      ],
      'application/json',
      v_request_body
    )::extensions.http_request
  );

  -- --------------------------------------------------------
  -- Handle non-200 responses
  -- --------------------------------------------------------
  IF v_response.status IS NULL THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, tidak bisa terhubung ke server AI. Periksa koneksi internet dan coba lagi.',
      'error', TRUE
    );
  END IF;

  IF v_response.status != 200 THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, terjadi kesalahan saat menghubungi AI (HTTP ' || v_response.status || '). Silakan coba lagi.',
      'error', TRUE,
      'status_code', v_response.status
    );
  END IF;

  -- --------------------------------------------------------
  -- Parse successful response
  -- --------------------------------------------------------
  BEGIN
    v_response_body := v_response.content::JSONB;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, respons dari AI tidak valid. Silakan coba lagi.',
      'error', TRUE
    );
  END;

  v_reply := v_response_body->'choices'->0->'message'->>'content';

  RETURN jsonb_build_object(
    'reply', COALESCE(v_reply, 'Maaf, saya tidak bisa memproses permintaan ini.'),
    'actions', '[]'::JSONB,
    'tokens_used', (v_response_body->'usage'->>'total_tokens')::INT,
    'model', v_response_body->>'model'
  );

-- --------------------------------------------------------
-- Global exception handler
-- --------------------------------------------------------
EXCEPTION
  WHEN query_canceled THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, permintaan AI memakan waktu terlalu lama. Coba pertanyaan yang lebih singkat.',
      'error', TRUE
    );
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, terjadi kesalahan: ' || SQLERRM,
      'error', TRUE
    );
END;
$$;
-- ============================================================
-- UTTER APP - Database Migration 015: Fix AI API Key
-- ============================================================
-- Run this AFTER 014_fix_ai_timeout.sql
-- Fixes: "API key belum dikonfigurasi" error
-- ALTER DATABASE SET is blocked by Supabase permissions,
-- so we hardcode the key directly in the function.
-- ============================================================

CREATE OR REPLACE FUNCTION ai_chat(
  p_message TEXT,
  p_history JSONB DEFAULT '[]',
  p_context JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET statement_timeout = '60s'
AS $$
DECLARE
  v_system_prompt TEXT;
  v_messages JSONB;
  v_request_body TEXT;
  v_response extensions.http_response;
  v_response_body JSONB;
  v_reply TEXT;
  v_api_key TEXT;
BEGIN
  -- Set HTTP extension timeout to 30 seconds
  PERFORM set_config('http.timeout_milliseconds', '30000', true);

  BEGIN
    SET LOCAL http.timeout_milliseconds = 30000;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- API key from vault/config (DO NOT hardcode)
  -- Note: This RPC is deprecated; AI calls now go directly from Flutter client
  v_api_key := current_setting('app.deepseek_api_key', true);

  -- Build system prompt with business context
  v_system_prompt := 'Kamu adalah Utter, AI co-pilot untuk bisnis F&B (kafe/restoran). ' ||
    'Kamu membantu pemilik bisnis dengan analisa penjualan, manajemen stok, dan saran bisnis. ' ||
    'Selalu jawab dalam Bahasa Indonesia yang natural dan ramah. ' ||
    'Berikan jawaban yang ringkas dan langsung ke poin. ' ||
    'Jika ada data konteks, gunakan untuk menjawab. Konteks: ' || COALESCE(p_context::TEXT, '{}');

  -- Build messages array: system + history + user message
  v_messages := jsonb_build_array(
    jsonb_build_object('role', 'system', 'content', v_system_prompt)
  ) || COALESCE(p_history, '[]'::JSONB) || jsonb_build_array(
    jsonb_build_object('role', 'user', 'content', p_message)
  );

  -- Build request body
  v_request_body := jsonb_build_object(
    'model', 'deepseek-chat',
    'messages', v_messages,
    'max_tokens', 800,
    'temperature', 0.7
  )::TEXT;

  -- Make HTTP call to DeepSeek API
  SELECT * INTO v_response FROM extensions.http(
    (
      'POST',
      'https://api.deepseek.com/chat/completions',
      ARRAY[
        extensions.http_header('Authorization', 'Bearer ' || v_api_key),
        extensions.http_header('Content-Type', 'application/json')
      ],
      'application/json',
      v_request_body
    )::extensions.http_request
  );

  -- Handle connection failure
  IF v_response.status IS NULL THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, tidak bisa terhubung ke server AI. Periksa koneksi internet dan coba lagi.',
      'error', TRUE
    );
  END IF;

  -- Handle non-200 responses
  IF v_response.status != 200 THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, terjadi kesalahan saat menghubungi AI (HTTP ' || v_response.status || '). Silakan coba lagi.',
      'error', TRUE,
      'status_code', v_response.status
    );
  END IF;

  -- Parse successful response
  BEGIN
    v_response_body := v_response.content::JSONB;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, respons dari AI tidak valid. Silakan coba lagi.',
      'error', TRUE
    );
  END;

  v_reply := v_response_body->'choices'->0->'message'->>'content';

  RETURN jsonb_build_object(
    'reply', COALESCE(v_reply, 'Maaf, saya tidak bisa memproses permintaan ini.'),
    'actions', '[]'::JSONB,
    'tokens_used', (v_response_body->'usage'->>'total_tokens')::INT,
    'model', v_response_body->>'model'
  );

EXCEPTION
  WHEN query_canceled THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, permintaan AI memakan waktu terlalu lama. Coba pertanyaan yang lebih singkat.',
      'error', TRUE
    );
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, terjadi kesalahan: ' || SQLERRM,
      'error', TRUE
    );
END;
$$;
-- ============================================================
-- Migration 016: Fix AI timeout + enrich context query
-- ============================================================

CREATE OR REPLACE FUNCTION ai_chat(
  p_message TEXT,
  p_history JSONB DEFAULT '[]',
  p_context JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET statement_timeout = '120s'
AS $$
DECLARE
  v_system_prompt TEXT;
  v_messages JSONB;
  v_request_body TEXT;
  v_response extensions.http_response;
  v_response_body JSONB;
  v_reply TEXT;
  v_api_key TEXT;
BEGIN
  -- Try to set HTTP timeout (may or may not work on Supabase)
  PERFORM set_config('http.timeout_milliseconds', '120000', true);

  -- API key from vault/config (DO NOT hardcode)
  -- Note: This RPC is deprecated; AI calls now go directly from Flutter client
  v_api_key := current_setting('app.deepseek_api_key', true);

  v_system_prompt := 'Kamu adalah Utter, AI co-pilot untuk bisnis F&B (kafe/restoran). ' ||
    'Kamu membantu pemilik bisnis dengan analisa penjualan, manajemen stok, dan saran bisnis. ' ||
    'Selalu jawab dalam Bahasa Indonesia yang natural dan ramah. ' ||
    'Berikan jawaban yang ringkas dan langsung ke poin. ' ||
    'Jika ada data konteks, gunakan untuk menjawab dengan detail. Konteks: ' || COALESCE(p_context::TEXT, '{}');

  v_messages := jsonb_build_array(
    jsonb_build_object('role', 'system', 'content', v_system_prompt)
  ) || COALESCE(p_history, '[]'::JSONB) || jsonb_build_array(
    jsonb_build_object('role', 'user', 'content', p_message)
  );

  v_request_body := jsonb_build_object(
    'model', 'deepseek-chat',
    'messages', v_messages,
    'max_tokens', 1500,
    'temperature', 0.7
  )::TEXT;

  SELECT * INTO v_response FROM extensions.http(
    (
      'POST',
      'https://api.deepseek.com/chat/completions',
      ARRAY[
        extensions.http_header('Authorization', 'Bearer ' || v_api_key),
        extensions.http_header('Content-Type', 'application/json')
      ],
      'application/json',
      v_request_body
    )::extensions.http_request
  );

  IF v_response.status IS NULL THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, tidak bisa terhubung ke server AI. Coba lagi.',
      'error', TRUE
    );
  END IF;

  IF v_response.status != 200 THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, error dari AI server (HTTP ' || v_response.status || '). Coba lagi.',
      'error', TRUE,
      'status_code', v_response.status
    );
  END IF;

  BEGIN
    v_response_body := v_response.content::JSONB;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('reply', 'Respons AI tidak valid.', 'error', TRUE);
  END;

  v_reply := v_response_body->'choices'->0->'message'->>'content';

  RETURN jsonb_build_object(
    'reply', COALESCE(v_reply, 'Tidak ada respons.'),
    'actions', '[]'::JSONB,
    'tokens_used', (v_response_body->'usage'->>'total_tokens')::INT,
    'model', v_response_body->>'model'
  );

EXCEPTION
  WHEN query_canceled THEN
    RETURN jsonb_build_object('reply', 'Timeout. Coba pertanyaan lebih singkat.', 'error', TRUE);
  WHEN OTHERS THEN
    RETURN jsonb_build_object('reply', 'Error: ' || SQLERRM, 'error', TRUE);
END;
$$;
-- ============================================================
-- Migration 017: Online Food POS - Manual Order Input
-- ============================================================

-- Add columns to orders table for online food tracking
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_source TEXT DEFAULT 'dine_in';
-- values: 'dine_in', 'takeaway', 'gofood', 'grabfood', 'shopeefood'

ALTER TABLE orders ADD COLUMN IF NOT EXISTS platform_order_id TEXT;
-- order number from platform, e.g. "F-123456789"

ALTER TABLE orders ADD COLUMN IF NOT EXISTS platform_final_amount DECIMAL(12,2);
-- actual amount received from platform after all deductions

ALTER TABLE orders ADD COLUMN IF NOT EXISTS platform_notes TEXT;
-- optional notes, e.g. driver name
-- ============================================================
-- UTTER APP - Database Migration 018: Product Stock (Stok Produk Jadi)
-- ============================================================
-- Run this AFTER 017_online_food_pos.sql
-- Adds finished goods stock tracking to products table
-- Creates product_stock_movements table for stock history
-- ============================================================

-- ============================================================
-- 1. Add stock columns to products table
-- ============================================================
ALTER TABLE products ADD COLUMN IF NOT EXISTS stock_quantity INT NOT NULL DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS min_stock INT NOT NULL DEFAULT 0;

-- track_stock already exists from 001_core_tables.sql (BOOLEAN DEFAULT true)

-- ============================================================
-- 2. Product Stock Movements Table
-- ============================================================
CREATE TABLE IF NOT EXISTS product_stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  type TEXT NOT NULL CHECK (type IN ('stock_in', 'stock_out', 'adjustment', 'production', 'sale', 'return')),
  quantity INT NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_product_stock_movements_product ON product_stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_product_stock_movements_outlet ON product_stock_movements(outlet_id);
CREATE INDEX IF NOT EXISTS idx_product_stock_movements_created ON product_stock_movements(created_at);

-- ============================================================
-- 3. RLS Policies
-- ============================================================
ALTER TABLE product_stock_movements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon read product_stock_movements" ON product_stock_movements FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon insert product_stock_movements" ON product_stock_movements FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon update product_stock_movements" ON product_stock_movements FOR UPDATE TO anon USING (true);
CREATE POLICY "Allow anon delete product_stock_movements" ON product_stock_movements FOR DELETE TO anon USING (true);
-- ============================================================
-- 018: Split Payment / Partial Payment Support
-- ============================================================
-- Add payment_details JSONB column to store split payment breakdown
-- Format: [{"method": "cash", "amount": 50000}, {"method": "qris", "amount": 30000}]

ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_details JSONB;

-- Update payment_method constraint to include 'split' and 'e_wallet'
-- (drop old constraint first, then re-add with expanded list)
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;
ALTER TABLE orders ADD CONSTRAINT orders_payment_method_check
  CHECK (payment_method IN ('cash', 'card', 'qris', 'ewallet', 'e_wallet', 'bank_transfer', 'split'));
-- ============================================================
-- 020: Product Images - Multi-image support per product
-- ============================================================

-- Create product_images table
CREATE TABLE IF NOT EXISTS product_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast lookup by product
CREATE INDEX IF NOT EXISTS idx_product_images_product_id ON product_images(product_id);
CREATE INDEX IF NOT EXISTS idx_product_images_sort_order ON product_images(product_id, sort_order);

-- RLS policies for anon access (POS web app uses anon key)
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_select_product_images" ON product_images
  FOR SELECT TO anon USING (true);

CREATE POLICY "anon_insert_product_images" ON product_images
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "anon_update_product_images" ON product_images
  FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "anon_delete_product_images" ON product_images
  FOR DELETE TO anon USING (true);

-- Create storage bucket for product images (via SQL)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: allow anon to upload/read/delete from product-images bucket
CREATE POLICY "anon_select_product_images_storage" ON storage.objects
  FOR SELECT TO anon USING (bucket_id = 'product-images');

CREATE POLICY "anon_insert_product_images_storage" ON storage.objects
  FOR INSERT TO anon WITH CHECK (bucket_id = 'product-images');

CREATE POLICY "anon_update_product_images_storage" ON storage.objects
  FOR UPDATE TO anon USING (bucket_id = 'product-images') WITH CHECK (bucket_id = 'product-images');

CREATE POLICY "anon_delete_product_images_storage" ON storage.objects
  FOR DELETE TO anon USING (bucket_id = 'product-images');
-- ============================================================
-- Migration 021: Seed Product-Modifier Group Links
-- ============================================================
-- Links products to modifier groups via the product_modifier_groups
-- junction table. Without these rows, no modifiers appear for any
-- product in either POS or Self-Order.
-- ============================================================

-- All coffee drinks get: Ukuran, Suhu, Extra Topping, Tingkat Gula
-- (Americano Hot, Americano Iced, Cafe Latte Hot, Cafe Latte Iced,
--  Cappuccino, Mocha Latte, Caramel Macchiato, Espresso Single,
--  Espresso Double, V60 Single Origin)
INSERT INTO product_modifier_groups (product_id, modifier_group_id, sort_order) VALUES
-- Americano Hot
('d0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000004', 3),
('d0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000003', 4),
-- Americano Iced
('d0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000004', 3),
('d0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000003', 4),
-- Cafe Latte Hot
('d0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000004', 3),
('d0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000003', 4),
-- Cafe Latte Iced
('d0000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000004', 3),
('d0000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000003', 4),
-- Cappuccino
('d0000000-0000-0000-0000-000000000005', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000005', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000005', 'e0000000-0000-0000-0000-000000000004', 3),
('d0000000-0000-0000-0000-000000000005', 'e0000000-0000-0000-0000-000000000003', 4),
-- Mocha Latte
('d0000000-0000-0000-0000-000000000006', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000006', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000006', 'e0000000-0000-0000-0000-000000000004', 3),
('d0000000-0000-0000-0000-000000000006', 'e0000000-0000-0000-0000-000000000003', 4),
-- Caramel Macchiato
('d0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000004', 3),
('d0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000003', 4),
-- Espresso Single
('d0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000004', 3),
('d0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000003', 4),
-- Espresso Double
('d0000000-0000-0000-0000-000000000009', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000009', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000009', 'e0000000-0000-0000-0000-000000000004', 3),
('d0000000-0000-0000-0000-000000000009', 'e0000000-0000-0000-0000-000000000003', 4),
-- V60 Single Origin
('d0000000-0000-0000-0000-000000000010', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000010', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000010', 'e0000000-0000-0000-0000-000000000004', 3),
('d0000000-0000-0000-0000-000000000010', 'e0000000-0000-0000-0000-000000000003', 4)
ON CONFLICT (product_id, modifier_group_id) DO NOTHING;

-- Non-Kopi drinks get: Ukuran, Suhu, Tingkat Gula, Extra Topping
-- (Matcha Latte, Cokelat Hot, Cokelat Iced)
INSERT INTO product_modifier_groups (product_id, modifier_group_id, sort_order) VALUES
-- Matcha Latte
('d0000000-0000-0000-0000-000000000011', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000011', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000011', 'e0000000-0000-0000-0000-000000000004', 3),
('d0000000-0000-0000-0000-000000000011', 'e0000000-0000-0000-0000-000000000003', 4),
-- Cokelat Hot
('d0000000-0000-0000-0000-000000000012', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000012', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000012', 'e0000000-0000-0000-0000-000000000004', 3),
('d0000000-0000-0000-0000-000000000012', 'e0000000-0000-0000-0000-000000000003', 4),
-- Cokelat Iced
('d0000000-0000-0000-0000-000000000013', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000013', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000013', 'e0000000-0000-0000-0000-000000000004', 3),
('d0000000-0000-0000-0000-000000000013', 'e0000000-0000-0000-0000-000000000003', 4)
ON CONFLICT (product_id, modifier_group_id) DO NOTHING;

-- Tea drinks get: Ukuran, Suhu, Tingkat Gula (no Extra Topping)
-- (Teh Tarik, Lemon Tea, Green Tea Latte)
INSERT INTO product_modifier_groups (product_id, modifier_group_id, sort_order) VALUES
-- Teh Tarik
('d0000000-0000-0000-0000-000000000014', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000014', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000014', 'e0000000-0000-0000-0000-000000000004', 3),
-- Lemon Tea
('d0000000-0000-0000-0000-000000000015', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000015', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000015', 'e0000000-0000-0000-0000-000000000004', 3),
-- Green Tea Latte
('d0000000-0000-0000-0000-000000000016', 'e0000000-0000-0000-0000-000000000001', 1),
('d0000000-0000-0000-0000-000000000016', 'e0000000-0000-0000-0000-000000000002', 2),
('d0000000-0000-0000-0000-000000000016', 'e0000000-0000-0000-0000-000000000004', 3)
ON CONFLICT (product_id, modifier_group_id) DO NOTHING;
-- ============================================================
-- 022: Fix modifier_groups schema - add missing columns + RLS
-- ============================================================

-- Add selection_type column (single/multiple) used by modifier management UI
ALTER TABLE modifier_groups ADD COLUMN IF NOT EXISTS selection_type TEXT DEFAULT 'single';

-- Add sort_order column for ordering modifier groups
ALTER TABLE modifier_groups ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;

-- Add anon DELETE policies for modifier CRUD
DO $$ BEGIN
  CREATE POLICY "Allow anon delete modifier_groups"
    ON modifier_groups FOR DELETE TO anon USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Allow anon delete modifier_options"
    ON modifier_options FOR DELETE TO anon USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Allow anon delete product_modifier_groups"
    ON product_modifier_groups FOR DELETE TO anon USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
-- ============================================================
-- UTTER APP - Database Migration 022: Reset All Dummy Data
-- ============================================================
-- Purpose: Delete all test/dummy data while preserving:
--   - outlets (store configuration)
--   - profiles/staff_profiles (staff accounts)
--   - taxes (tax settings)
--   - discounts (discount settings)
--   - tables (restaurant table layout)
--   - platform_configs (online food platform settings)
--
-- This migration is IDEMPOTENT - safe to run multiple times.
-- Uses DELETE FROM in correct FK dependency order.
-- ============================================================

BEGIN;

-- ============================================================
-- PHASE 1: AI-related data (no critical FK deps to other data)
-- ============================================================

-- AI messages depend on ai_conversations
DELETE FROM ai_messages;

-- AI action logs reference ai_conversations
DELETE FROM ai_action_logs;

-- AI conversations reference profiles (kept) and outlets (kept)
DELETE FROM ai_conversations;

-- AI insights reference outlets (kept)
DELETE FROM ai_insights;

-- AI trust settings reference outlets (kept) - reset to clean slate
DELETE FROM ai_trust_settings;

-- ============================================================
-- PHASE 2: Order-related data (deepest FK dependencies first)
-- ============================================================

-- Loyalty transactions reference customers, orders, loyalty_programs
DELETE FROM loyalty_transactions;

-- Online orders reference orders (the order link)
DELETE FROM online_orders;

-- Order items reference orders and products
DELETE FROM order_items;

-- Orders reference shifts, customers, tables (kept), profiles (kept), outlets (kept), discounts (kept)
DELETE FROM orders;

-- Shifts reference outlets (kept) and profiles (kept) - test shift data
DELETE FROM shifts;

-- ============================================================
-- PHASE 3: Product-related data (must come before products/categories)
-- ============================================================

-- Product stock movements reference products
DELETE FROM product_stock_movements;

-- Product images reference products
DELETE FROM product_images;

-- Product-modifier group links reference products and modifier_groups
DELETE FROM product_modifier_groups;

-- Recipes reference products and ingredients
DELETE FROM recipes;

-- ============================================================
-- PHASE 4: Purchase orders (reference suppliers and ingredients)
-- ============================================================

-- PO items reference purchase_orders and ingredients
DELETE FROM purchase_order_items;

-- Purchase orders reference suppliers and outlets (kept)
DELETE FROM purchase_orders;

-- ============================================================
-- PHASE 5: Stock movements (reference ingredients)
-- ============================================================

-- Stock movements reference ingredients and outlets (kept)
DELETE FROM stock_movements;

-- ============================================================
-- PHASE 6: Core catalog data
-- ============================================================

-- Products reference categories and outlets (kept)
DELETE FROM products;

-- Categories reference outlets (kept)
DELETE FROM categories;

-- Modifier options reference modifier_groups
DELETE FROM modifier_options;

-- Modifier groups reference outlets (kept)
DELETE FROM modifier_groups;

-- Ingredients reference outlets (kept) and suppliers
DELETE FROM ingredients;

-- Suppliers reference outlets (kept)
DELETE FROM suppliers;

-- ============================================================
-- PHASE 7: Customer and loyalty data
-- ============================================================

-- Customers reference outlets (kept)
DELETE FROM customers;

-- Loyalty programs reference outlets (kept)
DELETE FROM loyalty_programs;

-- ============================================================
-- PHASE 8: Reset product stock counters (column on products table)
-- Products are already deleted, but if any remain this ensures clean state
-- ============================================================

-- No-op since products are deleted, but safe to run
UPDATE products SET stock_quantity = 0, min_stock = 0 WHERE true;

COMMIT;

-- ============================================================
-- SUMMARY OF PRESERVED DATA:
--   outlets         - Store configuration intact
--   profiles        - Staff accounts (Kasir 1, Admin Toko) intact
--   taxes           - PPN, service charge settings intact
--   discounts       - Discount rules intact
--   tables          - Restaurant table layout intact
--   platform_configs - GoFood/GrabFood/ShopeeFood settings intact
--
-- SUMMARY OF DELETED DATA:
--   orders, order_items, shifts
--   products, categories, modifier_groups, modifier_options
--   product_modifier_groups, product_images, product_stock_movements
--   recipes, ingredients, stock_movements
--   suppliers, purchase_orders, purchase_order_items
--   customers, loyalty_programs, loyalty_transactions
--   online_orders (but NOT platform_configs)
--   ai_conversations, ai_messages, ai_action_logs, ai_insights, ai_trust_settings
-- ============================================================
-- ============================================================
-- UTTER APP - Migration 023: Featured Categories
-- ============================================================
-- Adds is_featured flag to categories table and seeds
-- three featured categories (Rekomendasi, Promo, Paket)
-- with negative sort_order so they always appear first.
--
-- Sort order convention:
--   Featured: sort_order < 0 (always first)
--   Regular:  sort_order >= 0
--   Query:    ORDER BY is_featured DESC, sort_order ASC, name ASC
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Add is_featured column to categories
-- ============================================================
ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;

-- ============================================================
-- 2. Create unique index on (outlet_id, name) for idempotent inserts
--    This allows ON CONFLICT (outlet_id, name) DO NOTHING
-- ============================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_outlet_name
  ON categories (outlet_id, name);

-- ============================================================
-- 3. RLS - No additional policy needed
--    categories already has anon SELECT/INSERT/UPDATE policies
--    from migration 005_staff_rpc.sql. The new is_featured column
--    is automatically covered by existing row-level policies.
-- ============================================================

-- ============================================================
-- 4. Seed featured categories for outlet a0000000-...-000000000001
--    Using negative sort_order so they always sort before regular
--    categories (which have sort_order >= 0).
--    ON CONFLICT DO NOTHING to be idempotent.
-- ============================================================
INSERT INTO categories (id, outlet_id, name, description, color, icon, sort_order, is_featured, is_active)
VALUES
  (gen_random_uuid(), 'a0000000-0000-0000-0000-000000000001',
   'Rekomendasi', 'Menu rekomendasi pilihan kami', '#10B981', 'star', -3, true, true),
  (gen_random_uuid(), 'a0000000-0000-0000-0000-000000000001',
   'Promo', 'Menu promo spesial', '#EF4444', 'local_offer', -2, true, true),
  (gen_random_uuid(), 'a0000000-0000-0000-0000-000000000001',
   'Paket', 'Paket hemat bundling', '#F59E0B', 'inventory_2', -1, true, true)
ON CONFLICT (outlet_id, name) DO NOTHING;

COMMIT;

-- ============================================================
-- NOTES:
--   - 3 featured categories seeded: Rekomendasi, Promo, Paket
--   - is_featured=true + negative sort_order ensures they appear
--     before regular categories in all UIs
--   - Recommended query sort:
--       ORDER BY is_featured DESC, sort_order ASC, name ASC
--   - Unique index on (outlet_id, name) prevents duplicate
--     category names within the same outlet
-- ============================================================
-- ============================================================
-- UTTER APP - Migration 023: Seed Real Menu Data
-- ============================================================
-- Source: Spreadsheet HPP Minuman, Perhitungan Laba, Bahan
-- Contains:
--   - Suppliers (from Bahan sheet)
--   - Ingredients with cost_per_unit (Minuman + Makanan)
--   - Categories (Coffee, Non-Coffee, Makanan, Snack)
--   - Products with selling_price & cost_price (Minuman only)
--   - Recipes / product-ingredient links (Minuman only)
--   - Modifier groups (Suhu, Gula, Kuah)
--   - Product-modifier group links
--
-- NOTE: Makanan products & recipes intentionally left empty.
--       Owner will add menu makanan manually via Back Office.
-- ============================================================

BEGIN;

-- ============================================================
-- STEP 1: SUPPLIERS
-- ============================================================
INSERT INTO suppliers (id, outlet_id, name, contact_person, phone, notes) VALUES
  ('b1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Superindo', NULL, NULL, 'Belakang Utter'),
  ('b1000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'Shopee', NULL, NULL, 'Online marketplace'),
  ('b1000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'Diva', NULL, '62895334063500', 'wa.me/62895334063500'),
  ('b1000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'Toko Ice', NULL, NULL, 'Beli langsung'),
  ('b1000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'Glory (Mie Ramen)', NULL, '62818532464', 'wa.me/62818532464'),
  ('b1000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', 'NS Chicken', NULL, '6281232663370', 'wa.me/6281232663370'),
  ('b1000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000001', 'Toko Orange', NULL, NULL, 'Dekat Utter'),
  ('b1000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000001', 'Pasar', NULL, NULL, 'Pasar tradisional'),
  ('b1000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', 'Indomaret', NULL, NULL, 'Toko langsung');

-- ============================================================
-- STEP 2: INGREDIENTS (Bahan Baku)
-- ============================================================
-- cost_per_unit = harga per satuan terkecil (per gram / per ml / per pcs)
-- Calculated from: Harga Per Satuan / Berat

-- === BAHAN MINUMAN ===
INSERT INTO ingredients (id, outlet_id, supplier_id, name, unit, cost_per_unit, current_stock, min_stock) VALUES
  -- Kopi: Rp58,000 / 380gr = Rp152.63/gr
  ('c1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Kopi Hitam (Kapal Api)', 'gram', 152.63, 760, 200),
  -- Susu UHT: Rp17,500 / 946ml = Rp18.50/ml
  ('c1000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Susu UHT (Frisian Flag)', 'ml', 18.50, 7568, 2000),
  -- Susu Coconut: Rp17,500 / 946ml = Rp18.50/ml
  ('c1000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Susu Coconut (Frisian Flag)', 'ml', 18.50, 4730, 1000),
  -- Creamer: Rp31,000 / 1000gr = Rp31/gr
  ('c1000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Creamer (Maxi Power)', 'gram', 31.00, 1000, 200),
  -- SKM: Rp25,000 / 1000gr = Rp25/gr
  ('c1000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000003', 'SKM (Milk Brand)', 'gram', 25.00, 5000, 1000),
  -- Gula Aren: Rp15,000 / 250gr = Rp60/gr
  ('c1000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000003', 'Gula Aren', 'gram', 60.00, 250, 100),
  -- Sirup Caramel: Rp60,000 / 750ml = Rp80/ml
  ('c1000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Sirup Caramel (Rasbell)', 'ml', 80.00, 750, 200),
  -- Sirup Hazelnut: Rp60,000 / 750ml = Rp80/ml
  ('c1000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Sirup Hazelnut (Rasbell)', 'ml', 80.00, 750, 200),
  -- Powder Taro: Rp37,500 / 500gr = Rp75/gr
  ('c1000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Powder Taro (Dellyfood)', 'gram', 75.00, 500, 100),
  -- Powder Coklat: Rp37,500 / 500gr = Rp75/gr
  ('c1000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Powder Coklat (Dellyfood)', 'gram', 75.00, 500, 100),
  -- Powder Green Tea: Rp37,500 / 500gr = Rp75/gr
  ('c1000000-0000-0000-0000-000000000011', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Powder Green Tea (Dellyfood)', 'gram', 75.00, 500, 100),
  -- Powder Lyche Tea: Rp37,500 / 500gr = Rp75/gr
  ('c1000000-0000-0000-0000-000000000012', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Powder Lyche Tea (Dellyfood)', 'gram', 75.00, 500, 100),
  -- Powder Red Velvet: Rp37,500 / 500gr = Rp75/gr
  ('c1000000-0000-0000-0000-000000000013', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Powder Red Velvet (Dellyfood)', 'gram', 75.00, 500, 100),
  -- Powder Lemon Tea: Rp37,500 / 500gr = Rp75/gr
  ('c1000000-0000-0000-0000-000000000014', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Powder Lemon Tea (Dellyfood)', 'gram', 75.00, 500, 100),
  -- Powder Bubble Gum: Rp37,500 / 500gr = Rp75/gr
  ('c1000000-0000-0000-0000-000000000015', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Powder Bubble Gum (Dellyfood)', 'gram', 75.00, 500, 100),
  -- Teh: Rp3,250 / 50gr * 10 bungkus, per gram: Rp3,250/50 ≈ Rp65/gr, tapi HPP pakai ~Rp4.06/ml (diseduh)
  ('c1000000-0000-0000-0000-000000000016', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Teh (Bandulan)', 'gram', 65.00, 500, 100),
  -- Ice Tube: Rp12,000 / 10,000gr = Rp1.20/gr
  ('c1000000-0000-0000-0000-000000000017', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000004', 'Ice Tube', 'gram', 1.20, 30000, 5000),
  -- Air Mineral: Rp13,000 / 12 botol = Rp1,083/botol
  ('c1000000-0000-0000-0000-000000000018', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000009', 'Air Mineral (Aquviva)', 'botol', 1083.33, 36, 12),
  -- Thai Tea: Rp58,000 / 400gr = Rp145/gr
  ('c1000000-0000-0000-0000-000000000019', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000003', 'Thai Tea Bubuk (Cha Tra Mue)', 'gram', 145.00, 800, 200),
  -- Sirup Jeruk: Rp13,000 / 450ml = Rp28.89/ml
  ('c1000000-0000-0000-0000-000000000020', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Sirup Jeruk (Marjan)', 'ml', 28.89, 450, 100),
  -- Sirup Mangga: Rp13,000 / 400ml = Rp32.50/ml
  ('c1000000-0000-0000-0000-000000000021', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Sirup Mangga (Marjan)', 'ml', 32.50, 400, 100),
  -- Sprite: Rp6,000 / 250ml = Rp24/ml
  ('c1000000-0000-0000-0000-000000000022', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Sprite', 'ml', 24.00, 750, 250),
  -- Fanta Merah: Rp6,000 / 250ml = Rp24/ml
  ('c1000000-0000-0000-0000-000000000023', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Fanta Merah', 'ml', 24.00, 750, 250),
  -- Fanta Anggur: Rp6,000 / 250ml = Rp24/ml
  ('c1000000-0000-0000-0000-000000000024', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Fanta Anggur', 'ml', 24.00, 750, 250),
  -- Selasih: Rp16,000 / botol (est ~1000gr) = ~Rp1/gr (used in HPP as Rp1/gr)
  ('c1000000-0000-0000-0000-000000000025', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Selasih', 'gram', 1.00, 500, 100),
  -- Air (water for brewing, negligible cost)
  ('c1000000-0000-0000-0000-000000000026', 'a0000000-0000-0000-0000-000000000001', NULL, 'Air', 'ml', 0.00, 99999, 0),
  -- Gula Putih: Rp19,000 / 1000gr = Rp19/gr
  ('c1000000-0000-0000-0000-000000000027', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Gula Putih', 'gram', 19.00, 1000, 200),

  -- === BAHAN MAKANAN ===
  -- Mie Ramen: Rp21,000 / 13 porsi = Rp1,615/porsi
  ('c1000000-0000-0000-0000-000000000030', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000005', 'Mie Ramen (Glory)', 'porsi', 1615.38, 104, 26),
  -- Ayam Fillet: Rp58,000 / 1000gr = Rp58/gr
  ('c1000000-0000-0000-0000-000000000031', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000006', 'Ayam Fillet (NS Chicken)', 'gram', 58.00, 3000, 1000),
  -- Beef Slice: Rp48,000 / 500gr = Rp96/gr
  ('c1000000-0000-0000-0000-000000000032', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Beef Slice', 'gram', 96.00, 2500, 500),
  -- Telur: Rp28,000 / 1000gr = Rp28/gr (~Rp1,680/butir @60gr)
  ('c1000000-0000-0000-0000-000000000033', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Telur Ayam', 'gram', 28.00, 3000, 500),
  -- Tepung Roti: Rp18,500 / 1000gr = Rp18.50/gr
  ('c1000000-0000-0000-0000-000000000034', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Tepung Roti (Piramid)', 'gram', 18.50, 2000, 500),
  -- Tepung Serbaguna: Rp10,000 / 1000gr = Rp10/gr
  ('c1000000-0000-0000-0000-000000000035', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Tepung Serbaguna (Jfood)', 'gram', 10.00, 2000, 500),
  -- Miso: Rp54,000 / 1000gr = Rp54/gr
  ('c1000000-0000-0000-0000-000000000036', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Miso (Miyachan)', 'gram', 54.00, 3000, 500),
  -- Kecap Asin: Rp120,000 / 2000ml = Rp60/ml
  ('c1000000-0000-0000-0000-000000000037', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Kecap Asin (Kikkoman)', 'ml', 60.00, 2000, 500),
  -- Rumput Laut / Nori: Rp25,000 / 50gr = Rp500/gr
  ('c1000000-0000-0000-0000-000000000038', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Nori Bubuk (Aonori)', 'gram', 500.00, 50, 10),
  -- Spicy Kuah: Rp53,000 / 1000gr = Rp53/gr
  ('c1000000-0000-0000-0000-000000000039', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Gochujang Spicy (Gungjung)', 'gram', 53.00, 1000, 200),
  -- Shoyu: Rp35,000 / 1000ml = Rp35/ml
  ('c1000000-0000-0000-0000-000000000040', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Shoyu Kecap', 'ml', 35.00, 2000, 500),
  -- Saos Sambel: Rp15,000 / 1000gr = Rp15/gr
  ('c1000000-0000-0000-0000-000000000041', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Saos Sambel (Gourmet)', 'gram', 15.00, 2000, 500),
  -- Naruto: Rp35,000 / 160gr = Rp218.75/gr
  ('c1000000-0000-0000-0000-000000000042', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Narutomaki', 'gram', 218.75, 320, 80),
  -- Bawang Putih Bubuk: Rp20,000 / botol
  ('c1000000-0000-0000-0000-000000000043', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Bawang Putih Bubuk', 'botol', 20000.00, 1, 1),
  -- Minyak Goreng: Rp20,000 / 1000ml = Rp20/ml
  ('c1000000-0000-0000-0000-000000000044', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Minyak Goreng (Sancho)', 'ml', 20.00, 2000, 500),
  -- Daun Bawang: Rp5,000 / ikat
  ('c1000000-0000-0000-0000-000000000045', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Daun Bawang', 'ikat', 5000.00, 1, 1),
  -- Wortel: Rp18,000 / 500gr = Rp36/gr
  ('c1000000-0000-0000-0000-000000000046', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000008', 'Wortel', 'gram', 36.00, 500, 200),
  -- Gyoza: Rp20,000 / 10pcs = Rp2,000/pcs
  ('c1000000-0000-0000-0000-000000000047', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Gyoza (Qufa Frozen)', 'pcs', 2000.00, 30, 10),
  -- Minyak Wijen: Rp50,000 / 600ml = Rp83.33/ml
  ('c1000000-0000-0000-0000-000000000048', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Minyak Wijen (Li Mang Huat)', 'ml', 83.33, 600, 100),
  -- Mayones: Rp27,000 / 1000gr = Rp27/gr
  ('c1000000-0000-0000-0000-000000000049', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Mayones (Gourmet)', 'gram', 27.00, 1000, 200),
  -- Kentang: Rp70,000 / 2500gr = Rp28/gr
  ('c1000000-0000-0000-0000-000000000050', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Kentang Goreng (Klan Store)', 'gram', 28.00, 5000, 1000),
  -- Nugget: Rp35,000 / 1000gr = Rp35/gr
  ('c1000000-0000-0000-0000-000000000051', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Nugget (Klan Store)', 'gram', 35.00, 2000, 500),
  -- Sosis: Rp20,000 / 51pcs = Rp392/pcs
  ('c1000000-0000-0000-0000-000000000052', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Sosis (Klan Store)', 'pcs', 392.16, 102, 20),
  -- Donat: Rp30,000 / 14pcs = Rp2,143/pcs
  ('c1000000-0000-0000-0000-000000000053', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 'Donat (Klan Store)', 'pcs', 2142.86, 28, 7),
  -- Kaldu Ayam: Rp30,000 / 1000gr = Rp30/gr
  ('c1000000-0000-0000-0000-000000000054', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Kaldu Ayam (Royco)', 'gram', 30.00, 1000, 200),
  -- Kecap Manis: Rp20,000 / botol
  ('c1000000-0000-0000-0000-000000000055', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Kecap Manis (ABC)', 'botol', 20000.00, 1, 1),
  -- Bumbu Kari: Rp35,000 / renceng
  ('c1000000-0000-0000-0000-000000000056', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Bumbu Kari (Sasa)', 'renceng', 35000.00, 1, 1),
  -- Beras: Rp80,000 / 5L
  ('c1000000-0000-0000-0000-000000000057', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Beras', 'liter', 16000.00, 5, 2),
  -- Merica Bubuk: Rp45,000 / bungkus
  ('c1000000-0000-0000-0000-000000000058', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Merica Bubuk', 'bungkus', 45000.00, 1, 1),
  -- Jahe Bubuk: Rp15,000 / botol
  ('c1000000-0000-0000-0000-000000000059', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Jahe Bubuk', 'botol', 15000.00, 2, 1),
  -- Kaldu Jamur: Rp30,000 / bungkus
  ('c1000000-0000-0000-0000-000000000060', 'a0000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Kaldu Jamur', 'bungkus', 30000.00, 1, 1);

-- ============================================================
-- STEP 3: CATEGORIES
-- ============================================================
INSERT INTO categories (id, outlet_id, name, color, icon, sort_order) VALUES
  ('d1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Coffee', '#6F4E37', 'coffee', 1),
  ('d1000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'Non-Coffee', '#8B5CF6', 'local_cafe', 2),
  ('d1000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'Makanan', '#EA580C', 'restaurant', 3),
  ('d1000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'Snack', '#F59E0B', 'fastfood', 4);

-- ============================================================
-- STEP 4: PRODUCTS (Menu)
-- ============================================================
-- selling_price = Harga Jual dari Perhitungan Laba
-- cost_price = HPP All In dari HPP Minuman

-- === COFFEE ===
INSERT INTO products (id, outlet_id, category_id, name, description, selling_price, cost_price, sort_order) VALUES
  ('e1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001',
   'Milko Creamy', 'Kopi dengan creamer & coconut milk yang creamy', 10000, 8118, 1),
  ('e1000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001',
   'Milko Java', 'Kopi dengan gula aren & susu UHT khas Java', 14000, 8168, 2),
  ('e1000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001',
   'Milko Caramel', 'Kopi dengan sirup caramel & susu UHT', 14000, 8208, 3),
  ('e1000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001',
   'Milko Spanish', 'Kopi ala Spanish latte dengan susu UHT', 16000, 7568, 4),
  ('e1000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001',
   'Milko Hazelnut', 'Kopi dengan sirup hazelnut & susu UHT', 16000, 8208, 5),

-- === NON-COFFEE ===
  ('e1000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002',
   'Milky Taro', 'Minuman taro creamy dengan susu UHT', 13000, 7167, 1),
  ('e1000000-0000-0000-0000-000000000011', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002',
   'Choco Java', 'Minuman coklat Java dengan susu UHT', 13000, 7542, 2),
  ('e1000000-0000-0000-0000-000000000012', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002',
   'Milky Matcha', 'Green tea matcha dengan susu UHT', 13000, 7167, 3),
  ('e1000000-0000-0000-0000-000000000013', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002',
   'Milky Red Velvet', 'Red velvet creamy dengan susu UHT', 13000, 7167, 4),
  ('e1000000-0000-0000-0000-000000000014', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002',
   'Milky Bublegum', 'Minuman bubblegum unik dengan susu UHT', 13000, 7167, 5),
  ('e1000000-0000-0000-0000-000000000015', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002',
   'Lemon Tea', 'Teh lemon segar', 10000, 4620, 6),
  ('e1000000-0000-0000-0000-000000000016', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002',
   'Lyche Tea', 'Teh lychee segar', 12000, 4620, 7),
  ('e1000000-0000-0000-0000-000000000017', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002',
   'Ice Tea', 'Es teh manis klasik', 7000, 3536, 8),
  ('e1000000-0000-0000-0000-000000000018', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002',
   'Thai Tea', 'Thai tea original Cha Tra Mue', 12000, 9592, 9),
  ('e1000000-0000-0000-0000-000000000019', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002',
   'Purple Glow', 'Fanta anggur dengan sirup mangga & selasih', 13000, 6842, 10),
  ('e1000000-0000-0000-0000-000000000020', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002',
   'Sunset Pop', 'Fanta merah dengan sirup jeruk & selasih', 13000, 6770, 11),
  ('e1000000-0000-0000-0000-000000000021', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002',
   'Orange Fizz', 'Sprite dengan sirup jeruk & selasih', 13000, 6770, 12),
  ('e1000000-0000-0000-0000-000000000022', 'a0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002',
   'Air Mineral', 'Air mineral Aquviva', 3000, 1083, 13);

-- ============================================================
-- STEP 5: RECIPES (Resep - dari HPP Minuman)
-- ============================================================

-- --- Milko Creamy ---
INSERT INTO recipes (product_id, ingredient_id, quantity, unit) VALUES
  ('e1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 10, 'gram'),   -- Kopi 10gr
  ('e1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000004', 5, 'gram'),    -- Creamer 5gr
  ('e1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000005', 15, 'gram'),   -- SKM 15gr
  ('e1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000003', 120, 'ml'),    -- Coconut Milk 120ml
  ('e1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Milko Java ---
  ('e1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 10, 'gram'),   -- Kopi 10gr
  ('e1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000006', 10, 'gram'),   -- Gula Aren 10gr
  ('e1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000005', 15, 'gram'),   -- SKM 15gr
  ('e1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000004', 5, 'gram'),    -- Creamer 5gr
  ('e1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000002', 120, 'ml'),    -- Susu UHT 120ml
  ('e1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Milko Caramel ---
  ('e1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000001', 10, 'gram'),   -- Kopi 10gr
  ('e1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000007', 8, 'ml'),      -- Sirup Caramel 8ml
  ('e1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000004', 5, 'gram'),    -- Creamer 5gr
  ('e1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000005', 15, 'gram'),   -- SKM 15gr
  ('e1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000002', 120, 'ml'),    -- Susu UHT 120ml
  ('e1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Milko Spanish ---
  ('e1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000001', 10, 'gram'),   -- Kopi 10gr
  ('e1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000005', 15, 'gram'),   -- SKM 15gr
  ('e1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000004', 5, 'gram'),    -- Creamer 5gr
  ('e1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000002', 120, 'ml'),    -- Susu UHT 120ml
  ('e1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Milko Hazelnut ---
  ('e1000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000001', 10, 'gram'),   -- Kopi 10gr
  ('e1000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000008', 8, 'ml'),      -- Sirup Hazelnut 8ml
  ('e1000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000004', 5, 'gram'),    -- Creamer 5gr
  ('e1000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000005', 15, 'gram'),   -- SKM 15gr
  ('e1000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000002', 120, 'ml'),    -- Susu UHT 120ml
  ('e1000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Milky Taro ---
  ('e1000000-0000-0000-0000-000000000010', 'c1000000-0000-0000-0000-000000000009', 15, 'gram'),   -- Powder Taro 15gr
  ('e1000000-0000-0000-0000-000000000010', 'c1000000-0000-0000-0000-000000000002', 120, 'ml'),    -- Susu UHT 120ml
  ('e1000000-0000-0000-0000-000000000010', 'c1000000-0000-0000-0000-000000000005', 15, 'gram'),   -- SKM 15gr
  ('e1000000-0000-0000-0000-000000000010', 'c1000000-0000-0000-0000-000000000004', 5, 'gram'),    -- Creamer 5gr
  ('e1000000-0000-0000-0000-000000000010', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Choco Java ---
  ('e1000000-0000-0000-0000-000000000011', 'c1000000-0000-0000-0000-000000000010', 20, 'gram'),   -- Powder Coklat 20gr
  ('e1000000-0000-0000-0000-000000000011', 'c1000000-0000-0000-0000-000000000002', 120, 'ml'),    -- Susu UHT 120ml
  ('e1000000-0000-0000-0000-000000000011', 'c1000000-0000-0000-0000-000000000005', 15, 'gram'),   -- SKM 15gr
  ('e1000000-0000-0000-0000-000000000011', 'c1000000-0000-0000-0000-000000000004', 5, 'gram'),    -- Creamer 5gr
  ('e1000000-0000-0000-0000-000000000011', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Milky Matcha ---
  ('e1000000-0000-0000-0000-000000000012', 'c1000000-0000-0000-0000-000000000011', 15, 'gram'),   -- Powder Green Tea 15gr
  ('e1000000-0000-0000-0000-000000000012', 'c1000000-0000-0000-0000-000000000002', 120, 'ml'),    -- Susu UHT 120ml
  ('e1000000-0000-0000-0000-000000000012', 'c1000000-0000-0000-0000-000000000005', 15, 'gram'),   -- SKM 15gr
  ('e1000000-0000-0000-0000-000000000012', 'c1000000-0000-0000-0000-000000000004', 5, 'gram'),    -- Creamer 5gr
  ('e1000000-0000-0000-0000-000000000012', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Milky Red Velvet ---
  ('e1000000-0000-0000-0000-000000000013', 'c1000000-0000-0000-0000-000000000013', 15, 'gram'),   -- Powder Red Velvet 15gr
  ('e1000000-0000-0000-0000-000000000013', 'c1000000-0000-0000-0000-000000000002', 120, 'ml'),    -- Susu UHT 120ml
  ('e1000000-0000-0000-0000-000000000013', 'c1000000-0000-0000-0000-000000000005', 15, 'gram'),   -- SKM 15gr
  ('e1000000-0000-0000-0000-000000000013', 'c1000000-0000-0000-0000-000000000004', 5, 'gram'),    -- Creamer 5gr
  ('e1000000-0000-0000-0000-000000000013', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Milky Bublegum ---
  ('e1000000-0000-0000-0000-000000000014', 'c1000000-0000-0000-0000-000000000015', 15, 'gram'),   -- Powder Bubble Gum 15gr
  ('e1000000-0000-0000-0000-000000000014', 'c1000000-0000-0000-0000-000000000002', 120, 'ml'),    -- Susu UHT 120ml
  ('e1000000-0000-0000-0000-000000000014', 'c1000000-0000-0000-0000-000000000005', 15, 'gram'),   -- SKM 15gr
  ('e1000000-0000-0000-0000-000000000014', 'c1000000-0000-0000-0000-000000000004', 5, 'gram'),    -- Creamer 5gr
  ('e1000000-0000-0000-0000-000000000014', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Lemon Tea ---
  ('e1000000-0000-0000-0000-000000000015', 'c1000000-0000-0000-0000-000000000014', 15, 'gram'),   -- Powder Lemon Tea 15gr
  ('e1000000-0000-0000-0000-000000000015', 'c1000000-0000-0000-0000-000000000016', 3, 'gram'),    -- Teh 3gr (brewed ~50ml)
  ('e1000000-0000-0000-0000-000000000015', 'c1000000-0000-0000-0000-000000000026', 70, 'ml'),     -- Air 70ml
  ('e1000000-0000-0000-0000-000000000015', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Lyche Tea ---
  ('e1000000-0000-0000-0000-000000000016', 'c1000000-0000-0000-0000-000000000012', 15, 'gram'),   -- Powder Lyche Tea 15gr
  ('e1000000-0000-0000-0000-000000000016', 'c1000000-0000-0000-0000-000000000016', 3, 'gram'),    -- Teh 3gr
  ('e1000000-0000-0000-0000-000000000016', 'c1000000-0000-0000-0000-000000000026', 70, 'ml'),     -- Air 70ml
  ('e1000000-0000-0000-0000-000000000016', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Ice Tea ---
  ('e1000000-0000-0000-0000-000000000017', 'c1000000-0000-0000-0000-000000000026', 60, 'ml'),     -- Air 60ml
  ('e1000000-0000-0000-0000-000000000017', 'c1000000-0000-0000-0000-000000000016', 4, 'gram'),    -- Teh 4gr
  ('e1000000-0000-0000-0000-000000000017', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Thai Tea ---
  ('e1000000-0000-0000-0000-000000000018', 'c1000000-0000-0000-0000-000000000019', 40, 'gram'),   -- Thai Tea Bubuk 40gr
  ('e1000000-0000-0000-0000-000000000018', 'c1000000-0000-0000-0000-000000000026', 60, 'ml'),     -- Air 60ml
  ('e1000000-0000-0000-0000-000000000018', 'c1000000-0000-0000-0000-000000000005', 20, 'gram'),   -- SKM 20gr
  ('e1000000-0000-0000-0000-000000000018', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Purple Glow ---
  ('e1000000-0000-0000-0000-000000000019', 'c1000000-0000-0000-0000-000000000021', 20, 'ml'),     -- Sirup Mangga 20ml
  ('e1000000-0000-0000-0000-000000000019', 'c1000000-0000-0000-0000-000000000024', 120, 'ml'),    -- Fanta Anggur 120ml
  ('e1000000-0000-0000-0000-000000000019', 'c1000000-0000-0000-0000-000000000025', 20, 'gram'),   -- Selasih 20gr
  ('e1000000-0000-0000-0000-000000000019', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Sunset Pop ---
  ('e1000000-0000-0000-0000-000000000020', 'c1000000-0000-0000-0000-000000000020', 20, 'ml'),     -- Sirup Jeruk 20ml
  ('e1000000-0000-0000-0000-000000000020', 'c1000000-0000-0000-0000-000000000023', 120, 'ml'),    -- Fanta Merah 120ml
  ('e1000000-0000-0000-0000-000000000020', 'c1000000-0000-0000-0000-000000000025', 20, 'gram'),   -- Selasih 20gr
  ('e1000000-0000-0000-0000-000000000020', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Orange Fizz ---
  ('e1000000-0000-0000-0000-000000000021', 'c1000000-0000-0000-0000-000000000020', 20, 'ml'),     -- Sirup Jeruk 20ml
  ('e1000000-0000-0000-0000-000000000021', 'c1000000-0000-0000-0000-000000000022', 120, 'ml'),    -- Sprite 120ml
  ('e1000000-0000-0000-0000-000000000021', 'c1000000-0000-0000-0000-000000000025', 20, 'gram'),   -- Selasih 20gr
  ('e1000000-0000-0000-0000-000000000021', 'c1000000-0000-0000-0000-000000000017', 160, 'gram'),  -- Ice Tube 160gr

-- --- Air Mineral ---
  ('e1000000-0000-0000-0000-000000000022', 'c1000000-0000-0000-0000-000000000018', 1, 'botol');   -- Air Mineral 1 botol

-- ============================================================
-- STEP 6: MODIFIER GROUPS
-- ============================================================
INSERT INTO modifier_groups (id, outlet_id, name, description, is_required, min_selections, max_selections) VALUES
  -- Suhu: wajib pilih 1 (Ice atau Hot)
  ('f1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
   'Suhu', 'Pilihan suhu minuman', true, 1, 1),
  -- Level Gula: wajib pilih 1
  ('f1000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001',
   'Level Gula', 'Pilihan tingkat kemanisan', true, 1, 1),
  -- Pilihan Kuah Ramen: wajib pilih 1
  ('f1000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001',
   'Pilihan Kuah', 'Pilihan kuah ramen', true, 1, 1);

-- ============================================================
-- STEP 7: MODIFIER OPTIONS
-- ============================================================
INSERT INTO modifier_options (id, modifier_group_id, name, price_adjustment, is_default, sort_order) VALUES
  -- Suhu options
  ('f2000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 'Ice', 0, true, 1),
  ('f2000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001', 'Hot', 0, false, 2),

  -- Level Gula options
  ('f2000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000002', 'Normal Sugar', 0, true, 1),
  ('f2000000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000002', 'Less Sugar', 0, false, 2),
  ('f2000000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000002', 'No Sugar', 0, false, 3),

  -- Pilihan Kuah options
  ('f2000000-0000-0000-0000-000000000006', 'f1000000-0000-0000-0000-000000000003', 'Miso', 0, true, 1),
  ('f2000000-0000-0000-0000-000000000007', 'f1000000-0000-0000-0000-000000000003', 'Shoyu', 0, false, 2),
  ('f2000000-0000-0000-0000-000000000008', 'f1000000-0000-0000-0000-000000000003', 'Spicy', 0, false, 3);

-- ============================================================
-- STEP 8: PRODUCT-MODIFIER LINKS
-- ============================================================
-- All Coffee products get Suhu + Level Gula
INSERT INTO product_modifier_groups (product_id, modifier_group_id, sort_order) VALUES
  -- Coffee → Suhu + Level Gula
  ('e1000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 1),
  ('e1000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000002', 2),
  ('e1000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001', 1),
  ('e1000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000002', 2),
  ('e1000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000001', 1),
  ('e1000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000002', 2),
  ('e1000000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000001', 1),
  ('e1000000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000002', 2),
  ('e1000000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000001', 1),
  ('e1000000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000002', 2),

  -- Non-Coffee Milky series → Suhu + Level Gula
  ('e1000000-0000-0000-0000-000000000010', 'f1000000-0000-0000-0000-000000000001', 1),
  ('e1000000-0000-0000-0000-000000000010', 'f1000000-0000-0000-0000-000000000002', 2),
  ('e1000000-0000-0000-0000-000000000011', 'f1000000-0000-0000-0000-000000000001', 1),
  ('e1000000-0000-0000-0000-000000000011', 'f1000000-0000-0000-0000-000000000002', 2),
  ('e1000000-0000-0000-0000-000000000012', 'f1000000-0000-0000-0000-000000000001', 1),
  ('e1000000-0000-0000-0000-000000000012', 'f1000000-0000-0000-0000-000000000002', 2),
  ('e1000000-0000-0000-0000-000000000013', 'f1000000-0000-0000-0000-000000000001', 1),
  ('e1000000-0000-0000-0000-000000000013', 'f1000000-0000-0000-0000-000000000002', 2),
  ('e1000000-0000-0000-0000-000000000014', 'f1000000-0000-0000-0000-000000000001', 1),
  ('e1000000-0000-0000-0000-000000000014', 'f1000000-0000-0000-0000-000000000002', 2),

  -- Tea series → Level Gula only (already cold/ice)
  ('e1000000-0000-0000-0000-000000000015', 'f1000000-0000-0000-0000-000000000002', 1),
  ('e1000000-0000-0000-0000-000000000016', 'f1000000-0000-0000-0000-000000000002', 1),
  ('e1000000-0000-0000-0000-000000000017', 'f1000000-0000-0000-0000-000000000002', 1),

  -- Thai Tea → Suhu + Level Gula
  ('e1000000-0000-0000-0000-000000000018', 'f1000000-0000-0000-0000-000000000001', 1),
  ('e1000000-0000-0000-0000-000000000018', 'f1000000-0000-0000-0000-000000000002', 2),

  -- Soda series → Level Gula only (cold drinks)
  ('e1000000-0000-0000-0000-000000000019', 'f1000000-0000-0000-0000-000000000002', 1),
  ('e1000000-0000-0000-0000-000000000020', 'f1000000-0000-0000-0000-000000000002', 1),
  ('e1000000-0000-0000-0000-000000000021', 'f1000000-0000-0000-0000-000000000002', 1);

  -- NOTE: Air Mineral tidak perlu modifier
  -- NOTE: Makanan products akan ditambahkan manual via Back Office
  --       Saat menambah menu ramen, link ke modifier "Pilihan Kuah" (f1000000-...-000000000003)

COMMIT;

-- ============================================================
-- SUMMARY:
--   9 Suppliers
--   40+ Ingredients (27 minuman + 20+ makanan)
--   4 Categories (Coffee, Non-Coffee, Makanan, Snack)
--   18 Products (5 coffee + 13 non-coffee)
--   85 Recipe entries (all drinks have full recipes)
--   3 Modifier groups (Suhu, Level Gula, Pilihan Kuah)
--   8 Modifier options
--   28 Product-modifier links
--
-- TODO (manual via Back Office):
--   - Add Makanan products (ramen, katsu, etc.)
--   - Add Snack products (gyoza, fries, nugget, etc.)
--   - Link makanan ramen → "Pilihan Kuah" modifier
--   - Add recipes for makanan products
-- ============================================================
-- ============================================================
-- UTTER APP - Migration 024: Product Featured Categories
-- ============================================================
-- Junction table to tag products with multiple featured
-- categories (e.g. Rekomendasi, Promo, Paket) while keeping
-- their primary category_id intact on the products table.
--
-- A product can belong to many featured categories, and a
-- featured category can contain many products.
-- ============================================================

-- ============================================================
-- 1. Create product_featured_categories junction table
-- ============================================================
CREATE TABLE IF NOT EXISTS product_featured_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  featured_category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (product_id, featured_category_id)
);

-- ============================================================
-- 2. Indexes for fast lookups
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_pfc_product_id
  ON product_featured_categories(product_id);

CREATE INDEX IF NOT EXISTS idx_pfc_featured_category_id
  ON product_featured_categories(featured_category_id);

-- ============================================================
-- 3. Enable RLS
-- ============================================================
ALTER TABLE product_featured_categories ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 4. RLS policies for anon role (POS web app uses anon key)
-- ============================================================
CREATE POLICY "anon_select_product_featured_categories"
  ON product_featured_categories
  FOR SELECT TO anon USING (true);

CREATE POLICY "anon_insert_product_featured_categories"
  ON product_featured_categories
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "anon_update_product_featured_categories"
  ON product_featured_categories
  FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "anon_delete_product_featured_categories"
  ON product_featured_categories
  FOR DELETE TO anon USING (true);
-- ============================================================================
-- Migration 025: Auto HPP (Cost Price) from Recipe + Ingredient Price Cascade
-- ============================================================================
-- Automation flow:
-- 1. Recipe berubah (add/edit/delete) → product.cost_price auto-recalculate
-- 2. Harga ingredient berubah → semua produk yang pakai ingredient itu auto-update
-- 3. Backfill semua existing products dari resep yang sudah ada
-- ============================================================================

-- ── Trigger 1: Recipe change → recalculate product cost_price ──────────────

CREATE OR REPLACE FUNCTION update_product_cost_from_recipe()
RETURNS TRIGGER AS $$
DECLARE
  v_product_id UUID;
  v_new_cost NUMERIC;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_product_id := OLD.product_id;
  ELSE
    v_product_id := NEW.product_id;
  END IF;

  -- Sum all recipe ingredients cost
  SELECT COALESCE(SUM(r.quantity * i.cost_per_unit), 0)
  INTO v_new_cost
  FROM recipes r
  JOIN ingredients i ON r.ingredient_id = i.id
  WHERE r.product_id = v_product_id;

  -- Update product cost_price
  UPDATE products
  SET cost_price = v_new_cost, updated_at = NOW()
  WHERE id = v_product_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_recipe_cost_update ON recipes;
CREATE TRIGGER trg_recipe_cost_update
  AFTER INSERT OR UPDATE OR DELETE ON recipes
  FOR EACH ROW
  EXECUTE FUNCTION update_product_cost_from_recipe();

-- ── Trigger 2: Ingredient price change → cascade to all products ───────────

CREATE OR REPLACE FUNCTION update_products_cost_on_ingredient_price_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Only fire when cost_per_unit actually changes
  IF OLD.cost_per_unit IS DISTINCT FROM NEW.cost_per_unit THEN
    UPDATE products p
    SET cost_price = sub.new_cost, updated_at = NOW()
    FROM (
      SELECT r.product_id, COALESCE(SUM(r.quantity * i.cost_per_unit), 0) AS new_cost
      FROM recipes r
      JOIN ingredients i ON r.ingredient_id = i.id
      WHERE r.product_id IN (
        SELECT DISTINCT product_id FROM recipes WHERE ingredient_id = NEW.id
      )
      GROUP BY r.product_id
    ) sub
    WHERE p.id = sub.product_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ingredient_cost_cascade ON ingredients;
CREATE TRIGGER trg_ingredient_cost_cascade
  AFTER UPDATE ON ingredients
  FOR EACH ROW
  EXECUTE FUNCTION update_products_cost_on_ingredient_price_change();

-- ── Backfill: Calculate cost_price for all products with recipes ───────────

UPDATE products p
SET cost_price = sub.hpp, updated_at = NOW()
FROM (
  SELECT r.product_id, SUM(r.quantity * i.cost_per_unit) AS hpp
  FROM recipes r
  JOIN ingredients i ON r.ingredient_id = i.id
  GROUP BY r.product_id
) sub
WHERE p.id = sub.product_id;
-- ============================================================
-- 026: Add category column to ingredients
-- Categories: makanan, minuman, snack
-- ============================================================

ALTER TABLE ingredients ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'makanan';
-- ============================================================
-- 027: Enable Supabase Realtime for key tables
-- Allows Flutter apps to receive live DB changes
-- and auto-refresh providers without manual polling.
-- ============================================================

-- Already in publication: ingredients, shifts, orders, order_items, ai_messages, ai_action_logs, ai_insights
-- Adding new tables:
ALTER PUBLICATION supabase_realtime ADD TABLE products;
ALTER PUBLICATION supabase_realtime ADD TABLE categories;
ALTER PUBLICATION supabase_realtime ADD TABLE recipes;
ALTER PUBLICATION supabase_realtime ADD TABLE stock_movements;
ALTER PUBLICATION supabase_realtime ADD TABLE product_stock_movements;
ALTER PUBLICATION supabase_realtime ADD TABLE purchases;
ALTER PUBLICATION supabase_realtime ADD TABLE purchase_items;
-- ============================================================
-- 028: Operational Costs for HPP calculation
-- Stores monthly fixed costs (rent, utilities, labor etc.)
-- Auto-allocated to HPP per product based on sales volume
-- ============================================================

CREATE TABLE IF NOT EXISTS operational_costs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  category TEXT NOT NULL DEFAULT 'operational',  -- 'operational' or 'labor'
  name TEXT NOT NULL,
  amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  is_monthly BOOLEAN DEFAULT true,
  is_active BOOLEAN DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_operational_costs_outlet
  ON operational_costs(outlet_id, is_active);

-- RLS
ALTER TABLE operational_costs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_select_operational_costs" ON operational_costs
  FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_operational_costs" ON operational_costs
  FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_operational_costs" ON operational_costs
  FOR UPDATE TO anon USING (true);
CREATE POLICY "anon_delete_operational_costs" ON operational_costs
  FOR DELETE TO anon USING (true);

-- Seed some common cost items for outlet a0000000-0000-0000-0000-000000000001
INSERT INTO operational_costs (outlet_id, category, name, amount, notes) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'operational', 'Sewa Tempat', 0, 'Biaya sewa per bulan'),
  ('a0000000-0000-0000-0000-000000000001', 'operational', 'Listrik', 0, 'Tagihan listrik bulanan'),
  ('a0000000-0000-0000-0000-000000000001', 'operational', 'Gas', 0, 'LPG / gas alam'),
  ('a0000000-0000-0000-0000-000000000001', 'operational', 'Air (PDAM)', 0, 'Tagihan air bulanan'),
  ('a0000000-0000-0000-0000-000000000001', 'operational', 'Internet', 0, 'WiFi / internet bulanan'),
  ('a0000000-0000-0000-0000-000000000001', 'labor', 'Gaji Karyawan', 0, 'Total gaji semua karyawan per bulan'),
  ('a0000000-0000-0000-0000-000000000001', 'labor', 'BPJS / Asuransi', 0, 'Iuran BPJS karyawan');
-- ============================================================
-- 031: Fix Audit Issues
-- 1. Create missing purchases & purchase_items tables
-- 2. Add missing columns: categories.station, shifts.total_cash, shifts.total_non_cash
-- 3. Fix realtime publication for purchases tables
-- 4. Add compound indexes for performance
-- 5. RLS policies for new tables
-- ============================================================

-- ── 1. Create purchases table ─────────────────────────────────
CREATE TABLE IF NOT EXISTS purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
  supplier_name TEXT NOT NULL DEFAULT '',
  pic_name TEXT NOT NULL DEFAULT '',
  payment_source TEXT NOT NULL DEFAULT 'kas_kasir'
    CHECK (payment_source IN ('kas_kasir', 'uang_luar')),
  payment_detail TEXT,
  shift_id UUID REFERENCES shifts(id) ON DELETE SET NULL,
  receipt_image_url TEXT,
  total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes TEXT,
  purchase_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_purchases_outlet_id ON purchases(outlet_id);
CREATE INDEX IF NOT EXISTS idx_purchases_supplier_id ON purchases(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchases_purchase_date ON purchases(purchase_date);
CREATE INDEX IF NOT EXISTS idx_purchases_outlet_date ON purchases(outlet_id, purchase_date DESC);

-- ── 2. Create purchase_items table ────────────────────────────
CREATE TABLE IF NOT EXISTS purchase_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
  ingredient_id UUID REFERENCES ingredients(id) ON DELETE SET NULL,
  item_name TEXT NOT NULL DEFAULT '',
  quantity NUMERIC(10,3) NOT NULL DEFAULT 0,
  unit TEXT NOT NULL DEFAULT 'pcs',
  unit_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase_id ON purchase_items(purchase_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_ingredient_id ON purchase_items(ingredient_id);

-- ── 3. Add missing column: categories.station ─────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'categories' AND column_name = 'station'
  ) THEN
    ALTER TABLE categories ADD COLUMN station TEXT NOT NULL DEFAULT 'kitchen'
      CHECK (station IN ('kitchen', 'bar'));
  END IF;
END $$;

-- ── 4. Add missing columns: shifts.total_cash, shifts.total_non_cash
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'shifts' AND column_name = 'total_cash'
  ) THEN
    ALTER TABLE shifts ADD COLUMN total_cash NUMERIC(12,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'shifts' AND column_name = 'total_non_cash'
  ) THEN
    ALTER TABLE shifts ADD COLUMN total_non_cash NUMERIC(12,2) DEFAULT 0;
  END IF;
END $$;

-- ── 5. RLS for purchases (idempotent) ─────────────────────────
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_purchases' AND tablename = 'purchases') THEN
    CREATE POLICY "anon_select_purchases" ON purchases FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_purchases' AND tablename = 'purchases') THEN
    CREATE POLICY "anon_insert_purchases" ON purchases FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_purchases' AND tablename = 'purchases') THEN
    CREATE POLICY "anon_update_purchases" ON purchases FOR UPDATE TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_delete_purchases' AND tablename = 'purchases') THEN
    CREATE POLICY "anon_delete_purchases" ON purchases FOR DELETE TO anon USING (true);
  END IF;
END $$;

-- ── 6. RLS for purchase_items (idempotent) ────────────────────
ALTER TABLE purchase_items ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_purchase_items' AND tablename = 'purchase_items') THEN
    CREATE POLICY "anon_select_purchase_items" ON purchase_items FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_purchase_items' AND tablename = 'purchase_items') THEN
    CREATE POLICY "anon_insert_purchase_items" ON purchase_items FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_purchase_items' AND tablename = 'purchase_items') THEN
    CREATE POLICY "anon_update_purchase_items" ON purchase_items FOR UPDATE TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_delete_purchase_items' AND tablename = 'purchase_items') THEN
    CREATE POLICY "anon_delete_purchase_items" ON purchase_items FOR DELETE TO anon USING (true);
  END IF;
END $$;

-- ── 7. Realtime publication (safe — ignores if already added) ─
DO $$ BEGIN
  -- Check if purchases is already in publication before adding
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'purchases'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE purchases;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'purchase_items'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE purchase_items;
  END IF;
END $$;

-- ── 8. Compound indexes for performance ───────────────────────
-- Orders: common report query pattern
CREATE INDEX IF NOT EXISTS idx_orders_outlet_created
  ON orders(outlet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_outlet_status_created
  ON orders(outlet_id, status, created_at DESC);

-- Products: menu display
CREATE INDEX IF NOT EXISTS idx_products_outlet_available
  ON products(outlet_id, is_available);

-- Ingredients: active list + supplier lookup
CREATE INDEX IF NOT EXISTS idx_ingredients_outlet_active
  ON ingredients(outlet_id, is_active);
CREATE INDEX IF NOT EXISTS idx_ingredients_supplier
  ON ingredients(supplier_id);

-- Stock movements: report pattern
CREATE INDEX IF NOT EXISTS idx_stock_movements_outlet_type_date
  ON stock_movements(outlet_id, movement_type, created_at DESC);

-- ── 9. Standardize payment method constraint ──────────────────
-- Migrate legacy values
UPDATE orders SET payment_method = 'ewallet' WHERE payment_method = 'e_wallet';
UPDATE orders SET payment_method = 'platform' WHERE payment_method IN ('gofood', 'grabfood', 'shopeefood');
-- Drop old constraint and re-add with clean values
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;
ALTER TABLE orders ADD CONSTRAINT orders_payment_method_check
  CHECK (payment_method IN ('cash', 'card', 'qris', 'ewallet', 'bank_transfer', 'split', 'platform'));
-- ============================================================================
-- Migration 032: Modifier Option Ingredients
-- Links modifier options to ingredients for per-modifier stock deduction.
-- ============================================================================

-- 1. Create table
CREATE TABLE IF NOT EXISTS modifier_option_ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  modifier_option_id UUID NOT NULL REFERENCES modifier_options(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
  quantity DECIMAL(12,3) NOT NULL,
  unit TEXT NOT NULL DEFAULT 'gram',
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(modifier_option_id, ingredient_id)
);

-- 2. Index for fast lookups by modifier_option_id
CREATE INDEX IF NOT EXISTS idx_modifier_option_ingredients_option
  ON modifier_option_ingredients(modifier_option_id);

-- 3. RLS
ALTER TABLE modifier_option_ingredients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_select_modifier_option_ingredients"
  ON modifier_option_ingredients FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_modifier_option_ingredients"
  ON modifier_option_ingredients FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_modifier_option_ingredients"
  ON modifier_option_ingredients FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_modifier_option_ingredients"
  ON modifier_option_ingredients FOR DELETE TO anon USING (true);

-- 4. Add to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE modifier_option_ingredients;

-- 5. Update stock deduction trigger to also deduct modifier ingredients
-- The trigger parses order_items.modifiers JSONB for modifier_option_id,
-- then joins modifier_option_ingredients to find ingredients to deduct.
CREATE OR REPLACE FUNCTION deduct_stock_on_order_complete()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN

    -- A) Deduct product recipe ingredients (existing logic)
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

    -- B) Deduct modifier option ingredients (new logic)
    -- Parse each order_item's modifiers JSONB array for modifier_option_id,
    -- then lookup modifier_option_ingredients for that option.
    INSERT INTO stock_movements (outlet_id, ingredient_id, movement_type, quantity, reference_type, reference_id, notes)
    SELECT
      NEW.outlet_id,
      moi.ingredient_id,
      'auto_deduct',
      -(moi.quantity * oi.quantity),
      'order',
      NEW.id,
      'Auto-deducted modifier from order ' || NEW.order_number
    FROM order_items oi,
      LATERAL jsonb_array_elements(COALESCE(oi.modifiers, '[]'::jsonb)) AS mod_elem
    JOIN modifier_option_ingredients moi
      ON moi.modifier_option_id = (mod_elem->>'modifier_option_id')::uuid
    WHERE oi.order_id = NEW.id
    AND oi.status != 'cancelled'
    AND mod_elem->>'modifier_option_id' IS NOT NULL;

    UPDATE ingredients i
    SET current_stock = i.current_stock - sub.total_deducted
    FROM (
      SELECT moi.ingredient_id, SUM(moi.quantity * oi.quantity) AS total_deducted
      FROM order_items oi,
        LATERAL jsonb_array_elements(COALESCE(oi.modifiers, '[]'::jsonb)) AS mod_elem
      JOIN modifier_option_ingredients moi
        ON moi.modifier_option_id = (mod_elem->>'modifier_option_id')::uuid
      WHERE oi.order_id = NEW.id
      AND oi.status != 'cancelled'
      AND mod_elem->>'modifier_option_id' IS NOT NULL
      GROUP BY moi.ingredient_id
    ) sub
    WHERE i.id = sub.ingredient_id;

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- ============================================================
-- UTTER APP - Database Migration 033: Unit Conversion System
-- ============================================================
-- Adds base_unit field to ingredients for proper unit conversion
-- Migrates existing units to base units (g for weight, ml for volume)
-- ============================================================

-- ============================================================
-- 1. Add base_unit column to ingredients
-- ============================================================
ALTER TABLE ingredients
ADD COLUMN IF NOT EXISTS base_unit TEXT;

-- ============================================================
-- 2. Migrate existing data to base units
-- ============================================================

-- Set base_unit based on current unit
UPDATE ingredients
SET base_unit = CASE
  -- Weight units → base: g (grams)
  WHEN unit IN ('mg', 'g', 'gram', 'kg', 'kilogram') THEN 'g'

  -- Volume units → base: ml (milliliters)
  WHEN unit IN ('ml', 'mL', 'l', 'liter', 'litre') THEN 'ml'

  -- Count units → no conversion, keep as is
  ELSE 'pcs'
END
WHERE base_unit IS NULL;

-- Convert existing stock values to base units
UPDATE ingredients
SET current_stock = CASE
  -- Convert kg to g (multiply by 1000)
  WHEN unit IN ('kg', 'kilogram') THEN current_stock * 1000

  -- Convert liter to ml (multiply by 1000)
  WHEN unit IN ('l', 'liter', 'litre') THEN current_stock * 1000

  -- Convert mg to g (divide by 1000)
  WHEN unit = 'mg' THEN current_stock / 1000

  -- Keep g and ml as is
  ELSE current_stock
END,
min_stock = CASE
  WHEN unit IN ('kg', 'kilogram') THEN min_stock * 1000
  WHEN unit IN ('l', 'liter', 'litre') THEN min_stock * 1000
  WHEN unit = 'mg' THEN min_stock / 1000
  ELSE min_stock
END,
max_stock = CASE
  WHEN unit IN ('kg', 'kilogram') THEN max_stock * 1000
  WHEN unit IN ('l', 'liter', 'litre') THEN max_stock * 1000
  WHEN unit = 'mg' THEN max_stock / 1000
  ELSE max_stock
END,
-- Update unit to base unit
unit = base_unit
WHERE base_unit IS NOT NULL;

-- ============================================================
-- 3. Set NOT NULL constraint after migration
-- ============================================================
ALTER TABLE ingredients
ALTER COLUMN base_unit SET DEFAULT 'pcs',
ALTER COLUMN base_unit SET NOT NULL;

-- ============================================================
-- 4. Add helpful comment
-- ============================================================
COMMENT ON COLUMN ingredients.base_unit IS 'Base unit for storage: g (weight), ml (volume), or pcs (count). All stock values are stored in base units.';
COMMENT ON COLUMN ingredients.unit IS 'Display unit shown to users. Can be mg, g, kg for weight; ml, l for volume; or pcs, buah, botol, etc for count.';
-- ============================================================================
-- Migration: 034_ai_memories_table.sql
-- Description: Persistent AI memory storage (replaces localStorage)
-- Author: Claude Code
-- Date: 2026-02-12
-- ============================================================================

-- Create AI memories table for persistent storage across sessions
CREATE TABLE IF NOT EXISTS ai_memories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  insight TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('sales', 'product', 'stock', 'customer', 'operational', 'general')),
  confidence DECIMAL(3,2) DEFAULT 0.80 CHECK (confidence >= 0 AND confidence <= 1),
  reinforce_count INTEGER DEFAULT 1,
  source TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_ai_memories_outlet ON ai_memories(outlet_id);
CREATE INDEX IF NOT EXISTS idx_ai_memories_category ON ai_memories(category);
CREATE INDEX IF NOT EXISTS idx_ai_memories_created ON ai_memories(created_at DESC);

-- RLS (Row Level Security) policies
ALTER TABLE ai_memories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view memories for their outlets"
  ON ai_memories FOR SELECT
  USING (
    outlet_id IN (
      SELECT outlet_id FROM staff WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert memories for their outlets"
  ON ai_memories FOR INSERT
  WITH CHECK (
    outlet_id IN (
      SELECT outlet_id FROM staff WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update memories for their outlets"
  ON ai_memories FOR UPDATE
  USING (
    outlet_id IN (
      SELECT outlet_id FROM staff WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete memories for their outlets"
  ON ai_memories FOR DELETE
  USING (
    outlet_id IN (
      SELECT outlet_id FROM staff WHERE user_id = auth.uid()
    )
  );

-- Comments
COMMENT ON TABLE ai_memories IS 'Persistent AI memory storage for business insights learned over time';
COMMENT ON COLUMN ai_memories.insight IS 'The business insight or pattern discovered by AI';
COMMENT ON COLUMN ai_memories.category IS 'Category of insight: sales, product, stock, customer, operational, general';
COMMENT ON COLUMN ai_memories.confidence IS 'Confidence level of this insight (0.0 to 1.0)';
COMMENT ON COLUMN ai_memories.reinforce_count IS 'How many times this insight has been reinforced';
-- ============================================================================
-- Migration: 035_analytics_views.sql
-- Description: Create analytics views for deep business intelligence
-- Author: Claude Code
-- Date: 2026-02-12
-- ============================================================================

-- Daily Sales Summary View - Aggregated daily metrics
CREATE OR REPLACE VIEW v_daily_sales_summary AS
SELECT
  outlet_id,
  DATE(created_at) as sale_date,
  COUNT(*) as total_orders,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
  COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_orders,
  COUNT(*) FILTER (WHERE status = 'refunded') as refunded_orders,
  SUM(total) FILTER (WHERE status = 'completed') as total_revenue,
  SUM(subtotal) FILTER (WHERE status = 'completed') as subtotal_revenue,
  SUM(tax_amount) FILTER (WHERE status = 'completed') as total_tax,
  SUM(discount_amount) FILTER (WHERE status = 'completed') as total_discounts,
  AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
  COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '') as unique_customers,
  ARRAY_AGG(DISTINCT payment_method) FILTER (WHERE status = 'completed') as payment_methods_used
FROM orders
GROUP BY outlet_id, DATE(created_at);

-- Hourly Revenue Pattern View - For predicting busy hours
CREATE OR REPLACE VIEW v_hourly_revenue_pattern AS
SELECT
  outlet_id,
  EXTRACT(HOUR FROM created_at)::INTEGER as hour_of_day,
  EXTRACT(DOW FROM created_at)::INTEGER as day_of_week, -- 0=Sunday, 6=Saturday
  COUNT(*) as order_count,
  SUM(total) FILTER (WHERE status = 'completed') as revenue,
  AVG(total) FILTER (WHERE status = 'completed') as avg_order_value
FROM orders
WHERE created_at >= NOW() - INTERVAL '90 days'
GROUP BY outlet_id, EXTRACT(HOUR FROM created_at), EXTRACT(DOW FROM created_at);

-- Product Performance View - Sales and profitability (Last 30 days)
CREATE OR REPLACE VIEW v_product_performance AS
SELECT
  p.id as product_id,
  p.outlet_id,
  p.name as product_name,
  p.category_id,
  c.name as category_name,
  p.selling_price,
  p.cost_price,
  COUNT(oi.id) as times_ordered,
  SUM(oi.quantity) as total_quantity_sold,
  SUM(oi.subtotal) as total_revenue,
  AVG(oi.unit_price) as avg_selling_price,
  COALESCE(SUM(oi.subtotal) - (SUM(oi.quantity) * COALESCE(p.cost_price, 0)), 0) as total_profit,
  CASE
    WHEN SUM(oi.quantity) > 0 AND COALESCE(p.cost_price, 0) > 0
    THEN ROUND(((SUM(oi.subtotal) - (SUM(oi.quantity) * p.cost_price)) / SUM(oi.subtotal) * 100)::NUMERIC, 2)
    ELSE 0
  END as profit_margin_pct,
  MAX(o.created_at) as last_sold_at
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN order_items oi ON oi.product_id = p.id
LEFT JOIN orders o ON oi.order_id = o.id
  AND o.status = 'completed'
  AND o.created_at >= NOW() - INTERVAL '30 days'
WHERE p.is_active = true
GROUP BY p.id, p.outlet_id, p.name, p.category_id, c.name, p.selling_price, p.cost_price;

-- Stock Alert View - Real-time stock warnings
CREATE OR REPLACE VIEW v_stock_alerts AS
SELECT
  id,
  outlet_id,
  name as ingredient_name,
  current_stock,
  min_stock,
  max_stock,
  unit,
  base_unit,
  cost_per_unit,
  CASE
    WHEN current_stock <= 0 THEN 'OUT_OF_STOCK'
    WHEN current_stock <= min_stock * 0.5 THEN 'CRITICAL'
    WHEN current_stock <= min_stock THEN 'LOW'
    WHEN current_stock >= max_stock THEN 'OVERSTOCK'
    ELSE 'NORMAL'
  END as stock_status,
  CASE
    WHEN current_stock < min_stock THEN GREATEST(min_stock - current_stock, 0)
    ELSE 0
  END as reorder_quantity,
  category
FROM ingredients
WHERE is_active = true
ORDER BY
  CASE
    WHEN current_stock <= 0 THEN 1
    WHEN current_stock <= min_stock * 0.5 THEN 2
    WHEN current_stock <= min_stock THEN 3
    WHEN current_stock >= max_stock THEN 4
    ELSE 5
  END,
  name;

-- Customer Order Frequency - RFM Analysis basis
CREATE OR REPLACE VIEW v_customer_order_frequency AS
SELECT
  outlet_id,
  customer_name,
  customer_phone,
  COUNT(*) as total_orders,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
  SUM(total) FILTER (WHERE status = 'completed') as lifetime_value,
  AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
  MAX(created_at) as last_order_date,
  MIN(created_at) as first_order_date,
  EXTRACT(DAYS FROM (NOW() - MAX(created_at)))::INTEGER as days_since_last_order,
  CASE
    WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 10 THEN 'VIP'
    WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 5 THEN 'LOYAL'
    WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 2 THEN 'REPEAT'
    ELSE 'NEW'
  END as customer_segment,
  CASE
    WHEN EXTRACT(DAYS FROM (NOW() - MAX(created_at))) <= 7 THEN 'ACTIVE'
    WHEN EXTRACT(DAYS FROM (NOW() - MAX(created_at))) <= 30 THEN 'AT_RISK'
    WHEN EXTRACT(DAYS FROM (NOW() - MAX(created_at))) <= 90 THEN 'DORMANT'
    ELSE 'LOST'
  END as recency_status
FROM orders
WHERE customer_name IS NOT NULL
  AND customer_name != ''
GROUP BY outlet_id, customer_name, customer_phone;

-- Category Performance View
CREATE OR REPLACE VIEW v_category_performance AS
SELECT
  c.id as category_id,
  c.outlet_id,
  c.name as category_name,
  COUNT(DISTINCT p.id) as total_products,
  COUNT(oi.id) as total_orders,
  SUM(oi.quantity) as total_quantity_sold,
  SUM(oi.subtotal) as total_revenue,
  AVG(oi.unit_price) as avg_product_price
FROM categories c
LEFT JOIN products p ON p.category_id = c.id AND p.is_active = true
LEFT JOIN order_items oi ON oi.product_id = p.id
LEFT JOIN orders o ON oi.order_id = o.id
  AND o.status = 'completed'
  AND o.created_at >= NOW() - INTERVAL '30 days'
WHERE c.is_active = true
GROUP BY c.id, c.outlet_id, c.name;

-- Comments
COMMENT ON VIEW v_daily_sales_summary IS 'Daily sales aggregates for trend analysis and MoM/YoY comparison';
COMMENT ON VIEW v_hourly_revenue_pattern IS 'Revenue patterns by hour and day of week for busy hour predictions';
COMMENT ON VIEW v_product_performance IS 'Product sales and profitability metrics with margin analysis';
COMMENT ON VIEW v_stock_alerts IS 'Real-time stock status and intelligent reorder alerts';
COMMENT ON VIEW v_customer_order_frequency IS 'Customer segmentation based on RFM (Recency, Frequency, Monetary) analysis';
COMMENT ON VIEW v_category_performance IS 'Category-level sales performance metrics';
-- ============================================================================
-- Migration: 036_ai_helper_functions.sql
-- Description: RPC functions for AI to get comprehensive business metrics
-- Author: Claude Code
-- Date: 2026-02-12
-- ============================================================================

-- Function: Get comprehensive business metrics for a time period
CREATE OR REPLACE FUNCTION get_business_metrics(
  p_outlet_id UUID,
  p_days_back INTEGER DEFAULT 30
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH metrics AS (
    SELECT
      COUNT(*) as total_orders,
      COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
      COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_orders,
      COUNT(*) FILTER (WHERE status = 'refunded') as refunded_orders,
      SUM(total) FILTER (WHERE status = 'completed') as total_revenue,
      SUM(subtotal) FILTER (WHERE status = 'completed') as subtotal_revenue,
      SUM(tax_amount) FILTER (WHERE status = 'completed') as total_tax,
      SUM(discount_amount) FILTER (WHERE status = 'completed') as total_discounts,
      AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
      COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '') as unique_customers,
      COUNT(DISTINCT DATE(created_at)) as days_with_sales
    FROM orders
    WHERE outlet_id = p_outlet_id
      AND created_at >= NOW() - (p_days_back || ' days')::INTERVAL
      AND created_at < NOW()
  )
  SELECT json_build_object(
    'period_days', p_days_back,
    'total_orders', COALESCE(total_orders, 0),
    'completed_orders', COALESCE(completed_orders, 0),
    'cancelled_orders', COALESCE(cancelled_orders, 0),
    'refunded_orders', COALESCE(refunded_orders, 0),
    'total_revenue', COALESCE(total_revenue, 0),
    'subtotal_revenue', COALESCE(subtotal_revenue, 0),
    'total_tax', COALESCE(total_tax, 0),
    'total_discounts', COALESCE(total_discounts, 0),
    'avg_order_value', COALESCE(avg_order_value, 0),
    'unique_customers', COALESCE(unique_customers, 0),
    'days_with_sales', COALESCE(days_with_sales, 0),
    'avg_daily_revenue', CASE
      WHEN days_with_sales > 0 THEN ROUND((total_revenue / days_with_sales)::NUMERIC, 2)
      ELSE 0
    END,
    'completion_rate', CASE
      WHEN total_orders > 0 THEN ROUND((completed_orders::DECIMAL / total_orders) * 100, 2)
      ELSE 0
    END,
    'cancellation_rate', CASE
      WHEN total_orders > 0 THEN ROUND((cancelled_orders::DECIMAL / total_orders) * 100, 2)
      ELSE 0
    END
  ) INTO result
  FROM metrics;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Compare current period vs previous period (MoM, WoW, etc.)
CREATE OR REPLACE FUNCTION compare_period_performance(
  p_outlet_id UUID,
  p_current_days INTEGER DEFAULT 7,
  p_comparison_days INTEGER DEFAULT 7
)
RETURNS JSON AS $$
DECLARE
  current_metrics JSON;
  comparison_metrics JSON;
  result JSON;
BEGIN
  -- Current period metrics
  SELECT json_build_object(
    'revenue', COALESCE(SUM(total) FILTER (WHERE status = 'completed'), 0),
    'orders', COUNT(*) FILTER (WHERE status = 'completed'),
    'avg_order', COALESCE(AVG(total) FILTER (WHERE status = 'completed'), 0),
    'unique_customers', COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '')
  ) INTO current_metrics
  FROM orders
  WHERE outlet_id = p_outlet_id
    AND created_at >= NOW() - (p_current_days || ' days')::INTERVAL;

  -- Comparison period metrics (previous period)
  SELECT json_build_object(
    'revenue', COALESCE(SUM(total) FILTER (WHERE status = 'completed'), 0),
    'orders', COUNT(*) FILTER (WHERE status = 'completed'),
    'avg_order', COALESCE(AVG(total) FILTER (WHERE status = 'completed'), 0),
    'unique_customers', COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '')
  ) INTO comparison_metrics
  FROM orders
  WHERE outlet_id = p_outlet_id
    AND created_at >= NOW() - ((p_current_days + p_comparison_days) || ' days')::INTERVAL
    AND created_at < NOW() - (p_current_days || ' days')::INTERVAL;

  -- Calculate growth percentages
  SELECT json_build_object(
    'current_period', current_metrics,
    'previous_period', comparison_metrics,
    'revenue_growth_pct', CASE
      WHEN (comparison_metrics->>'revenue')::DECIMAL > 0
      THEN ROUND((((current_metrics->>'revenue')::DECIMAL - (comparison_metrics->>'revenue')::DECIMAL) / (comparison_metrics->>'revenue')::DECIMAL) * 100, 2)
      ELSE NULL
    END,
    'order_growth_pct', CASE
      WHEN (comparison_metrics->>'orders')::INTEGER > 0
      THEN ROUND((((current_metrics->>'orders')::INTEGER - (comparison_metrics->>'orders')::INTEGER)::DECIMAL / (comparison_metrics->>'orders')::INTEGER) * 100, 2)
      ELSE NULL
    END,
    'avg_order_growth_pct', CASE
      WHEN (comparison_metrics->>'avg_order')::DECIMAL > 0
      THEN ROUND((((current_metrics->>'avg_order')::DECIMAL - (comparison_metrics->>'avg_order')::DECIMAL) / (comparison_metrics->>'avg_order')::DECIMAL) * 100, 2)
      ELSE NULL
    END,
    'customer_growth_pct', CASE
      WHEN (comparison_metrics->>'unique_customers')::INTEGER > 0
      THEN ROUND((((current_metrics->>'unique_customers')::INTEGER - (comparison_metrics->>'unique_customers')::INTEGER)::DECIMAL / (comparison_metrics->>'unique_customers')::INTEGER) * 100, 2)
      ELSE NULL
    END,
    'trend', CASE
      WHEN (comparison_metrics->>'revenue')::DECIMAL > 0 THEN
        CASE
          WHEN ((current_metrics->>'revenue')::DECIMAL - (comparison_metrics->>'revenue')::DECIMAL) / (comparison_metrics->>'revenue')::DECIMAL >= 0.1 THEN 'GROWING'
          WHEN ((current_metrics->>'revenue')::DECIMAL - (comparison_metrics->>'revenue')::DECIMAL) / (comparison_metrics->>'revenue')::DECIMAL <= -0.1 THEN 'DECLINING'
          ELSE 'STABLE'
        END
      ELSE 'INSUFFICIENT_DATA'
    END
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get top performing products by various metrics
CREATE OR REPLACE FUNCTION get_top_products(
  p_outlet_id UUID,
  p_metric TEXT DEFAULT 'revenue', -- 'revenue', 'quantity', 'profit', 'margin'
  p_limit INTEGER DEFAULT 10,
  p_days_back INTEGER DEFAULT 30
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH product_stats AS (
    SELECT
      p.id,
      p.name,
      p.selling_price,
      p.cost_price,
      c.name as category_name,
      SUM(oi.quantity) as total_quantity,
      SUM(oi.subtotal) as total_revenue,
      COUNT(DISTINCT oi.order_id) as order_count,
      COALESCE(SUM(oi.subtotal) - (SUM(oi.quantity) * COALESCE(p.cost_price, 0)), 0) as total_profit,
      CASE
        WHEN SUM(oi.quantity) > 0 AND COALESCE(p.cost_price, 0) > 0
        THEN ((SUM(oi.subtotal) - (SUM(oi.quantity) * p.cost_price)) / SUM(oi.subtotal) * 100)
        ELSE 0
      END as profit_margin_pct
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN order_items oi ON oi.product_id = p.id
    LEFT JOIN orders o ON oi.order_id = o.id
      AND o.status = 'completed'
      AND o.outlet_id = p_outlet_id
      AND o.created_at >= NOW() - (p_days_back || ' days')::INTERVAL
    WHERE p.outlet_id = p_outlet_id
      AND p.is_active = true
    GROUP BY p.id, p.name, p.selling_price, p.cost_price, c.name
    HAVING SUM(oi.quantity) > 0
  ),
  ranked_products AS (
    SELECT
      id,
      name,
      selling_price,
      cost_price,
      category_name,
      total_quantity,
      total_revenue,
      total_profit,
      profit_margin_pct,
      order_count,
      CASE p_metric
        WHEN 'revenue' THEN total_revenue
        WHEN 'quantity' THEN total_quantity
        WHEN 'profit' THEN total_profit
        WHEN 'margin' THEN profit_margin_pct
        ELSE total_revenue
      END as sort_value
    FROM product_stats
    ORDER BY sort_value DESC
    LIMIT p_limit
  )
  SELECT json_agg(
    json_build_object(
      'product_id', id,
      'product_name', name,
      'category', category_name,
      'selling_price', selling_price,
      'cost_price', cost_price,
      'total_quantity', total_quantity,
      'total_revenue', total_revenue,
      'total_profit', total_profit,
      'profit_margin_pct', ROUND(profit_margin_pct::NUMERIC, 2),
      'order_count', order_count
    )
  ) INTO result
  FROM ranked_products;

  RETURN COALESCE(result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get customer insights and segmentation
CREATE OR REPLACE FUNCTION get_customer_insights(
  p_outlet_id UUID,
  p_days_back INTEGER DEFAULT 90
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH customer_stats AS (
    SELECT
      customer_name,
      customer_phone,
      COUNT(*) FILTER (WHERE status = 'completed') as total_orders,
      SUM(total) FILTER (WHERE status = 'completed') as lifetime_value,
      AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
      MAX(created_at) as last_order_date,
      EXTRACT(DAYS FROM (NOW() - MAX(created_at)))::INTEGER as days_since_last_order,
      CASE
        WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 10 THEN 'VIP'
        WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 5 THEN 'LOYAL'
        WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 2 THEN 'REPEAT'
        ELSE 'NEW'
      END as segment
    FROM orders
    WHERE outlet_id = p_outlet_id
      AND customer_name IS NOT NULL
      AND customer_name != ''
      AND created_at >= NOW() - (p_days_back || ' days')::INTERVAL
    GROUP BY customer_name, customer_phone
  ),
  top_customers_cte AS (
    SELECT
      customer_name as name,
      customer_phone as phone,
      total_orders as orders,
      lifetime_value,
      segment
    FROM customer_stats
    ORDER BY lifetime_value DESC
    LIMIT 10
  )
  SELECT json_build_object(
    'total_customers', (SELECT COUNT(*)::INTEGER FROM customer_stats),
    'vip_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'VIP')::INTEGER FROM customer_stats),
    'loyal_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'LOYAL')::INTEGER FROM customer_stats),
    'repeat_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'REPEAT')::INTEGER FROM customer_stats),
    'new_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'NEW')::INTEGER FROM customer_stats),
    'avg_lifetime_value', ROUND((SELECT AVG(lifetime_value) FROM customer_stats)::NUMERIC, 2),
    'avg_order_value', ROUND((SELECT AVG(avg_order_value) FROM customer_stats)::NUMERIC, 2),
    'top_customers', (SELECT json_agg(row_to_json(t)) FROM top_customers_cte t)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comments
COMMENT ON FUNCTION get_business_metrics IS 'Get comprehensive business metrics for a specified time period';
COMMENT ON FUNCTION compare_period_performance IS 'Compare current period vs previous period (WoW, MoM, etc.) with growth percentages';
COMMENT ON FUNCTION get_top_products IS 'Get top performing products by revenue, quantity, profit, or margin';
COMMENT ON FUNCTION get_customer_insights IS 'Get customer segmentation and insights (VIP, Loyal, Repeat, New)';
-- ============================================================================
-- Migration: 038_add_customer_phone.sql
-- Description: Add customer_phone column to orders table
-- Author: Claude Code
-- Date: 2026-02-12
-- ============================================================================

-- Add customer_phone column to orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_phone TEXT;

-- Add index for customer phone lookups
CREATE INDEX IF NOT EXISTS idx_orders_customer_phone ON orders(customer_phone);

COMMENT ON COLUMN orders.customer_phone IS 'Customer phone number for contact and analytics';
-- ============================================================================
-- Migration: 034_ai_memories_table.sql
-- Description: Persistent AI memory storage (replaces localStorage)
-- Author: Claude Code
-- Date: 2026-02-12
-- ============================================================================

-- Create AI memories table for persistent storage across sessions
CREATE TABLE IF NOT EXISTS ai_memories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  insight TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('sales', 'product', 'stock', 'customer', 'operational', 'general')),
  confidence DECIMAL(3,2) DEFAULT 0.80 CHECK (confidence >= 0 AND confidence <= 1),
  reinforce_count INTEGER DEFAULT 1,
  source TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_ai_memories_outlet ON ai_memories(outlet_id);
CREATE INDEX IF NOT EXISTS idx_ai_memories_category ON ai_memories(category);
CREATE INDEX IF NOT EXISTS idx_ai_memories_created ON ai_memories(created_at DESC);

-- RLS (Row Level Security) policies
ALTER TABLE ai_memories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view memories for their outlets"
  ON ai_memories FOR SELECT
  USING (
    outlet_id IN (
      SELECT outlet_id FROM staff WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert memories for their outlets"
  ON ai_memories FOR INSERT
  WITH CHECK (
    outlet_id IN (
      SELECT outlet_id FROM staff WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update memories for their outlets"
  ON ai_memories FOR UPDATE
  USING (
    outlet_id IN (
      SELECT outlet_id FROM staff WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete memories for their outlets"
  ON ai_memories FOR DELETE
  USING (
    outlet_id IN (
      SELECT outlet_id FROM staff WHERE user_id = auth.uid()
    )
  );

-- Comments
COMMENT ON TABLE ai_memories IS 'Persistent AI memory storage for business insights learned over time';
COMMENT ON COLUMN ai_memories.insight IS 'The business insight or pattern discovered by AI';
COMMENT ON COLUMN ai_memories.category IS 'Category of insight: sales, product, stock, customer, operational, general';
COMMENT ON COLUMN ai_memories.confidence IS 'Confidence level of this insight (0.0 to 1.0)';
COMMENT ON COLUMN ai_memories.reinforce_count IS 'How many times this insight has been reinforced';
-- ============================================================================
-- Migration: 038_add_customer_phone.sql
-- Description: Add customer_phone column to orders table
-- Author: Claude Code
-- Date: 2026-02-12
-- ============================================================================

-- Add customer_phone column to orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_phone TEXT;

-- Add index for customer phone lookups
CREATE INDEX IF NOT EXISTS idx_orders_customer_phone ON orders(customer_phone);

COMMENT ON COLUMN orders.customer_phone IS 'Customer phone number for contact and analytics';
-- ============================================================================
-- Migration: 035_analytics_views.sql
-- Description: Create analytics views for deep business intelligence
-- Author: Claude Code
-- Date: 2026-02-12
-- ============================================================================

-- Daily Sales Summary View - Aggregated daily metrics
CREATE OR REPLACE VIEW v_daily_sales_summary AS
SELECT
  outlet_id,
  DATE(created_at) as sale_date,
  COUNT(*) as total_orders,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
  COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_orders,
  COUNT(*) FILTER (WHERE status = 'refunded') as refunded_orders,
  SUM(total) FILTER (WHERE status = 'completed') as total_revenue,
  SUM(subtotal) FILTER (WHERE status = 'completed') as subtotal_revenue,
  SUM(tax_amount) FILTER (WHERE status = 'completed') as total_tax,
  SUM(discount_amount) FILTER (WHERE status = 'completed') as total_discounts,
  AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
  COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '') as unique_customers,
  ARRAY_AGG(DISTINCT payment_method) FILTER (WHERE status = 'completed') as payment_methods_used
FROM orders
GROUP BY outlet_id, DATE(created_at);

-- Hourly Revenue Pattern View - For predicting busy hours
CREATE OR REPLACE VIEW v_hourly_revenue_pattern AS
SELECT
  outlet_id,
  EXTRACT(HOUR FROM created_at)::INTEGER as hour_of_day,
  EXTRACT(DOW FROM created_at)::INTEGER as day_of_week, -- 0=Sunday, 6=Saturday
  COUNT(*) as order_count,
  SUM(total) FILTER (WHERE status = 'completed') as revenue,
  AVG(total) FILTER (WHERE status = 'completed') as avg_order_value
FROM orders
WHERE created_at >= NOW() - INTERVAL '90 days'
GROUP BY outlet_id, EXTRACT(HOUR FROM created_at), EXTRACT(DOW FROM created_at);

-- Product Performance View - Sales and profitability (Last 30 days)
CREATE OR REPLACE VIEW v_product_performance AS
SELECT
  p.id as product_id,
  p.outlet_id,
  p.name as product_name,
  p.category_id,
  c.name as category_name,
  p.selling_price,
  p.cost_price,
  COUNT(oi.id) as times_ordered,
  SUM(oi.quantity) as total_quantity_sold,
  SUM(oi.subtotal) as total_revenue,
  AVG(oi.unit_price) as avg_selling_price,
  COALESCE(SUM(oi.subtotal) - (SUM(oi.quantity) * COALESCE(p.cost_price, 0)), 0) as total_profit,
  CASE
    WHEN SUM(oi.quantity) > 0 AND COALESCE(p.cost_price, 0) > 0
    THEN ROUND(((SUM(oi.subtotal) - (SUM(oi.quantity) * p.cost_price)) / SUM(oi.subtotal) * 100)::NUMERIC, 2)
    ELSE 0
  END as profit_margin_pct,
  MAX(o.created_at) as last_sold_at
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN order_items oi ON oi.product_id = p.id
LEFT JOIN orders o ON oi.order_id = o.id
  AND o.status = 'completed'
  AND o.created_at >= NOW() - INTERVAL '30 days'
WHERE p.is_active = true
GROUP BY p.id, p.outlet_id, p.name, p.category_id, c.name, p.selling_price, p.cost_price;

-- Stock Alert View - Real-time stock warnings
CREATE OR REPLACE VIEW v_stock_alerts AS
SELECT
  id,
  outlet_id,
  name as ingredient_name,
  current_stock,
  min_stock,
  max_stock,
  unit,
  base_unit,
  cost_per_unit,
  CASE
    WHEN current_stock <= 0 THEN 'OUT_OF_STOCK'
    WHEN current_stock <= min_stock * 0.5 THEN 'CRITICAL'
    WHEN current_stock <= min_stock THEN 'LOW'
    WHEN current_stock >= max_stock THEN 'OVERSTOCK'
    ELSE 'NORMAL'
  END as stock_status,
  CASE
    WHEN current_stock < min_stock THEN GREATEST(min_stock - current_stock, 0)
    ELSE 0
  END as reorder_quantity,
  category
FROM ingredients
WHERE is_active = true
ORDER BY
  CASE
    WHEN current_stock <= 0 THEN 1
    WHEN current_stock <= min_stock * 0.5 THEN 2
    WHEN current_stock <= min_stock THEN 3
    WHEN current_stock >= max_stock THEN 4
    ELSE 5
  END,
  name;

-- Customer Order Frequency - RFM Analysis basis
CREATE OR REPLACE VIEW v_customer_order_frequency AS
SELECT
  outlet_id,
  customer_name,
  customer_phone,
  COUNT(*) as total_orders,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
  SUM(total) FILTER (WHERE status = 'completed') as lifetime_value,
  AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
  MAX(created_at) as last_order_date,
  MIN(created_at) as first_order_date,
  EXTRACT(DAYS FROM (NOW() - MAX(created_at)))::INTEGER as days_since_last_order,
  CASE
    WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 10 THEN 'VIP'
    WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 5 THEN 'LOYAL'
    WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 2 THEN 'REPEAT'
    ELSE 'NEW'
  END as customer_segment,
  CASE
    WHEN EXTRACT(DAYS FROM (NOW() - MAX(created_at))) <= 7 THEN 'ACTIVE'
    WHEN EXTRACT(DAYS FROM (NOW() - MAX(created_at))) <= 30 THEN 'AT_RISK'
    WHEN EXTRACT(DAYS FROM (NOW() - MAX(created_at))) <= 90 THEN 'DORMANT'
    ELSE 'LOST'
  END as recency_status
FROM orders
WHERE customer_name IS NOT NULL
  AND customer_name != ''
GROUP BY outlet_id, customer_name, customer_phone;

-- Category Performance View
CREATE OR REPLACE VIEW v_category_performance AS
SELECT
  c.id as category_id,
  c.outlet_id,
  c.name as category_name,
  COUNT(DISTINCT p.id) as total_products,
  COUNT(oi.id) as total_orders,
  SUM(oi.quantity) as total_quantity_sold,
  SUM(oi.subtotal) as total_revenue,
  AVG(oi.unit_price) as avg_product_price
FROM categories c
LEFT JOIN products p ON p.category_id = c.id AND p.is_active = true
LEFT JOIN order_items oi ON oi.product_id = p.id
LEFT JOIN orders o ON oi.order_id = o.id
  AND o.status = 'completed'
  AND o.created_at >= NOW() - INTERVAL '30 days'
WHERE c.is_active = true
GROUP BY c.id, c.outlet_id, c.name;

-- Comments
COMMENT ON VIEW v_daily_sales_summary IS 'Daily sales aggregates for trend analysis and MoM/YoY comparison';
COMMENT ON VIEW v_hourly_revenue_pattern IS 'Revenue patterns by hour and day of week for busy hour predictions';
COMMENT ON VIEW v_product_performance IS 'Product sales and profitability metrics with margin analysis';
COMMENT ON VIEW v_stock_alerts IS 'Real-time stock status and intelligent reorder alerts';
COMMENT ON VIEW v_customer_order_frequency IS 'Customer segmentation based on RFM (Recency, Frequency, Monetary) analysis';
COMMENT ON VIEW v_category_performance IS 'Category-level sales performance metrics';
-- ============================================================================
-- Migration: 036_ai_helper_functions.sql
-- Description: RPC functions for AI to get comprehensive business metrics
-- Author: Claude Code
-- Date: 2026-02-12
-- ============================================================================

-- Function: Get comprehensive business metrics for a time period
CREATE OR REPLACE FUNCTION get_business_metrics(
  p_outlet_id UUID,
  p_days_back INTEGER DEFAULT 30
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH metrics AS (
    SELECT
      COUNT(*) as total_orders,
      COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
      COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_orders,
      COUNT(*) FILTER (WHERE status = 'refunded') as refunded_orders,
      SUM(total) FILTER (WHERE status = 'completed') as total_revenue,
      SUM(subtotal) FILTER (WHERE status = 'completed') as subtotal_revenue,
      SUM(tax_amount) FILTER (WHERE status = 'completed') as total_tax,
      SUM(discount_amount) FILTER (WHERE status = 'completed') as total_discounts,
      AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
      COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '') as unique_customers,
      COUNT(DISTINCT DATE(created_at)) as days_with_sales
    FROM orders
    WHERE outlet_id = p_outlet_id
      AND created_at >= NOW() - (p_days_back || ' days')::INTERVAL
      AND created_at < NOW()
  )
  SELECT json_build_object(
    'period_days', p_days_back,
    'total_orders', COALESCE(total_orders, 0),
    'completed_orders', COALESCE(completed_orders, 0),
    'cancelled_orders', COALESCE(cancelled_orders, 0),
    'refunded_orders', COALESCE(refunded_orders, 0),
    'total_revenue', COALESCE(total_revenue, 0),
    'subtotal_revenue', COALESCE(subtotal_revenue, 0),
    'total_tax', COALESCE(total_tax, 0),
    'total_discounts', COALESCE(total_discounts, 0),
    'avg_order_value', COALESCE(avg_order_value, 0),
    'unique_customers', COALESCE(unique_customers, 0),
    'days_with_sales', COALESCE(days_with_sales, 0),
    'avg_daily_revenue', CASE
      WHEN days_with_sales > 0 THEN ROUND((total_revenue / days_with_sales)::NUMERIC, 2)
      ELSE 0
    END,
    'completion_rate', CASE
      WHEN total_orders > 0 THEN ROUND((completed_orders::DECIMAL / total_orders) * 100, 2)
      ELSE 0
    END,
    'cancellation_rate', CASE
      WHEN total_orders > 0 THEN ROUND((cancelled_orders::DECIMAL / total_orders) * 100, 2)
      ELSE 0
    END
  ) INTO result
  FROM metrics;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Compare current period vs previous period (MoM, WoW, etc.)
CREATE OR REPLACE FUNCTION compare_period_performance(
  p_outlet_id UUID,
  p_current_days INTEGER DEFAULT 7,
  p_comparison_days INTEGER DEFAULT 7
)
RETURNS JSON AS $$
DECLARE
  current_metrics JSON;
  comparison_metrics JSON;
  result JSON;
BEGIN
  -- Current period metrics
  SELECT json_build_object(
    'revenue', COALESCE(SUM(total) FILTER (WHERE status = 'completed'), 0),
    'orders', COUNT(*) FILTER (WHERE status = 'completed'),
    'avg_order', COALESCE(AVG(total) FILTER (WHERE status = 'completed'), 0),
    'unique_customers', COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '')
  ) INTO current_metrics
  FROM orders
  WHERE outlet_id = p_outlet_id
    AND created_at >= NOW() - (p_current_days || ' days')::INTERVAL;

  -- Comparison period metrics (previous period)
  SELECT json_build_object(
    'revenue', COALESCE(SUM(total) FILTER (WHERE status = 'completed'), 0),
    'orders', COUNT(*) FILTER (WHERE status = 'completed'),
    'avg_order', COALESCE(AVG(total) FILTER (WHERE status = 'completed'), 0),
    'unique_customers', COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '')
  ) INTO comparison_metrics
  FROM orders
  WHERE outlet_id = p_outlet_id
    AND created_at >= NOW() - ((p_current_days + p_comparison_days) || ' days')::INTERVAL
    AND created_at < NOW() - (p_current_days || ' days')::INTERVAL;

  -- Calculate growth percentages
  SELECT json_build_object(
    'current_period', current_metrics,
    'previous_period', comparison_metrics,
    'revenue_growth_pct', CASE
      WHEN (comparison_metrics->>'revenue')::DECIMAL > 0
      THEN ROUND((((current_metrics->>'revenue')::DECIMAL - (comparison_metrics->>'revenue')::DECIMAL) / (comparison_metrics->>'revenue')::DECIMAL) * 100, 2)
      ELSE NULL
    END,
    'order_growth_pct', CASE
      WHEN (comparison_metrics->>'orders')::INTEGER > 0
      THEN ROUND((((current_metrics->>'orders')::INTEGER - (comparison_metrics->>'orders')::INTEGER)::DECIMAL / (comparison_metrics->>'orders')::INTEGER) * 100, 2)
      ELSE NULL
    END,
    'avg_order_growth_pct', CASE
      WHEN (comparison_metrics->>'avg_order')::DECIMAL > 0
      THEN ROUND((((current_metrics->>'avg_order')::DECIMAL - (comparison_metrics->>'avg_order')::DECIMAL) / (comparison_metrics->>'avg_order')::DECIMAL) * 100, 2)
      ELSE NULL
    END,
    'customer_growth_pct', CASE
      WHEN (comparison_metrics->>'unique_customers')::INTEGER > 0
      THEN ROUND((((current_metrics->>'unique_customers')::INTEGER - (comparison_metrics->>'unique_customers')::INTEGER)::DECIMAL / (comparison_metrics->>'unique_customers')::INTEGER) * 100, 2)
      ELSE NULL
    END,
    'trend', CASE
      WHEN (comparison_metrics->>'revenue')::DECIMAL > 0 THEN
        CASE
          WHEN ((current_metrics->>'revenue')::DECIMAL - (comparison_metrics->>'revenue')::DECIMAL) / (comparison_metrics->>'revenue')::DECIMAL >= 0.1 THEN 'GROWING'
          WHEN ((current_metrics->>'revenue')::DECIMAL - (comparison_metrics->>'revenue')::DECIMAL) / (comparison_metrics->>'revenue')::DECIMAL <= -0.1 THEN 'DECLINING'
          ELSE 'STABLE'
        END
      ELSE 'INSUFFICIENT_DATA'
    END
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get top performing products by various metrics
CREATE OR REPLACE FUNCTION get_top_products(
  p_outlet_id UUID,
  p_metric TEXT DEFAULT 'revenue', -- 'revenue', 'quantity', 'profit', 'margin'
  p_limit INTEGER DEFAULT 10,
  p_days_back INTEGER DEFAULT 30
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH product_stats AS (
    SELECT
      p.id,
      p.name,
      p.selling_price,
      p.cost_price,
      c.name as category_name,
      SUM(oi.quantity) as total_quantity,
      SUM(oi.subtotal) as total_revenue,
      COUNT(DISTINCT oi.order_id) as order_count,
      COALESCE(SUM(oi.subtotal) - (SUM(oi.quantity) * COALESCE(p.cost_price, 0)), 0) as total_profit,
      CASE
        WHEN SUM(oi.quantity) > 0 AND COALESCE(p.cost_price, 0) > 0
        THEN ((SUM(oi.subtotal) - (SUM(oi.quantity) * p.cost_price)) / SUM(oi.subtotal) * 100)
        ELSE 0
      END as profit_margin_pct
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN order_items oi ON oi.product_id = p.id
    LEFT JOIN orders o ON oi.order_id = o.id
      AND o.status = 'completed'
      AND o.outlet_id = p_outlet_id
      AND o.created_at >= NOW() - (p_days_back || ' days')::INTERVAL
    WHERE p.outlet_id = p_outlet_id
      AND p.is_active = true
    GROUP BY p.id, p.name, p.selling_price, p.cost_price, c.name
    HAVING SUM(oi.quantity) > 0
  ),
  ranked_products AS (
    SELECT
      id,
      name,
      selling_price,
      cost_price,
      category_name,
      total_quantity,
      total_revenue,
      total_profit,
      profit_margin_pct,
      order_count,
      CASE p_metric
        WHEN 'revenue' THEN total_revenue
        WHEN 'quantity' THEN total_quantity
        WHEN 'profit' THEN total_profit
        WHEN 'margin' THEN profit_margin_pct
        ELSE total_revenue
      END as sort_value
    FROM product_stats
    ORDER BY sort_value DESC
    LIMIT p_limit
  )
  SELECT json_agg(
    json_build_object(
      'product_id', id,
      'product_name', name,
      'category', category_name,
      'selling_price', selling_price,
      'cost_price', cost_price,
      'total_quantity', total_quantity,
      'total_revenue', total_revenue,
      'total_profit', total_profit,
      'profit_margin_pct', ROUND(profit_margin_pct::NUMERIC, 2),
      'order_count', order_count
    )
  ) INTO result
  FROM ranked_products;

  RETURN COALESCE(result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get customer insights and segmentation
CREATE OR REPLACE FUNCTION get_customer_insights(
  p_outlet_id UUID,
  p_days_back INTEGER DEFAULT 90
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH customer_stats AS (
    SELECT
      customer_name,
      customer_phone,
      COUNT(*) FILTER (WHERE status = 'completed') as total_orders,
      SUM(total) FILTER (WHERE status = 'completed') as lifetime_value,
      AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
      MAX(created_at) as last_order_date,
      EXTRACT(DAYS FROM (NOW() - MAX(created_at)))::INTEGER as days_since_last_order,
      CASE
        WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 10 THEN 'VIP'
        WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 5 THEN 'LOYAL'
        WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 2 THEN 'REPEAT'
        ELSE 'NEW'
      END as segment
    FROM orders
    WHERE outlet_id = p_outlet_id
      AND customer_name IS NOT NULL
      AND customer_name != ''
      AND created_at >= NOW() - (p_days_back || ' days')::INTERVAL
    GROUP BY customer_name, customer_phone
  ),
  top_customers_cte AS (
    SELECT
      customer_name as name,
      customer_phone as phone,
      total_orders as orders,
      lifetime_value,
      segment
    FROM customer_stats
    ORDER BY lifetime_value DESC
    LIMIT 10
  )
  SELECT json_build_object(
    'total_customers', (SELECT COUNT(*)::INTEGER FROM customer_stats),
    'vip_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'VIP')::INTEGER FROM customer_stats),
    'loyal_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'LOYAL')::INTEGER FROM customer_stats),
    'repeat_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'REPEAT')::INTEGER FROM customer_stats),
    'new_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'NEW')::INTEGER FROM customer_stats),
    'avg_lifetime_value', ROUND((SELECT AVG(lifetime_value) FROM customer_stats)::NUMERIC, 2),
    'avg_order_value', ROUND((SELECT AVG(avg_order_value) FROM customer_stats)::NUMERIC, 2),
    'top_customers', (SELECT json_agg(row_to_json(t)) FROM top_customers_cte t)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comments
COMMENT ON FUNCTION get_business_metrics IS 'Get comprehensive business metrics for a specified time period';
COMMENT ON FUNCTION compare_period_performance IS 'Compare current period vs previous period (WoW, MoM, etc.) with growth percentages';
COMMENT ON FUNCTION get_top_products IS 'Get top performing products by revenue, quantity, profit, or margin';
COMMENT ON FUNCTION get_customer_insights IS 'Get customer segmentation and insights (VIP, Loyal, Repeat, New)';
-- ============================================================================
-- AI Deep Upgrade - WITHOUT RLS (for databases without staff table)
-- ============================================================================

-- ============================================================================
-- 034: AI Memories Table (NO RLS VERSION)
-- ============================================================================

CREATE TABLE IF NOT EXISTS ai_memories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  insight TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('sales', 'product', 'stock', 'customer', 'operational', 'general')),
  confidence DECIMAL(3,2) DEFAULT 0.80 CHECK (confidence >= 0 AND confidence <= 1),
  reinforce_count INTEGER DEFAULT 1,
  source TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_ai_memories_outlet ON ai_memories(outlet_id);
CREATE INDEX IF NOT EXISTS idx_ai_memories_category ON ai_memories(category);
CREATE INDEX IF NOT EXISTS idx_ai_memories_created ON ai_memories(created_at DESC);

-- Comments
COMMENT ON TABLE ai_memories IS 'Persistent AI memory storage for business insights learned over time';
COMMENT ON COLUMN ai_memories.insight IS 'The business insight or pattern discovered by AI';
COMMENT ON COLUMN ai_memories.category IS 'Category of insight: sales, product, stock, customer, operational, general';
COMMENT ON COLUMN ai_memories.confidence IS 'Confidence level of this insight (0.0 to 1.0)';
COMMENT ON COLUMN ai_memories.reinforce_count IS 'How many times this insight has been reinforced';

-- ============================================================================
-- 038: Add Customer Phone Column
-- ============================================================================

ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_phone TEXT;
CREATE INDEX IF NOT EXISTS idx_orders_customer_phone ON orders(customer_phone);
COMMENT ON COLUMN orders.customer_phone IS 'Customer phone number for contact and analytics';

-- ============================================================================
-- 035: Analytics Views
-- ============================================================================

-- Daily Sales Summary View
CREATE OR REPLACE VIEW v_daily_sales_summary AS
SELECT
  outlet_id,
  DATE(created_at) as sale_date,
  COUNT(*) as total_orders,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
  COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_orders,
  COUNT(*) FILTER (WHERE status = 'refunded') as refunded_orders,
  SUM(total) FILTER (WHERE status = 'completed') as total_revenue,
  SUM(subtotal) FILTER (WHERE status = 'completed') as subtotal_revenue,
  SUM(tax_amount) FILTER (WHERE status = 'completed') as total_tax,
  SUM(discount_amount) FILTER (WHERE status = 'completed') as total_discounts,
  AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
  COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '') as unique_customers,
  ARRAY_AGG(DISTINCT payment_method) FILTER (WHERE status = 'completed') as payment_methods_used
FROM orders
GROUP BY outlet_id, DATE(created_at);

-- Hourly Revenue Pattern View
CREATE OR REPLACE VIEW v_hourly_revenue_pattern AS
SELECT
  outlet_id,
  EXTRACT(HOUR FROM created_at)::INTEGER as hour_of_day,
  EXTRACT(DOW FROM created_at)::INTEGER as day_of_week,
  COUNT(*) as order_count,
  SUM(total) FILTER (WHERE status = 'completed') as revenue,
  AVG(total) FILTER (WHERE status = 'completed') as avg_order_value
FROM orders
WHERE created_at >= NOW() - INTERVAL '90 days'
GROUP BY outlet_id, EXTRACT(HOUR FROM created_at), EXTRACT(DOW FROM created_at);

-- Product Performance View
CREATE OR REPLACE VIEW v_product_performance AS
SELECT
  p.id as product_id,
  p.outlet_id,
  p.name as product_name,
  p.category_id,
  c.name as category_name,
  p.selling_price,
  p.cost_price,
  COUNT(oi.id) as times_ordered,
  SUM(oi.quantity) as total_quantity_sold,
  SUM(oi.subtotal) as total_revenue,
  AVG(oi.unit_price) as avg_selling_price,
  COALESCE(SUM(oi.subtotal) - (SUM(oi.quantity) * COALESCE(p.cost_price, 0)), 0) as total_profit,
  CASE
    WHEN SUM(oi.quantity) > 0 AND COALESCE(p.cost_price, 0) > 0
    THEN ROUND(((SUM(oi.subtotal) - (SUM(oi.quantity) * p.cost_price)) / SUM(oi.subtotal) * 100)::NUMERIC, 2)
    ELSE 0
  END as profit_margin_pct,
  MAX(o.created_at) as last_sold_at
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN order_items oi ON oi.product_id = p.id
LEFT JOIN orders o ON oi.order_id = o.id
  AND o.status = 'completed'
  AND o.created_at >= NOW() - INTERVAL '30 days'
WHERE p.is_active = true
GROUP BY p.id, p.outlet_id, p.name, p.category_id, c.name, p.selling_price, p.cost_price;

-- Stock Alert View
CREATE OR REPLACE VIEW v_stock_alerts AS
SELECT
  id,
  outlet_id,
  name as ingredient_name,
  current_stock,
  min_stock,
  max_stock,
  unit,
  base_unit,
  cost_per_unit,
  CASE
    WHEN current_stock <= 0 THEN 'OUT_OF_STOCK'
    WHEN current_stock <= min_stock * 0.5 THEN 'CRITICAL'
    WHEN current_stock <= min_stock THEN 'LOW'
    WHEN current_stock >= max_stock THEN 'OVERSTOCK'
    ELSE 'NORMAL'
  END as stock_status,
  CASE
    WHEN current_stock < min_stock THEN GREATEST(min_stock - current_stock, 0)
    ELSE 0
  END as reorder_quantity,
  category
FROM ingredients
WHERE is_active = true
ORDER BY
  CASE
    WHEN current_stock <= 0 THEN 1
    WHEN current_stock <= min_stock * 0.5 THEN 2
    WHEN current_stock <= min_stock THEN 3
    WHEN current_stock >= max_stock THEN 4
    ELSE 5
  END,
  name;

-- Customer Order Frequency View
CREATE OR REPLACE VIEW v_customer_order_frequency AS
SELECT
  outlet_id,
  customer_name,
  customer_phone,
  COUNT(*) as total_orders,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
  SUM(total) FILTER (WHERE status = 'completed') as lifetime_value,
  AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
  MAX(created_at) as last_order_date,
  MIN(created_at) as first_order_date,
  EXTRACT(DAYS FROM (NOW() - MAX(created_at)))::INTEGER as days_since_last_order,
  CASE
    WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 10 THEN 'VIP'
    WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 5 THEN 'LOYAL'
    WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 2 THEN 'REPEAT'
    ELSE 'NEW'
  END as customer_segment,
  CASE
    WHEN EXTRACT(DAYS FROM (NOW() - MAX(created_at))) <= 7 THEN 'ACTIVE'
    WHEN EXTRACT(DAYS FROM (NOW() - MAX(created_at))) <= 30 THEN 'AT_RISK'
    WHEN EXTRACT(DAYS FROM (NOW() - MAX(created_at))) <= 90 THEN 'DORMANT'
    ELSE 'LOST'
  END as recency_status
FROM orders
WHERE customer_name IS NOT NULL
  AND customer_name != ''
GROUP BY outlet_id, customer_name, customer_phone;

-- Category Performance View
CREATE OR REPLACE VIEW v_category_performance AS
SELECT
  c.id as category_id,
  c.outlet_id,
  c.name as category_name,
  COUNT(DISTINCT p.id) as total_products,
  COUNT(oi.id) as total_orders,
  SUM(oi.quantity) as total_quantity_sold,
  SUM(oi.subtotal) as total_revenue,
  AVG(oi.unit_price) as avg_product_price
FROM categories c
LEFT JOIN products p ON p.category_id = c.id AND p.is_active = true
LEFT JOIN order_items oi ON oi.product_id = p.id
LEFT JOIN orders o ON oi.order_id = o.id
  AND o.status = 'completed'
  AND o.created_at >= NOW() - INTERVAL '30 days'
WHERE c.is_active = true
GROUP BY c.id, c.outlet_id, c.name;

-- Comments
COMMENT ON VIEW v_daily_sales_summary IS 'Daily sales aggregates for trend analysis';
COMMENT ON VIEW v_hourly_revenue_pattern IS 'Revenue patterns by hour and day of week';
COMMENT ON VIEW v_product_performance IS 'Product sales and profitability metrics';
COMMENT ON VIEW v_stock_alerts IS 'Real-time stock status and reorder alerts';
COMMENT ON VIEW v_customer_order_frequency IS 'Customer segmentation based on RFM analysis';
COMMENT ON VIEW v_category_performance IS 'Category-level sales performance';

-- ============================================================================
-- 036: AI Helper Functions
-- ============================================================================

-- Function: Get comprehensive business metrics
CREATE OR REPLACE FUNCTION get_business_metrics(
  p_outlet_id UUID,
  p_days_back INTEGER DEFAULT 30
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH metrics AS (
    SELECT
      COUNT(*) as total_orders,
      COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
      COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_orders,
      COUNT(*) FILTER (WHERE status = 'refunded') as refunded_orders,
      SUM(total) FILTER (WHERE status = 'completed') as total_revenue,
      SUM(subtotal) FILTER (WHERE status = 'completed') as subtotal_revenue,
      SUM(tax_amount) FILTER (WHERE status = 'completed') as total_tax,
      SUM(discount_amount) FILTER (WHERE status = 'completed') as total_discounts,
      AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
      COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '') as unique_customers,
      COUNT(DISTINCT DATE(created_at)) as days_with_sales
    FROM orders
    WHERE outlet_id = p_outlet_id
      AND created_at >= NOW() - (p_days_back || ' days')::INTERVAL
      AND created_at < NOW()
  )
  SELECT json_build_object(
    'period_days', p_days_back,
    'total_orders', COALESCE(total_orders, 0),
    'completed_orders', COALESCE(completed_orders, 0),
    'cancelled_orders', COALESCE(cancelled_orders, 0),
    'refunded_orders', COALESCE(refunded_orders, 0),
    'total_revenue', COALESCE(total_revenue, 0),
    'subtotal_revenue', COALESCE(subtotal_revenue, 0),
    'total_tax', COALESCE(total_tax, 0),
    'total_discounts', COALESCE(total_discounts, 0),
    'avg_order_value', COALESCE(avg_order_value, 0),
    'unique_customers', COALESCE(unique_customers, 0),
    'days_with_sales', COALESCE(days_with_sales, 0),
    'avg_daily_revenue', CASE
      WHEN days_with_sales > 0 THEN ROUND((total_revenue / days_with_sales)::NUMERIC, 2)
      ELSE 0
    END,
    'completion_rate', CASE
      WHEN total_orders > 0 THEN ROUND((completed_orders::DECIMAL / total_orders) * 100, 2)
      ELSE 0
    END,
    'cancellation_rate', CASE
      WHEN total_orders > 0 THEN ROUND((cancelled_orders::DECIMAL / total_orders) * 100, 2)
      ELSE 0
    END
  ) INTO result
  FROM metrics;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Compare period performance
CREATE OR REPLACE FUNCTION compare_period_performance(
  p_outlet_id UUID,
  p_current_days INTEGER DEFAULT 7,
  p_comparison_days INTEGER DEFAULT 7
)
RETURNS JSON AS $$
DECLARE
  current_metrics JSON;
  comparison_metrics JSON;
  result JSON;
BEGIN
  SELECT json_build_object(
    'revenue', COALESCE(SUM(total) FILTER (WHERE status = 'completed'), 0),
    'orders', COUNT(*) FILTER (WHERE status = 'completed'),
    'avg_order', COALESCE(AVG(total) FILTER (WHERE status = 'completed'), 0),
    'unique_customers', COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '')
  ) INTO current_metrics
  FROM orders
  WHERE outlet_id = p_outlet_id
    AND created_at >= NOW() - (p_current_days || ' days')::INTERVAL;

  SELECT json_build_object(
    'revenue', COALESCE(SUM(total) FILTER (WHERE status = 'completed'), 0),
    'orders', COUNT(*) FILTER (WHERE status = 'completed'),
    'avg_order', COALESCE(AVG(total) FILTER (WHERE status = 'completed'), 0),
    'unique_customers', COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '')
  ) INTO comparison_metrics
  FROM orders
  WHERE outlet_id = p_outlet_id
    AND created_at >= NOW() - ((p_current_days + p_comparison_days) || ' days')::INTERVAL
    AND created_at < NOW() - (p_current_days || ' days')::INTERVAL;

  SELECT json_build_object(
    'current_period', current_metrics,
    'previous_period', comparison_metrics,
    'revenue_growth_pct', CASE
      WHEN (comparison_metrics->>'revenue')::DECIMAL > 0
      THEN ROUND((((current_metrics->>'revenue')::DECIMAL - (comparison_metrics->>'revenue')::DECIMAL) / (comparison_metrics->>'revenue')::DECIMAL) * 100, 2)
      ELSE NULL
    END,
    'order_growth_pct', CASE
      WHEN (comparison_metrics->>'orders')::INTEGER > 0
      THEN ROUND((((current_metrics->>'orders')::INTEGER - (comparison_metrics->>'orders')::INTEGER)::DECIMAL / (comparison_metrics->>'orders')::INTEGER) * 100, 2)
      ELSE NULL
    END,
    'trend', CASE
      WHEN (comparison_metrics->>'revenue')::DECIMAL > 0 THEN
        CASE
          WHEN ((current_metrics->>'revenue')::DECIMAL - (comparison_metrics->>'revenue')::DECIMAL) / (comparison_metrics->>'revenue')::DECIMAL >= 0.1 THEN 'GROWING'
          WHEN ((current_metrics->>'revenue')::DECIMAL - (comparison_metrics->>'revenue')::DECIMAL) / (comparison_metrics->>'revenue')::DECIMAL <= -0.1 THEN 'DECLINING'
          ELSE 'STABLE'
        END
      ELSE 'INSUFFICIENT_DATA'
    END
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get top products
CREATE OR REPLACE FUNCTION get_top_products(
  p_outlet_id UUID,
  p_metric TEXT DEFAULT 'revenue',
  p_limit INTEGER DEFAULT 10,
  p_days_back INTEGER DEFAULT 30
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH product_stats AS (
    SELECT
      p.id,
      p.name,
      p.selling_price,
      p.cost_price,
      c.name as category_name,
      SUM(oi.quantity) as total_quantity,
      SUM(oi.subtotal) as total_revenue,
      COUNT(DISTINCT oi.order_id) as order_count,
      COALESCE(SUM(oi.subtotal) - (SUM(oi.quantity) * COALESCE(p.cost_price, 0)), 0) as total_profit,
      CASE
        WHEN SUM(oi.quantity) > 0 AND COALESCE(p.cost_price, 0) > 0
        THEN ((SUM(oi.subtotal) - (SUM(oi.quantity) * p.cost_price)) / SUM(oi.subtotal) * 100)
        ELSE 0
      END as profit_margin_pct
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN order_items oi ON oi.product_id = p.id
    LEFT JOIN orders o ON oi.order_id = o.id
      AND o.status = 'completed'
      AND o.outlet_id = p_outlet_id
      AND o.created_at >= NOW() - (p_days_back || ' days')::INTERVAL
    WHERE p.outlet_id = p_outlet_id
      AND p.is_active = true
    GROUP BY p.id, p.name, p.selling_price, p.cost_price, c.name
    HAVING SUM(oi.quantity) > 0
  ),
  ranked_products AS (
    SELECT
      id, name, selling_price, cost_price, category_name,
      total_quantity, total_revenue, total_profit, profit_margin_pct, order_count,
      CASE p_metric
        WHEN 'revenue' THEN total_revenue
        WHEN 'quantity' THEN total_quantity
        WHEN 'profit' THEN total_profit
        WHEN 'margin' THEN profit_margin_pct
        ELSE total_revenue
      END as sort_value
    FROM product_stats
    ORDER BY sort_value DESC
    LIMIT p_limit
  )
  SELECT json_agg(
    json_build_object(
      'product_id', id,
      'product_name', name,
      'category', category_name,
      'selling_price', selling_price,
      'cost_price', cost_price,
      'total_quantity', total_quantity,
      'total_revenue', total_revenue,
      'total_profit', total_profit,
      'profit_margin_pct', ROUND(profit_margin_pct::NUMERIC, 2),
      'order_count', order_count
    )
  ) INTO result
  FROM ranked_products;

  RETURN COALESCE(result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get customer insights
CREATE OR REPLACE FUNCTION get_customer_insights(
  p_outlet_id UUID,
  p_days_back INTEGER DEFAULT 90
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH customer_stats AS (
    SELECT
      customer_name, customer_phone,
      COUNT(*) FILTER (WHERE status = 'completed') as total_orders,
      SUM(total) FILTER (WHERE status = 'completed') as lifetime_value,
      AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
      MAX(created_at) as last_order_date,
      EXTRACT(DAYS FROM (NOW() - MAX(created_at)))::INTEGER as days_since_last_order,
      CASE
        WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 10 THEN 'VIP'
        WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 5 THEN 'LOYAL'
        WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 2 THEN 'REPEAT'
        ELSE 'NEW'
      END as segment
    FROM orders
    WHERE outlet_id = p_outlet_id
      AND customer_name IS NOT NULL
      AND customer_name != ''
      AND created_at >= NOW() - (p_days_back || ' days')::INTERVAL
    GROUP BY customer_name, customer_phone
  ),
  top_customers_cte AS (
    SELECT
      customer_name as name, customer_phone as phone,
      total_orders as orders, lifetime_value, segment
    FROM customer_stats
    ORDER BY lifetime_value DESC
    LIMIT 10
  )
  SELECT json_build_object(
    'total_customers', (SELECT COUNT(*)::INTEGER FROM customer_stats),
    'vip_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'VIP')::INTEGER FROM customer_stats),
    'loyal_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'LOYAL')::INTEGER FROM customer_stats),
    'repeat_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'REPEAT')::INTEGER FROM customer_stats),
    'new_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'NEW')::INTEGER FROM customer_stats),
    'avg_lifetime_value', ROUND((SELECT AVG(lifetime_value) FROM customer_stats)::NUMERIC, 2),
    'avg_order_value', ROUND((SELECT AVG(avg_order_value) FROM customer_stats)::NUMERIC, 2),
    'top_customers', (SELECT json_agg(row_to_json(t)) FROM top_customers_cte t)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comments
COMMENT ON FUNCTION get_business_metrics IS 'Get comprehensive business metrics for a time period';
COMMENT ON FUNCTION compare_period_performance IS 'Compare current vs previous period with growth percentages';
COMMENT ON FUNCTION get_top_products IS 'Get top performing products by revenue, quantity, profit, or margin';
COMMENT ON FUNCTION get_customer_insights IS 'Get customer segmentation and insights (VIP, Loyal, Repeat, New)';
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
