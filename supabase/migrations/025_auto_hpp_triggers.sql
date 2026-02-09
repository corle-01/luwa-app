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
