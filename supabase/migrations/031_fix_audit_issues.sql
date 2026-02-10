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
