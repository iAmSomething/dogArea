import { resolveEdgeAuthContext } from "../_shared/edge_auth.ts";

type Action =
  | "issue_quests"
  | "ingest_walk_event"
  | "claim_reward"
  | "transition_status"
  | "list_active";

type QuestScope = "daily" | "weekly";
type TransitionAction = "expire" | "reroll" | "replace";

type RequestDTO = {
  action?: Action;
  scope?: QuestScope;
  cycleKey?: string;
  expiresAt?: string;
  instanceId?: string;
  eventId?: string;
  eventType?: string;
  deltaValue?: number;
  payload?: Record<string, unknown>;
  requestId?: string;
  transitionAction?: TransitionAction;
  replacementTemplateId?: string;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const asString = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const asRecord = (value: unknown): Record<string, unknown> =>
  typeof value === "object" && value !== null ? (value as Record<string, unknown>) : {};

const toNumber = (value: unknown, fallback = 0): number => {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
};

const toUUIDOrNull = (value: unknown): string | null => {
  const raw = asString(value);
  if (!raw) return null;
  const normalized = raw.toLowerCase();
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
  return uuidPattern.test(normalized) ? normalized : null;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseURL || !supabaseAnonKey) {
    return json({ error: "SERVER_MISCONFIGURED" }, 500);
  }

  const auth = await resolveEdgeAuthContext({
    req,
    policy: {
      functionName: "quest-engine",
      kind: "member_required",
    },
    supabaseURL,
    supabaseAnonKey,
  });
  if (!auth.ok) {
    return auth.response;
  }
  const userClient = auth.context.userClient!;
  const userId = auth.context.userId!;

  let body: RequestDTO;
  try {
    body = await req.json();
  } catch {
    return json({ error: "INVALID_JSON" }, 400);
  }

  if (!body.action) return json({ error: "ACTION_REQUIRED" }, 400);

  const nowISO = new Date().toISOString();

  switch (body.action) {
    case "issue_quests": {
      const scope = asString(body.scope) ?? "daily";
      const cycleKey = asString(body.cycleKey);
      const expiresAt = asString(body.expiresAt);

      const { data, error } = await userClient.rpc("rpc_issue_quest_instances", {
        target_user_id: userId,
        target_scope: scope,
        target_cycle_key: cycleKey,
        expires_at: expiresAt,
        now_ts: nowISO,
      });
      if (error) return json({ error: error.message }, 500);

      return json({ quests: Array.isArray(data) ? data : [] });
    }

    case "ingest_walk_event": {
      const instanceId = toUUIDOrNull(body.instanceId);
      const eventId = asString(body.eventId);
      if (!instanceId || !eventId) {
        return json({ error: "INVALID_PAYLOAD" }, 400);
      }

      const { data, error } = await userClient.rpc("rpc_apply_quest_progress_event", {
        target_user_id: userId,
        target_instance_id: instanceId,
        event_id: eventId,
        event_type: asString(body.eventType) ?? "walk_event",
        delta_value: Math.max(0, toNumber(body.deltaValue, 1)),
        payload: asRecord(body.payload),
        now_ts: nowISO,
      });
      if (error) return json({ error: error.message }, 500);

      const row = Array.isArray(data) && data.length > 0 ? data[0] : null;
      return json({ progress: row });
    }

    case "claim_reward": {
      const instanceId = toUUIDOrNull(body.instanceId);
      if (!instanceId) return json({ error: "INVALID_PAYLOAD" }, 400);

      const { data, error } = await userClient.rpc("rpc_claim_quest_reward", {
        target_user_id: userId,
        target_instance_id: instanceId,
        request_id: asString(body.requestId),
        now_ts: nowISO,
      });
      if (error) return json({ error: error.message }, 500);

      const row = Array.isArray(data) && data.length > 0 ? data[0] : null;
      return json({ claim: row });
    }

    case "transition_status": {
      const instanceId = toUUIDOrNull(body.instanceId);
      const transitionAction = asString(body.transitionAction);
      if (!instanceId || !transitionAction) {
        return json({ error: "INVALID_PAYLOAD" }, 400);
      }

      const { data, error } = await userClient.rpc("rpc_transition_quest_status", {
        target_user_id: userId,
        target_instance_id: instanceId,
        transition_action: transitionAction,
        replacement_template_id: asString(body.replacementTemplateId),
        now_ts: nowISO,
      });
      if (error) return json({ error: error.message }, 500);

      const row = Array.isArray(data) && data.length > 0 ? data[0] : null;
      return json({ transition: row });
    }

    case "list_active": {
      const { data, error } = await userClient
        .from("quest_instances")
        .select("id,template_id,quest_scope,quest_type,title_snapshot,target_value_snapshot,progress_value,status,cycle_key,expires_at,completed_at,claimed_at")
        .eq("owner_user_id", userId)
        .in("status", ["active", "completed"])
        .order("created_at", { ascending: false })
        .limit(30);

      if (error) return json({ error: error.message }, 500);
      return json({ quests: data ?? [] });
    }

    default:
      return json({ error: "UNSUPPORTED_ACTION" }, 400);
  }
});
