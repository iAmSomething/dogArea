import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

type SyncStage = "session" | "points" | "meta";
type Action = "sync_walk_stage" | "get_backfill_summary";

type RequestDTO = {
  action?: Action;
  stage?: SyncStage;
  walk_session_id?: string;
  idempotency_key?: string;
  payload?: Record<string, unknown>;
  session_ids?: string[];
};

type SeasonScoreSummaryDTO = {
  walk_session_id: string;
  total_points: number;
  unique_tiles: number;
  novelty_ratio: number;
  repeat_suppressed_count: number;
  suspicious_repeat_count: number;
  base_score: number;
  new_route_bonus: number;
  catchup_bonus?: number;
  total_score: number;
  score_blocked: boolean;
  catchup_buff_active?: boolean;
  catchup_buff_granted_at?: string | null;
  catchup_buff_expires_at?: string | null;
  explain?: Record<string, unknown>;
};

type WeatherReplacementSummaryDTO = {
  applied: boolean;
  shield_applied: boolean;
  blocked_reason: string | null;
  risk_level: string | null;
  replacement_reason: string | null;
  replacement_count_today: number;
  daily_replacement_limit: number;
  shield_used_this_week: number;
  weekly_shield_limit: number;
};

type SeasonPipelineSummaryDTO = {
  season_id: string;
  season_key: string;
  ingested_rows: number;
  tile_rows: number;
  user_total_score: number;
  user_rank: number | null;
  run_status: string;
};

