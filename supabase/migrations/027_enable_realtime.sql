-- ============================================================
-- 027: Enable Supabase Realtime for key tables
-- Allows Flutter apps to receive live DB changes
-- and auto-refresh providers without manual polling.
-- ============================================================

-- Already in publication: ingredients, shifts, orders, order_items, ai_messages, ai_action_logs, ai_insights
-- Adding new tables:
ALTER PUBLICATION supabase_realtime ADD TABLE products;
ALTER PUBLICATION supabase_realtime ADD TABLE categories;
ALTER PUBLICATION supabase_realtime ADD TABLE recipes;
ALTER PUBLICATION supabase_realtime ADD TABLE stock_movements;
ALTER PUBLICATION supabase_realtime ADD TABLE product_stock_movements;
ALTER PUBLICATION supabase_realtime ADD TABLE purchases;
ALTER PUBLICATION supabase_realtime ADD TABLE purchase_items;
