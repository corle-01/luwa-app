-- Migration 028: Fix Critical Bugs from Code Audit
-- Fixes: CHECK constraints, void trigger, self-order completion
-- Date: 2026-02-09

-- ═══════════════════════════════════════════════════════════════
-- 1. Fix payment_method CHECK constraint
--    Original: 'cash', 'card', 'qris', 'ewallet', 'bank_transfer', 'split'
--    Missing:  'e_wallet', 'platform', 'gofood', 'grabfood', 'shopeefood'
-- ═══════════════════════════════════════════════════════════════

-- Drop the existing constraint and recreate with all valid values
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;
ALTER TABLE orders ADD CONSTRAINT orders_payment_method_check
  CHECK (payment_method IN (
    'cash', 'card', 'qris', 'ewallet', 'e_wallet', 'bank_transfer',
    'split', 'platform', 'gofood', 'grabfood', 'shopeefood'
  ));

-- Fix any existing 'ewallet' → keep as-is (both spellings allowed now)

-- ═══════════════════════════════════════════════════════════════
-- 2. Fix movement_type CHECK constraint
--    Original: 'stock_in','stock_out','adjustment','auto_deduct',
--              'transfer','waste','return','purchase_order'
--    Missing:  'purchase' (used by purchase trigger in migration 021)
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE stock_movements DROP CONSTRAINT IF EXISTS stock_movements_movement_type_check;
ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_movement_type_check
  CHECK (movement_type IN (
    'stock_in', 'stock_out', 'adjustment', 'auto_deduct',
    'transfer', 'waste', 'return', 'purchase_order', 'purchase'
  ));

-- ═══════════════════════════════════════════════════════════════
-- 3. Fix void trigger: products.quantity → products.stock_quantity
--    The restore_stock_on_void() function references p.quantity
--    but the actual column is stock_quantity (from migration 018)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION restore_stock_on_void()
RETURNS trigger AS $$
BEGIN
  IF (NEW.status IN ('voided', 'refunded') AND OLD.status = 'completed') THEN
    -- Restore product stock quantities from order_items
    UPDATE products p
    SET stock_quantity = p.stock_quantity + oi.quantity,
        updated_at = NOW()
    FROM order_items oi
    WHERE oi.order_id = NEW.id AND oi.product_id = p.id;

    -- Also restore ingredient stock via recipes
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

-- Recreate trigger (function replacement is enough, but ensure trigger exists)
DROP TRIGGER IF EXISTS restore_stock_on_void_trigger ON orders;
CREATE TRIGGER restore_stock_on_void_trigger
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.status IN ('voided', 'refunded') AND OLD.status = 'completed')
  EXECUTE FUNCTION restore_stock_on_void();

-- ═══════════════════════════════════════════════════════════════
-- 4. Add payment_details column if not exists (for split payment JSONB)
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_details JSONB;

-- ═══════════════════════════════════════════════════════════════
-- 5. Fix orders status CHECK constraint
--    Original: 'draft','pending','preparing','ready','completed','cancelled','refunded'
--    Missing:  'voided', 'served', 'pending_sync'
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE orders ADD CONSTRAINT orders_status_check
  CHECK (status IN (
    'draft', 'pending', 'preparing', 'ready', 'served',
    'completed', 'cancelled', 'refunded', 'voided', 'pending_sync'
  ));

-- ═══════════════════════════════════════════════════════════════
-- Done
-- ═══════════════════════════════════════════════════════════════
