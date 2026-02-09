-- ============================================================
-- 028: Operational Costs for HPP calculation
-- Stores monthly fixed costs (rent, utilities, labor etc.)
-- Auto-allocated to HPP per product based on sales volume
-- ============================================================

CREATE TABLE IF NOT EXISTS operational_costs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  category TEXT NOT NULL DEFAULT 'operational',  -- 'operational' or 'labor'
  name TEXT NOT NULL,
  amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  is_monthly BOOLEAN DEFAULT true,
  is_active BOOLEAN DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_operational_costs_outlet
  ON operational_costs(outlet_id, is_active);

-- RLS
ALTER TABLE operational_costs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_select_operational_costs" ON operational_costs
  FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_operational_costs" ON operational_costs
  FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_operational_costs" ON operational_costs
  FOR UPDATE TO anon USING (true);
CREATE POLICY "anon_delete_operational_costs" ON operational_costs
  FOR DELETE TO anon USING (true);

-- Seed some common cost items for outlet a0000000-0000-0000-0000-000000000001
INSERT INTO operational_costs (outlet_id, category, name, amount, notes) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'operational', 'Sewa Tempat', 0, 'Biaya sewa per bulan'),
  ('a0000000-0000-0000-0000-000000000001', 'operational', 'Listrik', 0, 'Tagihan listrik bulanan'),
  ('a0000000-0000-0000-0000-000000000001', 'operational', 'Gas', 0, 'LPG / gas alam'),
  ('a0000000-0000-0000-0000-000000000001', 'operational', 'Air (PDAM)', 0, 'Tagihan air bulanan'),
  ('a0000000-0000-0000-0000-000000000001', 'operational', 'Internet', 0, 'WiFi / internet bulanan'),
  ('a0000000-0000-0000-0000-000000000001', 'labor', 'Gaji Karyawan', 0, 'Total gaji semua karyawan per bulan'),
  ('a0000000-0000-0000-0000-000000000001', 'labor', 'BPJS / Asuransi', 0, 'Iuran BPJS karyawan');
