import Foundation

protocol QuestMapHUDInfoSetPolicyResolving {
    /// 지도 산책 중 HUD 최소 정보셋 정책 스냅샷을 생성합니다.
    /// - Returns: 상태별 collapsed/expanded 정보 구성과 wire 예시를 담은 정책 스냅샷입니다.
    func makePolicySnapshot() -> QuestMapHUDInfoSetPolicySnapshot

    /// 특정 HUD 상태에 맞는 collapsed 정보셋을 계산합니다.
    /// - Parameter state: 대표 HUD가 표현하려는 상태입니다.
    /// - Returns: 걷는 중 1~2초 안에 읽히도록 압축된 collapsed HUD 구성입니다.
    func collapsedInfoSet(for state: QuestMapHUDStateVariant) -> QuestMapHUDCollapsedInfoSet

    /// 특정 HUD 상태에 맞는 expanded 정보셋을 계산합니다.
    /// - Parameter state: 사용자가 HUD를 펼쳤을 때의 미션 상태입니다.
    /// - Returns: collapsed HUD를 보완하는 expanded 정보 블록 구성입니다.
    func expandedInfoSet(for state: QuestMapHUDStateVariant) -> QuestMapHUDExpandedInfoSet

    /// 상태별 QA wire 예시를 생성합니다.
    /// - Returns: QA가 화면 카피와 축약 규칙을 바로 확인할 수 있는 예시 목록입니다.
    func makeWireExamples() -> [QuestMapHUDWireExample]
}

final class QuestMapHUDInfoSetPolicyService: QuestMapHUDInfoSetPolicyResolving {
    /// 지도 산책 중 HUD 최소 정보셋 정책 스냅샷을 생성합니다.
    /// - Returns: 상태별 collapsed/expanded 정보 구성과 wire 예시를 담은 정책 스냅샷입니다.
    func makePolicySnapshot() -> QuestMapHUDInfoSetPolicySnapshot {
        QuestMapHUDInfoSetPolicySnapshot(
            collapsedStates: QuestMapHUDStateVariant.allCases.map { state in
                QuestMapHUDStatePolicy(
                    state: state,
                    collapsed: collapsedInfoSet(for: state),
                    expanded: expandedInfoSet(for: state),
                    visualWeightGuideline: visualWeightGuideline(for: state),
                    autoHideAfterSeconds: autoHideAfterSeconds(for: state)
                )
            },
            wireExamples: makeWireExamples(),
            emptyStateCopy: "진행 중인 산책 퀘스트가 없어요",
            multiMissionRule: "대표 1개만 제목으로 남기고, 나머지는 '+n개 진행 중' 배지로만 축약합니다.",
            visualWeightRule: "collapsed HUD는 2줄 + 배지 1개를 넘기지 않고, 전체 높이는 critical banner보다 작아야 합니다."
        )
    }

