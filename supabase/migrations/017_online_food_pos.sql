-- ============================================================
-- Migration 017: Online Food POS - Manual Order Input
-- ============================================================

-- Add columns to orders table for online food tracking
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_source TEXT DEFAULT 'dine_in';
-- values: 'dine_in', 'takeaway', 'gofood', 'grabfood', 'shopeefood'

ALTER TABLE orders ADD COLUMN IF NOT EXISTS platform_order_id TEXT;
-- order number from platform, e.g. "F-123456789"

ALTER TABLE orders ADD COLUMN IF NOT EXISTS platform_final_amount DECIMAL(12,2);
-- actual amount received from platform after all deductions

ALTER TABLE orders ADD COLUMN IF NOT EXISTS platform_notes TEXT;
-- optional notes, e.g. driver name
