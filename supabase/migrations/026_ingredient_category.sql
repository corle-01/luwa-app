-- ============================================================
-- 026: Add category column to ingredients
-- Categories: makanan, minuman, snack
-- ============================================================

ALTER TABLE ingredients ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'makanan';
