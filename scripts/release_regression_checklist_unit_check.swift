import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let checklist = load("docs/release-regression-checklist-v1.md")
let report = load("docs/release-regression-report-2026-02-26.md")

assertTrue(checklist.contains("## 3. 빌드 체크"), "checklist must include build check section")
assertTrue(checklist.contains("## 4. 핵심 시나리오 체크"), "checklist must include scenario check section")
assertTrue(checklist.contains("## 5. 마이그레이션 검증 시나리오"), "checklist must include migration section")
assertTrue(checklist.contains("## 6. 배포 파이프라인 검증 시나리오"), "checklist must include pipeline verification section")
assertTrue(checklist.contains("## 7. 결과 기록 템플릿"), "checklist must include result template")
assertTrue(checklist.contains("## 8. 배포 전/후 핵심 지표 비교"), "checklist must include pre/post metric comparison section")
assertTrue(checklist.contains("## 9. 예외 시나리오 게이트 (P0/P1)"), "checklist must include exception gate section")
assertTrue(checklist.contains("P0 FAIL >= 1"), "checklist must include P0 auto blocking rule")
assertTrue(checklist.contains("표본 미달 셀은 count가 노출되지 않고(percentile-only)"), "checklist should include privacy k-anon scenario")
assertTrue(checklist.contains("야간(22~06) 지연 60분 정책"), "checklist should include nighttime delay scenario")
assertTrue(checklist.contains("privacy_guard_policies/privacy_sensitive_geo_masks/privacy_guard_audit_logs"), "checklist should include privacy guard migration verification")
assertTrue(checklist.contains("동일 타일 30분 내 반복 이벤트가 0점 처리"), "checklist should include season anti-farming repeat suppression scenario")
assertTrue(checklist.contains("score_blocked=true"), "checklist should include season anti-farming blocking scenario")
assertTrue(checklist.contains("season_scoring_policies/season_tile_score_events/season_score_audit_logs"), "checklist should include season anti-farming migration verification")
assertTrue(checklist.contains("72시간 비활동 복귀 세션"), "checklist should include comeback buff eligibility scenario")
assertTrue(checklist.contains("block_reason=weekly_limit_reached"), "checklist should include comeback buff weekly limit scenario")
assertTrue(checklist.contains("block_reason=season_end_window"), "checklist should include comeback buff season-end block scenario")
assertTrue(checklist.contains("체감 날씨 다름"), "checklist should include weather feedback one-tap scenario")
assertTrue(checklist.contains("주간 3회 입력"), "checklist should include weather feedback weekly limit scenario")
assertTrue(checklist.contains("view_weather_feedback_kpis_7d"), "checklist should include weather feedback KPI view verification")
assertTrue(checklist.contains("최근 14일 활동량 기준"), "checklist should include rival 14-day activity league scenario")
assertTrue(checklist.contains("effective_league"), "checklist should include rival fallback merge scenario")
assertTrue(checklist.contains("rival_league_policies/rival_league_assignments/rival_league_history"), "checklist should include rival league migration verification")
assertTrue(checklist.contains("선택 반려견 기준"), "checklist should include selected pet context badge scenario")
assertTrue(checklist.contains("전체 기록 보기"), "checklist should include empty state CTA scenario")
assertTrue(checklist.contains("기준으로 돌아가기"), "checklist should include filter restore scenario")

assertTrue(report.contains("## 1. 빌드 체크 결과"), "report must include build results")
assertTrue(report.contains("## 2. 핵심 시나리오 점검 결과"), "report must include scenario results")
assertTrue(report.contains("## 3. 마이그레이션 검증 결과"), "report must include migration results")
assertTrue(report.contains("## 4. 배포 파이프라인 검증 결과"), "report must include pipeline results")
assertTrue(report.contains("## 5. P0/P1 예외 게이트 결과"), "report must include P0/P1 gate results")
assertTrue(report.contains("## 6. 배포 전/후 핵심 지표 비교 준비"), "report must include metric comparison preparation")
assertTrue(report.contains("릴리즈 가능 여부"), "report must include GO/NO-GO decision")

print("PASS: release regression checklist unit checks")
