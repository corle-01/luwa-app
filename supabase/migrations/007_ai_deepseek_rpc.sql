-- ============================================================
-- UTTER APP - Database Migration 007: AI Chat via DeepSeek RPC
-- ============================================================
-- Run this AFTER 006_inventory_tables.sql
-- Enables http extension and creates ai_chat RPC function
-- that proxies requests to DeepSeek API server-side
-- ============================================================

-- ============================================================
-- 1. Enable HTTP Extension
-- ============================================================
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

-- ============================================================
-- 2. AI Chat RPC Function
-- ============================================================
CREATE OR REPLACE FUNCTION ai_chat(
  p_message TEXT,
  p_history JSONB DEFAULT '[]',
  p_context JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET statement_timeout = '60s'
AS $$
DECLARE
  v_system_prompt TEXT;
  v_messages JSONB;
  v_request_body TEXT;
  v_response extensions.http_response;
  v_response_body JSONB;
  v_reply TEXT;
BEGIN
  v_system_prompt := 'Kamu adalah Utter, AI co-pilot untuk bisnis F&B (kafe/restoran). ' ||
    'Kamu membantu pemilik bisnis dengan analisa penjualan, manajemen stok, dan saran bisnis. ' ||
    'Selalu jawab dalam Bahasa Indonesia yang natural dan ramah. ' ||
    'Jika ada data konteks, gunakan untuk menjawab. Konteks: ' || COALESCE(p_context::TEXT, '{}');

  v_messages := jsonb_build_array(
    jsonb_build_object('role', 'system', 'content', v_system_prompt)
  ) || COALESCE(p_history, '[]'::JSONB) || jsonb_build_array(
    jsonb_build_object('role', 'user', 'content', p_message)
  );

  v_request_body := jsonb_build_object(
    'model', 'deepseek-chat',
    'messages', v_messages,
    'max_tokens', 1024,
    'temperature', 0.7
  )::TEXT;

  SELECT * INTO v_response FROM extensions.http(
    (
      'POST',
      'https://api.deepseek.com/chat/completions',
      ARRAY[
        extensions.http_header('Authorization', 'Bearer ' || current_setting('app.deepseek_api_key', true)),
        extensions.http_header('Content-Type', 'application/json')
      ],
      'application/json',
      v_request_body
    )::extensions.http_request
  );

  IF v_response.status != 200 THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, terjadi kesalahan saat menghubungi AI (HTTP ' || v_response.status || '). Silakan coba lagi.',
      'error', TRUE
    );
  END IF;

  v_response_body := v_response.content::JSONB;
  v_reply := v_response_body->'choices'->0->'message'->>'content';

  RETURN jsonb_build_object(
    'reply', COALESCE(v_reply, 'Maaf, saya tidak bisa memproses permintaan ini.'),
    'actions', '[]'::JSONB,
    'tokens_used', (v_response_body->'usage'->>'total_tokens')::INT,
    'model', v_response_body->>'model'
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'reply', 'Maaf, terjadi kesalahan: ' || SQLERRM,
    'error', TRUE
  );
END;
$$;

-- ============================================================
-- 3. Fix AI Tables for Anon Access
-- ============================================================
-- Make user_id nullable (app runs without Supabase Auth)
ALTER TABLE ai_conversations ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE ai_conversations DROP CONSTRAINT IF EXISTS ai_conversations_user_id_fkey;

-- Add RLS policies for AI tables
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'ai_conversations', 'ai_messages', 'ai_action_logs',
    'ai_insights', 'ai_trust_settings'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "Allow anon read %1$s" ON %1$I', tbl);
    EXECUTE format('CREATE POLICY "Allow anon read %1$s" ON %1$I FOR SELECT TO anon USING (true)', tbl);
    EXECUTE format('DROP POLICY IF EXISTS "Allow anon insert %1$s" ON %1$I', tbl);
    EXECUTE format('CREATE POLICY "Allow anon insert %1$s" ON %1$I FOR INSERT TO anon WITH CHECK (true)', tbl);
    EXECUTE format('DROP POLICY IF EXISTS "Allow anon update %1$s" ON %1$I', tbl);
    EXECUTE format('CREATE POLICY "Allow anon update %1$s" ON %1$I FOR UPDATE TO anon USING (true)', tbl);
  END LOOP;
END $$;
