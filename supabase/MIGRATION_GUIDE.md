# Migration Guide

## Option 1: Run All at Once (QUICK)
1. Open: https://supabase.com/dashboard/project/pxczlgndwjmkczdedjiq/sql/new
2. Copy content from `ALL_MIGRATIONS_FIXED.sql`
3. Paste and RUN

## Option 2: Run One by One (SAFE)

If you get errors with Option 1, run migrations individually in this order:

### Core Setup (Required)
1. `001_core_tables.sql` - Main tables (outlets, menus, orders, etc)
2. `002_ai_tables.sql` - AI features tables
3. `003_views_functions_rls.sql` - Views, functions, security
4. `004_seed_data.sql` - Initial data

### Additional Features
5. `005_staff_rpc.sql` - Staff management
6. `006_inventory_tables.sql` - Inventory system
7. `007_ai_deepseek_rpc.sql` - DeepSeek AI integration
8. `008_refund_void.sql` - Refund & void transactions
9. `009_supplier_po.sql` - Supplier & purchase orders
10. `010_loyalty.sql` - Loyalty program
11. `011_kds.sql` - Kitchen Display System
12. `012_self_order.sql` - Self-order kiosk
13. `013_online_food.sql` - Online food delivery
14. Continue with remaining migrations...

### How to Run Individually:
1. Open migration file (e.g., `001_core_tables.sql`)
2. Copy all content
3. Paste to Supabase SQL Editor
4. RUN
5. Wait for success message
6. Repeat for next file

## Tips:
- If a migration fails, note the error
- Fix the issue or skip to next migration
- Most features will work even if some migrations fail
- Core migrations (001-004) are most important
