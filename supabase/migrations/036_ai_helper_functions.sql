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
