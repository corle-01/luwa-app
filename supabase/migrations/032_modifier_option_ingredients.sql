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
