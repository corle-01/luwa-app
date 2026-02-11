-- ============================================================
-- UTTER APP - Database Migration 033: Unit Conversion System
-- ============================================================
-- Adds base_unit field to ingredients for proper unit conversion
-- Migrates existing units to base units (g for weight, ml for volume)
-- ============================================================

-- ============================================================
-- 1. Add base_unit column to ingredients
-- ============================================================
ALTER TABLE ingredients
ADD COLUMN IF NOT EXISTS base_unit TEXT;

-- ============================================================
-- 2. Migrate existing data to base units
-- ============================================================

-- Set base_unit based on current unit
UPDATE ingredients
SET base_unit = CASE
  -- Weight units → base: g (grams)
  WHEN unit IN ('mg', 'g', 'gram', 'kg', 'kilogram') THEN 'g'

  -- Volume units → base: ml (milliliters)
  WHEN unit IN ('ml', 'mL', 'l', 'liter', 'litre') THEN 'ml'

  -- Count units → no conversion, keep as is
  ELSE 'pcs'
END
WHERE base_unit IS NULL;

-- Convert existing stock values to base units
UPDATE ingredients
SET current_stock = CASE
  -- Convert kg to g (multiply by 1000)
  WHEN unit IN ('kg', 'kilogram') THEN current_stock * 1000

  -- Convert liter to ml (multiply by 1000)
  WHEN unit IN ('l', 'liter', 'litre') THEN current_stock * 1000

  -- Convert mg to g (divide by 1000)
  WHEN unit = 'mg' THEN current_stock / 1000

  -- Keep g and ml as is
  ELSE current_stock
END,
min_stock = CASE
  WHEN unit IN ('kg', 'kilogram') THEN min_stock * 1000
  WHEN unit IN ('l', 'liter', 'litre') THEN min_stock * 1000
  WHEN unit = 'mg' THEN min_stock / 1000
  ELSE min_stock
END,
max_stock = CASE
  WHEN unit IN ('kg', 'kilogram') THEN max_stock * 1000
  WHEN unit IN ('l', 'liter', 'litre') THEN max_stock * 1000
  WHEN unit = 'mg' THEN max_stock / 1000
  ELSE max_stock
END,
-- Update unit to base unit
unit = base_unit
WHERE base_unit IS NOT NULL;

-- ============================================================
-- 3. Set NOT NULL constraint after migration
-- ============================================================
ALTER TABLE ingredients
ALTER COLUMN base_unit SET DEFAULT 'pcs',
ALTER COLUMN base_unit SET NOT NULL;

-- ============================================================
-- 4. Add helpful comment
-- ============================================================
COMMENT ON COLUMN ingredients.base_unit IS 'Base unit for storage: g (weight), ml (volume), or pcs (count). All stock values are stored in base units.';
COMMENT ON COLUMN ingredients.unit IS 'Display unit shown to users. Can be mg, g, kg for weight; ml, l for volume; or pcs, buah, botol, etc for count.';
