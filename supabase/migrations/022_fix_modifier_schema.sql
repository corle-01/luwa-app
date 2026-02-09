-- ============================================================
-- 022: Fix modifier_groups schema - add missing columns + RLS
-- ============================================================

-- Add selection_type column (single/multiple) used by modifier management UI
ALTER TABLE modifier_groups ADD COLUMN IF NOT EXISTS selection_type TEXT DEFAULT 'single';

-- Add sort_order column for ordering modifier groups
ALTER TABLE modifier_groups ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;

-- Add anon DELETE policies for modifier CRUD
DO $$ BEGIN
  CREATE POLICY "Allow anon delete modifier_groups"
    ON modifier_groups FOR DELETE TO anon USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Allow anon delete modifier_options"
    ON modifier_options FOR DELETE TO anon USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Allow anon delete product_modifier_groups"
    ON product_modifier_groups FOR DELETE TO anon USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
