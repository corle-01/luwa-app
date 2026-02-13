-- ============================================================
-- LUWA APP - Database Migration 005: Staff RPC Functions (CLEAN)
-- ============================================================
-- RPC functions to manage staff profiles without auth.users FK
-- NO SEED DATA - Clean version for new clients
-- ============================================================

-- ============================================================
-- 1. RPC: Create Staff Profile (bypass auth.users FK)
-- ============================================================
CREATE OR REPLACE FUNCTION create_staff_profile(
  p_outlet_id UUID,
  p_full_name TEXT,
  p_role TEXT DEFAULT 'cashier',
  p_pin TEXT DEFAULT NULL,
  p_email TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id UUID := gen_random_uuid();
BEGIN
  -- Drop FK constraint to auth.users, insert, then re-add as NOT VALID
  ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

  INSERT INTO profiles (id, outlet_id, full_name, role, pin, email, phone, is_active)
  VALUES (v_id, p_outlet_id, p_full_name, p_role, p_pin, p_email, p_phone, true);

  -- Re-add FK constraint as NOT VALID (won't validate existing rows)
  ALTER TABLE profiles ADD CONSTRAINT profiles_id_fkey
    FOREIGN KEY (id) REFERENCES auth.users(id) NOT VALID;

  RETURN v_id;
END;
$$;

-- ============================================================
-- 2. RLS Policies for Anon Access (dev/web without Supabase Auth)
-- ============================================================
-- The app runs without Supabase Auth login, so auth.uid() is NULL.
-- Add permissive anon policies for POS-critical tables.

DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'profiles', 'shifts', 'orders', 'order_items', 'products',
    'categories', 'taxes', 'discounts', 'modifier_groups',
    'modifier_options', 'product_modifier_groups', 'customers',
    'tables', 'outlets'
  ] LOOP
    EXECUTE format('CREATE POLICY "Allow anon read %1$s" ON %1$I FOR SELECT TO anon USING (true)', tbl);
    EXECUTE format('CREATE POLICY "Allow anon insert %1$s" ON %1$I FOR INSERT TO anon WITH CHECK (true)', tbl);
    EXECUTE format('CREATE POLICY "Allow anon update %1$s" ON %1$I FOR UPDATE TO anon USING (true)', tbl);
  END LOOP;
END $$;
