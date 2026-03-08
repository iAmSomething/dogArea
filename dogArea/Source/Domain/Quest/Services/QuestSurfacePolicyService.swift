import Foundation

protocol QuestSurfacePolicyResolving {
    /// 산책/홈/위젯에 공통 적용할 퀘스트 표면 정책 스냅샷을 생성합니다.
    /// - Returns: 자동 추적 규칙, 표면별 source of truth, QA 시나리오를 담은 정책 스냅샷입니다.
    func makePolicySnapshot() -> QuestSurfacePolicySnapshot

    /// 현재 홈 전용 미션 카테고리를 어느 표면 bucket으로 분류할지 반환합니다.
    /// - Parameter category: 홈 실내 미션 카드의 카테고리입니다.
    /// - Returns: 홈/지도/요약 중 어떤 노출 버킷에 속하는지 나타내는 정책 값입니다.
    func classifyHomeMissionCategory(_ category: IndoorMissionCategory) -> QuestSurfaceVisibilityBucket

    /// 지도 HUD에서 대표 미션으로 노출할 후보를 선택합니다.
    /// - Parameter candidates: 현재 산책 중 표시 가능한 미션 후보 목록입니다.
    /// - Returns: 보상 가능 상태와 진행률 우선순위를 반영한 대표 후보입니다. 후보가 없으면 `nil`입니다.
    func selectPrimaryMapCandidate(from candidates: [QuestMapMissionCandidate]) -> QuestMapMissionCandidate?
}

final class QuestSurfacePolicyService: QuestSurfacePolicyResolving {
    /// 산책/홈/위젯에 공통 적용할 퀘스트 표면 정책 스냅샷을 생성합니다.
    /// - Returns: 자동 추적 규칙, 표면별 source of truth, QA 시나리오를 담은 정책 스냅샷입니다.
    func makePolicySnapshot() -> QuestSurfacePolicySnapshot {
        QuestSurfacePolicySnapshot(
            automaticTrackingRules: automaticTrackingRules(),
            homeOnlyMissionCategories: IndoorMissionCategory.allCases,
            rewardFlow: [.mapShowsClaimableStateOnly, .homeHandlesClaimCollection],
            homeSourceOfTruth: .localIndoorMissionBoard,
            mapSourceOfTruth: .serverCanonicalQuestSummary,
            widgetSourceOfTruth: .widgetMirrorOfServerSummary,
            qaScenarios: makeQAScenarios()
        )
    }

    /// 현재 홈 전용 미션 카테고리를 어느 표면 bucket으로 분류할지 반환합니다.
    /// - Parameter category: 홈 실내 미션 카드의 카테고리입니다.
    /// - Returns: 홈/지도/요약 중 어떤 노출 버킷에 속하는지 나타내는 정책 값입니다.
    func classifyHomeMissionCategory(_ category: IndoorMissionCategory) -> QuestSurfaceVisibilityBucket {
        switch category {
        case .recordCleanup, .petCareCheck, .trainingCheck:
            return .manualHomeOnly
        }
    }

    /// 지도 HUD에서 대표 미션으로 노출할 후보를 선택합니다.
    /// - Parameter candidates: 현재 산책 중 표시 가능한 미션 후보 목록입니다.
    /// - Returns: 보상 가능 상태와 진행률 우선순위를 반영한 대표 후보입니다. 후보가 없으면 `nil`입니다.
    func selectPrimaryMapCandidate(from candidates: [QuestMapMissionCandidate]) -> QuestMapMissionCandidate? {
        candidates.max { lhs, rhs in
            priorityScore(for: lhs) < priorityScore(for: rhs)
        }
    }

