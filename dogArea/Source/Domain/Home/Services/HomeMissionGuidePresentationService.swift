import Foundation

protocol HomeMissionGuidePresentationProviding {
    /// 홈 미션 도움말 시트와 코치 카드에 사용할 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - board: 현재 홈 미션 섹션에 반영된 실내 미션 보드 상태입니다.
    ///   - weatherSummary: 실내 대체 미션이 열린 이유와 날씨 문맥을 설명하는 요약 상태입니다.
    ///   - context: 사용자가 도움말에 진입한 맥락입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 코치 카드와 상세 sheet가 함께 사용할 도움말 프레젠테이션입니다.
    func makePresentation(
        board: IndoorMissionBoard,
        weatherSummary: WeatherMissionStatusSummary,
        context: HomeMissionGuideEntryContext,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeMissionGuidePresentation
}

final class HomeMissionGuidePresentationService: HomeMissionGuidePresentationProviding {
    /// 홈 미션 도움말 시트와 코치 카드에 사용할 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - board: 현재 홈 미션 섹션에 반영된 실내 미션 보드 상태입니다.
    ///   - weatherSummary: 실내 대체 미션이 열린 이유와 날씨 문맥을 설명하는 요약 상태입니다.
    ///   - context: 사용자가 도움말에 진입한 맥락입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 코치 카드와 상세 sheet가 함께 사용할 도움말 프레젠테이션입니다.
    func makePresentation(
        board: IndoorMissionBoard,
        weatherSummary: WeatherMissionStatusSummary,
        context: HomeMissionGuideEntryContext,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeMissionGuidePresentation {
        let reasonLine = missionReasonLine(
            board: board,
            weatherSummary: weatherSummary,
            localizedCopy: localizedCopy
        )
        let actionHint = currentActionHint(for: board, localizedCopy: localizedCopy)

        return HomeMissionGuidePresentation(
            context: context,
            badgeText: badgeText(for: context, localizedCopy: localizedCopy),
            title: title(for: context, localizedCopy: localizedCopy),
            subtitle: subtitle(for: context, localizedCopy: localizedCopy),
            heroLine: localizedCopy(
                "이 영역은 산책을 대신하는 새 기본 루프가 아니라, 산책이 어려운 날에만 잠깐 열리는 보조 미션 안내판이에요.",
                "This section is not a new primary loop. It is a backup mission board that opens only when walking is difficult."
            ),
            coachPresentation: makeCoachPresentation(
                reasonLine: reasonLine,
                actionHint: actionHint,
                localizedCopy: localizedCopy
            ),
            sections: makeSections(
                board: board,
                reasonLine: reasonLine,
                actionHint: actionHint,
                localizedCopy: localizedCopy
            ),
            comparisons: makeComparisons(localizedCopy: localizedCopy),
            steps: makeSteps(
                board: board,
                weatherSummary: weatherSummary,
                localizedCopy: localizedCopy
            ),
            revisitLine: localizedCopy(
                "나중에 다시 보고 싶다면 미션 제목 오른쪽의 도움말 버튼에서 언제든 열 수 있어요.",
                "You can reopen this guide anytime from the help button on the mission section header."
            )
        )
    }

    /// 도움말 진입 맥락에 맞는 배지 문구를 생성합니다.
    /// - Parameters:
    ///   - context: 사용자가 도움말을 연 진입 맥락입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 현재 가이드 진입 위치를 설명하는 짧은 배지 문구입니다.
    private func badgeText(
        for context: HomeMissionGuideEntryContext,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        switch context {
        case .firstVisitCoach:
            return localizedCopy("처음 보는 미션", "First Mission Guide")
        case .helpButtonReentry:
            return localizedCopy("미션 도움말", "Mission Help")
        }
    }

    /// 도움말 진입 맥락에 맞는 시트 제목을 생성합니다.
    /// - Parameters:
    ///   - context: 사용자가 도움말을 연 진입 맥락입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 도움말 시트 상단에 노출할 제목 문자열입니다.
    private func title(
        for context: HomeMissionGuideEntryContext,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        switch context {
        case .firstVisitCoach:
            return localizedCopy(
                "이 미션 영역이 왜 열렸는지부터 짧게 알려드릴게요",
                "Here is a quick explanation of why this mission area is open"
            )
        case .helpButtonReentry:
            return localizedCopy(
                "홈 미션을 다시 이해하기 쉽게 정리해둘게요",
                "Here is a compact explanation of how Home missions work"
            )
        }
    }

    /// 도움말 진입 맥락에 맞는 보조 설명을 생성합니다.
    /// - Parameters:
    ///   - context: 사용자가 도움말을 연 진입 맥락입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: sheet 상단에서 정보 구조를 예고하는 보조 설명 문자열입니다.
    private func subtitle(
        for context: HomeMissionGuideEntryContext,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        switch context {
        case .firstVisitCoach:
            return localizedCopy(
                "무엇을 하는 카드인지, 왜 오늘 열렸는지, 어떻게 완료하는지, 완료 후 무엇이 달라지는지 4가지로 나눠 보여드려요.",
                "This guide explains what the card is, why it opened today, how to finish it, and what changes after completion."
            )
        case .helpButtonReentry:
            return localizedCopy(
                "산책 기반 자동 기록과 실내 보조 미션의 차이까지 함께 다시 볼 수 있어요.",
                "It also revisits the difference between automatically tracked walk missions and self-logged indoor missions."
            )
        }
    }

    /// 1회성 코치 카드에 사용할 요약 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - reasonLine: 오늘 미션이 열린 이유를 사용자 언어로 풀어쓴 문장입니다.
    ///   - actionHint: 사용자가 지금 바로 해야 할 행동을 짧게 요약한 문장입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 홈 미션 섹션 상단에서 1회성으로 노출할 코치 카드 상태입니다.
    private func makeCoachPresentation(
        reasonLine: String,
        actionHint: String,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeMissionGuideCoachPresentation {
        HomeMissionGuideCoachPresentation(
            badgeText: localizedCopy("30초 설명", "30s Guide"),
            title: reasonLine,
            summaryText: actionHint,
            primaryActionTitle: localizedCopy("설명 보기", "Open Guide"),
            dismissActionTitle: localizedCopy("나중에", "Later")
        )
    }

    /// 도움말 시트의 4축 섹션을 생성합니다.
    /// - Parameters:
    ///   - board: 현재 홈 미션 섹션에 반영된 실내 미션 보드 상태입니다.
    ///   - reasonLine: 오늘 미션이 열린 이유를 설명하는 사용자 문구입니다.
    ///   - actionHint: 사용자가 지금 우선 해야 할 행동을 요약한 문구입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 무엇/왜/어떻게/완료 후 변화 4축을 담은 카드 배열입니다.
    private func makeSections(
        board: IndoorMissionBoard,
        reasonLine: String,
        actionHint: String,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> [HomeMissionGuideAxisPresentation] {
        [
            HomeMissionGuideAxisPresentation(
                id: "what",
                title: localizedCopy("무엇을 하는 카드인가요?", "What is this card?"),
                body: localizedCopy(
                    "이 카드는 산책이 어려운 날에 대신 확인하는 보조 미션 보드예요. `행동 +1 기록`은 실제로 끝낸 실내 루틴 1회를 직접 남기는 버튼입니다.",
                    "This is a backup mission board for days when walking is difficult. `+1` records one indoor routine that you actually completed."
                )
            ),
            HomeMissionGuideAxisPresentation(
                id: "why",
                title: localizedCopy("왜 오늘 열렸나요?", "Why is it open today?"),
                body: reasonLine
            ),
            HomeMissionGuideAxisPresentation(
                id: "how",
                title: localizedCopy("어떻게 완료하나요?", "How do I finish it?"),
                body: localizedCopy(
                    "카드의 기준 횟수를 보고, 실제로 행동한 뒤에만 `행동 +1 기록`을 누르세요. 기준을 채운 뒤 `완료 확인` 또는 `보상 받기`를 눌러야 완료가 확정됩니다. \(actionHint)",
                    "Read the target count, tap `+1` only after the real action, then use `Check Completion` or `Claim Reward` after reaching the target. \(actionHint)"
                )
            ),
            HomeMissionGuideAxisPresentation(
                id: "outcome",
                title: localizedCopy("완료되면 뭐가 달라지나요?", "What changes after completion?"),
                body: localizedCopy(
                    "보상이 지급되고, 진행 중 카드에서는 내려가며, 완료한 미션 영역으로 이동합니다. 이미 끝난 미션과 지금 해야 할 미션이 섞여 보이지 않도록 분리해 보여줘요.",
                    "The reward is granted, the card leaves the active list, and the mission moves to the completed area so finished and pending work stay clearly separated."
                )
            )
        ]
    }

    /// 산책 기반 자동 미션과 실내 보조 미션의 차이를 설명하는 비교 카드를 생성합니다.
    /// - Parameter localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 자동 추적과 자가 기록의 차이를 비교하는 카드 배열입니다.
    private func makeComparisons(
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> [HomeMissionGuideComparisonPresentation] {
        [
            HomeMissionGuideComparisonPresentation(
                id: "auto",
                title: localizedCopy("산책 중 자동 반영", "Auto During Walks"),
                body: localizedCopy(
                    "산책을 시작하면 시간, 경로, 영역이 자동으로 쌓입니다. 사용자가 `+1`을 누를 필요가 없습니다.",
                    "When you start a walk, time, route, and territory are tracked automatically. You do not manually press `+1`."
                )
            ),
            HomeMissionGuideComparisonPresentation(
                id: "manual",
                title: localizedCopy("실내 행동 직접 기록", "Log Indoor Actions Yourself"),
                body: localizedCopy(
                    "실제로 한 행동만 직접 기록해야 합니다. 기준 횟수를 채운 뒤 완료를 눌러야 보상이 확정됩니다.",
                    "You log only the actions you actually completed. The reward is finalized only after you reach the target and confirm completion."
                )
            )
        ]
    }

    /// 현재 홈 미션 도움말에서 보여줄 행동 순서 카드를 생성합니다.
    /// - Parameters:
    ///   - board: 현재 홈 미션 섹션에 반영된 실내 미션 보드 상태입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 사용자가 지금 따라야 할 3단계 행동 순서 카드 배열입니다.
    private func makeSteps(
        board: IndoorMissionBoard,
        weatherSummary: WeatherMissionStatusSummary,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> [HomeMissionGuideStepPresentation] {
        [
            HomeMissionGuideStepPresentation(
                id: "1",
                badgeText: localizedCopy("1단계", "Step 1"),
                title: localizedCopy("왜 열렸는지 먼저 확인", "Check why it opened"),
                body: missionReasonLine(
                    board: board,
                    weatherSummary: weatherSummary,
                    localizedCopy: localizedCopy
                )
            ),
            HomeMissionGuideStepPresentation(
                id: "2",
                badgeText: localizedCopy("2단계", "Step 2"),
                title: localizedCopy("실제로 한 행동만 기록", "Log only real actions"),
                body: localizedCopy(
                    "실내 루틴을 마친 뒤에만 `행동 +1 기록`을 누르세요. 준비만 했거나 계획만 세운 상태는 기록하지 않습니다.",
                    "Use `+1` only after the indoor routine is actually done. Planning or preparing does not count."
                )
            ),
            HomeMissionGuideStepPresentation(
                id: "3",
                badgeText: localizedCopy("3단계", "Step 3"),
                title: localizedCopy("기준 충족 후 완료 확정", "Finalize after reaching the target"),
                body: localizedCopy(
                    "횟수를 채웠다면 `완료 확인` 또는 `보상 받기`를 눌러 마무리하세요. 완료된 카드는 진행 목록이 아니라 완료 목록으로 이동합니다.",
                    "After reaching the target, use `Check Completion` or `Claim Reward`. Finished cards move to the completed list instead of staying in the active queue."
                )
            )
        ]
    }

    /// 현재 미션 보드 기준으로 카드가 열린 이유를 사용자 언어로 생성합니다.
    /// - Parameters:
    ///   - board: 현재 홈 미션 섹션에 반영된 실내 미션 보드 상태입니다.
    ///   - weatherSummary: 날씨와 전환 정책을 요약한 상태입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 오늘 실내 미션이 열린 배경을 한 문장으로 설명한 문자열입니다.
    private func missionReasonLine(
        board: IndoorMissionBoard,
        weatherSummary: WeatherMissionStatusSummary,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        if board.riskLevel != .clear {
            return localizedCopy(
                "오늘은 \(board.riskLevel.displayTitle) 단계라 실외 산책 대신 실내 보조 미션이 열렸어요. \(weatherSummary.reasonText)",
                "Today's weather is \(board.riskLevel.displayTitle), so indoor backup missions opened instead of outdoor walking. \(weatherSummary.reasonText)"
            )
        }
        switch board.extensionState {
        case .active, .consumed:
            return localizedCopy(
                "오늘 카드에는 어제 못 끝낸 보조 미션의 연장 슬롯이 함께 열려 있어요.",
                "Today's card includes a carry-over slot from an unfinished backup mission."
            )
        case .expired:
            return localizedCopy(
                "연장 가능 시간이 지나 오늘은 새 보조 미션만 확인할 수 있어요.",
                "The carry-over window expired, so only today's backup mission context is available now."
            )
        case .cooldown:
            return localizedCopy(
                "연장 슬롯은 잠시 쉬는 날이라 오늘은 기본 흐름을 먼저 챙기면 돼요.",
                "The carry-over slot is on cooldown today, so you only need to focus on the default flow first."
            )
        case .none:
            return localizedCopy(
                "오늘은 기본 루프가 산책이라 실내 보조 미션이 항상 열려 있는 것은 아니에요. 예외 상황이 생기면 이 영역에서 바로 설명해줘요.",
                "Walking is still the primary loop, so indoor backup missions are not always open. When an exception happens, this area explains it here."
            )
        }
    }

    /// 현재 보드에서 사용자가 우선 해야 할 행동을 짧게 요약합니다.
    /// - Parameters:
    ///   - board: 현재 홈 미션 섹션에 반영된 실내 미션 보드 상태입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 지금 가장 먼저 해야 할 행동을 정리한 짧은 문자열입니다.
    private func currentActionHint(
        for board: IndoorMissionBoard,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        if let readyMission = board.missions.first(where: { $0.progress.isCompleted == false && $0.progress.actionCount >= $0.minimumActionCount }) {
            return localizedCopy(
                "지금은 `\(readyMission.title)`를 바로 완료 확정할 수 있어요.",
                "Right now `\(readyMission.title)` is ready for completion confirmation."
            )
        }
        if let activeMission = board.missions.first(where: { $0.progress.isCompleted == false }) {
            let shortage = max(0, activeMission.minimumActionCount - activeMission.progress.actionCount)
            return localizedCopy(
                "지금은 `\(activeMission.title)`에서 실제 행동 \(shortage)회만 더 기록하면 완료 단계로 넘어갑니다.",
                "Right now `\(activeMission.title)` needs only \(shortage) more real actions before it moves to completion."
            )
        }
        if board.missions.contains(where: { $0.progress.isCompleted }) {
            return localizedCopy(
                "이미 끝난 미션은 아래 완료 목록으로 옮겨져 다시 진행 카드와 섞이지 않아요.",
                "Finished missions are moved into the completed list so they do not mix with active cards."
            )
        }
        return localizedCopy(
            "오늘은 보조 미션이 열리지 않았더라도, 도움이 필요하면 이 설명을 다시 열 수 있어요.",
            "Even if no backup mission is open today, you can always reopen this explanation when you need it."
        )
    }
}
