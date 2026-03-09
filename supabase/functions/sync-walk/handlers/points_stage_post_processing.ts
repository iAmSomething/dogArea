import { asRecord, asString, logSyncWalkStageFailure, toNumber, toUUIDOrNull } from "../support/core.ts";
import type {
  QuestProgressSummaryDTO,
  SeasonCanonicalSummaryDTO,
  SeasonPipelineSummaryDTO,
  SeasonScoreSummaryDTO,
  SyncWalkPointRow,
  SyncWalkStageRequestContext,
  WeatherReplacementSummaryDTO,
} from "../support/types.ts";

type PointsPostProcessingContext = SyncWalkStageRequestContext & {
  createdEpoch: number;
  durationSec: number;
  pointRows: SyncWalkPointRow[];
};

type PointsPostProcessingResult = {
  seasonScoreSummary: SeasonScoreSummaryDTO | null;
  seasonCanonicalSummary: SeasonCanonicalSummaryDTO | null;
  seasonPipelineSummary: SeasonPipelineSummaryDTO | null;
  weatherReplacementSummary: WeatherReplacementSummaryDTO | null;
  questProgressSummary: QuestProgressSummaryDTO[];
};

async function loadSeasonScoreSummary(
  context: PointsPostProcessingContext,
  nowISO: string,
): Promise<SeasonScoreSummaryDTO | null> {
  const { data, error } = await context.userClient.rpc(
    "rpc_score_walk_session_anti_farming",
    {
      target_walk_session_id: context.walkSessionId,
      now_ts: nowISO,
    },
  );

  if (error) {
    logSyncWalkStageFailure(context.requestId, "points", "season_score", error.message);
    return null;
  }

  return Array.isArray(data) && data.length > 0 ? data[0] as SeasonScoreSummaryDTO : null;
}

async function loadSeasonPipelineSummary(
  context: PointsPostProcessingContext,
  nowISO: string,
): Promise<SeasonPipelineSummaryDTO | null> {
  const { data, error } = await context.userClient.rpc(
    "rpc_ingest_season_tile_events",
    {
      target_walk_session_id: context.walkSessionId,
      now_ts: nowISO,
    },
  );

  if (error) {
    logSyncWalkStageFailure(context.requestId, "points", "season_pipeline", error.message);
    return null;
  }

  return Array.isArray(data) && data.length > 0 ? data[0] as SeasonPipelineSummaryDTO : null;
}

async function loadSeasonCanonicalSummary(
  context: PointsPostProcessingContext,
  nowISO: string,
): Promise<SeasonCanonicalSummaryDTO | null> {
  const { data, error } = await context.userClient.rpc(
    "rpc_get_owner_season_summary",
    {
      payload: {
        in_now_ts: nowISO,
      },
    },
  );

  if (error) {
    logSyncWalkStageFailure(context.requestId, "points", "season_canonical_summary", error.message);
    return null;
  }

  return Array.isArray(data) && data.length > 0 ? data[0] as SeasonCanonicalSummaryDTO : null;
}

async function loadWeatherReplacementSummary(
  context: PointsPostProcessingContext,
  nowISO: string,
): Promise<WeatherReplacementSummaryDTO | null> {
  const weatherRiskLevel = asString(context.payload.weather_risk_level) ?? "clear";
  const sourceQuestId = asString(context.payload.source_quest_id) ?? "outdoor.default";
  const replacementQuestId = asString(context.payload.replacement_quest_id) ?? "indoor.light";
  const { data, error } = await context.userClient.rpc(
    "rpc_apply_weather_replacement",
    {
      target_user_id: context.userId,
      target_walk_session_id: context.walkSessionId,
      target_risk_level: weatherRiskLevel,
      source_quest_id: sourceQuestId,
      replaced_quest_id: replacementQuestId,
      now_ts: nowISO,
    },
  );

  if (error) {
    logSyncWalkStageFailure(context.requestId, "points", "weather_replacement", error.message);
    return null;
  }

  return Array.isArray(data) && data.length > 0 ? data[0] as WeatherReplacementSummaryDTO : null;
}

async function loadQuestProgressSummary(
  context: PointsPostProcessingContext,
  nowISO: string,
): Promise<QuestProgressSummaryDTO[]> {
  const uniqueTileCount = Math.max(
    0,
    Math.trunc(toNumber(context.payload.unique_tile_count, context.pointRows.length > 0 ? 1 : 0)),
  );
  const deltaByQuestType: Record<string, number> = {
    walk_duration: Math.max(0, context.durationSec / 60.0),
    linked_path: Math.max(0, context.pointRows.length - 1),
    new_tile: uniqueTileCount,
    streak_days: 0,
  };

  const { data: activeQuestRows, error: activeQuestError } = await context.userClient
    .from("quest_instances")
    .select("id,quest_type")
    .eq("owner_user_id", context.userId)
    .in("status", ["generated", "active", "completed"])
    .limit(20);

  if (activeQuestError) {
    logSyncWalkStageFailure(context.requestId, "points", "load_active_quests", activeQuestError.message);
    return [];
  }
  if (!Array.isArray(activeQuestRows) || activeQuestRows.length == 0) {
    return [];
  }

  const questProgressSummary: QuestProgressSummaryDTO[] = [];
  const questEventBaseId = `${context.walkSessionId}:points:${context.pointRows.length}:${Math.trunc(context.createdEpoch)}`;

  for (const questRow of activeQuestRows) {
    const record = asRecord(questRow);
    const questInstanceId = toUUIDOrNull(record.id);
    const questType = asString(record.quest_type);
    if (!questInstanceId || !questType) continue;

    const delta = deltaByQuestType[questType] ?? 0;
    if (delta <= 0) continue;

    const { data: progressRows, error: progressError } = await context.userClient.rpc(
      "rpc_apply_quest_progress_event",
      {
        target_user_id: context.userId,
        target_instance_id: questInstanceId,
        event_id: `${questEventBaseId}:${questType}`,
        event_type: "walk_sync_points",
        delta_value: delta,
        payload: {
          walk_session_id: context.walkSessionId,
          point_count: context.pointRows.length,
          unique_tile_count: uniqueTileCount,
        },
        now_ts: nowISO,
      },
    );

    if (progressError) {
      logSyncWalkStageFailure(
        context.requestId,
        "points",
        `quest_progress:${questType}`,
        progressError.message,
      );
      continue;
    }

    if (Array.isArray(progressRows) && progressRows.length > 0) {
      questProgressSummary.push(progressRows[0] as QuestProgressSummaryDTO);
    }
  }

  return questProgressSummary;
}

export async function runPointsStagePostProcessing(
  context: PointsPostProcessingContext,
): Promise<PointsPostProcessingResult> {
  const nowISO = new Date().toISOString();
  const [
    seasonScoreSummary,
    seasonCanonicalSummary,
    seasonPipelineSummary,
    weatherReplacementSummary,
    questProgressSummary,
  ] = await Promise.all([
    loadSeasonScoreSummary(context, nowISO),
    loadSeasonCanonicalSummary(context, nowISO),
    loadSeasonPipelineSummary(context, nowISO),
    loadWeatherReplacementSummary(context, nowISO),
    loadQuestProgressSummary(context, nowISO),
  ]);

  return {
    seasonScoreSummary,
    seasonCanonicalSummary,
    seasonPipelineSummary,
    weatherReplacementSummary,
    questProgressSummary,
  };
}
