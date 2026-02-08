-- ============================================================
-- Migration 016: Fix AI timeout + enrich context query
-- ============================================================

CREATE OR REPLACE FUNCTION ai_chat(
  p_message TEXT,
  p_history JSONB DEFAULT '[]',
  p_context JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET statement_timeout = '120s'
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
  -- Try to set HTTP timeout (may or may not work on Supabase)
  PERFORM set_config('http.timeout_milliseconds', '120000', true);

  v_api_key := 'sk-13f5fc4e39f948839fd138cbe32c7182';

  v_system_prompt := 'Kamu adalah Utter, AI co-pilot untuk bisnis F&B (kafe/restoran). ' ||
    'Kamu membantu pemilik bisnis dengan analisa penjualan, manajemen stok, dan saran bisnis. ' ||
    'Selalu jawab dalam Bahasa Indonesia yang natural dan ramah. ' ||
    'Berikan jawaban yang ringkas dan langsung ke poin. ' ||
    'Jika ada data konteks, gunakan untuk menjawab dengan detail. Konteks: ' || COALESCE(p_context::TEXT, '{}');

  v_messages := jsonb_build_array(
    jsonb_build_object('role', 'system', 'content', v_system_prompt)
  ) || COALESCE(p_history, '[]'::JSONB) || jsonb_build_array(
    jsonb_build_object('role', 'user', 'content', p_message)
  );

  v_request_body := jsonb_build_object(
    'model', 'deepseek-chat',
    'messages', v_messages,
    'max_tokens', 1500,
    'temperature', 0.7
  )::TEXT;

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

  IF v_response.status IS NULL THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, tidak bisa terhubung ke server AI. Coba lagi.',
      'error', TRUE
    );
  END IF;

  IF v_response.status != 200 THEN
    RETURN jsonb_build_object(
      'reply', 'Maaf, error dari AI server (HTTP ' || v_response.status || '). Coba lagi.',
      'error', TRUE,
      'status_code', v_response.status
    );
  END IF;

  BEGIN
    v_response_body := v_response.content::JSONB;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('reply', 'Respons AI tidak valid.', 'error', TRUE);
  END;

  v_reply := v_response_body->'choices'->0->'message'->>'content';

  RETURN jsonb_build_object(
    'reply', COALESCE(v_reply, 'Tidak ada respons.'),
    'actions', '[]'::JSONB,
    'tokens_used', (v_response_body->'usage'->>'total_tokens')::INT,
    'model', v_response_body->>'model'
  );

EXCEPTION
  WHEN query_canceled THEN
    RETURN jsonb_build_object('reply', 'Timeout. Coba pertanyaan lebih singkat.', 'error', TRUE);
  WHEN OTHERS THEN
    RETURN jsonb_build_object('reply', 'Error: ' || SQLERRM, 'error', TRUE);
END;
$$;
