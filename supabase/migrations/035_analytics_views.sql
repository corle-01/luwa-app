-- ============================================================================
-- Migration: 035_analytics_views.sql
-- Description: Create analytics views for deep business intelligence
-- Author: Claude Code
-- Date: 2026-02-12
-- ============================================================================

-- Daily Sales Summary View - Aggregated daily metrics
CREATE OR REPLACE VIEW v_daily_sales_summary AS
SELECT
  outlet_id,
  DATE(created_at) as sale_date,
  COUNT(*) as total_orders,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
  COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_orders,
  COUNT(*) FILTER (WHERE status = 'refunded') as refunded_orders,
  SUM(total) FILTER (WHERE status = 'completed') as total_revenue,
  SUM(subtotal) FILTER (WHERE status = 'completed') as subtotal_revenue,
  SUM(tax_amount) FILTER (WHERE status = 'completed') as total_tax,
  SUM(discount_amount) FILTER (WHERE status = 'completed') as total_discounts,
  AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
  COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '') as unique_customers,
  ARRAY_AGG(DISTINCT payment_method) FILTER (WHERE status = 'completed') as payment_methods_used
FROM orders
GROUP BY outlet_id, DATE(created_at);

-- Hourly Revenue Pattern View - For predicting busy hours
CREATE OR REPLACE VIEW v_hourly_revenue_pattern AS
SELECT
  outlet_id,
  EXTRACT(HOUR FROM created_at)::INTEGER as hour_of_day,
  EXTRACT(DOW FROM created_at)::INTEGER as day_of_week, -- 0=Sunday, 6=Saturday
  COUNT(*) as order_count,
  SUM(total) FILTER (WHERE status = 'completed') as revenue,
  AVG(total) FILTER (WHERE status = 'completed') as avg_order_value
FROM orders
WHERE created_at >= NOW() - INTERVAL '90 days'
GROUP BY outlet_id, EXTRACT(HOUR FROM created_at), EXTRACT(DOW FROM created_at);

-- Product Performance View - Sales and profitability (Last 30 days)
CREATE OR REPLACE VIEW v_product_performance AS
SELECT
  p.id as product_id,
  p.outlet_id,
  p.name as product_name,
  p.category_id,
  c.name as category_name,
  p.selling_price,
  p.cost_price,
  COUNT(oi.id) as times_ordered,
  SUM(oi.quantity) as total_quantity_sold,
  SUM(oi.subtotal) as total_revenue,
  AVG(oi.unit_price) as avg_selling_price,
  COALESCE(SUM(oi.subtotal) - (SUM(oi.quantity) * COALESCE(p.cost_price, 0)), 0) as total_profit,
  CASE
    WHEN SUM(oi.quantity) > 0 AND COALESCE(p.cost_price, 0) > 0
    THEN ROUND(((SUM(oi.subtotal) - (SUM(oi.quantity) * p.cost_price)) / SUM(oi.subtotal) * 100)::NUMERIC, 2)
    ELSE 0
  END as profit_margin_pct,
  MAX(o.created_at) as last_sold_at
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN order_items oi ON oi.product_id = p.id
LEFT JOIN orders o ON oi.order_id = o.id
  AND o.status = 'completed'
  AND o.created_at >= NOW() - INTERVAL '30 days'
WHERE p.is_active = true
GROUP BY p.id, p.outlet_id, p.name, p.category_id, c.name, p.selling_price, p.cost_price;

-- Stock Alert View - Real-time stock warnings
CREATE OR REPLACE VIEW v_stock_alerts AS
SELECT
  id,
  outlet_id,
  name as ingredient_name,
  current_stock,
  min_stock,
  max_stock,
  unit,
  base_unit,
  cost_per_unit,
  CASE
    WHEN current_stock <= 0 THEN 'OUT_OF_STOCK'
    WHEN current_stock <= min_stock * 0.5 THEN 'CRITICAL'
    WHEN current_stock <= min_stock THEN 'LOW'
    WHEN current_stock >= max_stock THEN 'OVERSTOCK'
    ELSE 'NORMAL'
  END as stock_status,
  CASE
    WHEN current_stock < min_stock THEN GREATEST(min_stock - current_stock, 0)
    ELSE 0
  END as reorder_quantity,
  category
FROM ingredients
WHERE is_active = true
ORDER BY
  CASE
    WHEN current_stock <= 0 THEN 1
    WHEN current_stock <= min_stock * 0.5 THEN 2
    WHEN current_stock <= min_stock THEN 3
    WHEN current_stock >= max_stock THEN 4
    ELSE 5
  END,
  name;

-- Customer Order Frequency - RFM Analysis basis
CREATE OR REPLACE VIEW v_customer_order_frequency AS
SELECT
  outlet_id,
  customer_name,
  customer_phone,
  COUNT(*) as total_orders,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
  SUM(total) FILTER (WHERE status = 'completed') as lifetime_value,
  AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
  MAX(created_at) as last_order_date,
  MIN(created_at) as first_order_date,
  EXTRACT(DAYS FROM (NOW() - MAX(created_at)))::INTEGER as days_since_last_order,
  CASE
    WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 10 THEN 'VIP'
    WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 5 THEN 'LOYAL'
    WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 2 THEN 'REPEAT'
    ELSE 'NEW'
  END as customer_segment,
  CASE
    WHEN EXTRACT(DAYS FROM (NOW() - MAX(created_at))) <= 7 THEN 'ACTIVE'
    WHEN EXTRACT(DAYS FROM (NOW() - MAX(created_at))) <= 30 THEN 'AT_RISK'
    WHEN EXTRACT(DAYS FROM (NOW() - MAX(created_at))) <= 90 THEN 'DORMANT'
    ELSE 'LOST'
  END as recency_status
FROM orders
WHERE customer_name IS NOT NULL
  AND customer_name != ''
GROUP BY outlet_id, customer_name, customer_phone;

-- Category Performance View
CREATE OR REPLACE VIEW v_category_performance AS
SELECT
  c.id as category_id,
  c.outlet_id,
  c.name as category_name,
  COUNT(DISTINCT p.id) as total_products,
  COUNT(oi.id) as total_orders,
  SUM(oi.quantity) as total_quantity_sold,
  SUM(oi.subtotal) as total_revenue,
  AVG(oi.unit_price) as avg_product_price
FROM categories c
LEFT JOIN products p ON p.category_id = c.id AND p.is_active = true
LEFT JOIN order_items oi ON oi.product_id = p.id
LEFT JOIN orders o ON oi.order_id = o.id
  AND o.status = 'completed'
  AND o.created_at >= NOW() - INTERVAL '30 days'
WHERE c.is_active = true
GROUP BY c.id, c.outlet_id, c.name;

-- Comments
COMMENT ON VIEW v_daily_sales_summary IS 'Daily sales aggregates for trend analysis and MoM/YoY comparison';
COMMENT ON VIEW v_hourly_revenue_pattern IS 'Revenue patterns by hour and day of week for busy hour predictions';
COMMENT ON VIEW v_product_performance IS 'Product sales and profitability metrics with margin analysis';
COMMENT ON VIEW v_stock_alerts IS 'Real-time stock status and intelligent reorder alerts';
COMMENT ON VIEW v_customer_order_frequency IS 'Customer segmentation based on RFM (Recency, Frequency, Monetary) analysis';
COMMENT ON VIEW v_category_performance IS 'Category-level sales performance metrics';
