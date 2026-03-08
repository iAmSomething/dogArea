import Foundation

protocol QuestMapFeedbackPolicyResolving {
    /// 지도 산책 중 퀘스트 피드백의 기본 정책 스냅샷을 생성합니다.
    /// - Returns: HUD, 토스트, 체크리스트, 우선순위, QA 시나리오를 포함한 정책 스냅샷입니다.
    func makePolicySnapshot() -> QuestMapFeedbackPolicySnapshot

    /// 상단 chrome 상황에 맞는 HUD 접힘 상태를 계산합니다.
    /// - Parameters:
    ///   - hasCriticalBanner: 권한/복구/종료 제안 같은 critical banner 노출 여부입니다.
    ///   - hasMultipleMissionSignals: 동시에 보여줄 자동 추적 미션 신호가 여러 개인지 여부입니다.
    /// - Returns: 현재 지도 HUD가 어떤 정도로 접혀야 하는지 나타내는 상태입니다.
    func collapsedState(hasCriticalBanner: Bool, hasMultipleMissionSignals: Bool) -> QuestMapFeedbackCollapsedState

    /// 상단 배너 계층과 milestone toast의 분리 운영 규칙을 설명합니다.
    /// - Returns: `#468` 오버레이 우선순위 매트릭스 문서를 가리키는 설명 문자열입니다.
    func overlayPriorityReference() -> String

    /// 현재 대표 미션 후보와 자동 추적 규칙으로 확장 체크리스트 섹션을 생성합니다.
    /// - Parameters:
    ///   - candidate: 현재 지도 HUD가 대표로 삼는 미션 후보입니다.
    ///   - automaticRules: 산책 중 자동 추적 가능한 규칙 목록입니다.
    /// - Returns: 산책 중 달성 가능한 조건과 홈 전용 조건을 나눈 체크리스트 섹션입니다.
    func makeChecklistSections(
        candidate: QuestMapMissionCandidate?,
        automaticRules: [QuestAutomaticTrackingRule]
    ) -> [QuestMapChecklistSection]
}

final class QuestMapFeedbackPolicyService: QuestMapFeedbackPolicyResolving {
    /// 지도 산책 중 퀘스트 피드백의 기본 정책 스냅샷을 생성합니다.
    /// - Returns: HUD, 토스트, 체크리스트, 우선순위, QA 시나리오를 포함한 정책 스냅샷입니다.
    func makePolicySnapshot() -> QuestMapFeedbackPolicySnapshot {
        let automaticRules = QuestSurfacePolicyService().makePolicySnapshot().automaticTrackingRules
        return QuestMapFeedbackPolicySnapshot(
            layers: [.companionHUD, .milestoneToast, .expandedChecklist],
            priorityTiers: [.criticalBanner, .questCompanionHUD, .passiveStatus],
            defaultHUD: QuestMapCompanionHUDPolicy(
                titleLine: "오늘의 퀘스트",
                progressLine: "대표 미션 1개 + 추가 진행 n개만 요약합니다.",
                remainingLine: "산책 중 바로 달성 가능한 조건만 1줄로 남겨 보여줍니다.",
                collapsedState: .expanded,
                priorityTier: .questCompanionHUD
            ),
            milestoneToasts: milestoneToastPolicies(),
            checklistSections: makeChecklistSections(candidate: nil, automaticRules: automaticRules),
            qaScenarios: qaScenarios()
        )
    }

    /// 상단 chrome 상황에 맞는 HUD 접힘 상태를 계산합니다.
    /// - Parameters:
    ///   - hasCriticalBanner: 권한/복구/종료 제안 같은 critical banner 노출 여부입니다.
    ///   - hasMultipleMissionSignals: 동시에 보여줄 자동 추적 미션 신호가 여러 개인지 여부입니다.
    /// - Returns: 현재 지도 HUD가 어떤 정도로 접혀야 하는지 나타내는 상태입니다.
    func collapsedState(hasCriticalBanner: Bool, hasMultipleMissionSignals: Bool) -> QuestMapFeedbackCollapsedState {
        if hasCriticalBanner {
            return .hiddenByCriticalBanner
        }
        return hasMultipleMissionSignals ? .compactSingleLine : .expanded
    }

    /// 상단 배너 계층과 milestone toast의 분리 운영 규칙을 설명합니다.
    /// - Returns: `#468` 오버레이 우선순위 매트릭스 문서를 가리키는 설명 문자열입니다.
    func overlayPriorityReference() -> String {
        "상단 슬롯/토스트 슬롯 공존 규칙은 #468 문서와 `QuestMapOverlayPriorityService`를 기준으로 구현합니다."
    }

