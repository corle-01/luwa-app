-- ============================================================
-- Migration 012: Self-Order Support
-- Adds source column to orders for tracking order origin
-- ============================================================

-- Add source column to orders (pos, self_order, online, etc.)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'pos';

-- Index for filtering by source
CREATE INDEX IF NOT EXISTS idx_orders_source ON orders(source);
