-- ============================================================
-- 018: Split Payment / Partial Payment Support
-- ============================================================
-- Add payment_details JSONB column to store split payment breakdown
-- Format: [{"method": "cash", "amount": 50000}, {"method": "qris", "amount": 30000}]

ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_details JSONB;

-- Update payment_method constraint to include 'split' and 'e_wallet'
-- (drop old constraint first, then re-add with expanded list)
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;
ALTER TABLE orders ADD CONSTRAINT orders_payment_method_check
  CHECK (payment_method IN ('cash', 'card', 'qris', 'ewallet', 'e_wallet', 'bank_transfer', 'split'));
