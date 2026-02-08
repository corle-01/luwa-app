-- ============================================================
-- UTTER APP - Database Migration 015: Fix AI API Key
-- ============================================================
-- Run this AFTER 014_fix_ai_timeout.sql
-- Fixes: "API key belum dikonfigurasi" error
-- ALTER DATABASE SET is blocked by Supabase permissions,
-- so we hardcode the key directly in the function.
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
  v_api_key TEXT;
BEGIN
  -- Set HTTP extension timeout to 30 seconds
  PERFORM set_config('http.timeout_milliseconds', '30000', true);

  BEGIN
    SET LOCAL http.timeout_milliseconds = 30000;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- API key hardcoded (ALTER DATABASE SET blocked by Supabase)
  v_api_key := 'sk-13f5fc4e39f948839fd138cbe32c7182';

  -- Build system prompt with business context
  v_system_prompt := 'Kamu adalah Utter, AI co-pilot untuk bisnis F&B (kafe/restoran). ' ||
    'Kamu membantu pemilik bisnis dengan analisa penjualan, manajemen stok, dan saran bisnis. ' ||
    'Selalu jawab dalam Bahasa Indonesia yang natural dan ramah. ' ||
    'Berikan jawaban yang ringkas dan langsung ke poin. ' ||
    'Jika ada data konteks, gunakan untuk menjawab. Konteks: ' || COALESCE(p_context::TEXT, '{}');

  -- Build messages array: system + history + user message
  v_messages := jsonb_build_array(
    jsonb_build_object('role', 'system', 'content', v_system_prompt)
  ) || COALESCE(p_history, '[]'::JSONB) || jsonb_build_array(
    jsonb_build_object('role', 'user', 'content', p_message)
  );

  -- Build request body
  v_request_body := jsonb_build_object(
    'model', 'deepseek-chat',
    'messages', v_messages,
    'max_tokens', 800,
    'temperature', 0.7
  )::TEXT;

  -- Make HTTP call to DeepSeek API
  SELECT * INTO v_response FROM extensions.http(
    (
      'POST',
      'https://api.deepseek.com/chat/completions',
      ARRAY[
        extensions.http_header('Authorization', 'Bearer ' || v_api_key),
        extensions.http_header('Content-Type', 'application/json')
      ],
      'application/json',
      v_request_body
    )::extensions.http_request
  );

  -- Handle connection failure
  IF v_response.status IS NULL THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, tidak bisa terhubung ke server AI. Periksa koneksi internet dan coba lagi.',
      'error', TRUE
    );
  END IF;

  -- Handle non-200 responses
  IF v_response.status != 200 THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, terjadi kesalahan saat menghubungi AI (HTTP ' || v_response.status || '). Silakan coba lagi.',
      'error', TRUE,
      'status_code', v_response.status
    );
  END IF;

  -- Parse successful response
  BEGIN
    v_response_body := v_response.content::JSONB;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, respons dari AI tidak valid. Silakan coba lagi.',
      'error', TRUE
    );
  END;

  v_reply := v_response_body->'choices'->0->'message'->>'content';

  RETURN jsonb_build_object(
    'reply', COALESCE(v_reply, 'Maaf, saya tidak bisa memproses permintaan ini.'),
    'actions', '[]'::JSONB,
    'tokens_used', (v_response_body->'usage'->>'total_tokens')::INT,
    'model', v_response_body->>'model'
  );

EXCEPTION
  WHEN query_canceled THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, permintaan AI memakan waktu terlalu lama. Coba pertanyaan yang lebih singkat.',
      'error', TRUE
    );
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, terjadi kesalahan: ' || SQLERRM,
      'error', TRUE
    );
END;
$$;