    /// 자동 추적 가능한 산책 기반 퀘스트 규칙을 반환합니다.
    /// - Returns: 지도/위젯에서 동일 의미로 재사용할 자동 추적 규칙 목록입니다.
    private func automaticTrackingRules() -> [QuestAutomaticTrackingRule] {
        [
            QuestAutomaticTrackingRule(
                kind: .walkDuration,
                title: "산책 시간",
                countingRule: "산책 세션이 실제 walking 상태일 때만 누적합니다.",
                exclusionRule: "일시정지, 종료 확인 시트, 복구 대기 구간은 시간 누적에서 제외합니다."
            ),
            QuestAutomaticTrackingRule(
                kind: .walkDistance,
                title: "이동 거리",
                countingRule: "유효 위치 샘플 간 이동 거리만 누적합니다.",
                exclusionRule: "정지 상태 드리프트, 낮은 정확도 샘플, 복구 전 더미 위치는 제외합니다."
            ),
            QuestAutomaticTrackingRule(
                kind: .newlyCapturedTerritoryTile,
                title: "신규 점령 타일",
                countingRule: "시즌/영역 타일이 새로 점령되거나 표시될 때만 증가합니다.",
                exclusionRule: "이미 점령한 타일 재방문과 heatmap 가시화만으로는 증가하지 않습니다."
            ),
            QuestAutomaticTrackingRule(
                kind: .activeWalkingTime,
                title: "유효 산책 지속 시간",
                countingRule: "과도한 정지 구간을 제외한 active walking 구간만 집계합니다.",
                exclusionRule: "휴식 후보, 자동 종료 경고, watch/offline 복구 지연 구간은 기본 집계에서 제외합니다."
            )
        ]
    }

    /// 대표 미션 후보의 우선순위 점수를 계산합니다.
    /// - Parameter candidate: 우선순위를 계산할 지도 표시 후보입니다.
    /// - Returns: 값이 클수록 지도 HUD 대표 미션으로 우선 노출해야 하는 점수입니다.
    private func priorityScore(for candidate: QuestMapMissionCandidate) -> Int {
        if candidate.isClaimable {
            return 4_000
        }
        if candidate.isAutomaticTrackable == false {
            return 500
        }
        let nearCompletionBoost = candidate.progressRatio >= 0.85 ? 1_000 : 0
        let progressScore = Int((candidate.progressRatio * 100).rounded())
        return 2_000 + nearCompletionBoost + progressScore
    }

    /// QA가 그대로 재현할 수 있는 정책 시나리오 목록을 생성합니다.
    /// - Returns: 단일 미션, 다중 미션, 실내 혼합, 보상 가능 상태를 포함한 QA 시나리오 목록입니다.
    private func makeQAScenarios() -> [QuestSurfaceQAScenario] {
        [
            QuestSurfaceQAScenario(
                title: "단일 산책 자동 미션",
                setup: "walk_duration 1개만 active 상태이며 진행률이 40%입니다.",
                expectedMapBehavior: "지도는 해당 미션 1개를 HUD 대표 항목으로 노출합니다.",
                expectedHomeBehavior: "홈은 실내 미션 카드와 별도로 자동 미션 요약만 유지합니다.",
                expectedWidgetBehavior: "위젯은 같은 진행률/미션명을 서버 summary 기준으로 반영합니다."
            ),
            QuestSurfaceQAScenario(
                title: "다중 산책 자동 미션",
                setup: "walk_duration 70%, new_tile 90%, activeWalkingTime 20%가 동시에 active 상태입니다.",
                expectedMapBehavior: "지도는 near-complete인 new_tile을 대표 1개로 노출하고 추가 n개만 요약합니다.",
                expectedHomeBehavior: "홈은 자동 미션 완료 여부를 보조 요약으로만 보여주고 실내 체크 흐름과 섞지 않습니다.",
                expectedWidgetBehavior: "위젯은 서버가 선택한 대표 summary를 그대로 노출합니다."
            ),
            QuestSurfaceQAScenario(
                title: "실내 미션 혼합",
                setup: "recordCleanup과 petCareCheck는 active, walk_duration은 55% 진행 중입니다.",
                expectedMapBehavior: "지도는 walk_duration만 노출하고 실내 미션은 지도에 올리지 않습니다.",
                expectedHomeBehavior: "홈은 실내 미션 체크리스트를 계속 primary로 노출합니다.",
                expectedWidgetBehavior: "위젯은 산책 기반 summary만 보여주며 실내 체크는 반영하지 않습니다."
            ),
            QuestSurfaceQAScenario(
                title: "보상 가능 상태",
                setup: "서버 canonical quest가 completed+claimable 상태입니다.",
                expectedMapBehavior: "지도는 '보상 가능'까지만 알리고 즉시 수령은 홈 퀘스트 보드 진입으로 유도합니다.",
                expectedHomeBehavior: "홈은 실제 보상 수령 CTA와 완료 후 상태 전이를 담당합니다.",
                expectedWidgetBehavior: "위젯은 보상 가능 상태를 반영하되 claim action은 앱 라우트만 요청합니다."
            )
        ]
    }
}
