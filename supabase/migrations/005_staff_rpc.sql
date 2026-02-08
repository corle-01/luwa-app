-- ============================================================
-- UTTER APP - Database Migration 005: Staff RPC Functions
-- ============================================================
-- Run this AFTER 004_seed_data.sql
-- RPC functions to manage staff profiles without auth.users FK
-- + Seed default kasir for testing
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

  ALTER TABLE profiles ADD CONSTRAINT profiles_id_fkey
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE NOT VALID;

  RETURN v_id;
END;
$$;

-- ============================================================
-- 2. RPC: Update Staff Profile
-- ============================================================
CREATE OR REPLACE FUNCTION update_staff_profile(
  p_id UUID,
  p_full_name TEXT DEFAULT NULL,
  p_role TEXT DEFAULT NULL,
  p_pin TEXT DEFAULT NULL,
  p_email TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles
  SET
    full_name = COALESCE(p_full_name, full_name),
    role = COALESCE(p_role, role),
    pin = COALESCE(p_pin, pin),
    email = COALESCE(p_email, email),
    phone = COALESCE(p_phone, phone),
    updated_at = now()
  WHERE id = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Staff profile not found: %', p_id;
  END IF;
END;
$$;

-- ============================================================
-- 3. RPC: Delete Staff Profile
-- ============================================================
CREATE OR REPLACE FUNCTION delete_staff_profile(p_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Soft delete — set is_active = false
  UPDATE profiles
  SET is_active = false, updated_at = now()
  WHERE id = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Staff profile not found: %', p_id;
  END IF;
END;
$$;

-- ============================================================
-- 4. Seed Default Kasir
-- ============================================================
-- Use the RPC to insert staff without auth.users dependency
SELECT create_staff_profile(
  'a0000000-0000-0000-0000-000000000001'::UUID,
  'Kasir 1',
  'cashier',
  '1234',
  'kasir1@uttercoffee.com',
  '081000000001'
);

SELECT create_staff_profile(
  'a0000000-0000-0000-0000-000000000001'::UUID,
  'Admin Toko',
  'admin',
  NULL,
  'admin@uttercoffee.com',
  '081000000002'
);
