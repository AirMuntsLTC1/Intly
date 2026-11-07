import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const CODE_LIFETIME = 10 * 60 * 1000;
const RESEND_COOLDOWN = 60 * 1000;
const MAX_ATTEMPTS = 5;

function respond(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function normalizeEmail(value: unknown): string {
  return String(value ?? "").trim().toLowerCase();
}

function validEmail(email: string): boolean {
  return email.length <= 254 &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function generateCode(): string {
  const bytes = crypto.getRandomValues(new Uint32Array(1));
  return String(bytes[0] % 1000000).padStart(6, "0");
}

async function hashCode(
  email: string,
  code: string,
  pepper: string,
): Promise<string> {
  const input = `${email}:${code}:${pepper}`;

  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );

  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function equalHash(a: string, b: string): boolean {
  if (a.length !== b.length) return false;

  let difference = 0;

  for (let i = 0; i < a.length; i++) {
    difference |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }

  return difference === 0;
}

function base64url(bytes: Uint8Array): string {
  let binary = "";

  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

async function getGoogleAccessToken(): Promise<string> {
  const clientId = Deno.env.get("GOOGLE_CLIENT_ID");

  const clientSecret =
    Deno.env.get("GOOGLE_CLIENT_SECRET") ??
    Deno.env.get("GOOLE_SECRET_KEY");

  const refreshToken = Deno.env.get("GOOGLE_REFRESH_TOKEN");

  if (!clientId || !clientSecret || !refreshToken) {
    throw new Error(
      "Google OAuth configuration is incomplete. Check the Gmail secrets.",
    );
  }

  const result = await fetch(
    "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        refresh_token: refreshToken,
        grant_type: "refresh_token",
      }),
    },
  );

  const data = await result.json();

  if (!result.ok || !data.access_token) {
    console.error("Google token refresh failed:", data.error);
    throw new Error("Unable to connect to Gmail.");
  }

  return data.access_token;
}

async function sendVerificationEmail(
  email: string,
  code: string,
  purpose: string,
) {
  const accessToken = await getGoogleAccessToken();

  const isSignup = purpose === "signup";

  const subject = isSignup
    ? "Your Intly registration verification code"
    : "Your Intly password reset code";

  const body = [
    "Hello!",
    "",
    isSignup
      ? "Use this code to verify your email and create your Intly account:"
      : "Use this code to reset your Intly password:",
    "",
    code,
    "",
    "This code expires in 10 minutes.",
    "You have a maximum of 5 verification attempts.",
    "",
    "If you did not request this code, ignore this email.",
    "",
    "The Intly Team",
  ].join("\r\n");

  const mime = [
    `To: ${email}`,
    `From: Intly <maximoolid123@gmail.com>`,
    `Subject: ${subject}`,
    "MIME-Version: 1.0",
    "Content-Type: text/plain; charset=UTF-8",
    "Content-Transfer-Encoding: 7bit",
    "",
    body,
  ].join("\r\n");

  const raw = base64url(
    new TextEncoder().encode(mime),
  );

  const result = await fetch(
    "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ raw }),
    },
  );

  if (!result.ok) {
    const error = await result.text();
    console.error("Gmail delivery failed:", error);
    throw new Error("Unable to send verification email.");
  }
}

async function findUserByEmail(
  admin: ReturnType<typeof createClient>,
  email: string,
): Promise<any | null> {
  for (let page = 1; page <= 100; page++) {
    const { data, error } = await admin.auth.admin.listUsers({
      page,
      perPage: 1000,
    });

    if (error) throw error;

    const user = data.users.find(
      (item: any) => item.email?.toLowerCase() === email,
    );

    if (user) return user;

    if (data.users.length < 1000) break;
  }

  return null;
}

