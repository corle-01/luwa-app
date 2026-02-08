-- ============================================================
-- UTTER APP - Database Migration 002: AI Tables (22-26)
-- ============================================================
-- Run this AFTER 001_core_tables.sql
-- Total: 5 AI tables + functions
-- ============================================================

-- ============================================================
-- 22. AI_TRUST_SETTINGS - Pengaturan trust level per fitur AI
-- ============================================================
CREATE TABLE ai_trust_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  feature_key TEXT NOT NULL,
  trust_level INT NOT NULL DEFAULT 0 CHECK (trust_level BETWEEN 0 AND 3),
  is_enabled BOOLEAN DEFAULT true,
  config JSONB DEFAULT '{}',
  updated_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(outlet_id, feature_key)
);

CREATE TRIGGER update_ai_trust_settings_updated_at BEFORE UPDATE ON ai_trust_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function: Initialize default trust settings for new outlet
CREATE OR REPLACE FUNCTION init_ai_trust_settings(p_outlet_id UUID)
RETURNS VOID AS $$
BEGIN
  INSERT INTO ai_trust_settings (outlet_id, feature_key, trust_level) VALUES
    (p_outlet_id, 'stock_alert', 0),
    (p_outlet_id, 'auto_disable_product', 2),
    (p_outlet_id, 'auto_enable_product', 2),
    (p_outlet_id, 'draft_purchase_order', 1),
    (p_outlet_id, 'send_purchase_order', 1),
    (p_outlet_id, 'demand_forecast', 0),
    (p_outlet_id, 'pricing_recommendation', 1),
    (p_outlet_id, 'auto_promo', 1),
    (p_outlet_id, 'anomaly_alert', 2),
    (p_outlet_id, 'staffing_suggestion', 0),
    (p_outlet_id, 'auto_reorder', 1),
    (p_outlet_id, 'menu_recommendation', 0)
  ON CONFLICT (outlet_id, feature_key) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 23. AI_CONVERSATIONS - Riwayat percakapan AI
-- ============================================================
CREATE TABLE ai_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  user_id UUID NOT NULL REFERENCES profiles(id),
  title TEXT,
  source TEXT DEFAULT 'chat' CHECK (source IN ('chat', 'floating', 'voice')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER update_ai_conversations_updated_at BEFORE UPDATE ON ai_conversations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE INDEX idx_ai_conversations_outlet ON ai_conversations(outlet_id);
CREATE INDEX idx_ai_conversations_user ON ai_conversations(user_id);

-- ============================================================
-- 24. AI_MESSAGES - Pesan dalam percakapan AI
-- ============================================================
CREATE TABLE ai_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system', 'function')),
  content TEXT NOT NULL,
  function_calls JSONB,
  tokens_used INT,
  model TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ai_messages_conversation ON ai_messages(conversation_id);
CREATE INDEX idx_ai_messages_created ON ai_messages(created_at);

-- ============================================================
-- 25. AI_ACTION_LOGS - Log semua aksi AI
-- ============================================================
CREATE TABLE ai_action_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  feature_key TEXT NOT NULL,
  trust_level INT NOT NULL,
  action_type TEXT NOT NULL CHECK (action_type IN (
    'informed', 'suggested', 'auto_executed', 'silent_executed',
    'approved', 'rejected', 'edited', 'undone'
  )),
  action_description TEXT NOT NULL,
  action_data JSONB,
  source TEXT DEFAULT 'scheduler' CHECK (source IN ('chat', 'scheduler', 'trigger')),
  conversation_id UUID REFERENCES ai_conversations(id),
  triggered_by UUID REFERENCES profiles(id),
  approved_by UUID REFERENCES profiles(id),
  is_undone BOOLEAN DEFAULT false,
  undo_deadline TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ai_action_logs_outlet ON ai_action_logs(outlet_id);
CREATE INDEX idx_ai_action_logs_feature ON ai_action_logs(feature_key);
CREATE INDEX idx_ai_action_logs_created ON ai_action_logs(created_at);

-- ============================================================
-- 26. AI_INSIGHTS - Insight proaktif dari AI
-- ============================================================
CREATE TABLE ai_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  insight_type TEXT NOT NULL CHECK (insight_type IN (
    'demand_forecast', 'stock_prediction', 'anomaly',
    'pricing_suggestion', 'promo_suggestion', 'staffing',
    'product_performance', 'general'
  )),
  title TEXT NOT NULL,
  description TEXT,
  severity TEXT DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical', 'positive')),
  data JSONB,
  suggested_action JSONB,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'dismissed', 'acted_on', 'expired')),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ai_insights_outlet ON ai_insights(outlet_id);
CREATE INDEX idx_ai_insights_status ON ai_insights(status);
CREATE INDEX idx_ai_insights_type ON ai_insights(insight_type);
CREATE INDEX idx_ai_insights_created ON ai_insights(created_at);