type QuestProgressSummaryDTO = {
  quest_instance_id: string;
  owner_user_id: string;
  event_id: string;
  idempotent: boolean;
  previous_progress: number;
  current_progress: number;
  target_progress: number;
  status: string;
  completed_at: string | null;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const asRecord = (value: unknown): Record<string, unknown> =>
  typeof value === "object" && value !== null ? value as Record<string, unknown> : {};

const asString = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const toNumber = (value: unknown, fallback = 0): number => {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
};

const epochToIso = (value: unknown, fallbackEpochSec: number): string => {
  const epoch = toNumber(value, fallbackEpochSec);
  return new Date(Math.max(0, epoch) * 1000).toISOString();
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
  const userId = userResult.user.id;

  let body: RequestDTO;
  try {
    body = await req.json();
  } catch {
    return json({ error: "INVALID_JSON" }, 400);
  }

  const action = body.action;
  if (!action) return json({ error: "ACTION_REQUIRED" }, 400);

  if (action === "get_backfill_summary") {
    const requestedIds = (body.session_ids ?? [])
      .map((id) => toUUIDOrNull(id))
      .filter((id): id is string => Boolean(id));

    let sessionsQuery = userClient
      .from("walk_sessions")
      .select("id,area_m2,duration_sec")
      .order("started_at", { ascending: false });

    if (requestedIds.length > 0) {
      sessionsQuery = sessionsQuery.in("id", requestedIds);
    }

    const { data: sessions, error: sessionError } = await sessionsQuery;
    if (sessionError) return json({ error: sessionError.message }, 500);

    const safeSessions = sessions ?? [];
    const sessionIds = safeSessions
      .map((row) => asString((row as Record<string, unknown>).id))
      .filter((id): id is string => Boolean(id));

    let pointCount = 0;
    if (sessionIds.length > 0) {
      const { count, error: pointError } = await userClient
        .from("walk_points")
        .select("id", { count: "exact", head: true })
        .in("walk_session_id", sessionIds);
      if (pointError) return json({ error: pointError.message }, 500);
      pointCount = count ?? 0;
    }

    const totalArea = safeSessions.reduce(
      (acc, row) => acc + Math.max(0, toNumber((row as Record<string, unknown>).area_m2, 0)),
      0,
    );
    const totalDuration = safeSessions.reduce(
      (acc, row) => acc + Math.max(0, toNumber((row as Record<string, unknown>).duration_sec, 0)),
      0,
    );

    return json({
      summary: {
        session_count: safeSessions.length,
        point_count: pointCount,
        total_area_m2: totalArea,
        total_duration_sec: totalDuration,
      },
    });
  }

  if (action !== "sync_walk_stage") {
    return json({ error: "UNSUPPORTED_ACTION" }, 400);
  }

  const walkSessionId = toUUIDOrNull(body.walk_session_id);
  const stage = body.stage;
  const payload = asRecord(body.payload);

  if (!walkSessionId || !stage) {
    return json({ error: "INVALID_PAYLOAD" }, 400);
  }

  const createdEpoch = toNumber(payload.created_at, Date.now() / 1000);
  const startedEpoch = toNumber(payload.started_at, createdEpoch);
  const endedEpoch = toNumber(payload.ended_at, createdEpoch);
  const durationSec = Math.max(0, Math.round(toNumber(payload.duration_sec, Math.max(0, endedEpoch - startedEpoch))));
  const areaM2 = Math.max(0, toNumber(payload.area_m2, 0));
  const sourceDevice = asString(payload.source_device) ?? "ios";
  const petId = toUUIDOrNull(payload.pet_id);

  const baseSession = {
    id: walkSessionId,
    owner_user_id: userId,
    pet_id: petId,
    started_at: epochToIso(startedEpoch, startedEpoch),
    ended_at: epochToIso(endedEpoch, endedEpoch),
    duration_sec: durationSec,
    area_m2: areaM2,
    source_device: sourceDevice,
    created_at: epochToIso(createdEpoch, createdEpoch),
    updated_at: new Date().toISOString(),
  };

  if (stage === "session") {
    const { error } = await userClient
      .from("walk_sessions")
      .upsert(baseSession, { onConflict: "id" });
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true, stage, walk_session_id: walkSessionId, idempotency_key: body.idempotency_key ?? null });
  }

  if (stage === "points") {
    const { error: sessionUpsertError } = await userClient
      .from("walk_sessions")
      .upsert(baseSession, { onConflict: "id" });
    if (sessionUpsertError) return json({ error: sessionUpsertError.message }, 500);

    let parsedPoints: unknown[] = [];
    const rawPointsJSON = asString(payload.points_json);
    if (rawPointsJSON) {
      try {
        const decoded = JSON.parse(rawPointsJSON);
        if (Array.isArray(decoded)) parsedPoints = decoded;
      } catch {
        return json({ error: "INVALID_POINTS_JSON" }, 400);
      }
    }

    const rows = parsedPoints
      .map((raw, index) => {
        const point = asRecord(raw);
        const seqNo = Math.max(0, Math.trunc(toNumber(point.seq_no ?? point.seqNo, index)));
        const lat = toNumber(point.lat, NaN);
        const lng = toNumber(point.lng, NaN);
        const recordedAt = epochToIso(point.recorded_at ?? point.recordedAt, createdEpoch);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
        return {
          walk_session_id: walkSessionId,
          seq_no: seqNo,
          lat,
          lng,
          recorded_at: recordedAt,
          created_at: new Date().toISOString(),
        };
      })
      .filter((row): row is {
        walk_session_id: string;
        seq_no: number;
        lat: number;
        lng: number;
        recorded_at: string;
        created_at: string;
      } => Boolean(row));

    if (rows.length > 0) {
      const { error: pointsError } = await userClient
        .from("walk_points")
        .upsert(rows, { onConflict: "walk_session_id,seq_no" });
      if (pointsError) return json({ error: pointsError.message }, 500);
    }

    let seasonScoreSummary: SeasonScoreSummaryDTO | null = null;
    const { data: seasonScoreRows, error: seasonScoreError } = await userClient.rpc(
      "rpc_score_walk_session_anti_farming",
      {
        target_walk_session_id: walkSessionId,
        now_ts: new Date().toISOString(),
      },
    );

    if (seasonScoreError) {
      console.warn("season scoring rpc failed", seasonScoreError.message);
    } else if (Array.isArray(seasonScoreRows) && seasonScoreRows.length > 0) {
      seasonScoreSummary = seasonScoreRows[0] as SeasonScoreSummaryDTO;
    }

    let seasonPipelineSummary: SeasonPipelineSummaryDTO | null = null;
    const { data: seasonPipelineRows, error: seasonPipelineError } = await userClient.rpc(
      "rpc_ingest_season_tile_events",
      {
        target_walk_session_id: walkSessionId,
        now_ts: new Date().toISOString(),
      },
    );

    if (seasonPipelineError) {
      console.warn("season stage2 pipeline rpc failed", seasonPipelineError.message);
    } else if (Array.isArray(seasonPipelineRows) && seasonPipelineRows.length > 0) {
      seasonPipelineSummary = seasonPipelineRows[0] as SeasonPipelineSummaryDTO;
    }

    const weatherRiskLevel = asString(payload.weather_risk_level) ?? "clear";
    const sourceQuestId = asString(payload.source_quest_id) ?? "outdoor.default";
    const replacementQuestId = asString(payload.replacement_quest_id) ?? "indoor.light";
    let weatherReplacementSummary: WeatherReplacementSummaryDTO | null = null;
    const { data: weatherReplacementRows, error: weatherReplacementError } = await userClient.rpc(
      "rpc_apply_weather_replacement",
      {
        target_user_id: userId,
        target_walk_session_id: walkSessionId,
        target_risk_level: weatherRiskLevel,
        source_quest_id: sourceQuestId,
        replaced_quest_id: replacementQuestId,
        now_ts: new Date().toISOString(),
      },
    );

    if (weatherReplacementError) {
      console.warn("weather replacement rpc failed", weatherReplacementError.message);
    } else if (Array.isArray(weatherReplacementRows) && weatherReplacementRows.length > 0) {
      weatherReplacementSummary = weatherReplacementRows[0] as WeatherReplacementSummaryDTO;
    }

    const uniqueTileCount = Math.max(0, Math.trunc(toNumber(payload.unique_tile_count, rows.length > 0 ? 1 : 0)));
    const deltaByQuestType: Record<string, number> = {
      walk_duration: Math.max(0, durationSec / 60.0),
      linked_path: Math.max(0, rows.length - 1),
      new_tile: uniqueTileCount,
      streak_days: 0,
    };

    const questProgressSummary: QuestProgressSummaryDTO[] = [];
    const { data: activeQuestRows, error: activeQuestError } = await userClient
      .from("quest_instances")
      .select("id,quest_type")
      .eq("owner_user_id", userId)
      .in("status", ["generated", "active", "completed"])
      .limit(20);

    if (activeQuestError) {
      console.warn("quest active list query failed", activeQuestError.message);
    } else if (Array.isArray(activeQuestRows) && activeQuestRows.length > 0) {
      const questEventBaseId = `${walkSessionId}:points:${rows.length}:${Math.trunc(createdEpoch)}`;
      for (const questRow of activeQuestRows) {
        const record = asRecord(questRow);
        const questInstanceId = toUUIDOrNull(record.id);
        const questType = asString(record.quest_type);
        if (!questInstanceId || !questType) continue;

        const delta = deltaByQuestType[questType] ?? 0;
        if (delta <= 0) continue;

        const { data: progressRows, error: progressError } = await userClient.rpc(
          "rpc_apply_quest_progress_event",
          {
            target_user_id: userId,
            target_instance_id: questInstanceId,
            event_id: `${questEventBaseId}:${questType}`,
            event_type: "walk_sync_points",
            delta_value: delta,
            payload: {
              walk_session_id: walkSessionId,
              point_count: rows.length,
              unique_tile_count: uniqueTileCount,
            },
            now_ts: new Date().toISOString(),
          },
        );

        if (progressError) {
          console.warn("quest progress rpc failed", progressError.message);
          continue;
        }
        if (Array.isArray(progressRows) && progressRows.length > 0) {
          questProgressSummary.push(progressRows[0] as QuestProgressSummaryDTO);
        }
      }
    }

    return json({
      ok: true,
      stage,
      walk_session_id: walkSessionId,
      point_count: rows.length,
      season_score_summary: seasonScoreSummary,
      season_pipeline_summary: seasonPipelineSummary,
      weather_replacement_summary: weatherReplacementSummary,
      quest_progress_summary: questProgressSummary,
    });
  }

  if (stage === "meta") {
    const mapImageURL = asString(payload.map_image_url);
    const hasImage = asString(payload.has_image) === "true";
    const patch: Record<string, unknown> = {
      updated_at: new Date().toISOString(),
    };
    if (hasImage && mapImageURL) {
      patch.map_image_url = mapImageURL;
    }

    const { error } = await userClient
      .from("walk_sessions")
      .update(patch)
      .eq("id", walkSessionId)
      .eq("owner_user_id", userId);
    if (error) return json({ error: error.message }, 500);

    return json({ ok: true, stage, walk_session_id: walkSessionId });
  }

  return json({ error: "UNSUPPORTED_STAGE" }, 400);
});
