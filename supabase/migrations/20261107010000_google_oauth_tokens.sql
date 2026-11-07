CREATE TABLE IF NOT EXISTS public.google_oauth_tokens (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    google_sub TEXT NOT NULL,
    google_email TEXT NOT NULL,
    refresh_token_ciphertext TEXT NOT NULL,
    refresh_token_iv TEXT NOT NULL,
    scopes TEXT[] NOT NULL DEFAULT '{}'::text[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS google_oauth_tokens_google_sub_idx
ON public.google_oauth_tokens(google_sub);

CREATE TABLE IF NOT EXISTS public.google_oauth_states (
    state_hash TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    code_verifier_ciphertext TEXT NOT NULL,
    code_verifier_iv TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS google_oauth_states_user_id_idx
ON public.google_oauth_states(user_id);

ALTER TABLE public.google_oauth_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.google_oauth_states ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.google_oauth_tokens FROM anon, authenticated;
REVOKE ALL ON public.google_oauth_states FROM anon, authenticated;

GRANT ALL ON public.google_oauth_tokens TO service_role;
GRANT ALL ON public.google_oauth_states TO service_role;
