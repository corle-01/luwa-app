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

-- Auto stock-in per purchase item (fires per item row, not per purchase)
CREATE OR REPLACE FUNCTION auto_stock_in_on_purchase_item()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.ingredient_id IS NOT NULL THEN
    -- Create stock movement with correct column name
    INSERT INTO stock_movements (ingredient_id, outlet_id, movement_type, quantity, notes)
    SELECT
      NEW.ingredient_id,
      p.outlet_id,
      'purchase',
      NEW.quantity,
      'Pembelian: ' || NEW.item_name || ' (' || LEFT(NEW.purchase_id::text, 8) || ')'
    FROM purchases p
    WHERE p.id = NEW.purchase_id;

    -- Update ingredient stock
    UPDATE ingredients
    SET current_stock = current_stock + NEW.quantity,
        updated_at = NOW()
    WHERE id = NEW.ingredient_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_stock_in_purchase_item ON purchase_items;
CREATE TRIGGER trg_auto_stock_in_purchase_item
  AFTER INSERT ON purchase_items
  FOR EACH ROW
  EXECUTE FUNCTION auto_stock_in_on_purchase_item();

CREATE INDEX IF NOT EXISTS idx_purchases_outlet_id ON purchases(outlet_id);
CREATE INDEX IF NOT EXISTS idx_purchases_purchase_date ON purchases(purchase_date);
CREATE INDEX IF NOT EXISTS idx_purchases_supplier_id ON purchases(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase_id ON purchase_items(purchase_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_ingredient_id ON purchase_items(ingredient_id);
