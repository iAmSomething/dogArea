import { resolveEdgeAuthContext } from "../_shared/edge_auth.ts";
import { resolveCanonicalIdempotencyKey, resolveCanonicalRequestId } from "../_shared/request_keys.ts";

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
  cycle_key?: string;
  cycleKey?: string;
  expires_at?: string;
  expiresAt?: string;
  instance_id?: string;
  instanceId?: string;
  target_instance_id?: string;
  event_id?: string;
  eventId?: string;
  event_type?: string;
  eventType?: string;
  delta_value?: number;
  deltaValue?: number;
  payload?: Record<string, unknown>;
  request_id?: string;
  requestId?: string;
  idempotency_key?: string;
  idempotencyKey?: string;
  transition_action?: TransitionAction;
  transitionAction?: TransitionAction;
  replacement_template_id?: string;
  replacementTemplateId?: string;
  now_ts?: string;
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

  const bodyRecord = asRecord(body);
  const requestId = resolveCanonicalRequestId(bodyRecord, auth.context.requestId);
  const nowISO = asString(body.now_ts) ?? new Date().toISOString();

  switch (body.action) {
    case "issue_quests": {
      const scope = asString(body.scope) ?? "daily";
      const cycleKey = asString(body.cycle_key ?? body.cycleKey);
      const expiresAt = asString(body.expires_at ?? body.expiresAt);

      const { data, error } = await userClient.rpc("rpc_issue_quest_instances", {
        target_user_id: userId,
        target_scope: scope,
        target_cycle_key: cycleKey,
        expires_at: expiresAt,
        now_ts: nowISO,
      });
      if (error) return json({ error: error.message }, 500);

      return json({ request_id: requestId, quests: Array.isArray(data) ? data : [] });
    }

    case "ingest_walk_event": {
      const instanceId = toUUIDOrNull(body.instance_id ?? body.instanceId ?? body.target_instance_id);
      const eventId = resolveCanonicalIdempotencyKey(bodyRecord, {
        keys: ["event_id", "eventId", "idempotency_key", "idempotencyKey", "action_id"],
        fallback: requestId,
      });
      if (!instanceId || !eventId) {
        return json({ error: "INVALID_PAYLOAD" }, 400);
      }

      const { data, error } = await userClient.rpc("rpc_apply_quest_progress_event", {
        target_user_id: userId,
        target_instance_id: instanceId,
        event_id: eventId,
        event_type: asString(body.event_type ?? body.eventType) ?? "walk_event",
        delta_value: Math.max(0, toNumber(body.delta_value ?? body.deltaValue, 1)),
        payload: asRecord(body.payload),
        now_ts: nowISO,
      });
      if (error) return json({ error: error.message }, 500);

      const row = Array.isArray(data) && data.length > 0 ? data[0] : null;
      return json({ request_id: requestId, progress: row });
    }

    case "claim_reward": {
      const instanceId = toUUIDOrNull(body.instance_id ?? body.instanceId ?? body.target_instance_id);
      if (!instanceId) return json({ error: "INVALID_PAYLOAD" }, 400);

      const claimRequestId = resolveCanonicalIdempotencyKey(bodyRecord, {
        keys: ["request_id", "requestId", "idempotency_key", "idempotencyKey", "action_id"],
        fallback: requestId,
      });

      const { data, error } = await userClient.rpc("rpc_claim_quest_reward", {
        target_user_id: userId,
        target_instance_id: instanceId,
        request_id: claimRequestId,
        now_ts: nowISO,
      });
      if (error) return json({ error: error.message }, 500);

      const row = Array.isArray(data) && data.length > 0 ? data[0] : null;
      return json({ request_id: requestId, claim: row });
    }

    case "transition_status": {
      const instanceId = toUUIDOrNull(body.instance_id ?? body.instanceId ?? body.target_instance_id);
      const transitionAction = asString(body.transition_action ?? body.transitionAction);
      if (!instanceId || !transitionAction) {
        return json({ error: "INVALID_PAYLOAD" }, 400);
      }

      const { data, error } = await userClient.rpc("rpc_transition_quest_status", {
        target_user_id: userId,
        target_instance_id: instanceId,
        transition_action: transitionAction,
        replacement_template_id: asString(body.replacement_template_id ?? body.replacementTemplateId),
        now_ts: nowISO,
      });
      if (error) return json({ error: error.message }, 500);

      const row = Array.isArray(data) && data.length > 0 ? data[0] : null;
      return json({ request_id: requestId, transition: row });
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
      return json({ request_id: requestId, quests: data ?? [] });
    }

    default:
      return json({ error: "UNSUPPORTED_ACTION" }, 400);
  }
});
