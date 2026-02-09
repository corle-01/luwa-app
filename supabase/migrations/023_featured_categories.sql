-- ============================================================
-- UTTER APP - Migration 023: Featured Categories
-- ============================================================
-- Adds is_featured flag to categories table and seeds
-- three featured categories (Rekomendasi, Promo, Paket)
-- with negative sort_order so they always appear first.
--
-- Sort order convention:
--   Featured: sort_order < 0 (always first)
--   Regular:  sort_order >= 0
--   Query:    ORDER BY is_featured DESC, sort_order ASC, name ASC
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Add is_featured column to categories
-- ============================================================
ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;

-- ============================================================
-- 2. Create unique index on (outlet_id, name) for idempotent inserts
--    This allows ON CONFLICT (outlet_id, name) DO NOTHING
-- ============================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_outlet_name
  ON categories (outlet_id, name);

-- ============================================================
-- 3. RLS - No additional policy needed
--    categories already has anon SELECT/INSERT/UPDATE policies
--    from migration 005_staff_rpc.sql. The new is_featured column
--    is automatically covered by existing row-level policies.
-- ============================================================

-- ============================================================
-- 4. Seed featured categories for outlet a0000000-...-000000000001
--    Using negative sort_order so they always sort before regular
--    categories (which have sort_order >= 0).
--    ON CONFLICT DO NOTHING to be idempotent.
-- ============================================================
INSERT INTO categories (id, outlet_id, name, description, color, icon, sort_order, is_featured, is_active)
VALUES
  (gen_random_uuid(), 'a0000000-0000-0000-0000-000000000001',
   'Rekomendasi', 'Menu rekomendasi pilihan kami', '#10B981', 'star', -3, true, true),
  (gen_random_uuid(), 'a0000000-0000-0000-0000-000000000001',
   'Promo', 'Menu promo spesial', '#EF4444', 'local_offer', -2, true, true),
  (gen_random_uuid(), 'a0000000-0000-0000-0000-000000000001',
   'Paket', 'Paket hemat bundling', '#F59E0B', 'inventory_2', -1, true, true)
ON CONFLICT (outlet_id, name) DO NOTHING;

COMMIT;

-- ============================================================
-- NOTES:
--   - 3 featured categories seeded: Rekomendasi, Promo, Paket
--   - is_featured=true + negative sort_order ensures they appear
--     before regular categories in all UIs
--   - Recommended query sort:
--       ORDER BY is_featured DESC, sort_order ASC, name ASC
--   - Unique index on (outlet_id, name) prevents duplicate
--     category names within the same outlet
-- ============================================================
