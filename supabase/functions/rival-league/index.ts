import { resolveEdgeAuthContext } from "../_shared/edge_auth.ts";
import { requireSupabaseRuntimeEnv } from "../_shared/edge_runtime.ts";
import { errorJson, json, methodNotAllowed, parseJsonBody } from "../_shared/http.ts";

type Action = "get_my_league" | "get_leaderboard" | "export_my_data" | "delete_my_data";
type LeaderboardPeriod = "day" | "week" | "season";

type RequestDTO = {
  action?: Action;
  periodType?: LeaderboardPeriod;
  topN?: number;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return methodNotAllowed();

  const runtime = requireSupabaseRuntimeEnv();
  if (!runtime.ok) return runtime.response;
  const { supabaseURL, supabaseAnonKey } = runtime.value;

  const auth = await resolveEdgeAuthContext({
    req,
    policy: {
      functionName: "rival-league",
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

  const nowISO = new Date().toISOString();
  switch (body.action) {
    case "get_my_league": {
      const { data, error } = await userClient.rpc("rpc_get_my_rival_league", {
        requested_user_id: userId,
        now_ts: nowISO,
      });
      if (error) return errorJson(error.message, 500);
      const row = Array.isArray(data) && data.length > 0 ? data[0] : null;
      return json({ league: row });
    }
    case "get_leaderboard": {
      const periodType = body.periodType ?? "week";
      const topN = Math.max(1, Math.min(Number(body.topN ?? 20), 200));
      const { data, error } = await userClient.rpc("rpc_get_rival_leaderboard", {
        payload: {
          period_type: periodType,
          top_n: topN,
          now_ts: nowISO,
        },
      });
      if (error) return errorJson(error.message, 500);
      return json({ leaderboard: Array.isArray(data) ? data : [] });
    }
    case "export_my_data": {
      const { data, error } = await userClient.rpc("rpc_export_my_rival_data", {
        requested_user_id: userId,
        now_ts: nowISO,
      });
      if (error) return errorJson(error.message, 500);
      return json({ export: data });
    }
    case "delete_my_data": {
      const { data, error } = await userClient.rpc("rpc_delete_my_rival_data", {
        requested_user_id: userId,
        now_ts: nowISO,
      });
      if (error) return errorJson(error.message, 500);
      const row = Array.isArray(data) && data.length > 0 ? data[0] : null;
      return json({ deleted: row });
    }
    default:
      return errorJson("UNSUPPORTED_ACTION", 400);
  }
});
