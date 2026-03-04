import Foundation

struct RealtimeOpsGateInput: Decodable {
    let stage: String
    let windowMinutes: Int
    let activeSessions: Int
    let staleRatio: Double
    let p95LatencyMs: Double
    let errorRate: Double
    let batteryImpactPercentPerHour: Double
}

enum RealtimeOpsRolloutStage {
    case internalStage
    case tenPercent
    case fiftyPercent
    case hundredPercent
}

enum RealtimeOpsGateError: LocalizedError {
    case invalidArguments
    case invalidStage(String)
    case inputReadFailed(String)
    case inputDecodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "usage: swift scripts/realtime_ops_rollout_gate.swift --input <json-file>"
        case .invalidStage(let raw):
            return "unsupported stage: \(raw). allowed: internal, 10%, 50%, 100%"
        case .inputReadFailed(let path):
            return "failed to read input file: \(path)"
        case .inputDecodeFailed:
            return "failed to decode KPI input JSON"
        }
    }
}

/// 커맨드라인 인자에서 KPI 입력 파일 경로를 추출합니다.
/// - Parameter arguments: 실행 시 전달된 전체 인자 배열입니다.
/// - Returns: `--input` 인자의 파일 경로입니다.
/// - Throws: 인자 형식이 잘못되었으면 `RealtimeOpsGateError.invalidArguments`를 던집니다.
func parseInputPath(arguments: [String]) throws -> String {
    guard let inputIndex = arguments.firstIndex(of: "--input"), arguments.indices.contains(inputIndex + 1) else {
        throw RealtimeOpsGateError.invalidArguments
    }
    return arguments[inputIndex + 1]
}

/// 지정한 JSON 파일에서 실시간 운영 게이트 입력값을 로드합니다.
/// - Parameter path: KPI 입력 JSON 파일 경로입니다.
/// - Returns: 디코딩된 `RealtimeOpsGateInput`입니다.
/// - Throws: 파일 읽기/디코딩 실패 시 `RealtimeOpsGateError`를 던집니다.
func loadGateInput(from path: String) throws -> RealtimeOpsGateInput {
    let fileURL = URL(fileURLWithPath: path)
    guard let data = try? Data(contentsOf: fileURL) else {
        throw RealtimeOpsGateError.inputReadFailed(path)
    }
    guard let decoded = try? JSONDecoder().decode(RealtimeOpsGateInput.self, from: data) else {
        throw RealtimeOpsGateError.inputDecodeFailed
    }
    return decoded
}

/// 문자열 stage 값을 롤아웃 단계 열거형으로 변환합니다.
/// - Parameter rawStage: 입력 JSON의 stage 문자열입니다.
/// - Returns: 정규화된 `RealtimeOpsRolloutStage`입니다.
/// - Throws: 허용되지 않은 stage 문자열이면 `RealtimeOpsGateError.invalidStage`를 던집니다.
func parseStage(_ rawStage: String) throws -> RealtimeOpsRolloutStage {
    let normalized = rawStage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch normalized {
    case "internal":
        return .internalStage
    case "10", "10%":
        return .tenPercent
    case "50", "50%":
        return .fiftyPercent
    case "100", "100%":
        return .hundredPercent
    default:
        throw RealtimeOpsGateError.invalidStage(rawStage)
    }
}

/// 롤아웃 단계별 최소 활성 세션 수 기준을 반환합니다.
/// - Parameter stage: 현재 롤아웃 단계입니다.
/// - Returns: 게이트 통과에 필요한 최소 활성 세션 수입니다.
func minimumActiveSessions(for stage: RealtimeOpsRolloutStage) -> Int {
    switch stage {
    case .internalStage: return 20
    case .tenPercent: return 80
    case .fiftyPercent: return 200
    case .hundredPercent: return 400
    }
}

/// 게이트 실패 조건을 평가해 실패 사유 목록을 반환합니다.
/// - Parameter input: KPI 게이트 평가 입력값입니다.
/// - Returns: 기준 미달 항목의 설명 문자열 배열입니다.
/// - Throws: stage 파싱이 실패하면 `RealtimeOpsGateError`를 던집니다.
func evaluateFailures(input: RealtimeOpsGateInput) throws -> [String] {
    let stage = try parseStage(input.stage)
    var failures: [String] = []

    let minActiveSessions = minimumActiveSessions(for: stage)
    if input.activeSessions < minActiveSessions {
        failures.append("active_sessions_5m \(input.activeSessions) < \(minActiveSessions)")
    }
    if input.staleRatio >= 0.12 {
        failures.append(String(format: "stale_ratio_5m %.4f >= 0.12", input.staleRatio))
    }
    if input.p95LatencyMs >= 350 {
        failures.append(String(format: "p95_latency_ms %.1f >= 350", input.p95LatencyMs))
    }
    if input.errorRate >= 0.01 {
        failures.append(String(format: "error_rate_5m %.4f >= 0.01", input.errorRate))
    }
    if input.batteryImpactPercentPerHour >= 2.5 {
        failures.append(String(format: "battery_impact_percent_per_hour %.2f >= 2.5", input.batteryImpactPercentPerHour))
    }

    return failures
}

/// KPI 입력값을 사람이 읽기 쉬운 한 줄 요약으로 렌더링합니다.
/// - Parameter input: 출력할 KPI 입력값입니다.
/// - Returns: 로그/리포트용 한 줄 텍스트입니다.
func summaryLine(for input: RealtimeOpsGateInput) -> String {
    String(
        format: "stage=%@ window=%dm active=%d stale=%.4f p95=%.1fms error=%.4f battery=%.2f%%/h",
        input.stage,
        input.windowMinutes,
        input.activeSessions,
        input.staleRatio,
        input.p95LatencyMs,
        input.errorRate,
        input.batteryImpactPercentPerHour
    )
}

do {
    let inputPath = try parseInputPath(arguments: CommandLine.arguments)
    let input = try loadGateInput(from: inputPath)
    let failures = try evaluateFailures(input: input)

    print("Realtime Ops Gate input: \(summaryLine(for: input))")

    if failures.isEmpty {
        print("PASS: realtime ops rollout gate")
        exit(0)
    }

    fputs("FAIL: realtime ops rollout gate\n", stderr)
    failures.forEach { fputs("- \($0)\n", stderr) }
    exit(1)
} catch {
    fputs("FAIL: \(error.localizedDescription)\n", stderr)
    exit(2)
}
