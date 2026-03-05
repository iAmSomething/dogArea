import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

type Action = "get_my_league" | "get_leaderboard" | "export_my_data" | "delete_my_data";
type LeaderboardPeriod = "day" | "week" | "season";

type RequestDTO = {
  action?: Action;
  periodType?: LeaderboardPeriod;
  topN?: number;
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
  if (!supabaseURL || !supabaseAnonKey) {
    return json({ error: "SERVER_MISCONFIGURED" }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json({ error: "UNAUTHORIZED" }, 401);
  }
  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) return json({ error: "UNAUTHORIZED" }, 401);

  const userClient = createClient(supabaseURL, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userResult, error: userError } = await userClient.auth.getUser(token);
  if (userError || !userResult?.user) {
    return json({ error: "UNAUTHORIZED" }, 401);
  }

  let body: RequestDTO;
  try {
    body = await req.json();
  } catch {
    return json({ error: "INVALID_JSON" }, 400);
  }

  if (!body.action) return json({ error: "ACTION_REQUIRED" }, 400);

  const nowISO = new Date().toISOString();
  switch (body.action) {
    case "get_my_league": {
      const { data, error } = await userClient.rpc("rpc_get_my_rival_league", {
        requested_user_id: userResult.user.id,
        now_ts: nowISO,
      });
      if (error) return json({ error: error.message }, 500);
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
      if (error) return json({ error: error.message }, 500);
      return json({ leaderboard: Array.isArray(data) ? data : [] });
    }
    case "export_my_data": {
      const { data, error } = await userClient.rpc("rpc_export_my_rival_data", {
        requested_user_id: userResult.user.id,
        now_ts: nowISO,
      });
      if (error) return json({ error: error.message }, 500);
      return json({ export: data });
    }
    case "delete_my_data": {
      const { data, error } = await userClient.rpc("rpc_delete_my_rival_data", {
        requested_user_id: userResult.user.id,
        now_ts: nowISO,
      });
      if (error) return json({ error: error.message }, 500);
      const row = Array.isArray(data) && data.length > 0 ? data[0] : null;
      return json({ deleted: row });
    }
    default:
      return json({ error: "UNSUPPORTED_ACTION" }, 400);
  }
});