    /// 현재 대표 미션 후보와 자동 추적 규칙으로 확장 체크리스트 섹션을 생성합니다.
    /// - Parameters:
    ///   - candidate: 현재 지도 HUD가 대표로 삼는 미션 후보입니다.
    ///   - automaticRules: 산책 중 자동 추적 가능한 규칙 목록입니다.
    /// - Returns: 산책 중 달성 가능한 조건과 홈 전용 조건을 나눈 체크리스트 섹션입니다.
    func makeChecklistSections(
        candidate: QuestMapMissionCandidate?,
        automaticRules: [QuestAutomaticTrackingRule]
    ) -> [QuestMapChecklistSection] {
        let walkingSection = QuestMapChecklistSection(
            title: "산책 중 바로 반영돼요",
            items: automaticRules.map { rule in
                QuestMapChecklistItem(
                    title: rule.title,
                    detail: rule.countingRule,
                    state: candidate?.isAutomaticTrackable == true ? .remainingDuringWalk : .autoChecked
                )
            }
        )
        let homeOnlySection = QuestMapChecklistSection(
            title: "홈에서 직접 확인해요",
            items: [
                QuestMapChecklistItem(
                    title: "직접 체크 미션",
                    detail: "돌봄/훈련/정리 미션은 지도에서 자동 완료하지 않고 홈 보드에서 체크합니다.",
                    state: .homeOnly
                )
            ]
        )
        return [walkingSection, homeOnlySection]
    }

    /// milestone toast 정책 목록을 생성합니다.
    /// - Returns: 트리거별 copy, haptic, auto-dismiss, 중복 억제 규칙이 반영된 정책 목록입니다.
    private func milestoneToastPolicies() -> [QuestMapMilestoneToastPolicy] {
        [
            QuestMapMilestoneToastPolicy(
                trigger: .halfway,
                title: "절반 넘겼어요",
                body: "지금 pace를 유지하면 이번 산책 안에 충분히 달성할 수 있어요.",
                haptic: .progressPulse,
                autoDismissSeconds: 2.0,
                suppressDuplicateWindowSeconds: 45
            ),
            QuestMapMilestoneToastPolicy(
                trigger: .nearCompletion,
                title: "거의 다 왔어요",
                body: "남은 조건 한 가지만 더 채우면 바로 완료돼요.",
                haptic: .progressPulse,
                autoDismissSeconds: 2.2,
                suppressDuplicateWindowSeconds: 45
            ),
            QuestMapMilestoneToastPolicy(
                trigger: .completed,
                title: "퀘스트 완료",
                body: "산책 중 조건을 모두 채웠어요. 이제 보드에서 결과를 확인할 수 있어요.",
                haptic: .completionSuccess,
                autoDismissSeconds: 2.8,
                suppressDuplicateWindowSeconds: 90
            ),
            QuestMapMilestoneToastPolicy(
                trigger: .claimable,
                title: "보상 받을 수 있어요",
                body: "지도에서는 상태만 알려드리고, 실제 보상 수령은 홈 퀘스트 보드에서 이어집니다.",
                haptic: .rewardReady,
                autoDismissSeconds: 3.2,
                suppressDuplicateWindowSeconds: 120
            )
        ]
    }

    /// 지도 퀘스트 피드백 QA 시나리오를 생성합니다.
    /// - Returns: HUD, 토스트, 체크리스트 우선순위를 검증할 수 있는 대표 시나리오 목록입니다.
    private func qaScenarios() -> [QuestMapFeedbackQAScenario] {
        [
            QuestMapFeedbackQAScenario(
                title: "critical banner 우선",
                setup: "권한 복구 banner와 퀘스트 진행 1개가 동시에 active입니다.",
                expectedHUD: "퀘스트 HUD는 접히거나 숨겨지고 critical banner가 최상단을 점유합니다.",
                expectedToast: "퀘스트 milestone toast는 critical banner가 내려간 뒤에만 다시 허용됩니다.",
                expectedChecklist: "사용자가 HUD를 다시 열기 전까지 체크리스트는 자동 노출되지 않습니다."
            ),
            QuestMapFeedbackQAScenario(
                title: "자동 미션 다중 진행",
                setup: "자동 추적 미션 3개가 동시에 진행 중이며 그중 하나가 90%입니다.",
                expectedHUD: "HUD는 대표 1개와 추가 n개 요약만 보여줍니다.",
                expectedToast: "90%에 도달한 대표 미션만 near-completion toast를 1회 보여줍니다.",
                expectedChecklist: "확장 체크리스트에는 자동 추적 항목과 남은 조건이 섹션별로 보입니다."
            ),
            QuestMapFeedbackQAScenario(
                title: "완료 후 보상 가능 전이",
                setup: "자동 미션이 completed에서 claimable로 전이됩니다.",
                expectedHUD: "HUD는 '보상 가능' 상태를 유지하되 즉시 claim 버튼은 노출하지 않습니다.",
                expectedToast: "completed 이후 claimable toast는 중복 없이 1회만 추가로 노출됩니다.",
                expectedChecklist: "체크리스트 상단에는 완료 표시, 하단에는 홈에서 마무리하라는 안내가 나옵니다."
            ),
            QuestMapFeedbackQAScenario(
                title: "직접 체크 미션 혼합",
                setup: "산책 자동 미션 1개와 홈 전용 직접 체크 미션 2개가 함께 존재합니다.",
                expectedHUD: "HUD는 산책 중 자동 미션만 요약합니다.",
                expectedToast: "직접 체크 미션 때문에 지도 toast를 추가로 띄우지 않습니다.",
                expectedChecklist: "체크리스트 하단에 홈 전용 항목을 별도 섹션으로 구분해 보여줍니다."
            )
        ]
    }
}
