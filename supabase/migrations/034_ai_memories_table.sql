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