    /// 특정 HUD 상태에 맞는 collapsed 정보셋을 계산합니다.
    /// - Parameter state: 대표 HUD가 표현하려는 상태입니다.
    /// - Returns: 걷는 중 1~2초 안에 읽히도록 압축된 collapsed HUD 구성입니다.
    func collapsedInfoSet(for state: QuestMapHUDStateVariant) -> QuestMapHUDCollapsedInfoSet {
        let baseConstraint = QuestMapHUDTextConstraint(
            titleMaxCharacters: 16,
            summaryMaxCharacters: 22,
            maximumLineCount: 2,
            usesTrailingEllipsis: true
        )

        switch state {
        case .empty:
            return QuestMapHUDCollapsedInfoSet(
                lines: [.title],
                numberExpressionRule: .hiddenWhenNoMeaningfulDelta,
                badgeStyle: .none,
                textConstraint: baseConstraint,
                keepsProgressBarHidden: true
            )
        case .singleMission:
            return QuestMapHUDCollapsedInfoSet(
                lines: [.title, .summary],
                numberExpressionRule: .remainingCountSentence,
                badgeStyle: .none,
                textConstraint: baseConstraint,
                keepsProgressBarHidden: true
            )
        case .multipleMissions:
            return QuestMapHUDCollapsedInfoSet(
                lines: [.title, .summary],
                numberExpressionRule: .remainingCountSentence,
                badgeStyle: .plusAdditionalCount,
                textConstraint: baseConstraint,
                keepsProgressBarHidden: true
            )
        case .nearCompletion:
            return QuestMapHUDCollapsedInfoSet(
                lines: [.title, .summary],
                numberExpressionRule: .remainingCountSentence,
                badgeStyle: .almostDone,
                textConstraint: baseConstraint,
                keepsProgressBarHidden: true
            )
        case .completed:
            return QuestMapHUDCollapsedInfoSet(
                lines: [.title, .summary],
                numberExpressionRule: .progressRatioSentence,
                badgeStyle: .completed,
                textConstraint: baseConstraint,
                keepsProgressBarHidden: true
            )
        case .claimable:
            return QuestMapHUDCollapsedInfoSet(
                lines: [.title, .summary],
                numberExpressionRule: .progressRatioSentence,
                badgeStyle: .rewardReady,
                textConstraint: baseConstraint,
                keepsProgressBarHidden: true
            )
        }
    }

    /// 특정 HUD 상태에 맞는 expanded 정보셋을 계산합니다.
    /// - Parameter state: 사용자가 HUD를 펼쳤을 때의 미션 상태입니다.
    /// - Returns: collapsed HUD를 보완하는 expanded 정보 블록 구성입니다.
    func expandedInfoSet(for state: QuestMapHUDStateVariant) -> QuestMapHUDExpandedInfoSet {
        let automaticRules = QuestSurfacePolicyService().makePolicySnapshot().automaticTrackingRules
        let baseChecklistCount = min(automaticRules.count, 3)

        switch state {
        case .empty:
            return QuestMapHUDExpandedInfoSet(
                titleLine: "진행 중인 산책 퀘스트가 없어요",
                supportingSummaryLine: "산책 시간, 거리, 새 점령 타일 같은 자동 기록 미션이 생기면 여기서 요약해 드려요.",
                blocks: [.conditionBreakdown],
                numberExpressionRule: .hiddenWhenNoMeaningfulDelta,
                maximumChecklistItems: baseChecklistCount
            )
        case .singleMission:
            return QuestMapHUDExpandedInfoSet(
                titleLine: "대표 미션 1개를 따라가요",
                supportingSummaryLine: "진행률 수치보다 남은 조건 한 줄을 먼저 보여주고, 세부 조건은 체크리스트에서 풉니다.",
                blocks: [.checklist, .conditionBreakdown],
                numberExpressionRule: .remainingCountSentence,
                maximumChecklistItems: baseChecklistCount
            )
        case .multipleMissions:
            return QuestMapHUDExpandedInfoSet(
                titleLine: "대표 1개 + 추가 미션 요약",
                supportingSummaryLine: "대표 미션만 본문에 남기고, 나머지는 '+n개 진행 중'으로 합쳐 지도 시야를 지킵니다.",
                blocks: [.checklist, .conditionBreakdown],
                numberExpressionRule: .additionalMissionBadge,
                maximumChecklistItems: baseChecklistCount
            )
        case .nearCompletion:
            return QuestMapHUDExpandedInfoSet(
                titleLine: "거의 다 왔어요",
                supportingSummaryLine: "남은 횟수나 거리처럼 마지막 조건 1개만 먼저 보여주고, 전체 진행률 bar는 확장 상태에서만 보조로 씁니다.",
                blocks: [.checklist, .conditionBreakdown],
                numberExpressionRule: .remainingCountSentence,
                maximumChecklistItems: baseChecklistCount
            )
        case .completed:
            return QuestMapHUDExpandedInfoSet(
                titleLine: "이번 산책 조건을 채웠어요",
                supportingSummaryLine: "완료 직후에는 결과 요약만 남기고, 더 자세한 보상 맥락은 홈 퀘스트 보드에서 마무리합니다.",
                blocks: [.rewardSummary, .checklist],
                numberExpressionRule: .progressRatioSentence,
                maximumChecklistItems: baseChecklistCount
            )
        case .claimable:
            return QuestMapHUDExpandedInfoSet(
                titleLine: "보상 받을 준비가 됐어요",
                supportingSummaryLine: "지도에서는 claim 가능 상태만 알려주고, 실제 보상 수령은 홈 보드로 넘깁니다.",
                blocks: [.rewardSummary, .checklist],
                numberExpressionRule: .progressRatioSentence,
                maximumChecklistItems: baseChecklistCount
            )
        }
    }

