import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { resolveEdgeAuthContext } from "../_shared/edge_auth.ts";

type Action = "get_flags" | "track_metric" | "get_rollout_kpis";

type RequestDTO = {
  action: Action;
  keys?: string[];
  eventName?: string;
  featureKey?: string;
  eventValue?: number;
  appInstanceId?: string;
  userKey?: string;
  payload?: Record<string, unknown>;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !supabaseAnonKey || !serviceRole) {
    return json({ error: "SERVER_MISCONFIGURED" }, 500);
  }

  const auth = await resolveEdgeAuthContext({
    req,
    policy: {
      functionName: "feature-control",
      kind: "member_or_anon",
    },
    supabaseURL,
    supabaseAnonKey,
    supabaseServiceRoleKey: serviceRole,
  });
  if (!auth.ok) {
    return auth.response;
  }

  const client = createClient(supabaseURL, serviceRole);
  let body: RequestDTO;
  try {
    body = await req.json();
  } catch {
    return json({ error: "INVALID_JSON" }, 400);
  }

  if (!body.action) return json({ error: "ACTION_REQUIRED" }, 400);

  if (body.action === "get_flags") {
    const keys = (body.keys ?? []).filter((key) => key.startsWith("ff_"));
    let query = client
      .from("feature_flags")
      .select("key,is_enabled,rollout_percent,updated_at")
      .order("key", { ascending: true });

    if (keys.length > 0) {
      query = query.in("key", keys);
    }

    const { data, error } = await query;
    if (error) return json({ error: error.message }, 500);
    return json({ flags: data ?? [] });
  }

  if (body.action === "track_metric") {
    if (!body.eventName || !body.appInstanceId) {
      return json({ error: "INVALID_PAYLOAD" }, 400);
    }

    const payload = body.payload && typeof body.payload === "object"
      ? body.payload
      : {};

    const { error } = await client.from("app_metric_events").insert({
      event_name: body.eventName,
      feature_key: body.featureKey ?? null,
      event_value: typeof body.eventValue === "number" ? body.eventValue : null,
      app_instance_id: body.appInstanceId,
      user_key: body.userKey ?? null,
      payload,
    });

    if (error) return json({ error: error.message }, 500);
    return json({ ok: true });
  }

  if (body.action === "get_rollout_kpis") {
    const { data, error } = await client
      .from("view_rollout_kpis_24h")
      .select("*")
      .limit(1)
      .maybeSingle();

    if (error) return json({ error: error.message }, 500);
    return json({ kpis: data ?? null });
  }

  return json({ error: "UNSUPPORTED_ACTION" }, 400);
});
