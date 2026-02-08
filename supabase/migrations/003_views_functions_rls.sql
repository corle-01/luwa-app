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
