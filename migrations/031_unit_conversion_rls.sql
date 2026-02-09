-- Migration 031: Unit Conversion in Recipe Cost + Remaining RLS Policies
-- Date: 2026-02-09
-- Fixes:
--   1. Recipe cost calculation now converts units (g→kg, ml→l, etc.)
--   2. Missing anon RLS policies for AI tables + loyalty_transactions

-- ═══════════════════════════════════════════════════════════════
-- 1. Unit Conversion Function for Recipe Cost Calculation
-- ═══════════════════════════════════════════════════════════════

-- Returns a conversion factor: multiply recipe quantity by this to get ingredient-unit quantity.
-- Example: recipe_unit='gram', ingredient_unit='kg' → factor=0.001 (1g = 0.001kg)
CREATE OR REPLACE FUNCTION unit_conversion_factor(recipe_unit TEXT, ingredient_unit TEXT)
RETURNS NUMERIC AS $$
BEGIN
  -- Same unit = no conversion
  IF lower(recipe_unit) = lower(ingredient_unit) THEN
    RETURN 1;
  END IF;

  -- Weight conversions
  IF lower(recipe_unit) = 'gram' AND lower(ingredient_unit) = 'kg' THEN RETURN 0.001; END IF;
  IF lower(recipe_unit) = 'g' AND lower(ingredient_unit) = 'kg' THEN RETURN 0.001; END IF;
  IF lower(recipe_unit) = 'kg' AND lower(ingredient_unit) = 'gram' THEN RETURN 1000; END IF;
  IF lower(recipe_unit) = 'kg' AND lower(ingredient_unit) = 'g' THEN RETURN 1000; END IF;
  IF lower(recipe_unit) = 'mg' AND lower(ingredient_unit) = 'gram' THEN RETURN 0.001; END IF;
  IF lower(recipe_unit) = 'mg' AND lower(ingredient_unit) = 'g' THEN RETURN 0.001; END IF;
  IF lower(recipe_unit) = 'mg' AND lower(ingredient_unit) = 'kg' THEN RETURN 0.000001; END IF;
  IF lower(recipe_unit) = 'gram' AND lower(ingredient_unit) = 'mg' THEN RETURN 1000; END IF;
  IF lower(recipe_unit) = 'g' AND lower(ingredient_unit) = 'mg' THEN RETURN 1000; END IF;

  -- Volume conversions
  IF lower(recipe_unit) = 'ml' AND lower(ingredient_unit) = 'liter' THEN RETURN 0.001; END IF;
  IF lower(recipe_unit) = 'ml' AND lower(ingredient_unit) = 'l' THEN RETURN 0.001; END IF;
  IF lower(recipe_unit) = 'liter' AND lower(ingredient_unit) = 'ml' THEN RETURN 1000; END IF;
  IF lower(recipe_unit) = 'l' AND lower(ingredient_unit) = 'ml' THEN RETURN 1000; END IF;

  -- No known conversion — assume 1:1 (user responsibility)
  RETURN 1;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ═══════════════════════════════════════════════════════════════
-- 2. Update Recipe Cost Triggers to Use Unit Conversion
-- ═══════════════════════════════════════════════════════════════

-- Trigger 1: Recipe change → recalculate product cost_price WITH unit conversion
CREATE OR REPLACE FUNCTION update_product_cost_from_recipe()
RETURNS TRIGGER AS $$
DECLARE
  v_product_id UUID;
  v_new_cost NUMERIC;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_product_id := OLD.product_id;
  ELSE
    v_product_id := NEW.product_id;
  END IF;

  -- Sum all recipe ingredients cost WITH unit conversion
  SELECT COALESCE(SUM(
    r.quantity * unit_conversion_factor(r.unit, i.unit) * i.cost_per_unit
  ), 0)
  INTO v_new_cost
  FROM recipes r
  JOIN ingredients i ON r.ingredient_id = i.id
  WHERE r.product_id = v_product_id;

  UPDATE products
  SET cost_price = v_new_cost, updated_at = NOW()
  WHERE id = v_product_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger 2: Ingredient price change → cascade WITH unit conversion
CREATE OR REPLACE FUNCTION update_products_cost_on_ingredient_price_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.cost_per_unit IS DISTINCT FROM NEW.cost_per_unit THEN
    UPDATE products p
    SET cost_price = sub.new_cost, updated_at = NOW()
    FROM (
      SELECT r.product_id,
             COALESCE(SUM(
               r.quantity * unit_conversion_factor(r.unit, i.unit) * i.cost_per_unit
             ), 0) AS new_cost
      FROM recipes r
      JOIN ingredients i ON r.ingredient_id = i.id
      WHERE r.product_id IN (
        SELECT DISTINCT product_id FROM recipes WHERE ingredient_id = NEW.id
      )
      GROUP BY r.product_id
    ) sub
    WHERE p.id = sub.product_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Backfill: Recalculate all products with unit conversion