    /// 상태별 QA wire 예시를 생성합니다.
    /// - Returns: QA가 화면 카피와 축약 규칙을 바로 확인할 수 있는 예시 목록입니다.
    func makeWireExamples() -> [QuestMapHUDWireExample] {
        [
            QuestMapHUDWireExample(
                state: .empty,
                title: "진행 중인 퀘스트 없음",
                summary: "산책을 시작하면 자동 기록 미션을 여기서 보여줘요",
                badge: nil,
                expandedChecklistHint: "자동 기록 기준 보기"
            ),
            QuestMapHUDWireExample(
                state: .singleMission,
                title: "산책 20분 채우기",
                summary: "남은 시간 8분",
                badge: nil,
                expandedChecklistHint: "세부 조건 보기"
            ),
            QuestMapHUDWireExample(
                state: .multipleMissions,
                title: "새 영역 3칸 확보",
                summary: "남은 타일 1칸",
                badge: "+2개 진행 중",
                expandedChecklistHint: "다른 미션도 함께 보기"
            ),
            QuestMapHUDWireExample(
                state: .nearCompletion,
                title: "거리 미션 거의 완료",
                summary: "200m만 더 걸으면 끝나요",
                badge: "거의 완료",
                expandedChecklistHint: "마지막 조건 확인"
            ),
            QuestMapHUDWireExample(
                state: .completed,
                title: "퀘스트 완료",
                summary: "이번 산책 조건을 모두 채웠어요",
                badge: "완료",
                expandedChecklistHint: "완료 이유 보기"
            ),
            QuestMapHUDWireExample(
                state: .claimable,
                title: "보상 받을 수 있어요",
                summary: "홈 퀘스트 보드에서 이어서 마무리해요",
                badge: "보상 가능",
                expandedChecklistHint: "보상 안내 보기"
            )
        ]
    }

    /// 상태별 시각 무게 기준을 반환합니다.
    /// - Parameter state: 현재 대표 HUD 상태입니다.
    /// - Returns: 지도 조작을 방해하지 않도록 유지해야 할 시각 무게 기준 설명입니다.
    private func visualWeightGuideline(for state: QuestMapHUDStateVariant) -> String {
        switch state {
        case .multipleMissions:
            return "다중 미션 상태에서도 카드 높이는 72pt를 넘기지 않고, 배지는 한 개만 허용합니다."
        case .nearCompletion, .completed, .claimable:
            return "강한 상태 변화는 배지 색과 짧은 toast로만 강조하고, HUD 배경 자체는 커지지 않습니다."
        case .empty, .singleMission:
            return "기본 HUD는 제목 1줄과 요약 1줄만 유지하며, full-width progress bar는 collapsed 상태에서 사용하지 않습니다."
        }
    }

    /// 상태별 자동 숨김 정책을 반환합니다.
    /// - Parameter state: 현재 대표 HUD 상태입니다.
    /// - Returns: HUD가 자동으로 축약되거나 사라져야 하는 시간입니다. 없으면 상시 유지합니다.
    private func autoHideAfterSeconds(for state: QuestMapHUDStateVariant) -> TimeInterval? {
        switch state {
        case .completed:
            return 6
        case .claimable:
            return 8
        default:
            return nil
        }
    }
}
