-- Migration 032: Category Station (Kitchen/Bar routing for kitchen tickets)
-- Date: 2026-02-09
-- Purpose: Group kitchen ticket items by station so server knows
--          which items go to Kitchen vs Bar area.

-- Add station column: 'kitchen' (default) or 'bar'
ALTER TABLE categories ADD COLUMN IF NOT EXISTS station TEXT DEFAULT 'kitchen';

-- Set drinks-related categories to 'bar' station by convention
-- (Users can customize via Back Office → Kelola Kategori)
UPDATE categories
SET station = 'bar'
WHERE lower(name) LIKE '%minum%'
   OR lower(name) LIKE '%drink%'
   OR lower(name) LIKE '%beverage%'
   OR lower(name) LIKE '%kopi%'
   OR lower(name) LIKE '%coffee%'
   OR lower(name) LIKE '%juice%'
   OR lower(name) LIKE '%jus%'
   OR lower(name) LIKE '%bar%';
