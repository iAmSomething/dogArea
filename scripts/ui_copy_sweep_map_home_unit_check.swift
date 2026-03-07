import Foundation

/// 검사 실패 메시지를 stderr로 출력하고 프로세스를 종료합니다.
/// - Parameter message: 실패 시 출력할 설명입니다.
func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

/// 저장소 루트 기준 상대 경로의 파일 내용을 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: UTF-8로 디코딩한 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(relativePath)
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        fail("unable to load \(relativePath)")
    }
    return text
}

/// 대상 파일에 금지 문자열이 남아 있지 않은지 검증합니다.
/// - Parameters:
///   - forbidden: 제거되어야 하는 사용자 노출 문자열입니다.
///   - relativePath: 검사할 파일의 저장소 루트 기준 상대 경로입니다.
func assertNotContains(_ forbidden: String, in relativePath: String) {
    let content = load(relativePath)
    if content.contains(forbidden) {
        fail("\(relativePath) should not contain `\(forbidden)`")
    }
}

/// 대상 파일에 기대 문자열이 포함되어 있는지 검증합니다.
/// - Parameters:
///   - expected: 새로 고정할 사용자 노출 문자열입니다.
///   - relativePath: 검사할 파일의 저장소 루트 기준 상대 경로입니다.
func assertContains(_ expected: String, in relativePath: String) {
    let content = load(relativePath)
    if content.contains(expected) == false {
        fail("\(relativePath) should contain `\(expected)`")
    }
}

let forbiddenPairs: [(String, String)] = [
    ("Fallback: 날씨 데이터 연결 불가", "dogArea/Views/MapView/MapViewModel.swift"),
    ("title: \"Heatmap\"", "dogArea/Views/MapView/MapSubViews/MapSettingView.swift"),
    ("Text(\"AUTO\")", "dogArea/Views/MapView/MapSubViews/MapFloatingControlColumnView.swift"),
    ("영역 추가: 1탭+Undo", "dogArea/Views/MapView/MapSubViews/MapSettingView.swift"),
    ("자동 종료 정책 v1(고정)", "dogArea/Views/MapView/MapSubViews/MapSettingView.swift"),
    ("+\\(summary.todayScoreDelta) today", "dogArea/Views/HomeView/HomeSubView/Cards/HomeSeasonMotionCardView.swift"),
    ("Shield 적용", "dogArea/Views/HomeView/HomeSubView/Presentation/HomeSeasonDetailSheetView.swift"),
    ("Shield 적용", "dogArea/Views/HomeView/HomeSubView/Presentation/HomeSeasonResultOverlayView.swift"),
    ("오늘 스트릭 보호 요약", "dogArea/Views/HomeView/HomeSubView/Cards/HomeWeatherShieldSummaryCardView.swift"),
    ("DB 비교군", "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift"),
    ("로컬 비교군 (Fallback)", "dogArea/Views/HomeView/HomeViewModel.swift"),
    ("로컬 비교군 (Fallback)", "dogArea/Views/HomeView/HomeSubView/AreaDetailViewModel.swift"),
    ("Territory Goal Detail", "dogArea/Views/HomeView/HomeSubView/TerritoryGoalViewModel.swift"),
    ("Featured", "dogArea/Views/HomeView/HomeSubView/HomeGoalTrackerCardView.swift"),
    ("Featured", "dogArea/Views/HomeView/HomeSubView/TerritoryGoalViewModel.swift"),
    ("Featured", "dogArea/Views/HomeView/HomeSubView/AreaDetailViewModel.swift"),
    ("로컬 비교군 (Fallback)", "dogArea/Source/Infrastructure/Supabase/Services/SupabaseWidgetAndAreaServices.swift")
]

for (forbidden, path) in forbiddenPairs {
    assertNotContains(forbidden, in: path)
}

let expectedPairs: [(String, String)] = [
    ("날씨 정보를 잠시 불러오지 못했어요", "dogArea/Views/MapView/MapViewModel.swift"),
    ("산책 분포", "dogArea/Views/MapView/MapSubViews/MapSettingView.swift"),
    ("자동 기록", "dogArea/Views/MapView/MapSubViews/MapFloatingControlColumnView.swift"),
    ("영역 추가 후 실행 취소", "dogArea/Views/MapView/MapSubViews/MapSettingView.swift"),
    ("자동 종료 기준 적용 중", "dogArea/Views/MapView/MapSubViews/MapSettingView.swift"),
    ("오늘 +\\(summary.todayScoreDelta)점", "dogArea/Views/HomeView/HomeSubView/Cards/HomeSeasonMotionCardView.swift"),
    ("보호", "dogArea/Views/HomeView/HomeSubView/Cards/HomeSeasonMotionCardView.swift"),
    ("오늘 기록 보호 요약", "dogArea/Views/HomeView/HomeSubView/Cards/HomeWeatherShieldSummaryCardView.swift"),
    ("운영 비교 구역", "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift"),
    ("기본 비교 구역", "dogArea/Views/HomeView/HomeViewModel.swift"),
    ("우선 추천", "dogArea/Views/HomeView/HomeSubView/HomeGoalTrackerCardView.swift"),
    ("영역 목표 상세", "dogArea/Views/HomeView/HomeSubView/TerritoryGoalViewModel.swift"),
    ("기본 비교 구역", "dogArea/Source/Infrastructure/Supabase/Services/SupabaseWidgetAndAreaServices.swift")
]

for (expected, path) in expectedPairs {
    assertContains(expected, in: path)
}

print("PASS: map/home ui copy sweep checks")
