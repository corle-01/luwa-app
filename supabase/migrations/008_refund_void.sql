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
