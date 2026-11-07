SELECT jsonb_pretty(
  jsonb_build_object(
    'success', true,
    'connected', EXISTS (
      SELECT 1
      FROM public.google_oauth_tokens
    ),
    'account', (
      SELECT google_email
      FROM public.google_oauth_tokens
      ORDER BY created_at DESC
      LIMIT 1
    ),
    'scopes', COALESCE(
      (
        SELECT to_jsonb(scopes)
        FROM public.google_oauth_tokens
        ORDER BY created_at DESC
        LIMIT 1
      ),
      '[]'::jsonb
    ),
    'token_status', CASE
      WHEN EXISTS (
        SELECT 1
        FROM public.google_oauth_tokens
        WHERE refresh_token_ciphertext IS NOT NULL
          AND refresh_token_iv IS NOT NULL
      )
      THEN 'ENCRYPTED TOKEN STORED'
      ELSE 'MISSING'
    END
  )
);
