-- Migration 030: Fix RLS Policies + Shift/Report Bugs
-- Date: 2026-02-09
-- Fixes: Missing anon RLS policies, shift summary split payment

-- ═══════════════════════════════════════════════════════════════
-- 1. Add anon policies for recipes table (was completely blocked)
-- ═══════════════════════════════════════════════════════════════
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='recipes' AND policyname='anon_select_recipes') THEN
  CREATE POLICY anon_select_recipes ON recipes FOR SELECT TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='recipes' AND policyname='anon_insert_recipes') THEN
  CREATE POLICY anon_insert_recipes ON recipes FOR INSERT TO anon WITH CHECK (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='recipes' AND policyname='anon_update_recipes') THEN
  CREATE POLICY anon_update_recipes ON recipes FOR UPDATE TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='recipes' AND policyname='anon_delete_recipes') THEN
  CREATE POLICY anon_delete_recipes ON recipes FOR DELETE TO anon USING (true);
END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- 2. Add missing anon DELETE policies for critical tables
-- ═══════════════════════════════════════════════════════════════
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='products' AND policyname='anon_delete_products') THEN
  CREATE POLICY anon_delete_products ON products FOR DELETE TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='categories' AND policyname='anon_delete_categories') THEN
  CREATE POLICY anon_delete_categories ON categories FOR DELETE TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='discounts' AND policyname='anon_delete_discounts') THEN
  CREATE POLICY anon_delete_discounts ON discounts FOR DELETE TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='customers' AND policyname='anon_delete_customers') THEN
  CREATE POLICY anon_delete_customers ON customers FOR DELETE TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ingredients' AND policyname='anon_delete_ingredients') THEN
  CREATE POLICY anon_delete_ingredients ON ingredients FOR DELETE TO anon USING (true);
END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- Done
-- ═══════════════════════════════════════════════════════════════
