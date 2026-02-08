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