function validPassword(password: string): boolean {
  return password.length >= 8 && password.length <= 128;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return respond({ error: "Method not allowed." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const pepper = Deno.env.get("EMAIL_CODE_PEPPER");

  if (!supabaseUrl || !serviceRoleKey || !pepper) {
    return respond({
      error: "Authentication server configuration is incomplete.",
    }, 500);
  }

  const admin = createClient(
    supabaseUrl,
    serviceRoleKey,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );

  try {
    const input = await req.json();

    const action = String(input.action ?? "");
    const email = normalizeEmail(input.email);

    if (!validEmail(email)) {
      return respond({ error: "Enter a valid email address." }, 400);
    }

    // --------------------------------------------------
    // 1. LOGIN: email + password
    // --------------------------------------------------

    if (action === "login") {
      const password = String(input.password ?? "");

      if (!password) {
        return respond({ error: "Enter your password." }, 400);
      }

      const { data, error } = await admin.auth.signInWithPassword({
        email,
        password,
      });

      if (error || !data.session) {
        return respond({
          error: "Incorrect email or password.",
        }, 401);
      }

      return respond({
        success: true,
        message: "Login successful.",
        user: data.user,
        session: data.session,
      });
    }

    // --------------------------------------------------
    // 2. SEND REGISTRATION OR PASSWORD RESET CODE
    // --------------------------------------------------

    if (action === "send_code") {
      const purpose = String(input.purpose ?? "");

      if (!["signup", "password_reset"].includes(purpose)) {
        return respond({ error: "Invalid verification purpose." }, 400);
      }

      // Do not disclose whether an account exists during password reset.
      if (purpose === "password_reset") {
        const existingUser = await findUserByEmail(admin, email);

        if (!existingUser) {
          return respond({
            success: true,
            message:
              "If an account exists for this email, a reset code will be sent.",
            resend_after: 60,
          });
        }
      }

      const { data: previous, error: previousError } = await admin
        .from("email_login_codes")
        .select("last_sent_at")
        .eq("email", email)
        .maybeSingle();

      if (previousError) throw previousError;

      if (previous?.last_sent_at) {
        const elapsed =
          Date.now() - new Date(previous.last_sent_at).getTime();

        if (elapsed < RESEND_COOLDOWN) {
          return respond({
            error: "Please wait before requesting another code.",
            retry_after: Math.ceil(
              (RESEND_COOLDOWN - elapsed) / 1000,
            ),
          }, 429);
        }
      }

      if (purpose === "signup") {
        const username = String(input.username ?? "")
          .trim()
          .toLowerCase();

        const displayName = String(input.display_name ?? "").trim();

        if (!/^[a-z0-9_.]{3,30}$/.test(username)) {
          return respond({
            error:
              "Username must contain 3–30 letters, numbers, dots or underscores.",
          }, 400);
        }

        if (displayName.length > 60) {
          return respond({ error: "Display name is too long." }, 400);
        }

        const { data: existing } = await admin
          .from("profiles")
          .select("id")
          .ilike("username", username)
          .limit(1);

        if (existing && existing.length > 0) {
          return respond({ error: "That username is already taken." }, 409);
        }
      }

      const code = generateCode();
      const codeHash = await hashCode(email, code, pepper);

      const metadata = purpose === "signup"
        ? {
            username: String(input.username ?? "").trim().toLowerCase(),
            display_name: String(input.display_name ?? "").trim(),
          }
        : {};

      const now = new Date();

      const { error: saveError } = await admin
        .from("email_login_codes")
        .upsert({
          email,
          code_hash: codeHash,
          purpose,
          user_metadata: metadata,
          expires_at: new Date(
            now.getTime() + CODE_LIFETIME,
          ).toISOString(),
          attempts: 0,
          last_sent_at: now.toISOString(),
          created_at: now.toISOString(),
        });

      if (saveError) throw saveError;

      try {
        await sendVerificationEmail(email, code, purpose);
      } catch (error) {
        await admin
          .from("email_login_codes")
          .delete()
          .eq("email", email);

        throw error;
      }

      return respond({
        success: true,
        message: "Verification code sent.",
        expires_in: 600,
        resend_after: 60,
      });
    }

    // --------------------------------------------------
    // 3. VERIFY CODE: registration or password reset
    // --------------------------------------------------

    if (action === "verify_code") {
      const code = String(input.code ?? "").trim();
      const purpose = String(input.purpose ?? "");
      const password = String(input.password ?? "");

      if (!["signup", "password_reset"].includes(purpose)) {
        return respond({ error: "Invalid verification purpose." }, 400);
      }

      if (!/^\d{6}$/.test(code)) {
        return respond({
          error: "Enter the six-digit verification code.",
        }, 400);
      }

      if (!validPassword(password)) {
        return respond({
          error: "Password must be between 8 and 128 characters.",
        }, 400);
      }

      const { data: record, error: lookupError } = await admin
        .from("email_login_codes")
        .select("*")
        .eq("email", email)
        .maybeSingle();

      if (lookupError) throw lookupError;

      if (!record || record.purpose !== purpose) {
        return respond({
          error: "Invalid verification request. Request a new code.",
        }, 400);
      }

      if (new Date(record.expires_at).getTime() <= Date.now()) {
        await admin
          .from("email_login_codes")
          .delete()
          .eq("email", email);

        return respond({
          error: "Verification code expired. Request a new one.",
        }, 400);
      }

      if (record.attempts >= MAX_ATTEMPTS) {
        await admin
          .from("email_login_codes")
          .delete()
          .eq("email", email);

        return respond({
          error: "Too many attempts. Request a new code.",
        }, 429);
      }

      const suppliedHash = await hashCode(email, code, pepper);

      if (!equalHash(suppliedHash, record.code_hash)) {
        await admin
          .from("email_login_codes")
          .update({ attempts: record.attempts + 1 })
          .eq("email", email);

        return respond({
          error: "Incorrect verification code.",
          attempts_remaining: MAX_ATTEMPTS - record.attempts - 1,
        }, 400);
      }

      // ----------------------------------------------
      // Registration: create confirmed Supabase account
      // ----------------------------------------------

      if (purpose === "signup") {
        const existingUser = await findUserByEmail(admin, email);

        if (existingUser) {
          await admin
            .from("email_login_codes")
            .delete()
            .eq("email", email);

          return respond({
            error: "An account already exists. Please sign in.",
          }, 409);
        }

        const metadata = record.user_metadata ?? {};

        const { data: created, error: createError } =
          await admin.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
            user_metadata: {
              username: metadata.username,
              display_name: metadata.display_name,
            },
          });

        if (createError) {
          if (createError.message.toLowerCase().includes("already")) {
            return respond({
              error: "An account already exists. Please sign in.",
            }, 409);
          }

          throw createError;
        }

        // The existing database trigger creates profiles and settings.
        const { data: login, error: loginError } =
          await admin.auth.signInWithPassword({
            email,
            password,
          });

        if (loginError || !login.session) {
          throw new Error(
            "Account created, but session creation failed. Please sign in.",
          );
        }

        await admin
          .from("email_login_codes")
          .delete()
          .eq("email", email);

        return respond({
          success: true,
          message: "Your Intly account was created successfully.",
          user: login.user ?? created.user,
          session: login.session,
        });
      }

      // ----------------------------------------------
      // Password reset: update existing user's password
      // ----------------------------------------------

      if (purpose === "password_reset") {
        const user = await findUserByEmail(admin, email);

        if (!user) {
          await admin
            .from("email_login_codes")
            .delete()
            .eq("email", email);

          return respond({
            error: "Unable to reset this account.",
          }, 400);
        }

        const { error: updateError } =
          await admin.auth.admin.updateUserById(user.id, {
            password,
          });

        if (updateError) throw updateError;

        await admin
          .from("email_login_codes")
          .delete()
          .eq("email", email);

        const { data: login, error: loginError } =
          await admin.auth.signInWithPassword({
            email,
            password,
          });

        if (loginError || !login.session) {
          return respond({
            success: true,
            message:
              "Password updated successfully. Please sign in with your new password.",
          });
        }

        return respond({
          success: true,
          message: "Your password has been reset successfully.",
          user: login.user,
          session: login.session,
        });
      }
    }

    return respond({
      error: "Unknown action. Use login, send_code, or verify_code.",
    }, 400);
  } catch (error) {
    console.error("Intly authentication error:", error);

    return respond({
      error: error instanceof Error
        ? error.message
        : "Authentication request failed.",
    }, 500);
  }
});
