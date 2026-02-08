-- ============================================================
-- UTTER APP - Database Migration 018: Product Stock (Stok Produk Jadi)
-- ============================================================
-- Run this AFTER 017_online_food_pos.sql
-- Adds finished goods stock tracking to products table
-- Creates product_stock_movements table for stock history
-- ============================================================

-- ============================================================
-- 1. Add stock columns to products table
-- ============================================================
ALTER TABLE products ADD COLUMN IF NOT EXISTS stock_quantity INT NOT NULL DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS min_stock INT NOT NULL DEFAULT 0;

-- track_stock already exists from 001_core_tables.sql (BOOLEAN DEFAULT true)

-- ============================================================
-- 2. Product Stock Movements Table
-- ============================================================
CREATE TABLE IF NOT EXISTS product_stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  type TEXT NOT NULL CHECK (type IN ('stock_in', 'stock_out', 'adjustment', 'production', 'sale', 'return')),
  quantity INT NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_product_stock_movements_product ON product_stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_product_stock_movements_outlet ON product_stock_movements(outlet_id);
CREATE INDEX IF NOT EXISTS idx_product_stock_movements_created ON product_stock_movements(created_at);

-- ============================================================
-- 3. RLS Policies
-- ============================================================
ALTER TABLE product_stock_movements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon read product_stock_movements" ON product_stock_movements FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon insert product_stock_movements" ON product_stock_movements FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon update product_stock_movements" ON product_stock_movements FOR UPDATE TO anon USING (true);
CREATE POLICY "Allow anon delete product_stock_movements" ON product_stock_movements FOR DELETE TO anon USING (true);
