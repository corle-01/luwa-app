-- Migration 021: Purchasing/Expense Tracking System
-- Created: 2026-02-09

CREATE TABLE IF NOT EXISTS purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL,
  supplier_id UUID,
  supplier_name TEXT NOT NULL DEFAULT '',
  pic_name TEXT NOT NULL DEFAULT '',
  payment_source TEXT NOT NULL DEFAULT 'kas_kasir' CHECK (payment_source IN ('kas_kasir', 'uang_luar')),
  payment_detail TEXT,
  shift_id UUID,
  receipt_image_url TEXT,
  total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes TEXT,
  purchase_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS purchase_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
  ingredient_id UUID,
  item_name TEXT NOT NULL,
  quantity NUMERIC(12,3) NOT NULL DEFAULT 0,
  unit TEXT NOT NULL DEFAULT 'pcs',
  unit_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_price NUMERIC(12,2) NOT NULL DEFAULT 0
);

ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_select_purchases" ON purchases FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_purchases" ON purchases FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_purchases" ON purchases FOR UPDATE TO anon USING (true);
CREATE POLICY "anon_delete_purchases" ON purchases FOR DELETE TO anon USING (true);

CREATE POLICY "anon_select_purchase_items" ON purchase_items FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_purchase_items" ON purchase_items FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_purchase_items" ON purchase_items FOR UPDATE TO anon USING (true);
CREATE POLICY "anon_delete_purchase_items" ON purchase_items FOR DELETE TO anon USING (true);

CREATE OR REPLACE FUNCTION auto_stock_in_on_purchase()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO stock_movements (ingredient_id, outlet_id, quantity, type, notes)
  SELECT
    pi.ingredient_id,
    NEW.outlet_id,
    pi.quantity,
    'purchase',
    'Pembelian: ' || pi.item_name || ' (' || LEFT(NEW.id::text, 8) || ')'
  FROM purchase_items pi
  WHERE pi.purchase_id = NEW.id
    AND pi.ingredient_id IS NOT NULL;

  UPDATE ingredients i
  SET current_stock = i.current_stock + pi.quantity,
      updated_at = NOW()
  FROM purchase_items pi
  WHERE pi.purchase_id = NEW.id
    AND pi.ingredient_id = i.id
    AND pi.ingredient_id IS NOT NULL;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_stock_in_purchase ON purchases;
CREATE TRIGGER trg_auto_stock_in_purchase
  AFTER INSERT ON purchases
  FOR EACH ROW
  EXECUTE FUNCTION auto_stock_in_on_purchase();

CREATE INDEX IF NOT EXISTS idx_purchases_outlet_id ON purchases(outlet_id);
CREATE INDEX IF NOT EXISTS idx_purchases_purchase_date ON purchases(purchase_date);
CREATE INDEX IF NOT EXISTS idx_purchases_supplier_id ON purchases(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase_id ON purchase_items(purchase_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_ingredient_id ON purchase_items(ingredient_id);
