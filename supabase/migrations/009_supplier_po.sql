-- ============================================================
-- UTTER APP - Database Migration 009: Suppliers & Purchase Orders
-- ============================================================
-- Run this AFTER 008_refund_void.sql
-- Adds suppliers, purchase_orders, and purchase_order_items tables
-- ============================================================

-- ============================================================
-- 1. Suppliers Table
-- ============================================================
CREATE TABLE IF NOT EXISTS suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 2. Purchase Orders Table
-- ============================================================
CREATE TABLE IF NOT EXISTS purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  po_number TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft', -- draft, ordered, partial, received, cancelled
  order_date TIMESTAMPTZ DEFAULT now(),
  expected_date TIMESTAMPTZ,
  received_date TIMESTAMPTZ,
  total_amount DECIMAL(12,2) DEFAULT 0,
  notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 3. Purchase Order Items Table
-- ============================================================
CREATE TABLE IF NOT EXISTS purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  ingredient_name TEXT NOT NULL,
  quantity DECIMAL(12,3) NOT NULL,
  unit TEXT NOT NULL,
  unit_cost DECIMAL(12,2) DEFAULT 0,
  total_cost DECIMAL(12,2) DEFAULT 0,
  received_quantity DECIMAL(12,3) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 4. Generate PO Number Function
-- ============================================================
CREATE OR REPLACE FUNCTION generate_po_number(p_outlet_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_count INT;
BEGIN
  SELECT COUNT(*) + 1 INTO v_count FROM purchase_orders WHERE outlet_id = p_outlet_id;
  RETURN 'PO-' || LPAD(v_count::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 5. RLS Policies
-- ============================================================
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;

-- Suppliers RLS
CREATE POLICY "anon_select_suppliers" ON suppliers FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_suppliers" ON suppliers FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_suppliers" ON suppliers FOR UPDATE TO anon USING (true);
CREATE POLICY "anon_delete_suppliers" ON suppliers FOR DELETE TO anon USING (true);

-- Purchase Orders RLS
CREATE POLICY "anon_select_po" ON purchase_orders FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_po" ON purchase_orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_po" ON purchase_orders FOR UPDATE TO anon USING (true);
CREATE POLICY "anon_delete_po" ON purchase_orders FOR DELETE TO anon USING (true);

-- Purchase Order Items RLS
CREATE POLICY "anon_select_po_items" ON purchase_order_items FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_po_items" ON purchase_order_items FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_po_items" ON purchase_order_items FOR UPDATE TO anon USING (true);
CREATE POLICY "anon_delete_po_items" ON purchase_order_items FOR DELETE TO anon USING (true);

-- ============================================================
-- 6. Seed Sample Supplier
-- ============================================================
INSERT INTO suppliers (outlet_id, name, contact_person, phone, email, address)
VALUES ('a0000000-0000-0000-0000-000000000001', 'PT Bahan Baku Utama', 'Budi Santoso', '081234567890', 'budi@bahanbaku.com', 'Jl. Industri No. 10, Malang');