UPDATE products p
SET cost_price = sub.hpp, updated_at = NOW()
FROM (
  SELECT r.product_id,
         SUM(r.quantity * unit_conversion_factor(r.unit, i.unit) * i.cost_per_unit) AS hpp
  FROM recipes r
  JOIN ingredients i ON r.ingredient_id = i.id
  GROUP BY r.product_id
) sub
WHERE p.id = sub.product_id;

-- ═══════════════════════════════════════════════════════════════
-- 3. Missing Anon RLS Policies for AI Tables
-- ═══════════════════════════════════════════════════════════════

-- ai_trust_settings
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_trust_settings' AND policyname='anon_select_ai_trust_settings') THEN
  CREATE POLICY anon_select_ai_trust_settings ON ai_trust_settings FOR SELECT TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_trust_settings' AND policyname='anon_insert_ai_trust_settings') THEN
  CREATE POLICY anon_insert_ai_trust_settings ON ai_trust_settings FOR INSERT TO anon WITH CHECK (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_trust_settings' AND policyname='anon_update_ai_trust_settings') THEN
  CREATE POLICY anon_update_ai_trust_settings ON ai_trust_settings FOR UPDATE TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_trust_settings' AND policyname='anon_delete_ai_trust_settings') THEN
  CREATE POLICY anon_delete_ai_trust_settings ON ai_trust_settings FOR DELETE TO anon USING (true);
END IF;
END $$;

-- ai_conversations
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_conversations' AND policyname='anon_select_ai_conversations') THEN
  CREATE POLICY anon_select_ai_conversations ON ai_conversations FOR SELECT TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_conversations' AND policyname='anon_insert_ai_conversations') THEN
  CREATE POLICY anon_insert_ai_conversations ON ai_conversations FOR INSERT TO anon WITH CHECK (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_conversations' AND policyname='anon_update_ai_conversations') THEN
  CREATE POLICY anon_update_ai_conversations ON ai_conversations FOR UPDATE TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_conversations' AND policyname='anon_delete_ai_conversations') THEN
  CREATE POLICY anon_delete_ai_conversations ON ai_conversations FOR DELETE TO anon USING (true);
END IF;
END $$;

-- ai_messages
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_messages' AND policyname='anon_select_ai_messages') THEN
  CREATE POLICY anon_select_ai_messages ON ai_messages FOR SELECT TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_messages' AND policyname='anon_insert_ai_messages') THEN
  CREATE POLICY anon_insert_ai_messages ON ai_messages FOR INSERT TO anon WITH CHECK (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_messages' AND policyname='anon_update_ai_messages') THEN
  CREATE POLICY anon_update_ai_messages ON ai_messages FOR UPDATE TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_messages' AND policyname='anon_delete_ai_messages') THEN
  CREATE POLICY anon_delete_ai_messages ON ai_messages FOR DELETE TO anon USING (true);
END IF;
END $$;

-- ai_action_logs
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_action_logs' AND policyname='anon_select_ai_action_logs') THEN
  CREATE POLICY anon_select_ai_action_logs ON ai_action_logs FOR SELECT TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_action_logs' AND policyname='anon_insert_ai_action_logs') THEN
  CREATE POLICY anon_insert_ai_action_logs ON ai_action_logs FOR INSERT TO anon WITH CHECK (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_action_logs' AND policyname='anon_update_ai_action_logs') THEN
  CREATE POLICY anon_update_ai_action_logs ON ai_action_logs FOR UPDATE TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_action_logs' AND policyname='anon_delete_ai_action_logs') THEN
  CREATE POLICY anon_delete_ai_action_logs ON ai_action_logs FOR DELETE TO anon USING (true);
END IF;
END $$;

-- ai_insights
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_insights' AND policyname='anon_select_ai_insights') THEN
  CREATE POLICY anon_select_ai_insights ON ai_insights FOR SELECT TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_insights' AND policyname='anon_insert_ai_insights') THEN
  CREATE POLICY anon_insert_ai_insights ON ai_insights FOR INSERT TO anon WITH CHECK (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_insights' AND policyname='anon_update_ai_insights') THEN
  CREATE POLICY anon_update_ai_insights ON ai_insights FOR UPDATE TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ai_insights' AND policyname='anon_delete_ai_insights') THEN
  CREATE POLICY anon_delete_ai_insights ON ai_insights FOR DELETE TO anon USING (true);
END IF;
END $$;

-- loyalty_transactions (missing UPDATE and DELETE)
DO $$ BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='loyalty_transactions' AND policyname='anon_update_loyalty_transactions') THEN
  CREATE POLICY anon_update_loyalty_transactions ON loyalty_transactions FOR UPDATE TO anon USING (true);
END IF;
IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='loyalty_transactions' AND policyname='anon_delete_loyalty_transactions') THEN
  CREATE POLICY anon_delete_loyalty_transactions ON loyalty_transactions FOR DELETE TO anon USING (true);
END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- Done
-- ═══════════════════════════════════════════════════════════════
