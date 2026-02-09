-- ============================================================
-- UTTER APP - Migration 024: Product Featured Categories
-- ============================================================
-- Junction table to tag products with multiple featured
-- categories (e.g. Rekomendasi, Promo, Paket) while keeping
-- their primary category_id intact on the products table.
--
-- A product can belong to many featured categories, and a
-- featured category can contain many products.
-- ============================================================

-- ============================================================
-- 1. Create product_featured_categories junction table
-- ============================================================
CREATE TABLE IF NOT EXISTS product_featured_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  featured_category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (product_id, featured_category_id)
);

-- ============================================================
-- 2. Indexes for fast lookups
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_pfc_product_id
  ON product_featured_categories(product_id);

CREATE INDEX IF NOT EXISTS idx_pfc_featured_category_id
  ON product_featured_categories(featured_category_id);

-- ============================================================
-- 3. Enable RLS
-- ============================================================
ALTER TABLE product_featured_categories ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 4. RLS policies for anon role (POS web app uses anon key)
-- ============================================================
CREATE POLICY "anon_select_product_featured_categories"
  ON product_featured_categories
  FOR SELECT TO anon USING (true);

CREATE POLICY "anon_insert_product_featured_categories"
  ON product_featured_categories
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "anon_update_product_featured_categories"
  ON product_featured_categories
  FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "anon_delete_product_featured_categories"
  ON product_featured_categories
  FOR DELETE TO anon USING (true);
