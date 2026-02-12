-- ============================================================================
-- Migration: 034_ai_memories_table.sql
-- Description: Persistent AI memory storage (replaces localStorage)
-- Author: Claude Code
-- Date: 2026-02-12
-- ============================================================================

-- Create AI memories table for persistent storage across sessions
CREATE TABLE IF NOT EXISTS ai_memories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE CASCADE,
  insight TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('sales', 'product', 'stock', 'customer', 'operational', 'general')),
  confidence DECIMAL(3,2) DEFAULT 0.80 CHECK (confidence >= 0 AND confidence <= 1),
  reinforce_count INTEGER DEFAULT 1,
  source TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_ai_memories_outlet ON ai_memories(outlet_id);
CREATE INDEX IF NOT EXISTS idx_ai_memories_category ON ai_memories(category);
CREATE INDEX IF NOT EXISTS idx_ai_memories_created ON ai_memories(created_at DESC);

-- RLS (Row Level Security) policies
ALTER TABLE ai_memories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view memories for their outlets"
  ON ai_memories FOR SELECT
  USING (
    outlet_id IN (
      SELECT outlet_id FROM staff WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert memories for their outlets"
  ON ai_memories FOR INSERT
  WITH CHECK (
    outlet_id IN (
      SELECT outlet_id FROM staff WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update memories for their outlets"
  ON ai_memories FOR UPDATE
  USING (
    outlet_id IN (
      SELECT outlet_id FROM staff WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete memories for their outlets"
  ON ai_memories FOR DELETE
  USING (
    outlet_id IN (
      SELECT outlet_id FROM staff WHERE user_id = auth.uid()
    )
  );

-- Comments
COMMENT ON TABLE ai_memories IS 'Persistent AI memory storage for business insights learned over time';
COMMENT ON COLUMN ai_memories.insight IS 'The business insight or pattern discovered by AI';
COMMENT ON COLUMN ai_memories.category IS 'Category of insight: sales, product, stock, customer, operational, general';
COMMENT ON COLUMN ai_memories.confidence IS 'Confidence level of this insight (0.0 to 1.0)';
COMMENT ON COLUMN ai_memories.reinforce_count IS 'How many times this insight has been reinforced';
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
-- ============================================================================
-- Migration: 036_ai_helper_functions.sql
-- Description: RPC functions for AI to get comprehensive business metrics
-- Author: Claude Code
-- Date: 2026-02-12
-- ============================================================================

-- Function: Get comprehensive business metrics for a time period
CREATE OR REPLACE FUNCTION get_business_metrics(
  p_outlet_id UUID,
  p_days_back INTEGER DEFAULT 30
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH metrics AS (
    SELECT
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
      COUNT(DISTINCT DATE(created_at)) as days_with_sales
    FROM orders
    WHERE outlet_id = p_outlet_id
      AND created_at >= NOW() - (p_days_back || ' days')::INTERVAL
      AND created_at < NOW()
  )
  SELECT json_build_object(
    'period_days', p_days_back,
    'total_orders', COALESCE(total_orders, 0),
    'completed_orders', COALESCE(completed_orders, 0),
    'cancelled_orders', COALESCE(cancelled_orders, 0),
    'refunded_orders', COALESCE(refunded_orders, 0),
    'total_revenue', COALESCE(total_revenue, 0),
    'subtotal_revenue', COALESCE(subtotal_revenue, 0),
    'total_tax', COALESCE(total_tax, 0),
    'total_discounts', COALESCE(total_discounts, 0),
    'avg_order_value', COALESCE(avg_order_value, 0),
    'unique_customers', COALESCE(unique_customers, 0),
    'days_with_sales', COALESCE(days_with_sales, 0),
    'avg_daily_revenue', CASE
      WHEN days_with_sales > 0 THEN ROUND((total_revenue / days_with_sales)::NUMERIC, 2)
      ELSE 0
    END,
    'completion_rate', CASE
      WHEN total_orders > 0 THEN ROUND((completed_orders::DECIMAL / total_orders) * 100, 2)
      ELSE 0
    END,
    'cancellation_rate', CASE
      WHEN total_orders > 0 THEN ROUND((cancelled_orders::DECIMAL / total_orders) * 100, 2)
      ELSE 0
    END
  ) INTO result
  FROM metrics;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Compare current period vs previous period (MoM, WoW, etc.)
CREATE OR REPLACE FUNCTION compare_period_performance(
  p_outlet_id UUID,
  p_current_days INTEGER DEFAULT 7,
  p_comparison_days INTEGER DEFAULT 7
)
RETURNS JSON AS $$
DECLARE
  current_metrics JSON;
  comparison_metrics JSON;
  result JSON;
BEGIN
  -- Current period metrics
  SELECT json_build_object(
    'revenue', COALESCE(SUM(total) FILTER (WHERE status = 'completed'), 0),
    'orders', COUNT(*) FILTER (WHERE status = 'completed'),
    'avg_order', COALESCE(AVG(total) FILTER (WHERE status = 'completed'), 0),
    'unique_customers', COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '')
  ) INTO current_metrics
  FROM orders
  WHERE outlet_id = p_outlet_id
    AND created_at >= NOW() - (p_current_days || ' days')::INTERVAL;

  -- Comparison period metrics (previous period)
  SELECT json_build_object(
    'revenue', COALESCE(SUM(total) FILTER (WHERE status = 'completed'), 0),
    'orders', COUNT(*) FILTER (WHERE status = 'completed'),
    'avg_order', COALESCE(AVG(total) FILTER (WHERE status = 'completed'), 0),
    'unique_customers', COUNT(DISTINCT customer_name) FILTER (WHERE customer_name IS NOT NULL AND customer_name != '')
  ) INTO comparison_metrics
  FROM orders
  WHERE outlet_id = p_outlet_id
    AND created_at >= NOW() - ((p_current_days + p_comparison_days) || ' days')::INTERVAL
    AND created_at < NOW() - (p_current_days || ' days')::INTERVAL;

  -- Calculate growth percentages
  SELECT json_build_object(
    'current_period', current_metrics,
    'previous_period', comparison_metrics,
    'revenue_growth_pct', CASE
      WHEN (comparison_metrics->>'revenue')::DECIMAL > 0
      THEN ROUND((((current_metrics->>'revenue')::DECIMAL - (comparison_metrics->>'revenue')::DECIMAL) / (comparison_metrics->>'revenue')::DECIMAL) * 100, 2)
      ELSE NULL
    END,
    'order_growth_pct', CASE
      WHEN (comparison_metrics->>'orders')::INTEGER > 0
      THEN ROUND((((current_metrics->>'orders')::INTEGER - (comparison_metrics->>'orders')::INTEGER)::DECIMAL / (comparison_metrics->>'orders')::INTEGER) * 100, 2)
      ELSE NULL
    END,
    'avg_order_growth_pct', CASE
      WHEN (comparison_metrics->>'avg_order')::DECIMAL > 0
      THEN ROUND((((current_metrics->>'avg_order')::DECIMAL - (comparison_metrics->>'avg_order')::DECIMAL) / (comparison_metrics->>'avg_order')::DECIMAL) * 100, 2)
      ELSE NULL
    END,
    'customer_growth_pct', CASE
      WHEN (comparison_metrics->>'unique_customers')::INTEGER > 0
      THEN ROUND((((current_metrics->>'unique_customers')::INTEGER - (comparison_metrics->>'unique_customers')::INTEGER)::DECIMAL / (comparison_metrics->>'unique_customers')::INTEGER) * 100, 2)
      ELSE NULL
    END,
    'trend', CASE
      WHEN (comparison_metrics->>'revenue')::DECIMAL > 0 THEN
        CASE
          WHEN ((current_metrics->>'revenue')::DECIMAL - (comparison_metrics->>'revenue')::DECIMAL) / (comparison_metrics->>'revenue')::DECIMAL >= 0.1 THEN 'GROWING'
          WHEN ((current_metrics->>'revenue')::DECIMAL - (comparison_metrics->>'revenue')::DECIMAL) / (comparison_metrics->>'revenue')::DECIMAL <= -0.1 THEN 'DECLINING'
          ELSE 'STABLE'
        END
      ELSE 'INSUFFICIENT_DATA'
    END
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get top performing products by various metrics
CREATE OR REPLACE FUNCTION get_top_products(
  p_outlet_id UUID,
  p_metric TEXT DEFAULT 'revenue', -- 'revenue', 'quantity', 'profit', 'margin'
  p_limit INTEGER DEFAULT 10,
  p_days_back INTEGER DEFAULT 30
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH product_stats AS (
    SELECT
      p.id,
      p.name,
      p.selling_price,
      p.cost_price,
      c.name as category_name,
      SUM(oi.quantity) as total_quantity,
      SUM(oi.subtotal) as total_revenue,
      COUNT(DISTINCT oi.order_id) as order_count,
      COALESCE(SUM(oi.subtotal) - (SUM(oi.quantity) * COALESCE(p.cost_price, 0)), 0) as total_profit,
      CASE
        WHEN SUM(oi.quantity) > 0 AND COALESCE(p.cost_price, 0) > 0
        THEN ((SUM(oi.subtotal) - (SUM(oi.quantity) * p.cost_price)) / SUM(oi.subtotal) * 100)
        ELSE 0
      END as profit_margin_pct
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN order_items oi ON oi.product_id = p.id
    LEFT JOIN orders o ON oi.order_id = o.id
      AND o.status = 'completed'
      AND o.outlet_id = p_outlet_id
      AND o.created_at >= NOW() - (p_days_back || ' days')::INTERVAL
    WHERE p.outlet_id = p_outlet_id
      AND p.is_active = true
    GROUP BY p.id, p.name, p.selling_price, p.cost_price, c.name
    HAVING SUM(oi.quantity) > 0
  ),
  ranked_products AS (
    SELECT
      id,
      name,
      selling_price,
      cost_price,
      category_name,
      total_quantity,
      total_revenue,
      total_profit,
      profit_margin_pct,
      order_count,
      CASE p_metric
        WHEN 'revenue' THEN total_revenue
        WHEN 'quantity' THEN total_quantity
        WHEN 'profit' THEN total_profit
        WHEN 'margin' THEN profit_margin_pct
        ELSE total_revenue
      END as sort_value
    FROM product_stats
    ORDER BY sort_value DESC
    LIMIT p_limit
  )
  SELECT json_agg(
    json_build_object(
      'product_id', id,
      'product_name', name,
      'category', category_name,
      'selling_price', selling_price,
      'cost_price', cost_price,
      'total_quantity', total_quantity,
      'total_revenue', total_revenue,
      'total_profit', total_profit,
      'profit_margin_pct', ROUND(profit_margin_pct::NUMERIC, 2),
      'order_count', order_count
    )
  ) INTO result
  FROM ranked_products;

  RETURN COALESCE(result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get customer insights and segmentation
CREATE OR REPLACE FUNCTION get_customer_insights(
  p_outlet_id UUID,
  p_days_back INTEGER DEFAULT 90
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH customer_stats AS (
    SELECT
      customer_name,
      customer_phone,
      COUNT(*) FILTER (WHERE status = 'completed') as total_orders,
      SUM(total) FILTER (WHERE status = 'completed') as lifetime_value,
      AVG(total) FILTER (WHERE status = 'completed') as avg_order_value,
      MAX(created_at) as last_order_date,
      EXTRACT(DAYS FROM (NOW() - MAX(created_at)))::INTEGER as days_since_last_order,
      CASE
        WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 10 THEN 'VIP'
        WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 5 THEN 'LOYAL'
        WHEN COUNT(*) FILTER (WHERE status = 'completed') >= 2 THEN 'REPEAT'
        ELSE 'NEW'
      END as segment
    FROM orders
    WHERE outlet_id = p_outlet_id
      AND customer_name IS NOT NULL
      AND customer_name != ''
      AND created_at >= NOW() - (p_days_back || ' days')::INTERVAL
    GROUP BY customer_name, customer_phone
  ),
  top_customers_cte AS (
    SELECT
      customer_name as name,
      customer_phone as phone,
      total_orders as orders,
      lifetime_value,
      segment
    FROM customer_stats
    ORDER BY lifetime_value DESC
    LIMIT 10
  )
  SELECT json_build_object(
    'total_customers', (SELECT COUNT(*)::INTEGER FROM customer_stats),
    'vip_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'VIP')::INTEGER FROM customer_stats),
    'loyal_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'LOYAL')::INTEGER FROM customer_stats),
    'repeat_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'REPEAT')::INTEGER FROM customer_stats),
    'new_customers', (SELECT COUNT(*) FILTER (WHERE segment = 'NEW')::INTEGER FROM customer_stats),
    'avg_lifetime_value', ROUND((SELECT AVG(lifetime_value) FROM customer_stats)::NUMERIC, 2),
    'avg_order_value', ROUND((SELECT AVG(avg_order_value) FROM customer_stats)::NUMERIC, 2),
    'top_customers', (SELECT json_agg(row_to_json(t)) FROM top_customers_cte t)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comments
COMMENT ON FUNCTION get_business_metrics IS 'Get comprehensive business metrics for a specified time period';
COMMENT ON FUNCTION compare_period_performance IS 'Compare current period vs previous period (WoW, MoM, etc.) with growth percentages';
COMMENT ON FUNCTION get_top_products IS 'Get top performing products by revenue, quantity, profit, or margin';
COMMENT ON FUNCTION get_customer_insights IS 'Get customer segmentation and insights (VIP, Loyal, Repeat, New)';
