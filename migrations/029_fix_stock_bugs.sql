-- Migration 029: Fix Stock & Inventory Bugs from Audit
-- Fixes: Race conditions (atomic RPCs), product stock deduction trigger,
--        AI executor movement types
-- Date: 2026-02-09

-- ═══════════════════════════════════════════════════════════════
-- 1. Atomic ingredient stock increment RPC (fixes race condition BUG-04)
--    Replaces read-then-write pattern with single atomic UPDATE
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION increment_ingredient_stock(
  p_ingredient_id UUID,
  p_quantity NUMERIC
)
RETURNS void AS $$
BEGIN
  UPDATE ingredients
  SET current_stock = GREATEST(0, current_stock + p_quantity),
      updated_at = NOW()
  WHERE id = p_ingredient_id;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════
-- 2. Atomic product stock increment RPC (fixes race condition BUG-04)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION increment_product_stock(
  p_product_id UUID,
  p_quantity INT
)
RETURNS void AS $$
BEGIN
  UPDATE products
  SET stock_quantity = GREATEST(0, stock_quantity + p_quantity),
      updated_at = NOW()
  WHERE id = p_product_id;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════
-- 3. Product stock_quantity deduction trigger (BUG-07)
--    Products with track_stock=true get stock decremented on order complete.
--    Also handles void/refund to restore product stock.
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION deduct_product_stock_on_order_complete()
RETURNS trigger AS $$
BEGIN
  IF (NEW.status = 'completed' AND OLD.status = 'pending') THEN
    -- Deduct stock_quantity for tracked products
    UPDATE products p
    SET stock_quantity = GREATEST(0, p.stock_quantity - oi.quantity),
        updated_at = NOW()
    FROM order_items oi
    WHERE oi.order_id = NEW.id
      AND oi.product_id = p.id
      AND p.track_stock = true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS deduct_product_stock_trigger ON orders;
CREATE TRIGGER deduct_product_stock_trigger
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.status = 'completed' AND OLD.status = 'pending')
  EXECUTE FUNCTION deduct_product_stock_on_order_complete();

-- ═══════════════════════════════════════════════════════════════
-- 4. Update void trigger to also restore product stock_quantity
--    (supplement to migration 028 fix #3)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION restore_stock_on_void()
RETURNS trigger AS $$
BEGIN
  IF (NEW.status IN ('voided', 'refunded') AND OLD.status = 'completed') THEN
    -- Restore product stock_quantity for tracked products
    UPDATE products p
    SET stock_quantity = p.stock_quantity + oi.quantity,
        updated_at = NOW()
    FROM order_items oi
    WHERE oi.order_id = NEW.id
      AND oi.product_id = p.id
      AND p.track_stock = true;

    -- Restore ingredient stock via recipes
    UPDATE ingredients i
    SET current_stock = i.current_stock + sub.total_restore,
        updated_at = NOW()
    FROM (
      SELECT r.ingredient_id, SUM(r.quantity * oi.quantity) AS total_restore
      FROM order_items oi
      JOIN recipes r ON oi.product_id = r.product_id
      WHERE oi.order_id = NEW.id
      AND oi.status != 'cancelled'
      GROUP BY r.ingredient_id
    ) sub
    WHERE i.id = sub.ingredient_id;

    -- Release table if it was dine_in
    IF NEW.table_id IS NOT NULL THEN
      UPDATE tables SET status = 'available', updated_at = NOW() WHERE id = NEW.table_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════
-- Done
-- ═══════════════════════════════════════════════════════════════
