import Foundation

/// 조건이 거짓일 때 stderr 출력 후 실패 코드로 종료합니다.
/// - Parameters:
///   - condition: 검증할 불리언 조건입니다.
///   - message: 실패 시 출력할 메시지입니다.
/// - Returns: 없음. 실패 시 프로세스를 종료합니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 상대 경로의 UTF-8 텍스트를 로드합니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 문자열 본문입니다.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

struct GameLayerKPIInput {
    let questProgressApplied: Double
    let questRewardClaimed: Double
    let questClaimDuplicateBlocked: Double
    let seasonParticipatedUsers: Double
    let gameLayerActiveUsers: Double
    let rivalOptInUsers: Double
    let rivalTouchedUsers: Double
    let weatherReplacementApplied: Double
    let weatherReplacementOffer: Double
    let syncAuthRefreshFailed: Double
    let syncAuthRefreshTotal: Double
}

/// 게임 레이어 KPI 비율을 산출합니다.
/// - Parameter input: KPI 집계 입력값입니다.
/// - Returns: KPI 비율 튜플입니다.
func computeRates(_ input: GameLayerKPIInput) -> (
    questCompletion: Double?,
    questDuplicate: Double?,
    seasonParticipation: Double?,
    rivalOptIn: Double?,
    weatherAcceptance: Double?,
    syncAuthRefreshFailure: Double?
) {
    let questCompletion = input.questProgressApplied == 0
        ? nil
        : input.questRewardClaimed / input.questProgressApplied

    let questClaimTotal = input.questRewardClaimed + input.questClaimDuplicateBlocked
    let questDuplicate = questClaimTotal == 0
        ? nil
        : input.questClaimDuplicateBlocked / questClaimTotal

    let seasonParticipation = input.gameLayerActiveUsers == 0
        ? nil
        : input.seasonParticipatedUsers / input.gameLayerActiveUsers

    let rivalOptIn = input.rivalTouchedUsers == 0
        ? nil
        : input.rivalOptInUsers / input.rivalTouchedUsers

    let weatherAcceptance = input.weatherReplacementOffer == 0
        ? nil
        : input.weatherReplacementApplied / input.weatherReplacementOffer

    let syncAuthRefreshFailure = input.syncAuthRefreshTotal == 0
        ? nil
        : input.syncAuthRefreshFailed / input.syncAuthRefreshTotal

    return (
        questCompletion,
        questDuplicate,
        seasonParticipation,
        rivalOptIn,
        weatherAcceptance,
        syncAuthRefreshFailure
    )
}

let migration = load("supabase/migrations/20260303194000_game_layer_kpi_dashboard_view.sql")
let observabilitySpec = load("docs/game-layer-observability-qa-v1.md")
let schemaSpec = load("docs/supabase-schema-v1.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(migration.contains("create or replace view public.view_game_layer_kpis_7d"), "migration should create view_game_layer_kpis_7d")
assertTrue(migration.contains("quest_completion_rate_7d"), "migration should expose quest completion KPI")
assertTrue(migration.contains("quest_claim_duplicate_rate_7d"), "migration should expose quest duplicate KPI")
assertTrue(migration.contains("season_participation_rate_7d"), "migration should expose season participation KPI")
assertTrue(migration.contains("rival_opt_in_rate_7d"), "migration should expose rival opt-in KPI")
assertTrue(migration.contains("weather_replacement_acceptance_rate_7d"), "migration should expose weather acceptance KPI")
assertTrue(migration.contains("sync_auth_refresh_failure_rate_24h"), "migration should expose sync auth refresh KPI")
assertTrue(migration.contains("grant select on public.view_game_layer_kpis_7d to anon, authenticated;"), "migration should grant select on KPI view")

assertTrue(observabilitySpec.contains("view_game_layer_kpis_7d"), "observability spec should reference KPI dashboard view")
assertTrue(observabilitySpec.contains("weather_replacement_acceptance_rate_7d"), "observability spec should describe weather acceptance KPI")
assertTrue(schemaSpec.contains("view_game_layer_kpis_7d"), "schema spec should include KPI dashboard view")
assertTrue(prCheck.contains("scripts/game_layer_kpi_dashboard_unit_check.swift"), "ios_pr_check should include KPI dashboard unit check")

let rates = computeRates(.init(
    questProgressApplied: 120,
    questRewardClaimed: 48,
    questClaimDuplicateBlocked: 2,
    seasonParticipatedUsers: 36,
    gameLayerActiveUsers: 100,
    rivalOptInUsers: 26,
    rivalTouchedUsers: 100,
    weatherReplacementApplied: 44,
    weatherReplacementOffer: 100,
    syncAuthRefreshFailed: 1,
    syncAuthRefreshTotal: 200
))

assertTrue(abs((rates.questCompletion ?? 0) - 0.4) < 0.0001, "quest completion rate formula")
assertTrue(abs((rates.questDuplicate ?? 0) - 0.04) < 0.0001, "quest duplicate rate formula")
assertTrue(abs((rates.seasonParticipation ?? 0) - 0.36) < 0.0001, "season participation rate formula")
assertTrue(abs((rates.rivalOptIn ?? 0) - 0.26) < 0.0001, "rival opt-in rate formula")
assertTrue(abs((rates.weatherAcceptance ?? 0) - 0.44) < 0.0001, "weather acceptance rate formula")
assertTrue(abs((rates.syncAuthRefreshFailure ?? 0) - 0.005) < 0.0001, "sync auth refresh failure rate formula")

print("PASS: game layer KPI dashboard unit checks")
