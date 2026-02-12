-- ============================================================================
-- Migration: 038_add_customer_phone.sql
-- Description: Add customer_phone column to orders table
-- Author: Claude Code
-- Date: 2026-02-12
-- ============================================================================

-- Add customer_phone column to orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_phone TEXT;

-- Add index for customer phone lookups
CREATE INDEX IF NOT EXISTS idx_orders_customer_phone ON orders(customer_phone);

COMMENT ON COLUMN orders.customer_phone IS 'Customer phone number for contact and analytics';
