import { resolveEdgeAuthContext } from "../_shared/edge_auth.ts";
import { requireSupabaseRuntimeEnv } from "../_shared/edge_runtime.ts";
import { errorJson, json, methodNotAllowed, parseJsonBody } from "../_shared/http.ts";
import { asRecord, asString, toNumber, toUUIDOrNull } from "../_shared/parsers.ts";
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

Deno.serve(async (req) => {
  if (req.method !== "POST") return methodNotAllowed();

  const runtime = requireSupabaseRuntimeEnv();
  if (!runtime.ok) return runtime.response;
  const { supabaseURL, supabaseAnonKey } = runtime.value;

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

  const parsedBody = await parseJsonBody<RequestDTO>(req);
  if (!parsedBody.ok) return parsedBody.response;
  const body = parsedBody.body;

  if (!body.action) return errorJson("ACTION_REQUIRED", 400);

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
      if (error) return errorJson(error.message, 500);

      return json({ request_id: requestId, quests: Array.isArray(data) ? data : [] });
    }

    case "ingest_walk_event": {
      const instanceId = toUUIDOrNull(body.instance_id ?? body.instanceId ?? body.target_instance_id);
      const eventId = resolveCanonicalIdempotencyKey(bodyRecord, {
        keys: ["event_id", "eventId", "idempotency_key", "idempotencyKey", "action_id"],
        fallback: requestId,
      });
      if (!instanceId || !eventId) {
        return errorJson("INVALID_PAYLOAD", 400);
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
      if (error) return errorJson(error.message, 500);

      const row = Array.isArray(data) && data.length > 0 ? data[0] : null;
      return json({ request_id: requestId, progress: row });
    }

    case "claim_reward": {
      const instanceId = toUUIDOrNull(body.instance_id ?? body.instanceId ?? body.target_instance_id);
      if (!instanceId) return errorJson("INVALID_PAYLOAD", 400);

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
      if (error) return errorJson(error.message, 500);

      const row = Array.isArray(data) && data.length > 0 ? data[0] : null;
      return json({ request_id: requestId, claim: row });
    }

    case "transition_status": {
      const instanceId = toUUIDOrNull(body.instance_id ?? body.instanceId ?? body.target_instance_id);
      const transitionAction = asString(body.transition_action ?? body.transitionAction);
      if (!instanceId || !transitionAction) {
        return errorJson("INVALID_PAYLOAD", 400);
      }

      const { data, error } = await userClient.rpc("rpc_transition_quest_status", {
        target_user_id: userId,
        target_instance_id: instanceId,
        transition_action: transitionAction,
        replacement_template_id: asString(body.replacement_template_id ?? body.replacementTemplateId),
        now_ts: nowISO,
      });
      if (error) return errorJson(error.message, 500);

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

      if (error) return errorJson(error.message, 500);
      return json({ request_id: requestId, quests: data ?? [] });
    }

    default:
      return errorJson("UNSUPPORTED_ACTION", 400);
  }
});
