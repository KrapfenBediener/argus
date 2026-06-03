// © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
// Edge Function: exchange-code
// Validiert einen 8-stelligen Argus-Code und gibt ein signiertes JWT zurück.
// Kein User-Datensatz wird angelegt — Pseudonymität ist gewahrt.
// JWT enthält: praesidium_id, is_master, role, iat, exp (kein Name, keine E-Mail).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function b64url(data: Uint8Array): string {
  let b = "";
  for (let i = 0; i < data.length; i++) b += String.fromCharCode(data[i]);
  return btoa(b).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

function encodeJson(obj: unknown): string {
  return b64url(new TextEncoder().encode(JSON.stringify(obj)));
}

async function signJwt(
  payload: Record<string, unknown>,
  secret: string,
): Promise<string> {
  const header = encodeJson({ alg: "HS256", typ: "JWT" });
  const body = encodeJson(payload);
  const input = `${header}.${body}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = b64url(
    new Uint8Array(
      await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(input)),
    ),
  );
  return `${input}.${sig}`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  try {
    const { code } = await req.json();
    if (!code || typeof code !== "string") {
      return new Response(JSON.stringify({ error: "Code fehlt" }), {
        status: 400,
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    // Code bereinigen: Bindestriche + Leerzeichen entfernen, uppercase
    const clean = code.replace(/[\s\-]/g, "").toUpperCase();
    if (clean.length < 8) {
      return new Response(JSON.stringify({ error: "Code zu kurz" }), {
        status: 400,
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }
    const shortCode = `${clean.slice(0, 4)}-${clean.slice(4, 8)}`;

    // Service-Role-Client (privilegierter Zugriff — nie im App-Frontend)
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const jwtSecret = Deno.env.get("SUPABASE_JWT_SECRET")!;

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Token in access_tokens suchen
    const { data: token, error: tokenErr } = await admin
      .from("access_tokens")
      .select(
        "praesidium_id, is_master, ttl_hours, single_use, used_at, temporary",
      )
      .eq("short_code", shortCode)
      .maybeSingle();

    if (tokenErr || !token) {
      return new Response(
        JSON.stringify({ error: "Ungültiger oder verbrauchter Code" }),
        {
          status: 401,
          headers: { ...CORS, "Content-Type": "application/json" },
        },
      );
    }

    // Einmal-Code bereits verbraucht?
    if (token.single_use && token.used_at) {
      return new Response(
        JSON.stringify({ error: "Ungültiger oder verbrauchter Code" }),
        {
          status: 401,
          headers: { ...CORS, "Content-Type": "application/json" },
        },
      );
    }

    // TTL berechnen
    const now = Math.floor(Date.now() / 1000);
    const ttlSeconds = token.is_master
      ? 30 * 24 * 3600 // MasterToken: 30 Tage
      : token.ttl_hours
        ? token.ttl_hours * 3600 // temporär: z. B. 24 h
        : 30 * 24 * 3600; // dauerhaft: 30 Tage
    const exp = now + ttlSeconds;

    // JWT signieren — enthält praesidium_id, is_master, role=anon, exp
    const jwt = await signJwt(
      {
        iss: "supabase",
        sub: "argus-device",
        role: "anon",
        praesidium_id: token.praesidium_id ?? null,
        is_master: token.is_master ?? false,
        iat: now,
        exp,
      },
      jwtSecret,
    );

    // Einmal-Code als verbraucht markieren
    if (token.single_use && !token.used_at) {
      await admin
        .from("access_tokens")
        .update({ used_at: new Date().toISOString() })
        .eq("short_code", shortCode)
        .is("used_at", null);
    }

    // Präsidiumsname laden (für Bestätigungs-UI)
    let praesidiumName: string | null = null;
    if (token.praesidium_id) {
      const { data: p } = await admin
        .from("praesidien")
        .select("name")
        .eq("id", token.praesidium_id)
        .maybeSingle();
      praesidiumName = p?.name ?? null;
    }

    return new Response(
      JSON.stringify({
        jwt,
        exp,
        praesidium_id: token.praesidium_id ?? null,
        praesidium_name: praesidiumName,
        is_master: token.is_master ?? false,
        ttl_seconds: ttlSeconds,
      }),
      { status: 200, headers: { ...CORS, "Content-Type": "application/json" } },
    );
  } catch (_err) {
    return new Response(JSON.stringify({ error: "Interner Fehler" }), {
      status: 500,
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
});
