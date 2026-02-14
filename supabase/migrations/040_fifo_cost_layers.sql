-- ============================================================================
-- Migration 040: FIFO Cost Layers (Switch from WAC to FIFO costing)
-- ============================================================================
-- Each purchase becomes a separate "cost layer" (batch).
-- Stock consumption always depletes the oldest batch first.
-- ingredients.cost_per_unit is updated to reflect the oldest remaining layer,
-- so all downstream consumers (triggers, views, recipes, HPP) work as-is.
-- ============================================================================

-- ═══════════════════════════════════════════════════════════════
-- 1. Cost Layers Table (FIFO batches)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE ingredient_cost_layers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  purchase_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  original_qty NUMERIC(15,4) NOT NULL,     -- qty purchased (base unit)
  remaining_qty NUMERIC(15,4) NOT NULL,    -- qty still available
  cost_per_unit NUMERIC(15,4) NOT NULL,    -- cost per base unit for this batch
  reference_type TEXT,                      -- 'purchase', 'initial', 'adjustment'
  reference_id UUID,                       -- optional link to stock_movement
  created_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT positive_remaining CHECK (remaining_qty >= 0)
);

CREATE INDEX idx_cost_layers_ingredient ON ingredient_cost_layers(ingredient_id);
CREATE INDEX idx_cost_layers_fifo ON ingredient_cost_layers(ingredient_id, remaining_qty, purchase_date);

-- ═══════════════════════════════════════════════════════════════
-- 2. Row Level Security
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE ingredient_cost_layers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own outlet cost layers"
  ON ingredient_cost_layers FOR ALL
  USING (outlet_id IN (SELECT outlet_id FROM profiles WHERE id = auth.uid()));

-- ═══════════════════════════════════════════════════════════════
-- 3. RPC: Consume stock FIFO and return weighted cost of consumed units
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION consume_fifo_layers(
  p_ingredient_id UUID,
  p_quantity NUMERIC
) RETURNS NUMERIC AS $$
DECLARE
  v_remaining NUMERIC := p_quantity;
  v_total_cost NUMERIC := 0;
  v_layer RECORD;
  v_consume NUMERIC;
BEGIN
  FOR v_layer IN
    SELECT id, remaining_qty, cost_per_unit
    FROM ingredient_cost_layers
    WHERE ingredient_id = p_ingredient_id AND remaining_qty > 0
    ORDER BY purchase_date ASC, created_at ASC
  LOOP
    IF v_remaining <= 0 THEN EXIT; END IF;

    v_consume := LEAST(v_remaining, v_layer.remaining_qty);
    v_total_cost := v_total_cost + (v_consume * v_layer.cost_per_unit);
    v_remaining := v_remaining - v_consume;

    UPDATE ingredient_cost_layers
    SET remaining_qty = remaining_qty - v_consume
    WHERE id = v_layer.id;
  END LOOP;

  -- Return weighted average cost of consumed units (for recording on movement)
  IF p_quantity > 0 THEN
    RETURN v_total_cost / p_quantity;
  END IF;
  RETURN 0;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════
-- 4. RPC: Update ingredient cost_per_unit to oldest layer's cost (FIFO)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_fifo_cost(p_ingredient_id UUID) RETURNS VOID AS $$
DECLARE
  v_fifo_cost NUMERIC;
BEGIN
  SELECT cost_per_unit INTO v_fifo_cost
  FROM ingredient_cost_layers
  WHERE ingredient_id = p_ingredient_id AND remaining_qty > 0
  ORDER BY purchase_date ASC, created_at ASC
  LIMIT 1;

  IF v_fifo_cost IS NOT NULL THEN
    UPDATE ingredients
    SET cost_per_unit = v_fifo_cost, updated_at = NOW()
    WHERE id = p_ingredient_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════
-- 5. Add cost_at_movement column to stock_movements
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS cost_at_movement NUMERIC(15,4);

-- ═══════════════════════════════════════════════════════════════
-- 6. Backfill: Create initial cost layer from current stock + cost
-- ═══════════════════════════════════════════════════════════════

INSERT INTO ingredient_cost_layers (
  ingredient_id, outlet_id, original_qty, remaining_qty,
  cost_per_unit, reference_type, purchase_date
)
SELECT
  id, outlet_id, current_stock, current_stock,
  cost_per_unit, 'initial',
  COALESCE(updated_at, created_at, NOW())
FROM ingredients
WHERE current_stock > 0 AND is_active = true;
