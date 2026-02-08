-- ============================================================
-- Migration 010: Loyalty Program
-- Adds loyalty_programs columns and loyalty_transactions table
-- ============================================================

-- Add missing columns to loyalty_programs (table may already exist from schema)
ALTER TABLE loyalty_programs ADD COLUMN IF NOT EXISTS amount_per_point DECIMAL(12,2) DEFAULT 10000;
ALTER TABLE loyalty_programs ADD COLUMN IF NOT EXISTS min_redeem_points INT DEFAULT 10;
ALTER TABLE loyalty_programs ADD COLUMN IF NOT EXISTS redeem_value DECIMAL(12,2) DEFAULT 10000;

-- Loyalty transactions table (earn/redeem history)
CREATE TABLE IF NOT EXISTS loyalty_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  program_id UUID REFERENCES loyalty_programs(id),
  order_id UUID REFERENCES orders(id),
  type TEXT NOT NULL, -- 'earn' or 'redeem'
  points INT NOT NULL,
  amount DECIMAL(12,2) DEFAULT 0, -- related transaction amount
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE loyalty_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_transactions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_loyalty_programs') THEN
    CREATE POLICY anon_select_loyalty_programs ON loyalty_programs FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_loyalty_programs') THEN
    CREATE POLICY anon_insert_loyalty_programs ON loyalty_programs FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_loyalty_programs') THEN
    CREATE POLICY anon_update_loyalty_programs ON loyalty_programs FOR UPDATE TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_delete_loyalty_programs') THEN
    CREATE POLICY anon_delete_loyalty_programs ON loyalty_programs FOR DELETE TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_loyalty_tx') THEN
    CREATE POLICY anon_select_loyalty_tx ON loyalty_transactions FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_loyalty_tx') THEN
    CREATE POLICY anon_insert_loyalty_tx ON loyalty_transactions FOR INSERT TO anon WITH CHECK (true);
  END IF;
END $$;

-- Seed default loyalty program
INSERT INTO loyalty_programs (outlet_id, name, description, points_per_amount, amount_per_point, min_redeem_points, redeem_value)
SELECT 'a0000000-0000-0000-0000-000000000001', 'Program Loyalitas Utter', 'Setiap pembelian Rp 10.000 mendapat 1 poin', 1, 10000, 10, 10000
WHERE NOT EXISTS (SELECT 1 FROM loyalty_programs WHERE outlet_id = 'a0000000-0000-0000-0000-000000000001' AND name = 'Program Loyalitas Utter');
