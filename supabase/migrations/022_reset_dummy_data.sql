-- ============================================================
-- UTTER APP - Database Migration 022: Reset All Dummy Data
-- ============================================================
-- Purpose: Delete all test/dummy data while preserving:
--   - outlets (store configuration)
--   - profiles/staff_profiles (staff accounts)
--   - taxes (tax settings)
--   - discounts (discount settings)
--   - tables (restaurant table layout)
--   - platform_configs (online food platform settings)
--
-- This migration is IDEMPOTENT - safe to run multiple times.
-- Uses DELETE FROM in correct FK dependency order.
-- ============================================================

BEGIN;

-- ============================================================
-- PHASE 1: AI-related data (no critical FK deps to other data)
-- ============================================================

-- AI messages depend on ai_conversations
DELETE FROM ai_messages;

-- AI action logs reference ai_conversations
DELETE FROM ai_action_logs;

-- AI conversations reference profiles (kept) and outlets (kept)
DELETE FROM ai_conversations;

-- AI insights reference outlets (kept)
DELETE FROM ai_insights;

-- AI trust settings reference outlets (kept) - reset to clean slate
DELETE FROM ai_trust_settings;

-- ============================================================
-- PHASE 2: Order-related data (deepest FK dependencies first)
-- ============================================================

-- Loyalty transactions reference customers, orders, loyalty_programs
DELETE FROM loyalty_transactions;

-- Online orders reference orders (the order link)
DELETE FROM online_orders;

-- Order items reference orders and products
DELETE FROM order_items;

-- Orders reference shifts, customers, tables (kept), profiles (kept), outlets (kept), discounts (kept)
DELETE FROM orders;

-- Shifts reference outlets (kept) and profiles (kept) - test shift data
DELETE FROM shifts;

-- ============================================================
-- PHASE 3: Product-related data (must come before products/categories)
-- ============================================================

-- Product stock movements reference products
DELETE FROM product_stock_movements;

-- Product images reference products
DELETE FROM product_images;

-- Product-modifier group links reference products and modifier_groups
DELETE FROM product_modifier_groups;

-- Recipes reference products and ingredients
DELETE FROM recipes;

-- ============================================================
-- PHASE 4: Purchase orders (reference suppliers and ingredients)
-- ============================================================

-- PO items reference purchase_orders and ingredients
DELETE FROM purchase_order_items;

-- Purchase orders reference suppliers and outlets (kept)
DELETE FROM purchase_orders;

-- ============================================================
-- PHASE 5: Stock movements (reference ingredients)
-- ============================================================

-- Stock movements reference ingredients and outlets (kept)
DELETE FROM stock_movements;

-- ============================================================
-- PHASE 6: Core catalog data
-- ============================================================

-- Products reference categories and outlets (kept)
DELETE FROM products;

-- Categories reference outlets (kept)
DELETE FROM categories;

-- Modifier options reference modifier_groups
DELETE FROM modifier_options;

-- Modifier groups reference outlets (kept)
DELETE FROM modifier_groups;

-- Ingredients reference outlets (kept) and suppliers
DELETE FROM ingredients;

-- Suppliers reference outlets (kept)
DELETE FROM suppliers;

-- ============================================================
-- PHASE 7: Customer and loyalty data
-- ============================================================

-- Customers reference outlets (kept)
DELETE FROM customers;

-- Loyalty programs reference outlets (kept)
DELETE FROM loyalty_programs;

-- ============================================================
-- PHASE 8: Reset product stock counters (column on products table)
-- Products are already deleted, but if any remain this ensures clean state
-- ============================================================

-- No-op since products are deleted, but safe to run
UPDATE products SET stock_quantity = 0, min_stock = 0 WHERE true;

COMMIT;

-- ============================================================
-- SUMMARY OF PRESERVED DATA:
--   outlets         - Store configuration intact
--   profiles        - Staff accounts (Kasir 1, Admin Toko) intact
--   taxes           - PPN, service charge settings intact
--   discounts       - Discount rules intact
--   tables          - Restaurant table layout intact
--   platform_configs - GoFood/GrabFood/ShopeeFood settings intact
--
-- SUMMARY OF DELETED DATA:
--   orders, order_items, shifts
--   products, categories, modifier_groups, modifier_options
--   product_modifier_groups, product_images, product_stock_movements
--   recipes, ingredients, stock_movements
--   suppliers, purchase_orders, purchase_order_items
--   customers, loyalty_programs, loyalty_transactions
--   online_orders (but NOT platform_configs)
--   ai_conversations, ai_messages, ai_action_logs, ai_insights, ai_trust_settings
-- ============================================================
