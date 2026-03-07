import { resolveEdgeAuthContext } from "../_shared/edge_auth.ts";
import { resolveCanonicalIdempotencyKey, resolveCanonicalRequestId } from "../_shared/request_keys.ts";
import { handleBackfillSummary } from "./handlers/backfill_summary.ts";
import { dispatchSyncWalkStage, isSupportedSyncStage } from "./handlers/stage_dispatcher.ts";
import { asRecord, json, toUUIDOrNull } from "./support/core.ts";
import type { RequestDTO } from "./support/types.ts";

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
      functionName: "sync-walk",
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

  if (!body.action) {
    return json({ error: "ACTION_REQUIRED" }, 400);
  }

  const bodyRecord = asRecord(body);
  const requestId = resolveCanonicalRequestId(bodyRecord, auth.context.requestId);

  if (body.action === "get_backfill_summary") {
    const sessionIds = (body.session_ids ?? [])
      .map((id) => toUUIDOrNull(id))
      .filter((id): id is string => Boolean(id));

    return handleBackfillSummary({
      userClient,
      requestId,
      sessionIds,
    });
  }

  if (body.action !== "sync_walk_stage") {
    return json({ error: "UNSUPPORTED_ACTION" }, 400);
  }

  const walkSessionId = toUUIDOrNull(body.walk_session_id);
  const payload = asRecord(body.payload);
  if (!walkSessionId || !isSupportedSyncStage(body.stage)) {
    return json({ error: "INVALID_PAYLOAD" }, 400);
  }

  const idempotencyKey = resolveCanonicalIdempotencyKey(bodyRecord, {
    keys: ["idempotency_key", "idempotencyKey", "request_id", "requestId"],
    fallback: requestId,
  });

  return dispatchSyncWalkStage(body.stage, {
    userClient,
    userId,
    requestId,
    walkSessionId,
    idempotencyKey,
    payload,
  });
});
