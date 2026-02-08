-- ============================================================
-- UTTER APP - Database Migration 006: Inventory Tables
-- ============================================================
-- Run this AFTER 005_staff_rpc.sql
-- Adds ingredients and stock_movements tables for inventory management
-- ============================================================

-- ============================================================
-- 1. Ingredients Table
-- ============================================================
CREATE TABLE IF NOT EXISTS ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  name TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT 'pcs',
  current_stock NUMERIC NOT NULL DEFAULT 0,
  min_stock NUMERIC NOT NULL DEFAULT 0,
  cost_per_unit NUMERIC NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 2. Stock Movements Table
-- ============================================================
CREATE TABLE IF NOT EXISTS stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  movement_type TEXT NOT NULL DEFAULT 'purchase',
  quantity NUMERIC NOT NULL,
  notes TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 3. RLS
-- ============================================================
ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;

-- Anon policies
CREATE POLICY IF NOT EXISTS "Allow anon read ingredients" ON ingredients FOR SELECT TO anon USING (true);
CREATE POLICY IF NOT EXISTS "Allow anon insert ingredients" ON ingredients FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "Allow anon update ingredients" ON ingredients FOR UPDATE TO anon USING (true);

CREATE POLICY IF NOT EXISTS "Allow anon read stock_movements" ON stock_movements FOR SELECT TO anon USING (true);
CREATE POLICY IF NOT EXISTS "Allow anon insert stock_movements" ON stock_movements FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "Allow anon update stock_movements" ON stock_movements FOR UPDATE TO anon USING (true);

-- ============================================================
-- 4. Seed Sample Ingredients
-- ============================================================
INSERT INTO ingredients (outlet_id, name, unit, current_stock, min_stock, cost_per_unit) VALUES
('a0000000-0000-0000-0000-000000000001', 'Biji Kopi Arabica', 'kg', 15.5, 5, 120000),
('a0000000-0000-0000-0000-000000000001', 'Susu Full Cream', 'liter', 20, 10, 18000),
('a0000000-0000-0000-0000-000000000001', 'Gula Pasir', 'kg', 8, 3, 15000),
('a0000000-0000-0000-0000-000000000001', 'Sirup Vanilla', 'botol', 4, 2, 85000),
('a0000000-0000-0000-0000-000000000001', 'Whipped Cream', 'kaleng', 6, 3, 45000),
('a0000000-0000-0000-0000-000000000001', 'Cokelat Bubuk', 'kg', 3, 2, 95000),
('a0000000-0000-0000-0000-000000000001', 'Cup Plastik 16oz', 'pcs', 150, 50, 800),
('a0000000-0000-0000-0000-000000000001', 'Sedotan', 'pcs', 200, 100, 200);
